'use strict';

const nodemailer = require('nodemailer');
const env = require('../config/env');
const logger = require('../config/logger');

let transporter = null;

if (env.mail.user && env.mail.pass) {
  transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: env.mail.user,
      pass: env.mail.pass,
    },
  });
} else {
  logger.warn('Nodemailer config is missing. Email features will be disabled or simulated.');
}

async function sendMail(options) {
  if (!transporter) {
    logger.info(`[SIMULATED EMAIL] To: ${options.to}, Subject: ${options.subject}`);
    return;
  }
  
  const mailOptions = {
    from: `"SpendDiary" <${env.mail.user}>`,
    ...options
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    logger.info(`Email sent to ${options.to}: ${info.messageId}`);
    return info;
  } catch (error) {
    logger.error('Error sending email:', error);
    throw error;
  }
}

async function sendBanNotification(email, reason) {
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333;">
      <h2 style="color: #ef4444;">Tài khoản bị khóa</h2>
      <p>Xin chào,</p>
      <p>Tài khoản SpendDiary của bạn đã bị khóa với lý do sau:</p>
      <blockquote style="border-left: 4px solid #ef4444; padding-left: 16px; margin-left: 0; font-weight: bold; background: #fef2f2; padding: 12px;">
        ${reason || 'Vi phạm điều khoản sử dụng'}
      </blockquote>
      <p>Nếu bạn cho rằng đây là một sự nhầm lẫn, vui lòng mở ứng dụng SpendDiary và chọn mục <b>"Gửi khiếu nại"</b> tại màn hình đăng nhập để yêu cầu mở khóa tài khoản.</p>
      <p>Trân trọng,<br/>Đội ngũ SpendDiary</p>
    </div>
  `;

  return sendMail({
    to: email,
    subject: 'Thông báo khóa tài khoản SpendDiary',
    html
  });
}

async function sendUnbanNotification(email, username) {
  const name = username || 'bạn';
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333; line-height: 1.6;">
      <h2 style="color: #10b981;">Tài khoản đã được mở khóa</h2>
      <p>Xin chào <strong>${name}</strong>,</p>
      <p>Chúng tôi xin thông báo rằng tài khoản SpendDiary của bạn đã được quản trị viên mở khóa thành công.</p>
      <p>Hiện tại bạn đã có thể đăng nhập lại vào ứng dụng và tiếp tục sử dụng tất cả các dịch vụ của SpendDiary một cách bình thường.</p>
      <p style="margin-top: 24px;">Trân trọng,<br/><strong>Đội ngũ SpendDiary</strong></p>
    </div>
  `;

  return sendMail({
    to: email,
    subject: '[SpendDiary] Thông báo mở khóa tài khoản',
    html
  });
}

async function sendAppealApprovedNotification(email, username) {
  const name = username || 'bạn';
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333; line-height: 1.6;">
      <h2 style="color: #10b981;">Khiếu nại được chấp thuận</h2>
      <p>Xin chào <strong>${name}</strong>,</p>
      <p>Yêu cầu khiếu nại mở khóa tài khoản SpendDiary của bạn đã được ban quản trị xem xét và <strong>chấp thuận</strong>.</p>
      <p>Tài khoản của bạn đã được khôi phục trạng thái hoạt động. Bạn có thể mở ứng dụng SpendDiary để đăng nhập ngay bây giờ.</p>
      <p style="margin-top: 24px;">Cảm ơn sự kiên nhẫn của bạn.<br/>Trân trọng,<br/><strong>Đội ngũ SpendDiary</strong></p>
    </div>
  `;

  return sendMail({
    to: email,
    subject: '[SpendDiary] Khiếu nại mở khóa tài khoản đã được chấp thuận',
    html
  });
}

async function sendAppealRejectedNotification(email, username, adminNote) {
  const name = username || 'bạn';
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333; line-height: 1.6;">
      <h2 style="color: #ef4444;">Kết quả xem xét khiếu nại</h2>
      <p>Xin chào <strong>${name}</strong>,</p>
      <p>Yêu cầu khiếu nại mở khóa tài khoản SpendDiary của bạn đã được ban quản trị xem xét.</p>
      <p>Rất tiếc, chúng tôi <strong>chưa thể mở khóa</strong> tài khoản của bạn tại thời điểm này.</p>
      <blockquote style="border-left: 4px solid #ef4444; padding-left: 16px; margin: 16px 0; background: #fef2f2; padding: 12px; border-radius: 4px;">
        <strong>Lý do từ ban quản trị:</strong><br/>
        ${adminNote || 'Tài khoản không đáp ứng các tiêu chuẩn và điều khoản bảo mật của hệ thống.'}
      </blockquote>
      <p>Nếu bạn có thêm câu hỏi hoặc bằng chứng bổ sung, vui lòng liên hệ với bộ phận hỗ trợ của chúng tôi.</p>
      <p style="margin-top: 24px;">Trân trọng,<br/><strong>Đội ngũ SpendDiary</strong></p>
    </div>
  `;

  return sendMail({
    to: email,
    subject: '[SpendDiary] Kết quả xem xét khiếu nại mở khóa tài khoản',
    html
  });
}

module.exports = {
  sendMail,
  sendBanNotification,
  sendUnbanNotification,
  sendAppealApprovedNotification,
  sendAppealRejectedNotification
};
