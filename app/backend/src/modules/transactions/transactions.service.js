'use strict';

const { query, withTransaction } = require('../../config/db');
const ApiError = require('../../utils/ApiError');
const walletService = require('../wallets/wallets.service');
const { paginate } = require('../../utils/paginate');
const { normalizeMascotMood } = require('../../utils/mascotMood');
const {
  resolveCategoryCorrectionKeyword,
  isInvalidPersonalizationKeyword,
} = require('../../utils/billPersonalization');

function row(r) {
  return {
    id: r.id,
    walletId: r.wallet_id,
    creatorId: r.creator_id,
    categoryId: r.category_id,
    categoryCode: r.category_code,
    amount: Number(r.amount),
    type: r.type,
    source: r.source,
    note: r.note,
    imageUrl: r.image_url,
    thumbnailUrl: r.thumbnail_url,
    aiExtracted: r.ai_extracted,
    aiConfidence: r.ai_confidence !== null ? Number(r.ai_confidence) : null,
    aiMeta: r.ai_meta || {},
    mascotMood: r.ai_emotion || r.mascot_mood || null,
    aiComment: r.ai_message || r.ai_comment || null,
    occurredAt: r.occurred_at,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
    storyId: r.story_id || null,
    storyUserId: r.story_user_id || null,
    username: r.username || null,
    userAvatar: r.avatar_url || null,
    isDraft: r.is_draft || false,
    originalText: r.original_text || null,
    processingStatus: r.processing_status || 'done',
  };
}

async function findCategoryByCode(userId, code, type) {
  if (!code) return null;
  const r = await query(
    `SELECT id FROM categories
     WHERE code = $1
       AND (owner_id IS NULL OR owner_id = $2)
       AND (type = $3 OR type = 'both')
       AND is_active = TRUE
     ORDER BY owner_id NULLS LAST
     LIMIT 1`,
    [code, userId, type]
  );
  return r.rows[0]?.id || null;
}

