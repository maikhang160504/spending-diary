require('dotenv').config();
const { query } = require('../src/db');

async function setAdmin(email) {
  if (!email) {
    console.error('Please provide an email. Usage: node set_admin.js <email>');
    process.exit(1);
  }

  try {
    console.log(`Setting role "admin" for user: ${email}...`);
    const result = await query(
      `UPDATE users SET role = 'admin' WHERE email = $1 RETURNING id, email, role`,
      [email]
    );

    if (result.rows.length === 0) {
      console.log(`User with email ${email} not found.`);
    } else {
      console.log('Success!', result.rows[0]);
    }
  } catch (err) {
    console.error('Error setting admin:', err);
  } finally {
    process.exit(0);
  }
}

const email = process.argv[2];
setAdmin(email);
