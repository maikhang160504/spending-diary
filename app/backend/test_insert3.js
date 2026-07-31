require('dotenv').config();
const { Client } = require('pg');
const client = new Client({ connectionString: process.env.DATABASE_URL });

async function run() {
  await client.connect();
  try {
    const userRes = await client.query('SELECT id FROM users LIMIT 1');
    const walletRes = await client.query('SELECT id FROM wallets LIMIT 1');
    const userId = userRes.rows[0].id;
    const walletId = walletRes.rows[0].id;
    const occurredAt = new Date();
    const imageUrl = null;
    
    // Simulate what ai.service.js does:
    const storyRes = await client.query(
        `INSERT INTO stories (user_id, wallet_id, title, total_amount, cover_image_url, occurred_on)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
        [userId, walletId, 'Hóa đơn', 0, imageUrl, occurredAt]
    );
    const storyId = storyRes.rows[0].id;
    
    const itemRes = await client.query(
        `INSERT INTO story_items (story_id, raw_text, media_url, media_type)
         VALUES ($1, $2, $3, $4) RETURNING id`,
        [storyId, 'Note', imageUrl, imageUrl ? 'image' : 'text']
    );
    const storyItemId = itemRes.rows[0].id;
    
    await client.query(
          `INSERT INTO ai_comments (story_id, content_text, visual_state, emotion)
           VALUES ($1, $2, $3, $4)`,
          [storyId, 'llmStory', 'Success', 'Success']
        );
    console.log("SUCCESS");
  } catch (err) {
    console.error("ERROR:", err.message);
  } finally {
    await client.end();
  }
}
run();
