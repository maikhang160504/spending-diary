const { Pool } = require('pg'); 
const pool = new Pool({connectionString: require('./src/config/env').database.url, ssl: require('./src/config/env').database.ssl}); 
pool.query(`SELECT COUNT(DISTINCT u.id)::int AS cnt FROM users u JOIN user_settings us ON us.user_id = u.id WHERE u.id != '82ad229d-194c-45a3-b858-0980a6177167' AND (us.age_group = '18-22 tuổi' OR LOWER(us.job_type) = LOWER('Văn phòng'))`).then(res => { console.log(res.rows[0]); pool.end(); }).catch(console.error);
