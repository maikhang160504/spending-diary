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
    
    let extracted = { category: 'Food', amount: 834000 }; // no note
    const imageUrl = 'https://example.com/image.jpg';
    const occurredAt = new Date();
    
    let storyId = null;
    let storyItemId = null;

    const storyRes = await client.query(
      `INSERT INTO stories (user_id, wallet_id, title, total_amount, cover_image_url, occurred_on)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
      [userId, walletId, extracted.note || extracted.category || 'Hóa đơn', extracted.amount || 0, imageUrl, occurredAt]
    );
    storyId = storyRes.rows[0].id;
    console.log("STORY ID:", storyId);

    const itemRes = await client.query(
      `INSERT INTO story_items (story_id, raw_text, media_url, media_type)
       VALUES ($1, $2, $3, $4) RETURNING id`,
      [storyId, extracted.note || null, imageUrl, imageUrl ? 'image' : 'text']
    );
    storyItemId = itemRes.rows[0].id;
    console.log("STORY ITEM ID:", storyItemId);

    let llmStory = "Vibe cực Mai Khang ơi";
    let mascotMood = "Happy";
    await client.query(
      `INSERT INTO ai_comments (story_id, content_text, visual_state, emotion)
       VALUES ($1, $2, $3, $4)`,
      [storyId, llmStory, mascotMood, mascotMood]
    );
    console.log("AI COMMENT INSERTED");

  } catch (err) {
    console.error("ERROR:", err.message);
  } finally {
    await client.end();
  }
}
run();
