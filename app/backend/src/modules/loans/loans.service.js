'use strict';

const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');
const transactionsService = require('../transactions/transactions.service');
const { dispatchUserNotification } = require('../../services/notificationDispatch');

async function list(userId) {
  const r = await query(
    `SELECT l.*, w.name AS wallet_name 
     FROM loans l
     LEFT JOIN wallets w ON w.id = l.wallet_id
     WHERE l.user_id = $1 
     ORDER BY l.due_date ASC`,
    [userId]
  );
  return r.rows;
}

async function getById(userId, loanId) {
  const r = await query(
    `SELECT l.*, w.name AS wallet_name 
     FROM loans l
     LEFT JOIN wallets w ON w.id = l.wallet_id
     WHERE l.id = $1 AND l.user_id = $2`,
    [loanId, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Loan not found.');
  return r.rows[0];
}

async function create(userId, data) {
  const { wallet_id, contact_name, type, amount, due_date, note, interest_rate, create_transaction } = data;
  const r = await query(
    `INSERT INTO loans (user_id, wallet_id, contact_name, type, amount, due_date, note, interest_rate)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [userId, wallet_id || null, contact_name, type, amount, due_date || null, note || '', interest_rate || 0]
  );
  const loan = r.rows[0];

  if (create_transaction && wallet_id) {
    const txType = type === 'lend' ? 'expense' : 'income';
    await transactionsService.create(userId, {
      walletId: wallet_id,
      categoryCode: 'Others',
      type: txType,
      amount: amount,
      note: (type === 'lend' ? 'Cho vay: ' : 'Đi vay: ') + contact_name
    }).catch(e => console.error('Failed to create transaction for loan:', e));
  }

  // Tự động gửi thông báo ngay nếu ngày đến hạn <= 2 ngày kể từ hôm nay (ví dụ: ngày mai)
  if (due_date) {
    try {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const due = new Date(due_date);
      due.setHours(0, 0, 0, 0);
      const diffDays = Math.round((due - today) / (1000 * 60 * 60 * 24));
      if (diffDays >= 0 && diffDays <= 2) {
        const typeLabel = type === 'lend' ? 'thu nợ' : 'trả nợ';
        const isDueToday = diffDays === 0;
        const isDueTomorrow = diffDays === 1;
        const title = isDueToday
          ? `Đến hạn ${typeLabel} hôm nay 🔔`
          : isDueTomorrow
          ? `Sắp đến hạn ${typeLabel} ngày mai ⏳`
          : `Sắp đến hạn ${typeLabel} (còn 2 ngày) ⏳`;
        const timeStr = isDueToday ? 'hôm nay' : isDueTomorrow ? 'vào ngày mai' : 'sau 2 ngày nữa';
        const formattedAmount = Number(amount || 0).toLocaleString('vi-VN');
        const formattedDate = `${due.getDate().toString().padStart(2, '0')}/${(due.getMonth() + 1).toString().padStart(2, '0')}/${due.getFullYear()}`;
        const message = `Khoản ${typeLabel} với ${contact_name || 'người liên hệ'} số tiền ${formattedAmount}đ sẽ đến hạn ${timeStr} (${formattedDate}).`;
        
        await dispatchUserNotification(userId, {
          type: 'LOAN_REMINDER',
          payload: {
            title,
            message,
            deepLink: '/app/settings',
          },
        });
      }
    } catch (e) {
      console.error('Error dispatching immediate loan notification:', e);
    }
  }

  return loan;
}

async function update(userId, loanId, data) {
  const { contact_name, amount, paid_amount, due_date, status, note, interest_rate } = data;
  const r = await query(
    `UPDATE loans 
     SET contact_name = COALESCE($1, contact_name),
         amount = COALESCE($2, amount),
         paid_amount = COALESCE($3, paid_amount),
         due_date = COALESCE($4, due_date),
         status = COALESCE($5, status),
         note = COALESCE($6, note),
         interest_rate = COALESCE($7, interest_rate),
         updated_at = NOW()
     WHERE id = $8 AND user_id = $9
     RETURNING *`,
    [contact_name, amount, paid_amount, due_date, status, note, interest_rate, loanId, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Loan not found.');
  return r.rows[0];
}

async function remove(userId, loanId) {
  const r = await query(
    `DELETE FROM loans WHERE id = $1 AND user_id = $2 RETURNING id`,
    [loanId, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Loan not found.');
}

async function contribute(userId, loanId, amount, walletId) {
  const loan = await getById(userId, loanId);
  const newPaidAmount = Number(loan.paid_amount || 0) + Number(amount);
  const newStatus = newPaidAmount >= Number(loan.amount) ? 'completed' : loan.status;

  const r = await query(
    `UPDATE loans 
     SET paid_amount = $1, status = $2, updated_at = NOW()
     WHERE id = $3 AND user_id = $4
     RETURNING *`,
    [newPaidAmount, newStatus, loanId, userId]
  );

  if (walletId) {
    const txType = loan.type === 'lend' ? 'income' : 'expense'; // Tra tien cho vay la thu nhap, tra no la chi phi
    await transactionsService.create(userId, {
      walletId: walletId,
      categoryCode: 'Debt',
      type: txType,
      amount: amount,
      note: (loan.type === 'lend' ? 'Thu nợ: ' : 'Trả nợ: ') + loan.contact_name
    }).catch(e => console.error('Failed to create transaction for loan contribution:', e));
  }

  return r.rows[0];
}

module.exports = { list, getById, create, update, remove, contribute };
