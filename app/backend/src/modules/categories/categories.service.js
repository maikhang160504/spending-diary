'use strict';

const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

function row(r) {
  return {
    id: r.id,
    name: r.name,
    code: r.code,
    type: r.type,
    icon: r.icon,
    color: r.color,
    isSystem: !r.owner_id,
    isActive: r.is_active,
    createdAt: r.created_at,
  };
}

async function listAvailable(userId, { type } = {}) {
  const params = [userId];
  let where = '(owner_id IS NULL OR owner_id = $1) AND is_active = TRUE';
  if (type) {
    params.push(type);
    where += ` AND (type = $${params.length} OR type = 'both')`;
  }
  const r = await query(
    `SELECT id, owner_id, name, code, type, icon, color, is_active, created_at
     FROM categories WHERE ${where}
     ORDER BY owner_id NULLS FIRST, name`,
    params
  );
  return r.rows.map(row);
}

async function create(userId, payload) {
  const r = await query(
    `INSERT INTO categories (owner_id, name, code, type, icon, color)
     VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT DO NOTHING
     RETURNING id, owner_id, name, code, type, icon, color, is_active, created_at`,
    [userId, payload.name, payload.code, payload.type, payload.icon, payload.color]
  );
  if (r.rowCount === 0) {
    throw ApiError.conflict('A category with this code already exists.');
  }
  return row(r.rows[0]);
}

async function update(userId, id, payload) {
  const fields = [];
  const values = [];
  let i = 1;
  for (const k of ['name', 'code', 'type', 'icon', 'color']) {
    if (payload[k] !== undefined) {
      fields.push(`${k} = $${i++}`);
      values.push(payload[k]);
    }
  }
  if (fields.length === 0) throw ApiError.badRequest('No fields to update.');
  values.push(id, userId);
  const r = await query(
    `UPDATE categories SET ${fields.join(', ')}
     WHERE id = $${i++} AND owner_id = $${i}
     RETURNING id, owner_id, name, code, type, icon, color, is_active, created_at`,
    values
  );
  if (r.rowCount === 0) throw ApiError.notFound('Category not found.');
  return row(r.rows[0]);
}

async function remove(userId, id) {
  const r = await query(
    `UPDATE categories SET is_active = FALSE WHERE id = $1 AND owner_id = $2 RETURNING id`,
    [id, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Category not found.');
}

module.exports = { listAvailable, create, update, remove };