async function create(userId, payload) {
  await walletService.assertMember(payload.walletId, userId, ['owner', 'member']);
  const categoryId = await findCategoryByCode(userId, payload.categoryCode, payload.type);

  const tx = await withTransaction(async (client) => {
    // 1. Create a story
    const storyTitle = payload.note || payload.categoryCode || 'Giao dịch mới';
    const storyRes = await client.query(
      `INSERT INTO stories (user_id, wallet_id, title, total_amount, cover_image_url, occurred_on)
       VALUES ($1, $2, $3, $4, $5, COALESCE($6::date, CURRENT_DATE))
       RETURNING id`,
      [
        userId,
        payload.walletId,
        storyTitle,
        payload.amount,
        payload.imageUrl || null,
        payload.occurredAt ? payload.occurredAt.split('T')[0] : null,
      ]
    );
    const storyId = storyRes.rows[0].id;

    // 2. Create a story item — raw_text ưu tiên câu gốc user nhập (originalText)
    const itemRes = await client.query(
      `INSERT INTO story_items (story_id, raw_text, media_url, media_type)
       VALUES ($1, $2, $3, $4)
       RETURNING id`,
      [
        storyId,
        payload.originalText || payload.note || null,
        payload.imageUrl || null,
        payload.imageUrl ? 'image' : 'text',
      ]
    );
    const storyItemId = itemRes.rows[0].id;

    // 3. Create an AI comment if LLM story is in aiMeta
    const nlu = payload.aiMeta?.nlu;
    const llmStory =
      nlu?.gemini_json?.response ||
      nlu?.gemini_json?.story ||
      nlu?.nlg_response ||
      nlu?.response ||
      payload.aiComment;
    const intent = nlu?.intent || 'Record';
    const moodRaw =
      nlu?.mimo_emotion ||
      nlu?.llm_emotion ||
      nlu?.mascot_mood ||
      nlu?.gemini_json?.mimo_emotion ||
      nlu?.gemini_json?.emotion ||
      nlu?.llama_json?.mimo_emotion ||
      nlu?.llama_json?.emotion ||
      payload.mascotMood;
    const mascotMood = normalizeMascotMood(moodRaw, intent);
    const commentText = llmStory || payload.aiComment;
    if (commentText) {
      await client.query(
        `INSERT INTO ai_comments (story_id, content_text, visual_state, emotion)
         VALUES ($1, $2, $3, $4)`,
        [
          storyId,
          commentText,
          mascotMood,
          mascotMood,
        ]
      );
    }

    // 4. Create the transaction and link it to storyItemId
    const r = await client.query(
      `INSERT INTO transactions
         (wallet_id, creator_id, category_id, category_code, amount, type, source,
          note, image_url, thumbnail_url, ai_extracted, ai_confidence, ai_meta,
          occurred_at, story_item_id, is_draft)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13,
               COALESCE($14::timestamptz, NOW()), $15, $16)
       RETURNING *`,
      [
        payload.walletId,
        userId,
        categoryId,
        payload.categoryCode || null,
        payload.amount,
        payload.type,
        payload.source,
        payload.note || null,
        payload.imageUrl || null,
        payload.thumbnailUrl || null,
        payload.aiExtracted || payload.source === 'text' || payload.source === 'bill' || false,
        payload.aiConfidence || null,
        payload.aiMeta || {},
        payload.occurredAt || null,
        storyItemId,
        payload.isDraft || false,
      ]
    );
    const tx = r.rows[0];
    tx.story_id = storyId;
    return row(tx);
  });

  if (payload.type === 'expense' && payload.categoryCode) {
    setImmediate(() => checkBudgetLimitsAndAlert(userId, payload.categoryCode, payload.walletId));
  }

  // Automatically log correction if the category was updated before saving (AI extraction)
  if (tx.ai_extracted && payload.aiMeta?.nlu) {
    const predictedCategory = payload.aiMeta.nlu.categoryCode || payload.aiMeta.nlu.category;
    if (predictedCategory && payload.categoryCode && payload.categoryCode !== predictedCategory) {
      const text = resolveCategoryCorrectionKeyword(tx);
      if (text) {
        try {
          const recordType = (payload.type || 'expense').toLowerCase() === 'income' ? 'Income' : 'Expense';
          await query(
            `INSERT INTO user_corrections
               (user_id, text, intent, category_code, record_type, predicted, source)
             VALUES ($1, $2, 'Record', $3, $4, $5, 'user')`,
            [userId, text, payload.categoryCode, recordType, payload.aiMeta.nlu]
          );

          const cleanedText = text.trim().toLowerCase();
          await query(
            `INSERT INTO user_category_mappings (user_id, keyword, category_code, updated_at)
             VALUES ($1, $2, $3, NOW())
             ON CONFLICT (user_id, keyword)
             DO UPDATE SET category_code = EXCLUDED.category_code, updated_at = NOW()`,
            [userId, cleanedText, payload.categoryCode]
          );
        } catch (err) {
          console.error('[NLU Personalization] Failed to write correction triggers:', err.message);
        }
      }
    }
  }

  return row(tx);
}

