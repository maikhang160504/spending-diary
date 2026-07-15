'use strict';

const { query } = require('../../config/db');

/**
 * Lấy chi tiêu trung bình theo danh mục của một nhóm (tuổi hoặc nghề nghiệp),
 * ẩn danh hoàn toàn — chỉ aggregate trên server.
 *
 * @param {string} userId     - id người dùng hiện tại (để loại ra)
 * @param {string} month      - 'YYYY-MM', so sánh cùng tháng
 * @returns {Promise<Object>} Object chứa metadata và data so sánh
 */
async function getPeerCompare(userId, { month } = {}) {
  // 1. Lấy thông tin người dùng từ user_settings
  const userRow = await query(
    'SELECT age_group, job_type FROM user_settings WHERE user_id = $1',
    [userId]
  );
  
  let ageGroup = null;
  let jobTitle = null;

  if (userRow.rowCount > 0) {
    ageGroup = userRow.rows[0].age_group;
    jobTitle = userRow.rows[0].job_type;
  }

  console.log(`[DEBUG] userId: ${userId}, ageGroup: '${ageGroup}', jobTitle: '${jobTitle}'`);
  console.log(`[DEBUG] Condition: ${(!ageGroup || ageGroup.trim() === '') && (!jobTitle || jobTitle.trim() === '')}`);

  // Cần ít nhất 1 tiêu chí để so sánh
  if ((!ageGroup || ageGroup.trim() === '') && (!jobTitle || jobTitle.trim() === '')) {
    return {
      hasProfile: false,
      message: 'Vui lòng cập nhật tuổi và nghề nghiệp để xem so sánh nhóm.',
      data: [],
    };
  }

  // 2. Xác định khoảng tháng
  const now = new Date();
  const targetMonth = month || `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  const fromDate = `${targetMonth}-01`;
  const toDate = new Date(
    parseInt(targetMonth.split('-')[0]),
    parseInt(targetMonth.split('-')[1]), 
    1
  );
  toDate.setDate(0); // last day of target month
  const toDateStr = toDate.toISOString().split('T')[0];

  // 3. Lấy chi tiêu của người dùng hiện tại trong tháng
  const mySpendRow = await query(
    `SELECT 
       CASE WHEN category_code IS NULL OR LOWER(category_code) IN ('other','others') THEN 'Other' 
            ELSE category_code END AS category_code,
       SUM(amount)::numeric AS total
     FROM transactions t
     JOIN wallet_members wm ON wm.wallet_id = t.wallet_id AND wm.user_id = $1
     WHERE t.is_deleted = FALSE
       AND t.type = 'expense'
       AND (t.category_code IS NULL OR t.category_code != 'Saving')
       AND t.occurred_at >= $2
       AND t.occurred_at <= ($3::date + INTERVAL '1 day')
     GROUP BY 1`,
    [userId, fromDate, toDateStr]
  );
  
  const mySpend = {};
  for (const row of mySpendRow.rows) {
    mySpend[row.category_code] = Number(row.total);
  }

  // 4. Xây dựng điều kiện peer: cùng nhóm tuổi VÀ/HOẶC nghề nghiệp, loại bản thân
  const conditions = ['u.id != $1'];
  const params = [userId];
  let paramIdx = 2;

  if (ageGroup && jobTitle) {
    conditions.push(`(us.age_group = $${paramIdx++} OR LOWER(COALESCE(us.job_type,'')) = LOWER($${paramIdx++}))`);
    params.push(ageGroup, jobTitle);
  } else if (ageGroup) {
    conditions.push(`us.age_group = $${paramIdx++}`);
    params.push(ageGroup);
  } else if (jobTitle) {
    conditions.push(`LOWER(COALESCE(us.job_type,'')) = LOWER($${paramIdx++})`);
    params.push(jobTitle);
  }
  
  params.push(fromDate, toDateStr);
  const dateFromIdx = params.length - 1;
  const dateToIdx = params.length;

  // 5. Đếm peer count
  const peerCountRow = await query(
    `SELECT COUNT(DISTINCT u.id)::int AS cnt
     FROM users u
     JOIN user_settings us ON us.user_id = u.id
     WHERE ${conditions.join(' AND ')}`,
    params.slice(0, params.length - 2) // không truyền date params ở đây
  );
  const peerCount = parseInt(peerCountRow.rows[0]?.cnt || 0, 10);

  if (peerCount < 3) {
    // Bảo vệ ẩn danh: cần ít nhất 3 người để hiển thị
    return {
      hasProfile: true,
      ageGroup,
      jobTitle,
      month: targetMonth,
      peerCount,
      notEnoughPeers: true,
      message: `Chưa đủ dữ liệu (cần ít nhất 3 người cùng nhóm, hiện có ${peerCount}).`,
      data: [],
    };
  }

  // 6. Tính chi tiêu trung vị (median) theo danh mục của nhóm để tránh bị lệch (skewed) bởi các outliers
  const avgRowClean = await query(
    `SELECT
       user_sums.category_code,
       PERCENTILE_CONT(0.5::float8) WITHIN GROUP (ORDER BY user_sums.total::float8)::numeric AS avg_amount
     FROM (
       SELECT wm2.user_id,
              CASE WHEN t2.category_code IS NULL OR LOWER(t2.category_code) IN ('other','others') THEN 'Other'
                   ELSE t2.category_code END AS category_code,
              SUM(t2.amount) AS total
       FROM transactions t2
       JOIN wallet_members wm2 ON wm2.wallet_id = t2.wallet_id
       JOIN users u ON u.id = wm2.user_id
       JOIN user_settings us ON us.user_id = u.id
       WHERE t2.is_deleted = FALSE
         AND t2.type = 'expense'
         AND (t2.category_code IS NULL OR t2.category_code != 'Saving')
         AND t2.occurred_at >= $${dateFromIdx}
         AND t2.occurred_at <= ($${dateToIdx}::date + INTERVAL '1 day')
         AND ${conditions.join(' AND ')}
       GROUP BY 1, 2
     ) AS user_sums
     GROUP BY 1
     ORDER BY avg_amount DESC`,
    params
  );

  // Build result: merge mySpend + peer avg
  const allCategories = new Set([
    ...Object.keys(mySpend),
    ...avgRowClean.rows.map(r => r.category_code),
  ]);

  const data = [...allCategories].map(cat => {
    const peerRow = avgRowClean.rows.find(r => r.category_code === cat);
    const avgAmount = peerRow ? Math.round(Number(peerRow.avg_amount)) : 0;
    const userAmount = mySpend[cat] || 0;
    const diffPercent = avgAmount > 0
      ? Math.round(((userAmount - avgAmount) / avgAmount) * 100)
      : null;
    return {
      categoryCode: cat,
      userAmount,
      avgAmount,
      diffPercent, 
    };
  }).filter(d => d.userAmount > 0 || d.avgAmount > 0)
    .sort((a, b) => b.userAmount - a.userAmount);

  return {
    hasProfile: true,
    ageGroup,
    jobTitle,
    month: targetMonth,
    peerCount,
    notEnoughPeers: false,
    data,
  };
}

module.exports = { getPeerCompare };

