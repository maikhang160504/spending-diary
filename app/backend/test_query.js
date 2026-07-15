const { Pool } = require('pg'); 
const pool = new Pool({connectionString: require('./src/config/env').database.url, ssl: require('./src/config/env').database.ssl}); 
const ageGroup = '23-30 tuổi'; 
const jobTitle = 'Văn phòng'; 
pool.query(`SELECT COUNT(DISTINCT u.id)::int AS cnt FROM users u JOIN user_settings us ON us.user_id = u.id WHERE us.age_group = $1 AND LOWER(COALESCE(us.job_type,'')) = LOWER($2)`, [ageGroup, jobTitle]).then(res => { console.log(res.rows[0]); pool.end(); }).catch(console.error);
