require('dotenv').config();
const { Client } = require('pg');
const client = new Client({ connectionString: process.env.DATABASE_URL });

async function run() {
  await client.connect();
  try {
    const txRes = await client.query('SELECT id FROM transactions LIMIT 1');
    const transactionId = txRes.rows[0].id;

    const storyItemId = 'a2d31878-2516-4c7f-88c2-d57260d0acb8'; // from previous run
    const occurredAt = new Date();

    const r = await client.query(
        `UPDATE transactions SET
           category_id       = COALESCE($1, category_id),
           category_code     = COALESCE($2, category_code),
           amount            = COALESCE($3, amount),
           type              = COALESCE($4::varchar, type),
           note              = COALESCE($5, note),
           ai_extracted      = TRUE,
           ai_confidence     = $6,
           ai_meta           = $7,
           story_item_id     = COALESCE($8, story_item_id),
           processing_status = 'done',
           occurred_at       = $10,
           updated_at        = NOW()
         WHERE id = $9 RETURNING *`,
        [
          null, // categoryId
          'Food', // finalCategoryCode
          834000, // extracted.amount
          'expense', // type
          null, // note
          0.9, // confidence
          { nlu: {}, ocr: {}, image_url: null, personalizationKeyword: 'test' }, // aiMeta
          storyItemId,
          transactionId,
          occurredAt,
        ]
    );
    console.log("UPDATE SUCCESS:", r.rows[0].id);
  } catch (err) {
    console.error("ERROR:", err.message);
  } finally {
    await client.end();
  }
}
run();
