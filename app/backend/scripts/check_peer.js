const { Pool } = require('pg');

const pool = new Pool({
  connectionString: 'postgresql://khangb2205881:FFs0Rk8h8L0bw7yvsnH7Ig@spending-stories-15879.jxf.gcp-asia-southeast1.cockroachlabs.cloud:26257/spending-stories?sslmode=verify-full',
});

async function check() {
  const query = `
    WITH StudentUsers AS (
      SELECT u.id, us.age_group, us.job_type
      FROM users u
      JOIN user_settings us ON u.id = us.user_id
      WHERE us.job_type = 'Sinh viên'
    ),
    UserMonthlyCategorySums AS (
      SELECT 
        t.creator_id,
        t.category_code,
        DATE_TRUNC('month', t.occurred_at) AS month,
        SUM(t.amount) AS total_amount
      FROM transactions t
      JOIN StudentUsers su ON t.creator_id = su.id
      WHERE t.type = 'expense'
      GROUP BY t.creator_id, t.category_code, DATE_TRUNC('month', t.occurred_at)
    )
    SELECT 
      category_code,
      PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(total_amount AS FLOAT8)) AS median_amount,
      AVG(total_amount) as avg_amount
    FROM UserMonthlyCategorySums
    GROUP BY category_code
    ORDER BY median_amount DESC;
  `;
  try {
    const res = await pool.query(query);
    console.log("=== KẾT QUẢ SO SÁNH PEER COMPARE (SINH VIÊN) ===");
    let totalMedian = 0;
    let md = "| Hạng mục | Median (VNĐ) | Avg (VNĐ) |\n|---|---|---|\n";
    for (const row of res.rows) {
      md += `| ${row.category_code} | ${Number(row.median_amount).toLocaleString('vi-VN')} | ${Number(row.avg_amount).toLocaleString('vi-VN')} |\n`;
      totalMedian += Number(row.median_amount);
    }
    md += `\n**Tổng chi tiêu (Median):** ${totalMedian.toLocaleString('vi-VN')} VNĐ`;
    console.log(md);
    const fs = require('fs');
    fs.writeFileSync('C:/Users/LENOVO/.gemini/antigravity-ide/brain/cba278ee-9be1-4c97-8802-df7cc116e309/peer_compare_after_fix.md', md);
  } catch (e) {
    console.error(e);
  } finally {
    pool.end();
  }
}

check();
