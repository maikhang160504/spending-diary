'use strict';

const { pool } = require('../../config/db');
const { v4: uuidv4 } = require('uuid');

const generateInviteCode = () => {
  return Math.random().toString(36).substring(2, 8).toUpperCase();
};

async function createGroup(userId, userName, data) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // Create group
    const inviteCode = generateInviteCode();
    const groupRes = await client.query(`
      INSERT INTO expense_groups (name, description, invite_code, created_by)
      VALUES ($1, $2, $3, $4) RETURNING *
    `, [data.name, data.description || '', inviteCode, userId]);
    
    const group = groupRes.rows[0];
    
    // Add creator as member
    await client.query(`
      INSERT INTO group_members (group_id, user_id, display_name)
      VALUES ($1, $2, $3)
    `, [group.id, userId, userName]);
    
    // Add other members if provided
    if (data.members && data.members.length > 0) {
      for (const memberName of data.members) {
        if (memberName !== userName) {
          await client.query(`
            INSERT INTO group_members (group_id, display_name)
            VALUES ($1, $2)
          `, [group.id, memberName]);
        }
      }
    }
    
    await client.query('COMMIT');
    return group;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function listGroups(userId) {
  // Get all groups where user is a member
  const { rows } = await pool.query(`
    SELECT g.* 
    FROM expense_groups g
    JOIN group_members gm ON gm.group_id = g.id
    WHERE gm.user_id = $1
    ORDER BY g.created_at DESC
  `, [userId]);
  return rows;
}

async function joinGroup(userId, userName, inviteCode) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const groupRes = await client.query('SELECT * FROM expense_groups WHERE invite_code = $1', [inviteCode]);
    if (groupRes.rowCount === 0) {
      throw new Error('NOT_FOUND');
    }
    const group = groupRes.rows[0];
    
    // Check if already a member
    const memRes = await client.query('SELECT * FROM group_members WHERE group_id = $1 AND user_id = $2', [group.id, userId]);
    if (memRes.rowCount > 0) {
      return group; // Already joined
    }
    
    // Insert new member
    await client.query(`
      INSERT INTO group_members (group_id, user_id, display_name)
      VALUES ($1, $2, $3)
    `, [group.id, userId, userName]);
    
    await client.query('COMMIT');
    return group;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function getGroupDetails(groupId, userId) {
  // verify user is in group
  const verifyRes = await pool.query('SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2', [groupId, userId]);
  if (verifyRes.rowCount === 0) throw new Error('FORBIDDEN');
  
  const groupRes = await pool.query('SELECT * FROM expense_groups WHERE id = $1', [groupId]);
  const group = groupRes.rows[0];
  
  const membersRes = await pool.query('SELECT * FROM group_members WHERE group_id = $1 ORDER BY joined_at ASC', [groupId]);
  group.members = membersRes.rows;
  
  const txRes = await pool.query(`
    SELECT t.*, m.display_name as paid_by_name
    FROM group_transactions t
    JOIN group_members m ON t.paid_by = m.id
    WHERE t.group_id = $1
    ORDER BY t.occurred_at DESC
  `, [groupId]);
  group.transactions = txRes.rows;
  
  return {
    group: {
      id: group.id,
      name: group.name,
      description: group.description,
      invite_code: group.invite_code,
      created_at: group.created_at,
      created_by: group.created_by
    },
    members: group.members,
    transactions: group.transactions,
    debts: (await calculateSplit(groupId, userId)).settlements
  };
}

async function addTransaction(groupId, userId, data) {
  // verify user is in group
  const verifyRes = await pool.query('SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2', [groupId, userId]);
  if (verifyRes.rowCount === 0) throw new Error('FORBIDDEN');

  const { rows } = await pool.query(`
    INSERT INTO group_transactions (group_id, paid_by, amount, note, occurred_at, created_by)
    VALUES ($1, $2, $3, $4, $5, $6) RETURNING *
  `, [groupId, data.paidBy, data.amount, data.note || '', data.occurredAt || new Date(), userId]);
  return rows[0];
}

async function updateTransaction(txId, userId, data) {
  // Verify user is in group
  const txRes = await pool.query('SELECT group_id, paid_by FROM group_transactions WHERE id = $1', [txId]);
  if (txRes.rowCount === 0) throw new Error('NOT_FOUND');
  const groupId = txRes.rows[0].group_id;
  
  const verifyRes = await pool.query('SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2', [groupId, userId]);
  if (verifyRes.rowCount === 0) throw new Error('FORBIDDEN');
  
  const fields = [];
  const values = [];
  let i = 1;
  for (const [k, col] of [
    ['amount', 'amount'],
    ['note', 'note'],
    ['isDraft', 'is_draft'],
  ]) {
    if (data[k] !== undefined) {
      fields.push(`${col} = $${i++}`);
      values.push(data[k]);
    }
  }

  if (fields.length === 0) return txRes.rows[0]; // nothing to update

  values.push(txId);
  const q = `
    UPDATE group_transactions
    SET ${fields.join(', ')}
    WHERE id = $${i}
    RETURNING *
  `;
  const result = await pool.query(q, values);
  return result.rows[0];
}