async function listForUser(userId, filters) {
  const { limit, offset, page, pageSize } = paginate(filters);

  const conds = ['t.is_deleted = FALSE'];
  const values = [];

  // Restrict to wallets the user belongs to.
  values.push(userId);
  conds.push(
    `t.wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $${values.length})`
  );

  if (filters.walletId) {
    values.push(filters.walletId);
    conds.push(`t.wallet_id = $${values.length}`);
  }
  if (filters.categoryCode) {
    values.push(filters.categoryCode);
    conds.push(`t.category_code = $${values.length}`);
  }
  if (filters.type) {
    values.push(filters.type);
    conds.push(`t.type = $${values.length}`);
  }
  if (filters.from) {
    values.push(filters.from);
    conds.push(`t.occurred_at >= $${values.length}`);
  }
  if (filters.to) {
    values.push(filters.to);
    conds.push(`t.occurred_at <= $${values.length}`);
  }

  const where = conds.join(' AND ');

  const totalQ = await query(`SELECT COUNT(*)::int AS c FROM transactions t WHERE ${where}`, values);
  values.push(limit, offset);
  const dataQ = await query(
    `SELECT t.*, si.story_id,
            si.raw_text AS original_text,
            s.user_id AS story_user_id,
            ac.content_text AS ai_message,
            ac.emotion AS ai_emotion,
            u.username,
            u.avatar_url
     FROM transactions t
     LEFT JOIN story_items si ON t.story_item_id = si.id
     LEFT JOIN stories s ON s.id = si.story_id
     LEFT JOIN ai_comments ac ON ac.story_id = si.story_id
     LEFT JOIN users u ON u.id = t.creator_id
     WHERE ${where}
     ORDER BY t.occurred_at DESC, t.created_at DESC
     LIMIT $${values.length - 1} OFFSET $${values.length}`,
    values
  );
  return {
    page,
    pageSize,
    total: totalQ.rows[0].c,
    items: dataQ.rows.map(row),
  };
}

