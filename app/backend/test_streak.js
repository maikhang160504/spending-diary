const { query } = require('./src/config/db');
function getTodayVNStr() {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(now);
}
function getDaysDiff(dStr1, dStr2) {
  const d1 = new Date(dStr1 + 'T00:00:00Z');
  const d2 = new Date(dStr2 + 'T00:00:00Z');
  return Math.round((d1.getTime() - d2.getTime()) / 86400000);
}

async function test() {
  const r = await query('SELECT id FROM users ORDER BY created_at ASC LIMIT 1');
  const userId = r.rows[0].id;
  
  const r2 = await query(`
    SELECT DISTINCT day FROM (
       SELECT TO_CHAR(t.occurred_at AT TIME ZONE 'Asia/Ho_Chi_Minh', 'YYYY-MM-DD') AS day
       FROM transactions t
       JOIN wallet_members wm ON wm.wallet_id = t.wallet_id
       WHERE wm.user_id = $1 AND t.is_deleted = FALSE
       UNION
       SELECT TO_CHAR(cm.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh', 'YYYY-MM-DD') AS day
       FROM chat_messages cm
       JOIN chat_sessions cs ON cs.id = cm.session_id
       WHERE cs.user_id = $1 AND cm.role = 'user'
       UNION
       SELECT TO_CHAR(s.occurred_on, 'YYYY-MM-DD') AS day
       FROM stories s
       WHERE s.user_id = $1
     ) active_days
     ORDER BY day DESC
  `, [userId]);
  
  console.log('User:', userId);
  console.log('Active dates:', r2.rows);
  
  const dates = r2.rows.map(r => r.day).filter(Boolean);
  const todayStr = getTodayVNStr();
  console.log('Today:', todayStr, 'Dates:', dates);
  
  if (dates.length > 0) {
    const daysSinceLast = getDaysDiff(todayStr, dates[0]);
    console.log('daysSinceLast:', daysSinceLast);
    let currentStreak = 0;
    if (daysSinceLast <= 2) {
      currentStreak = 1;
      for (let i = 1; i < dates.length; i++) {
        const diff = getDaysDiff(dates[i - 1], dates[i]);
        if (diff <= 2) {
          currentStreak++;
        } else {
          break;
        }
      }
    }
    console.log('currentStreak:', currentStreak);
  }
  
  process.exit(0);
}

test();
