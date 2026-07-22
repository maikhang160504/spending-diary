'use strict';

const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { OAuth2Client } = require('google-auth-library');
const nodemailer = require('nodemailer');
const jwt = require('jsonwebtoken');

const { query, withTransaction } = require('../../config/db');
const ApiError = require('../../utils/ApiError');
const logger = require('../../config/logger');
const {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} = require('../../utils/jwt');
const env = require('../../config/env');

const _googleClient = new OAuth2Client();

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

async function findUserByEmail(email) {
  const r = await query('SELECT * FROM users WHERE email = $1', [email]);
  return r.rows[0] || null;
}

async function findUserById(id) {
  const r = await query(
    `SELECT id, email, username, avatar_url, preferred_vibe, role, is_active, status, ban_reason, created_at,
            income_amount, job_title
     FROM users WHERE id = $1`,
    [id]
  );
  return r.rows[0] || null;
}

async function register({ email, password, username, preferredVibe = 'funny' }) {
  const existing = await findUserByEmail(email);
  if (existing) {
    throw ApiError.conflict('Email already registered.');
  }
  const hash = await bcrypt.hash(password, 10);
  const result = await withTransaction(async (client) => {
    const userInsert = await client.query(
      `INSERT INTO users (email, password_hash, username, preferred_vibe)
       VALUES ($1, $2, $3, $4)
       RETURNING id, email, username, avatar_url, preferred_vibe, role, created_at`,
      [email, hash, username, preferredVibe]
    );
    const user = userInsert.rows[0];
    const wallet = await client.query(
      `INSERT INTO wallets (owner_id, name, type, currency)
       VALUES ($1, 'Ví cá nhân', 'personal', 'VND') RETURNING id`,
      [user.id]
    );
    await client.query(
      `INSERT INTO wallet_members (wallet_id, user_id, role) VALUES ($1, $2, 'owner')`,
      [wallet.rows[0].id, user.id]
    );
    return { user, walletId: wallet.rows[0].id };
  });
  return issueTokens(result.user);
}

async function login({ email, password }) {
  const user = await findUserByEmail(email);
  if (!user || !user.is_active) {
    throw ApiError.unauthorized('Invalid credentials.');
  }
  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) {
    throw ApiError.unauthorized('Invalid credentials.');
  }
  await query('UPDATE users SET last_login_at = NOW() WHERE id = $1', [user.id]);
  return issueTokens(user);
}

async function issueTokens(user) {
  const accessToken = signAccessToken({ sub: user.id, email: user.email, role: user.role });
  const refreshToken = signRefreshToken({ sub: user.id });
  const expiresAt = new Date(Date.now() + env.jwt.refreshTtl * 1000);
  await query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
    [user.id, hashToken(refreshToken), expiresAt]
  );
  return {
    accessToken,
    refreshToken,
    expiresIn: env.jwt.accessTtl,
    user: {
      id: user.id,
      email: user.email,
      username: user.username,
      role: user.role,
      preferredVibe: user.preferred_vibe,
      avatarUrl: user.avatar_url,
      status: user.status,
      banReason: user.ban_reason
    },
  };
}

async function refresh({ refreshToken }) {
  let decoded;
  try {
    decoded = verifyRefreshToken(refreshToken);
  } catch (err) {
    throw ApiError.unauthorized('Invalid refresh token.', { reason: err.message });
  }
  const hash = hashToken(refreshToken);
  const r = await query(
    `SELECT id FROM refresh_tokens
     WHERE user_id = $1 AND token_hash = $2 AND revoked_at IS NULL AND expires_at > NOW()`,
    [decoded.sub, hash]
  );
  if (r.rowCount === 0) {
    throw ApiError.unauthorized('Refresh token revoked or expired.');
  }
  await query('UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = $1', [r.rows[0].id]);
  const user = await findUserById(decoded.sub);
  if (!user) throw ApiError.unauthorized('User not found.');
  return issueTokens({
    id: user.id,
    email: user.email,
    role: user.role,
    preferred_vibe: user.preferred_vibe,
    username: user.username,
    avatar_url: user.avatar_url,
    status: user.status,
    ban_reason: user.ban_reason
  });
}

