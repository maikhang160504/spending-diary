const { query } = require('./app/backend/src/config/db');
async function test() {
  const goalRes = await query("SELECT * FROM goals ORDER BY created_at DESC LIMIT 1");
  const goal = goalRes.rows[0];
  const goalId = goal.id;
  const userId = goal.user_id;
  
  console.log('Goal type:', goal.type);
  
  await query(`UPDATE goals SET type = 'challenge' WHERE id = $1`, [goalId]);
  
  await query(`INSERT INTO goal_members(goal_id, user_id, role) VALUES($1, $2, 'owner') ON CONFLICT DO NOTHING`, [goalId, userId]);
  
  const mems1 = await query(`SELECT * FROM goal_members WHERE goal_id = $1`, [goalId]);
  console.log('Before contrib:', mems1.rows);
  
  const amount = 50000;
  
  const memRes = await query(
      `INSERT INTO goal_members (goal_id, user_id, role, current_amount)
       VALUES ($1, $2, 'member', $3)
       ON CONFLICT (goal_id, user_id)
       DO UPDATE SET current_amount = goal_members.current_amount + EXCLUDED.current_amount,
                     status = CASE WHEN goal_members.current_amount + EXCLUDED.current_amount >= $4 THEN 'completed' ELSE goal_members.status END,
                     completed_at = CASE WHEN goal_members.current_amount + EXCLUDED.current_amount >= $4 AND goal_members.completed_at IS NULL THEN NOW() ELSE goal_members.completed_at END
       RETURNING current_amount`,
      [goalId, userId, amount, Number(goal.target_amount)]
    );
    
  console.log('Returned current_amount:', memRes.rows);
  
  const mems2 = await query(`SELECT * FROM goal_members WHERE goal_id = $1`, [goalId]);
  console.log('After contrib:', mems2.rows);
}
test().catch(console.error).then(()=>process.exit(0));