async function calculateSplit(groupId, userId) {
  // get details manually instead of getGroupDetails to avoid circular call
  const groupRes = await pool.query('SELECT * FROM expense_groups WHERE id = $1', [groupId]);
  if (groupRes.rowCount === 0) return { totalAmount: 0, splitAmount: 0, settlements: [] };
  
  const membersRes = await pool.query('SELECT * FROM group_members WHERE group_id = $1', [groupId]);
  const members = membersRes.rows;
  const memberCount = members.length;
  
  const txRes = await pool.query('SELECT * FROM group_transactions WHERE group_id = $1', [groupId]);
  const transactions = txRes.rows;
  
  const totalAmount = transactions.reduce((sum, tx) => sum + parseFloat(tx.amount), 0);
  if (memberCount === 0 || totalAmount === 0) return { totalAmount, splitAmount: 0, settlements: [] };
  
  // Calculate balances based on algorithm
  const balances = {};
  members.forEach(m => { balances[m.id] = 0; });
  
  transactions.forEach(tx => {
    const amount = parseFloat(tx.amount);
    balances[tx.paid_by] += amount;
    
    const exactShare = amount / memberCount;
    const share = Math.ceil(exactShare / 1000) * 1000;
    
    members.forEach(m => {
      if (m.id === tx.paid_by) {
        balances[m.id] -= (amount - share * (memberCount - 1));
      } else {
        balances[m.id] -= share;
      }
    });
  });
  
  // Adjust balances based on settlements
  const setRes = await pool.query('SELECT * FROM group_settlements WHERE group_id = $1', [groupId]);
  setRes.rows.forEach(s => {
    const amt = parseFloat(s.amount);
    balances[s.from_member_id] += amt; // they paid, so balance increases
    balances[s.to_member_id] -= amt; // they received, so balance decreases
  });
  
  // Greedy algorithm to settle remaining debts
  let debtors = Object.keys(balances).filter(m => balances[m] < -0.01).map(m => ({ id: m, amount: -balances[m] })).sort((a, b) => b.amount - a.amount);
  let creditors = Object.keys(balances).filter(m => balances[m] > 0.01).map(m => ({ id: m, amount: balances[m] })).sort((a, b) => b.amount - a.amount);
  
  const settlements = [];
  let d = 0;
  let c = 0;
  
  while (d < debtors.length && c < creditors.length) {
    let debtor = debtors[d];
    let creditor = creditors[c];
    
    let amount = Math.min(debtor.amount, creditor.amount);
    
    const debtorInfo = members.find(m => m.id === debtor.id);
    const creditorInfo = members.find(m => m.id === creditor.id);
    
    settlements.push({
      id: `${debtor.id}_${creditor.id}`,
      from_member_id: debtor.id,
      from_member_name: debtorInfo ? debtorInfo.display_name : 'Unknown',
      to_member_id: creditor.id,
      to_member_name: creditorInfo ? creditorInfo.display_name : 'Unknown',
      amount: amount,
      status: 'pending'
    });
    
    debtor.amount -= amount;
    creditor.amount -= amount;
    
    if (debtor.amount < 0.01) d++;
    if (creditor.amount < 0.01) c++;
  }
  
  // Add already settled debts from group_settlements for UI display history
  setRes.rows.forEach(s => {
    const debtorInfo = members.find(m => m.id === s.from_member_id);
    const creditorInfo = members.find(m => m.id === s.to_member_id);
    settlements.push({
      id: s.id,
      from_member_id: s.from_member_id,
      from_member_name: debtorInfo ? debtorInfo.display_name : 'Unknown',
      to_member_id: s.to_member_id,
      to_member_name: creditorInfo ? creditorInfo.display_name : 'Unknown',
      amount: parseFloat(s.amount),
      status: 'settled'
    });
  });
  
  return {
    totalAmount,
    splitAmount: totalAmount / memberCount,
    settlements
  };
}

async function settleGroupDebt(groupId, userId, debtId) {
  // verify user is in group
  const verifyRes = await pool.query('SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2', [groupId, userId]);
  if (verifyRes.rowCount === 0) throw new Error('FORBIDDEN');
  
  // debtId is expected to be "fromId_toId"
  const parts = debtId.split('_');
  if (parts.length !== 2) throw new Error('INVALID_DEBT_ID');
  
  const fromMemberId = parts[0];
  const toMemberId = parts[1];
  
  // Calculate to find the exact amount they owe
  const splitRes = await calculateSplit(groupId, userId);
  const pendingDebt = splitRes.settlements.find(s => s.status === 'pending' && s.from_member_id === fromMemberId && s.to_member_id === toMemberId);
  
  if (!pendingDebt) throw new Error('DEBT_NOT_FOUND');
  
  // Insert into group_settlements
  await pool.query(`
    INSERT INTO group_settlements (group_id, from_member_id, to_member_id, amount)
    VALUES ($1, $2, $3, $4)
  `, [groupId, fromMemberId, toMemberId, pendingDebt.amount]);
  
  return { success: true };
}

module.exports = {
  createGroup,
  listGroups,
  joinGroup,
  getGroupDetails,
  addTransaction,
  updateTransaction,
  calculateSplit,
  settleGroupDebt
};
