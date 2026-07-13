'use strict';

const { query } = require('../../config/db');

/**
 * Phân nhóm tuổi từ số tuổi.
 * Trả về chuỗi nhóm: '18-22' | '23-30' | '31-40' | '41-50' | '50+'
 */
function ageGroupFromAge(age) {
  if (!age || age < 18) return null;
  if (age <= 22) return '18-22';
  if (age <= 30) return '23-30';
  if (age <= 40) return '31-40';
  if (age <= 50) return '41-50';
  return '50+';
}

/**
 * Lấy chi tiêu trung bình theo danh mục của một nhóm (tuổi hoặc nghề nghiệp),
 * ẩn danh hoàn toàn — chỉ aggregate trên server.
 *
 * @param {number|null} ageGroup   - nhóm tuổi (18-22, 23-30, ...)
 * @param {string|null} jobTitle   - tiêu đề nghề nghiệp (từ users.job_title)
 * @param {string}      month      - 'YYYY-MM', so sánh cùng tháng
 * @param {string}      userId     - id người dùng hiện tại (để loại ra)
 * @returns {Promise<Array>} mảng { categoryCode, avgAmount, userAmount, peerCount }
 */
async function getPeerCompare(userId, { month } = {}) {
  // 1. Lấy thông tin người dùng
  const userRow = await query(
    'SELECT age, job_title, income_amount FROM users WHERE id = $1',
    [userId]
  );
  if (userRow.rowCount === 0) throw new Error('User not found');
  const { age, job_title: jobTitle } = userRow.rows[0];

  const ageGroup = ageGroupFromAge(age);

  // Cần ít nhất 1 tiêu chí để so sánh
  if (!ageGroup && !jobTitle) {
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
    parseInt(targetMonth.split('-')[1]), // getMonth is 0-based, keep 1-based here → next month day 0
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

  if (ageGroup) {
    // Nhóm tuổi: lọc theo range
    const [minAge, maxAge] = ageGroup === '50+'
      ? [51, 999]
      : ageGroup.split('-').map(Number);
    conditions.push(`u.age >= $${paramIdx++} AND u.age <= $${paramIdx++}`);
    params.push(minAge, maxAge);
  }
  if (jobTitle) {
    conditions.push(`LOWER(COALESCE(u.job_title,'')) = LOWER($${paramIdx++})`);
    params.push(jobTitle);
  }
  params.push(fromDate, toDateStr);
  const dateFromIdx = paramIdx++;
  const dateToIdx = paramIdx++;

  // 5. Đếm peer count
  const peerCountRow = await query(
    `SELECT COUNT(DISTINCT u.id)::int AS cnt
     FROM users u
     WHERE ${conditions.join(' AND ')}`,
    params.slice(0, params.length - 2) // không truyền date params ở đây
  );
  const peerCount = peerCountRow.rows[0]?.cnt || 0;

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

  // 6. Tính chi tiêu trung bình theo danh mục của nhóm
  const avgRow = await query(
    `SELECT
       CASE WHEN t.category_code IS NULL OR LOWER(t.category_code) IN ('other','others') THEN 'Other'
            ELSE t.category_code END AS category_code,
       AVG(user_cat_total.total)::numeric AS avg_amount,
       COUNT(DISTINCT t.wallet_id)::int AS user_count
     FROM (
       SELECT wm2.wallet_id,
              CASE WHEN t2.category_code IS NULL OR LOWER(t2.category_code) IN ('other','others') THEN 'Other'
                   ELSE t2.category_code END AS category_code,
              SUM(t2.amount) AS total
       FROM transactions t2
       JOIN wallet_members wm2 ON wm2.wallet_id = t2.wallet_id
       JOIN users u ON u.id = wm2.user_id
       WHERE t2.is_deleted = FALSE
         AND t2.type = 'expense'
         AND (t2.category_code IS NULL OR t2.category_code != 'Saving')
         AND t2.occurred_at >= $${dateFromIdx}
         AND t2.occurred_at <= ($${dateToIdx}::date + INTERVAL '1 day')
         AND ${conditions.join(' AND ')}
       GROUP BY 1, 2
     ) user_cat_total
     JOIN transactions t ON TRUE  -- join trick to get category_code alias
     GROUP BY 1`,
    params
  );

  // Simplified query — let's use a cleaner approach
  const avgRowClean = await query(
    `SELECT
       CASE WHEN t2.category_code IS NULL OR LOWER(t2.category_code) IN ('other','others') THEN 'Other'
            ELSE t2.category_code END AS category_code,
       AVG(user_sums.total)::numeric AS avg_amount
     FROM (
       SELECT wm2.user_id,
              CASE WHEN t2.category_code IS NULL OR LOWER(t2.category_code) IN ('other','others') THEN 'Other'
                   ELSE t2.category_code END AS category_code,
              SUM(t2.amount) AS total
       FROM transactions t2
       JOIN wallet_members wm2 ON wm2.wallet_id = t2.wallet_id
       JOIN users u ON u.id = wm2.user_id
       WHERE t2.is_deleted = FALSE
         AND t2.type = 'expense'
         AND (t2.category_code IS NULL OR t2.category_code != 'Saving')
         AND t2.occurred_at >= $${dateFromIdx}
         AND t2.occurred_at <= ($${dateToIdx}::date + INTERVAL '1 day')
         AND ${conditions.join(' AND ')}
       GROUP BY 1, 2
     ) AS user_sums
     JOIN (SELECT 1) dummy ON TRUE
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
      diffPercent, // dương = cao hơn TB nhóm, âm = thấp hơn
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