async function getById(userId, id) {
  const r = await query(
    `SELECT t.*, si.story_id,
            ac.content_text AS ai_message,
            ac.emotion AS ai_emotion
     FROM transactions t
     JOIN wallet_members wm ON wm.wallet_id = t.wallet_id AND wm.user_id = $1
     LEFT JOIN story_items si ON t.story_item_id = si.id
     LEFT JOIN ai_comments ac ON ac.story_id = si.story_id
     WHERE t.id = $2 AND t.is_deleted = FALSE`,
    [userId, id]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Transaction not found.');
  return row(r.rows[0]);
}

async function update(userId, id, payload) {
  // Make sure user can access tx (also returns wallet to assert role).
  const current = await query(
    `SELECT t.wallet_id, t.type, t.category_code, t.note, t.source, t.ai_extracted, t.ai_meta FROM transactions t
     JOIN wallet_members wm ON wm.wallet_id = t.wallet_id AND wm.user_id = $1
     WHERE t.id = $2 AND t.is_deleted = FALSE`,
    [userId, id]
  );
  if (current.rowCount === 0) throw ApiError.notFound('Transaction not found.');
  await walletService.assertMember(current.rows[0].wallet_id, userId, ['owner', 'member']);

  const fields = [];
  const values = [];
  let i = 1;
  for (const [k, col] of [
    ['amount', 'amount'],
    ['type', 'type'],
    ['note', 'note'],
    ['categoryCode', 'category_code'],
    ['imageUrl', 'image_url'],
    ['thumbnailUrl', 'thumbnail_url'],
    ['isDraft', 'is_draft'],
    ['processingStatus', 'processing_status'],
  ]) {
    if (payload[k] !== undefined) {
      fields.push(`${col} = $${i++}`);
      values.push(payload[k]);
    }
  }
  if (payload.occurredAt !== undefined) {
    fields.push(`occurred_at = $${i++}`);
    values.push(payload.occurredAt);
  }
  if (payload.categoryCode !== undefined) {
    const newType = payload.type || current.rows[0].type;
    const catId = await findCategoryByCode(userId, payload.categoryCode, newType);
    fields.push(`category_id = $${i++}`);
    values.push(catId);
  }
  if (fields.length === 0) throw ApiError.badRequest('No fields to update.');
  fields.push(`updated_at = NOW()`);
  values.push(id);
  const r = await query(
    `UPDATE transactions SET ${fields.join(', ')} WHERE id = $${i} RETURNING *`,
    values
  );

  // Automatically log correction if the category was updated for an AI-extracted transaction
  const oldTx = current.rows[0];
  if (payload.categoryCode !== undefined && payload.categoryCode !== oldTx.category_code) {
    if (oldTx.ai_extracted) {
      const text = resolveCategoryCorrectionKeyword(oldTx);
      if (text) {
        try {
          const recordType = (payload.type || oldTx.type || 'expense').toLowerCase() === 'income' ? 'Income' : 'Expense';
          // Log into user_corrections
          await query(
            `INSERT INTO user_corrections
               (user_id, text, intent, category_code, record_type, predicted, source)
             VALUES ($1, $2, 'Record', $3, $4, $5, 'user')`,
            [
              userId,
              text,
              payload.categoryCode,
              recordType,
              oldTx.ai_meta?.nlu || null
            ]
          );

          // Upsert into user_category_mappings (Layer 1 exact override)
          const cleanedText = text.trim().toLowerCase();
          await query(
            `INSERT INTO user_category_mappings (user_id, keyword, category_code, updated_at)
             VALUES ($1, $2, $3, NOW())
             ON CONFLICT (user_id, keyword)
             DO UPDATE SET category_code = EXCLUDED.category_code, updated_at = NOW()`,
            [userId, cleanedText, payload.categoryCode]
          );
        } catch (err) {
          // Non-blocking error logging
          console.error('[NLU Personalization] Failed to write correction triggers:', err.message);
        }
      }
    }
  }

  const updatedTx = row(r.rows[0]);

  if (updatedTx.type === 'expense') {
    if (payload.amount !== undefined || payload.categoryCode !== undefined) {
      setImmediate(() => checkBudgetLimitsAndAlert(userId, updatedTx.categoryCode, updatedTx.walletId));
    }
  }

  return updatedTx;
}

async function softDelete(userId, id) {
  const r = await query(
    `UPDATE transactions t SET is_deleted = TRUE, updated_at = NOW()
     WHERE t.id = $2
       AND EXISTS (SELECT 1 FROM wallet_members wm
                   WHERE wm.wallet_id = t.wallet_id AND wm.user_id = $1)
     RETURNING id`,
    [userId, id]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Transaction not found.');
}

async function createFromAi(userId, payload) {
  return withTransaction(async (client) => {
    const tx = await create(userId, payload);
    return tx;
  });
}

async function checkBudgetLimitsAndAlert(userId, categoryCode, walletId) {
  if (!categoryCode) return;

  const budgetsService = require('../budgets/budgets.service');
  const { dispatchUserNotification } = require('../../services/notificationDispatch');

  try {
    // 15% Income Exceeded Checker
    try {
      const incomeRes = await query(
        `SELECT COALESCE(SUM(amount), 0) AS total_income 
         FROM transactions 
         WHERE wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)
           AND type = 'income' AND is_deleted = FALSE 
           AND date_trunc('month', occurred_at) = date_trunc('month', NOW())`,
        [userId]
      );
      let monthlyIncome = Number(incomeRes.rows[0]?.total_income || 0);
      
      if (monthlyIncome <= 0) {
        const avgIncomeRes = await query(
          `SELECT COALESCE(AVG(monthly_sum), 0) AS avg_income FROM (
             SELECT SUM(amount) AS monthly_sum 
             FROM transactions 
             WHERE wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)
               AND type = 'income' AND is_deleted = FALSE
               AND occurred_at >= NOW() - INTERVAL '3 months'
             GROUP BY date_trunc('month', occurred_at)
           ) t`,
          [userId]
        );
        monthlyIncome = Number(avgIncomeRes.rows[0]?.avg_income || 0);
      }
      
      if (monthlyIncome <= 0) {
        monthlyIncome = 8000000; // Fallback
      }

      const spentRes = await query(
        `SELECT COALESCE(SUM(amount), 0) AS total_spent 
         FROM transactions 
         WHERE wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)
           AND type = 'expense' AND category_code = $2 AND is_deleted = FALSE 
           AND date_trunc('month', occurred_at) = date_trunc('month', NOW())`,
        [userId, categoryCode]
      );
      const categorySpent = Number(spentRes.rows[0]?.total_spent || 0);

      if (categorySpent > 0.15 * monthlyIncome) {
        const localDateStr = new Date(Date.now() + 7 * 3600000).toISOString().split('T')[0];
        const timePeriod = `exceed_15_${categoryCode}`.substring(0, 20);
        
        const logCheck = await query(
          `SELECT 1 FROM user_notification_logs 
           WHERE user_id = $1 AND sent_date = $2::date AND time_period = $3`,
          [userId, localDateStr, timePeriod]
        );

        if (logCheck.rows.length === 0) {
          await query(
            `INSERT INTO user_notification_logs (user_id, notification_type, time_period, sent_date)
             VALUES ($1, 'MASCOT_EXCEED_15_ALERT', $2, $3::date)`,
            [userId, timePeriod, localDateStr]
          );

          const VI_CATEGORY_LABELS = {
            'Food': 'Ăn uống',
            'Transport': 'Di chuyển',
            'Housing': 'Nhà ở',
            'Shopping': 'Mua sắm',
            'Entertainment': 'Giải trí',
            'Health': 'Sức khỏe',
            'Education': 'Giáo dục',
            'Beauty': 'Làm đẹp',
            'Social': 'Xã hội',
            'Others': 'Tiêu dùng khác',
          };
          const catLabel = VI_CATEGORY_LABELS[categoryCode] || categoryCode;
          const pct = Math.round((categorySpent / monthlyIncome) * 100);
          
          const title = '💡 Gợi ý từ Mimo';
          const message = `Mimo nhận thấy bạn đã tiêu dùng cho '${catLabel}' (${pct}% thu nhập). Bạn nên thiết lập hạn mức để tránh thâm hụt nhé!`;

          await dispatchUserNotification(userId, {
            type: 'MASCOT_EXCEED_15_ALERT',
            payload: {
              title,
              message,
              categoryCode,
              usagePct: pct,
              suggestedLimit: Math.round(monthlyIncome * 0.10),
              deepLink: `/limits?categoryCode=${categoryCode}`,
            },
          });
          console.log(`[15% Exceeded Suggest] Notification dispatched to user ${userId} for ${categoryCode}`);
        }
      }
    } catch (err) {
      console.error('[15% Monitor check] failed:', err.message);
    }

    const summaries = await budgetsService.summary(userId);
    const budget = summaries.find(b => b.categoryCode === categoryCode && b.isActive);
    if (!budget) {
      // Suggest setting a budget limit for a category that doesn't have one
      try {
        const localDateStr = new Date(Date.now() + 7 * 3600000).toISOString().split('T')[0];
        const timePeriod = `limit_${categoryCode}`.substring(0, 20); // Max 20 chars for time_period
        
        const logCheck = await query(
          `SELECT 1 FROM user_notification_logs 
           WHERE user_id = $1 AND sent_date = $2::date AND time_period = $3`,
          [userId, localDateStr, timePeriod]
        );

        if (logCheck.rows.length === 0) {
          try {
            await query(
              `INSERT INTO user_notification_logs (user_id, notification_type, time_period, sent_date)
               VALUES ($1, 'BUDGET_SUGGEST_LIMIT', $2, $3::date)`,
              [userId, timePeriod, localDateStr]
            );
          } catch (dbErr) {
            return;
          }

          const VI_CATEGORY_LABELS = {
            'Food': 'Ăn uống',
            'Transport': 'Di chuyển',
            'Housing': 'Nhà ở',
            'Shopping': 'Mua sắm',
            'Entertainment': 'Giải trí',
            'Health': 'Sức khỏe',
            'Education': 'Giáo dục',
            'Beauty': 'Làm đẹp',
            'Social': 'Xã hội',
            'Others': 'Tiêu dùng khác',
          };
          const catLabel = VI_CATEGORY_LABELS[categoryCode] || categoryCode;
          const title = '💡 Gợi ý đặt hạn mức';
          const message = `Bạn vừa chi tiêu cho '${catLabel}' nhưng chưa đặt hạn mức. Hãy đặt hạn mức để kiểm soát chi tiêu tốt hơn nhé!`;

          await dispatchUserNotification(userId, {
            type: 'BUDGET_SUGGEST_LIMIT',
            payload: {
              title,
              message,
              categoryCode,
              deepLink: `/limits?categoryCode=${categoryCode}`,
            },
          });
          console.log(`[Budget Suggest] Notification dispatched to user ${userId} to set budget limit for ${categoryCode}`);
        }
      } catch (err) {
        console.error('[Budget Suggest] Failed to run suggestion check:', err.message);
      }
      return;
    }

    if (!budget.alertEnabled) {
      return;
    }

    const limit = budget.amountLimit;
    const spent = budget.spent;
    const usagePct = budget.usagePct; // e.g. 85.5

    if (usagePct >= 80) {
      const VI_CATEGORY_LABELS = {
        'Food': 'Ăn uống',
        'Transport': 'Di chuyển',
        'Housing': 'Nhà ở',
        'Shopping': 'Mua sắm',
        'Entertainment': 'Giải trí',
        'Health': 'Sức khỏe',
        'Education': 'Giáo dục',
        'Beauty': 'Làm đẹp',
        'Social': 'Xã hội',
        'Others': 'Tiêu dùng khác',
      };
      const catLabel = VI_CATEGORY_LABELS[categoryCode] || categoryCode;

      const title = usagePct >= 100 ? '🚨 Vượt hạn mức chi tiêu!' : '⚠️ Sắp chạm hạn mức chi tiêu!';
      const message = usagePct >= 100
        ? `Nguy hiểm! Danh mục '${catLabel}' tháng này đã tiêu hết ${usagePct}% hạn mức. Chạm vào đây để AI tư vấn cắt giảm chi tiêu ngay.`
        : `Cảnh báo! Danh mục '${catLabel}' tháng này đã đạt ${usagePct}% hạn mức. Chạm vào đây để AI lập thực đơn tiết kiệm nhé.`;

      await dispatchUserNotification(userId, {
        type: 'BUDGET_ALERT',
        payload: {
          title,
          message,
          categoryCode,
          usagePct,
          limitAmount: limit,
          spentAmount: spent,
          deepLink: '/chat',
        },
      });
      console.log(`[Budget Alert] Notification dispatched to user ${userId} for category ${categoryCode} (spent: ${spent}/${limit}, ${usagePct}%)`);
    }
  } catch (err) {
    console.error('[Budget Alert] check failed:', err.message);
  }
}

function inferRangeForExport(period, dateStr) {
  const now = dateStr ? new Date(dateStr) : new Date();
  const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0);
  const endOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59);

  if (period === 'day') {
    const from = startOfDay(now);
    const to = endOfDay(now);
    return { from: from.toISOString(), to: to.toISOString() };
  }
  if (period === 'week') {
    const from = startOfDay(now);
    const day = from.getDay();
    const diff = day === 0 ? 6 : day - 1;
    from.setDate(from.getDate() - diff);
    const to = new Date(from);
    to.setDate(to.getDate() + 6);
    return { from: from.toISOString(), to: endOfDay(to).toISOString() };
  }
  if (period === 'month') {
    const from = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0);
    const to = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);
    return { from: from.toISOString(), to: to.toISOString() };
  }
  const from = new Date(now.getFullYear() - 10, now.getMonth(), 1);
  return { from: from.toISOString(), to: now.toISOString() };
}

module.exports = {
  create,
  listForUser,
  getById,
  update,
  softDelete,
  createFromAi,
  findCategoryByCode,
  checkBudgetLimitsAndAlert,
  inferRangeForExport,
};
