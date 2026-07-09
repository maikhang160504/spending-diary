'use strict';

const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');
const transactionsService = require('../transactions/transactions.service');

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

module.exports = { list, getById, create, update, remove };
