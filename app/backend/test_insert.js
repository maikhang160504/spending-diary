require('dotenv').config();
const { Client } = require('pg');
const client = new Client({ connectionString: process.env.DATABASE_URL });

async function run() {
  await client.connect();
  try {
    const storyRes = await client.query(
      `INSERT INTO stories (user_id, wallet_id, title, total_amount, cover_image_url, occurred_on)
       VALUES ($1, $2, $3, $4, $5, COALESCE($6::date, CURRENT_DATE))
       RETURNING id`,
      [
        '00000000-0000-0000-0000-000000000000', // Need a valid user_id and wallet_id to test foreign keys?
        '00000000-0000-0000-0000-000000000000',
        'Test story',
        10000,
        null,
        '2026-07-16',
      ]
    );
    console.log(storyRes.rows);
  } catch (err) {
    console.error(err.message);
  } finally {
    await client.end();
  }
}
run();