async function logout({ refreshToken }) {
  try {
    const decoded = verifyRefreshToken(refreshToken);
    await query(
      `UPDATE refresh_tokens SET revoked_at = NOW()
       WHERE user_id = $1 AND token_hash = $2`,
      [decoded.sub, hashToken(refreshToken)]
    );
  } catch (_) {
    // ignore: idempotent logout
  }
}

async function changePassword(userId, { currentPassword, newPassword }) {
  const r = await query('SELECT password_hash FROM users WHERE id = $1', [userId]);
  const user = r.rows[0];
  if (!user) throw ApiError.notFound('User not found.');
  const ok = await bcrypt.compare(currentPassword, user.password_hash);
  if (!ok) throw ApiError.unauthorized('Current password is incorrect.');
  const newHash = await bcrypt.hash(newPassword, 10);
  await query('UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2', [newHash, userId]);
}

async function getStreak(userId) {
  // Get all distinct dates with transactions for this user (ordered desc)
  const r = await query(
    `SELECT DISTINCT day FROM (
       SELECT DATE(t.occurred_at) AS day
       FROM transactions t
       JOIN wallet_members wm ON wm.wallet_id = t.wallet_id
       WHERE wm.user_id = $1 AND t.is_deleted = FALSE
       UNION
       SELECT DATE(cm.created_at) AS day
       FROM chat_messages cm
       JOIN chat_sessions cs ON cs.id = cm.session_id
       WHERE cs.user_id = $1 AND cm.role = 'user'
     ) active_days
     ORDER BY day DESC`,
    [userId]
  );
  const dates = r.rows.map((row) => row.day); // Date objects from pg

  if (dates.length === 0) {
    return { currentStreak: 0, longestStreak: 0, totalDays: dates.length, lastActivityDate: null };
  }

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const startOfDay = (d) => {
    const x = new Date(d);
    x.setHours(0, 0, 0, 0);
    return x;
  };

  // Calculate current streak — KHOAN HỒNG 1 NGÀY:
  // bỏ lỡ đúng 1 ngày sẽ KHÔNG làm streak về 0 (chấp nhận khoảng cách ≤ 2 ngày).
  let currentStreak = 0;
  // dates đã sort giảm dần → dates[0] là ngày hoạt động gần nhất.
  const daysSinceLast = Math.round((today - startOfDay(dates[0])) / 86400000);
  if (daysSinceLast <= 2) {
    currentStreak = 1;
    for (let i = 1; i < dates.length; i++) {
      const prev = startOfDay(dates[i - 1]);
      const curr = startOfDay(dates[i]);
      const diff = Math.round((prev - curr) / 86400000);
      // diff === 1: liên tiếp; diff === 2: nghỉ đúng 1 ngày → vẫn giữ streak.
      if (diff <= 2) {
        currentStreak++;
      } else {
        break;
      }
    }
  }

  // Calculate longest streak
  let longestStreak = 0;
  let streak = 1;
  for (let i = 1; i < dates.length; i++) {
    const prev = new Date(dates[i - 1]);
    const curr = new Date(dates[i]);
    prev.setHours(0, 0, 0, 0);
    curr.setHours(0, 0, 0, 0);
    const diff = Math.round((prev - curr) / 86400000);
    if (diff === 1) {
      streak++;
    } else {
      longestStreak = Math.max(longestStreak, streak);
      streak = 1;
    }
  }
  longestStreak = Math.max(longestStreak, streak);

  return {
    currentStreak,
    longestStreak,
    totalDays: dates.length,
    lastActivityDate: dates[0] ? new Date(dates[0]).toISOString().split('T')[0] : null,
  };
}

