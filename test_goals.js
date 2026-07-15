const { query } = require('./app/backend/src/config/db');
query("SELECT * FROM goals ORDER BY created_at DESC LIMIT 1").then(res => console.log(res.rows)).catch(console.error).then(()=>process.exit(0));
