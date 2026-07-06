'use strict';

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const { Pool } = require('pg');
const env = require('../src/config/env');

const pool = new Pool({
  connectionString: env.database.url,
  ssl: env.database.ssl,
});

async function runFix() {
  const client = await pool.connect();
  try {
    console.log('=== Starting Demographic Fix Script ===');

    // 1. Update students
    const res1 = await client.query(
      `UPDATE user_settings 
       SET age_group = '18-22 tuổi', job_type = 'Sinh viên' 
       WHERE age_group = '18-22' AND job_type = 'student'`
    );
    console.log(`Updated student users: ${res1.rowCount}`);

    // 2. Fetch and distribute office users' age groups randomly
    const officeUsers = await client.query(
      `SELECT user_id FROM user_settings WHERE age_group = '23-35' AND job_type = 'office'`
    );
    console.log(`Found office users to update: ${officeUsers.rows.length}`);
    const ageOptions = ['23-30 tuổi', '31-40 tuổi', '41-50 tuổi'];
    for (let i = 0; i < officeUsers.rows.length; i++) {
      const uId = officeUsers.rows[i].user_id;
      const ageGroup = ageOptions[i % ageOptions.length];
      await client.query(
        `UPDATE user_settings 
         SET age_group = $1, job_type = 'Văn phòng' 
         WHERE user_id = $2`,
        [ageGroup, uId]
      );
    }

    // 3. Fetch and distribute freelancer users' age groups randomly
    const freelancerUsers = await client.query(
      `SELECT user_id FROM user_settings WHERE age_group = '23-45' AND job_type = 'freelancer'`
    );
    console.log(`Found freelancer users to update: ${freelancerUsers.rows.length}`);
    for (let i = 0; i < freelancerUsers.rows.length; i++) {
      const uId = freelancerUsers.rows[i].user_id;
      const ageGroup = ageOptions[i % ageOptions.length];
      await client.query(
        `UPDATE user_settings 
         SET age_group = $1, job_type = 'Freelancer' 
         WHERE user_id = $2`,
        [ageGroup, uId]
      );
    }

    // 4. Cleanup any remaining lowercase job types (just in case)
    const cleanupOffice = await client.query(
      `UPDATE user_settings SET job_type = 'Văn phòng' WHERE job_type = 'office'`
    );
    const cleanupFree = await client.query(
      `UPDATE user_settings SET job_type = 'Freelancer' WHERE job_type = 'freelancer'`
    );
    const cleanupStudent = await client.query(
      `UPDATE user_settings SET job_type = 'Sinh viên' WHERE job_type = 'student'`
    );
    console.log(`Cleanup remaining rows: office=${cleanupOffice.rowCount}, freelancer=${cleanupFree.rowCount}, student=${cleanupStudent.rowCount}`);

    console.log('=== Demographic Fix Completed Successfully ===');
  } catch (err) {
    console.error('Error during demographic fix:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

runFix();
