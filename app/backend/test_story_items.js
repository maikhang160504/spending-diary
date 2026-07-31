require('dotenv').config();
const { Client } = require('pg');
const client = new Client({ connectionString: process.env.DATABASE_URL });

client.connect()
  .then(() => client.query("SELECT column_name FROM information_schema.columns WHERE table_name = 'story_items'"))
  .then(res => { console.log(res.rows); process.exit(0); });
