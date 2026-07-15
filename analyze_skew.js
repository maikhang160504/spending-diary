const { query } = require('./app/backend/src/config/db');

async function analyzeSkew() {
  const fromDate = '2026-07-01';
  const toDateStr = '2026-07-31';

  const userTotalsRow = await query(
    `SELECT u.id,
            SUM(t.amount)::numeric AS total
     FROM transactions t
     JOIN wallet_members wm ON wm.wallet_id = t.wallet_id
     JOIN users u ON u.id = wm.user_id
     WHERE t.is_deleted = FALSE
       AND t.type = 'expense'
       AND t.occurred_at >= $1
       AND t.occurred_at <= ($2::date + INTERVAL '1 day')
     GROUP BY u.id
     ORDER BY total DESC`,
    [fromDate, toDateStr]
  );
  
  const totals = userTotalsRow.rows.map(r => Number(r.total));
  const sum = totals.reduce((a, b) => a + b, 0);
  const count = totals.length;
  const mean = sum / count;
  
  totals.sort((a, b) => a - b);
  const median = totals[Math.floor(count / 2)];
  
  console.log('--- USER TOTAL EXPENSE ---');
  console.log(`Count: ${count}`);
  console.log(`Mean: ${mean.toLocaleString()}`);
  console.log(`Median: ${median.toLocaleString()}`);
  console.log(`Top 5: ${totals.slice(-5).reverse().map(t => t.toLocaleString()).join(', ')}`);
  console.log(`Bottom 5: ${totals.slice(0, 5).map(t => t.toLocaleString()).join(', ')}`);

  // Analyze by category
  const categoryTotalsRow = await query(
    `SELECT category_code,
            COUNT(DISTINCT u.id) as user_count,
            SUM(t.amount)::numeric / COUNT(DISTINCT u.id) AS mean_amount
     FROM transactions t
     JOIN wallet_members wm ON wm.wallet_id = t.wallet_id
     JOIN users u ON u.id = wm.user_id
     WHERE t.is_deleted = FALSE
       AND t.type = 'expense'
       AND t.occurred_at >= $1
       AND t.occurred_at <= ($2::date + INTERVAL '1 day')
     GROUP BY category_code
     ORDER BY mean_amount DESC`,
    [fromDate, toDateStr]
  );

  console.log('\n--- MEAN EXPENSE BY CATEGORY ---');
  categoryTotalsRow.rows.forEach(r => {
    console.log(`${r.category_code}: Users=${r.user_count}, Mean=${Number(r.mean_amount).toLocaleString()}`);
  });
}

analyzeSkew().catch(console.error).then(() => process.exit(0));