async function googleLogin({ idToken }) {
  if (!idToken) {
    logger.warn('[googleLogin] idToken is missing in request body');
    throw ApiError.badRequest('idToken is required.');
  }

  let payload;
  if (idToken === 'mock-google-token' && process.env.NODE_ENV !== 'production') {
    logger.info('[googleLogin] Using mock Google login (development fallback mode)');
    payload = {
      sub: 'mock-google-id-123456789',
      email: 'mimo_google_dev@diary.local',
      name: 'Google Dev Test',
      picture: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80',
    };
  } else {
    try {
      logger.info({ audience: env.google.clientId }, '[googleLogin] Verifying real Google ID Token');
      const ticket = await _googleClient.verifyIdToken({
        idToken,
        audience: env.google.clientId || undefined,
      });
      payload = ticket.getPayload();
      logger.info({ email: payload.email, sub: payload.sub }, '[googleLogin] Google token verified successfully');
    } catch (err) {
      logger.error({ err: { message: err.message, stack: err.stack }, audience: env.google.clientId }, '[googleLogin] Real Google token verification failed');
      throw ApiError.unauthorized('Invalid Google token.', { reason: err.message });
    }
  }

  const googleId = payload.sub;
  const email = payload.email;
  const name = payload.name || payload.email.split('@')[0];
  const avatarUrl = payload.picture || null;

  // 1. Find by google_id
  let userRow = (await query('SELECT * FROM users WHERE google_id = $1', [googleId])).rows[0];

  // 2. Find by email → link google_id
  if (!userRow && email) {
    userRow = await findUserByEmail(email);
    if (userRow) {
      await query('UPDATE users SET google_id = $1, updated_at = NOW() WHERE id = $2', [googleId, userRow.id]);
      userRow.google_id = googleId;
    }
  }

  // 3. Create new user (no password)
  if (!userRow) {
    const result = await withTransaction(async (client) => {
      const userInsert = await client.query(
        `INSERT INTO users (email, google_id, username, avatar_url, preferred_vibe)
         VALUES ($1, $2, $3, $4, 'funny')
         RETURNING id, email, username, avatar_url, preferred_vibe, role, created_at`,
        [email, googleId, name, avatarUrl]
      );
      const user = userInsert.rows[0];
      const wallet = await client.query(
        `INSERT INTO wallets (owner_id, name, type, currency)
         VALUES ($1, 'Ví cá nhân', 'personal', 'VND') RETURNING id`,
        [user.id]
      );
      await client.query(
        `INSERT INTO wallet_members (wallet_id, user_id, role) VALUES ($1, $2, 'owner')`,
        [wallet.rows[0].id, user.id]
      );
      return user;
    });
    userRow = result;
  }

  if (!userRow.is_active && userRow.is_active !== undefined) {
    throw ApiError.unauthorized('Account is disabled.');
  }

  await query('UPDATE users SET last_login_at = NOW() WHERE id = $1', [userRow.id]);
  return issueTokens(userRow);
}

async function updateProfile(userId, payload) {
  const fields = [];
  const values = [userId];
  let idx = 2;

  if (payload.username !== undefined) {
    fields.push(`username = $${idx++}`);
    values.push(payload.username);
  }
  if (payload.avatarUrl !== undefined) {
    fields.push(`avatar_url = $${idx++}`);
    values.push(payload.avatarUrl);
  }
  if (payload.preferredVibe !== undefined) {
    fields.push(`preferred_vibe = $${idx++}`);
    values.push(payload.preferredVibe);
  }
  if (payload.age !== undefined) {
    fields.push(`age = $${idx++}`);
    values.push(payload.age ? parseInt(payload.age) : null);
  }
  if (payload.jobTitle !== undefined) {
    fields.push(`job_title = $${idx++}`);
    values.push(payload.jobTitle);
  }
  if (payload.incomeAmount !== undefined) {
    fields.push(`income_amount = $${idx++}`);
    values.push(payload.incomeAmount ? parseFloat(payload.incomeAmount) : 0);
  }
  if (payload.incomeType !== undefined) {
    fields.push(`income_type = $${idx++}`);
    values.push(payload.incomeType);
  }

  if (fields.length === 0) {
    return findUserById(userId);
  }

  fields.push('updated_at = NOW()');
  const r = await query(
    `UPDATE users SET ${fields.join(', ')} WHERE id = $1 RETURNING id, email, username, avatar_url, preferred_vibe, role, created_at, age, job_title, income_amount, income_type`,
    values
  );
  return r.rows[0];
}

async function forgotPassword(email) {
  const userRow = await findUserByEmail(email);
  if (!userRow) {
    throw ApiError.notFound('Email không tồn tại trong hệ thống.');
  }

  // Tạo mã OTP 6 số
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  // Set hết hạn 15 phút
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

  await query(
    'UPDATE users SET reset_otp = $1, reset_otp_expires = $2 WHERE id = $3',
    [otp, expiresAt, userRow.id]
  );

  // Gửi email
  if (!env.mail.user || !env.mail.pass) {
    logger.warn('Nodemailer config is missing. OTP generated but cannot send email.');
    if (env.nodeEnv !== 'production') {
      logger.info(`[DEV] Mã OTP cho ${email} là: ${otp}`);
      return; // Giả lập thành công ở dev mode
    }
    throw ApiError.internal('Hệ thống chưa cấu hình gửi email. Vui lòng liên hệ quản trị viên.');
  }

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: env.mail.user,
      pass: env.mail.pass,
    },
  });

  const mailOptions = {
    from: `"SpendDiary" <${env.mail.user}>`,
    to: email,
    subject: 'Mã xác nhận khôi phục mật khẩu',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #14B8A6;">SpendDiary</h2>
        <p>Xin chào,</p>
        <p>Bạn vừa yêu cầu khôi phục mật khẩu. Dưới đây là mã xác nhận (OTP) của bạn, có hiệu lực trong 15 phút:</p>
        <h1 style="background: #F1F5F9; padding: 16px; text-align: center; font-size: 32px; letter-spacing: 4px; color: #1E293B; border-radius: 8px;">${otp}</h1>
        <p>Nếu bạn không yêu cầu, vui lòng bỏ qua email này.</p>
        <p>Trân trọng,<br/>Đội ngũ SpendDiary</p>
      </div>
    `,
  };

  await transporter.sendMail(mailOptions);
  logger.info({ email }, 'Đã gửi email OTP khôi phục mật khẩu');
}

async function verifyResetOtp(email, otp) {
  const userRow = await findUserByEmail(email);
  if (!userRow) {
    throw ApiError.badRequest('Email hoặc mã xác nhận không hợp lệ.');
  }

  if (userRow.reset_otp !== otp) {
    throw ApiError.badRequest('Mã xác nhận không chính xác.');
  }

  if (new Date(userRow.reset_otp_expires) < new Date()) {
    throw ApiError.badRequest('Mã xác nhận đã hết hạn. Vui lòng yêu cầu lại.');
  }

  // Xóa mã OTP để không dùng lại được
  await query(
    'UPDATE users SET reset_otp = NULL, reset_otp_expires = NULL WHERE id = $1',
    [userRow.id]
  );

  // Cấp resetToken tạm thời có hạn 10 phút để người dùng đổi mật khẩu
  const resetToken = jwt.sign(
    { sub: userRow.id, intent: 'reset_password' },
    env.jwt.secret,
    { expiresIn: '10m' }
  );

  return { resetToken };
}

async function resetPassword(resetToken, newPassword) {
  let payload;
  try {
    payload = jwt.verify(resetToken, env.jwt.secret);
  } catch (e) {
    throw ApiError.badRequest('Phiên đổi mật khẩu đã hết hạn hoặc không hợp lệ.');
  }

  if (payload.intent !== 'reset_password') {
    throw ApiError.badRequest('Token không hợp lệ.');
  }

  const userId = payload.sub;
  const userRow = await findUserById(userId);
  if (!userRow) {
    throw ApiError.notFound('Người dùng không tồn tại.');
  }

  const hashed = await bcrypt.hash(newPassword, 12);
  await query('UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2', [hashed, userId]);
  
  logger.info({ userId }, 'Người dùng đã khôi phục mật khẩu thành công');
}

async function createAppeal(userId, reason) {
  if (!reason) {
    throw ApiError.badRequest('Vui lòng nhập lý do khiếu nại.');
  }
  const result = await query(
    'INSERT INTO ban_appeals (user_id, reason) VALUES ($1, $2) RETURNING id, status, created_at',
    [userId, reason]
  );
  return result.rows[0];
}

module.exports = {
  register,
  login,
  refresh,
  logout,
  findUserById,
  updateProfile,
  changePassword,
  getStreak,
  googleLogin,
  forgotPassword,
  verifyResetOtp,
  resetPassword,
  createAppeal
};
