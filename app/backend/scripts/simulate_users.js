'use strict';

const path = require('path');
// Ensure environment variables are loaded from app/backend/.env
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const { Pool } = require('pg');
const env = require('../src/config/env');

const pool = new Pool({
  connectionString: env.database.url,
  ssl: env.database.ssl,
});

const PASSWORD_HASH = '$2a$10$K37iZtbO6g2t4Jz/lqO1fe4h1vD4yJtOWhYw73xGle2B2.U1m3J4a'; // Pre-computed bcrypt for 'password123'

const STUDENT_NOTES = {
  Food: ['Ăn trưa', 'Trà sữa KOI', 'Ăn sáng bánh mì', 'Bún bò Huế', 'Cơm tấm sườn', 'KFC', 'Lẩu Haidilao với bạn', 'Ăn vặt bánh tráng'],
  Transport: ['Đổ xăng xe máy', 'GrabBike đi học', 'Vé xe bus tháng', 'Gửi xe trường học'],
  Entertainment: ['Xem phim CGV', 'Cà phê Highland', 'Cà phê sữa đá Phúc Long', 'Billiard với bạn', 'Đi bar cuối tuần'],
  Education: ['In tài liệu học tập', 'Mua giáo trình', 'Khóa học online', 'Mua bút thước'],
  Others: ['Mua đồ tạp hóa', 'Cắt tóc', 'Sửa xe máy'],
};

const OFFICE_NOTES = {
  Food: ['Cơm trưa văn phòng', 'Đi siêu thị Coopmart', 'Ăn tối nhà hàng', 'Starbucks Coffee', 'Đặt đồ ăn GrabFood', 'Mua hoa quả'],
  Transport: ['Đổ xăng ô tô', 'Bảo dưỡng xe máy', 'Phí gửi xe chung cư', 'GrabCar đi tiệc'],
  Housing: ['Thanh toán tiền điện', 'Tiền nước', 'Phí dịch vụ chung cư', 'Internet cáp quang', 'Truyền hình cáp'],
  Shopping: ['Mua quần áo Uniqlo', 'Mua giày Nike', 'Mỹ phẩm Watson', 'Mua sắm gia dụng Tiki'],
  Health: ['Mua thuốc tây', 'Khám sức khỏe định kỳ', 'Mua vitamin'],
  Social: ['Quà cưới đồng nghiệp', 'Ăn liên hoan công ty', 'Sinh nhật sếp'],
  Others: ['Cắt tóc gội đầu', 'Giặt là đồ vest'],
};

const FREELANCER_NOTES = {
  Food: ['Ăn tối tiếp đối tác', 'Cafe làm việc', 'Cơm văn phòng tự nấu', 'Mua hải sản', 'Ăn sáng phở bò', 'Pizza Company'],
  Transport: ['GrabCar đi gặp khách', 'Đổ xăng xe', 'Thuê xe tự lái'],
  Housing: ['Thuê căn hộ studio', 'Phí điện nước văn phòng', 'Cước điện thoại 4G'],
  Shopping: ['Mua RAM máy tính', 'Mua bàn phím cơ', 'Chuột Logitech', 'Mua sách chuyên ngành'],
  Social: ['Mời cafe khách hàng', 'Quà tặng đối tác', 'Giao lưu cộng đồng'],
  Others: ['Đăng ký tên miền', 'Thuê server Cloud', 'Bảo hiểm sức khỏe'],
};

function randomRange(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomChoice(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

async function runSimulation() {
  const client = await pool.connect();
  try {
    console.log('=== Initializing Database Simulator ===');
    
    // Check if target categories exist
    const catCheck = await client.query('SELECT code FROM categories');
    if (catCheck.rows.length === 0) {
      console.log('Seeding default categories first...');
      const schemaSql = require('fs').readFileSync(path.join(__dirname, '../../database/schema.sql'), 'utf8');
      const seedPart = schemaSql.substring(schemaSql.indexOf('INSERT INTO categories'));
      await client.query(seedPart);
    }
    
    const categoriesMap = {};
    const catRes = await client.query('SELECT id, code FROM categories');
    for (const row of catRes.rows) {
      categoriesMap[row.code] = row.id;
    }
    
    console.log('Generating 150 mock users...');
    const userTypes = ['student', 'office', 'freelancer'];
    const totalUsers = 150;
    
    // Create users batch
    const users = [];
    for (let i = 1; i <= totalUsers; i++) {
      const type = userTypes[(i - 1) % 3];
      const username = `user_${type}_${i}`;
      const email = `${username}@mimo.vn`;
      
      const userRes = await client.query(
        `INSERT INTO users (username, email, password_hash, preferred_vibe, role, is_active)
         VALUES ($1, $2, $3, 'funny', 'user', true)
         RETURNING id`,
        [username, email, PASSWORD_HASH]
      );
      const userId = userRes.rows[0].id;
      
      // Insert settings
      let ageGroup = '23-30 tuổi';
      let jobType = 'Văn phòng';
      if (type === 'student') {
        ageGroup = '18-22 tuổi';
        jobType = 'Sinh viên';
      } else if (type === 'freelancer') {
        ageGroup = randomChoice(['23-30 tuổi', '31-40 tuổi', '41-50 tuổi']);
        jobType = 'Freelancer';
      } else if (type === 'office') {
        ageGroup = randomChoice(['23-30 tuổi', '31-40 tuổi', '41-50 tuổi']);
        jobType = 'Văn phòng';
      }
      
      await client.query(
        `INSERT INTO user_settings (user_id, verbal_style, age_group, job_type)
         VALUES ($1, 'funny', $2, $3)`,
        [userId, ageGroup, jobType]
      );
      
      // Insert wallet
      const walletRes = await client.query(
        `INSERT INTO wallets (owner_id, name, type, balance)
         VALUES ($1, $2, 'personal', 0)
         RETURNING id`,
        [userId, `Ví cá nhân ${username}`]
      );
      const walletId = walletRes.rows[0].id;
      
      // Link wallet member
      await client.query(
        `INSERT INTO wallet_members (wallet_id, user_id, role)
         VALUES ($1, $2, 'owner')`,
        [walletId, userId]
      );
      
      users.push({ id: userId, walletId, type });
    }
    
    console.log(`Successfully created 150 users.`);
    console.log('Generating 15,000 transactions over past 90 days...');
    
    let totalTransactionsInserted = 0;
    const now = new Date();
    
    // Process each user to generate exactly 100 transactions
    for (const u of users) {
      const txRows = [];
      
      if (u.type === 'student') {
        // Income: weekly allowance of 1,500,000 - 2,500,000 VND on Mondays
        for (let dayOffset = 0; dayOffset < 90; dayOffset += 7) {
          const date = new Date(now.getTime() - dayOffset * 24 * 3600000);
          txRows.push({
            type: 'income',
            category_code: 'salary',
            amount: randomRange(15, 25) * 100000,
            note: 'Chu cấp từ gia đình',
            occurred_at: date,
          });
        }
        
        // Expenses
        for (let i = 0; i < 90; i++) {
          const date = new Date(now.getTime() - randomRange(0, 90) * 24 * 3600000 - randomRange(0, 23) * 3600000);
          const cat = randomChoice(['Food', 'Food', 'Food', 'Transport', 'Entertainment', 'Entertainment', 'Education', 'Others']);
          const noteList = STUDENT_NOTES[cat] || STUDENT_NOTES['Others'];
          const note = randomChoice(noteList);
          
          let amount = 0;
          if (cat === 'Food') amount = randomRange(25, 120) * 1000;
          else if (cat === 'Transport') amount = randomRange(20, 60) * 1000;
          else if (cat === 'Entertainment') amount = randomRange(50, 200) * 1000;
          else if (cat === 'Education') amount = randomRange(30, 250) * 1000;
          else amount = randomRange(20, 100) * 1000;
          
          txRows.push({
            type: 'expense',
            category_code: cat,
            amount,
            note,
            occurred_at: date,
          });
        }
        
      } else if (u.type === 'office') {
        // Income: monthly salary of 12,000,000 - 25,000,000 VND on the 5th of each month
        for (let m = 0; m < 3; m++) {
          const date = new Date(now.getFullYear(), now.getMonth() - m, 5, 9, 0, 0);
          txRows.push({
            type: 'income',
            category_code: 'salary',
            amount: randomRange(120, 250) * 100000,
            note: 'Lương chuyển khoản tháng',
            occurred_at: date,
          });
        }
        
        // Income: occasional bonus
        if (Math.random() > 0.5) {
          const date = new Date(now.getTime() - randomRange(10, 80) * 24 * 3600000);
          txRows.push({
            type: 'income',
            category_code: 'bonus',
            amount: randomRange(2, 6) * 1000000,
            note: 'Thưởng quý hiệu quả công việc',
            occurred_at: date,
          });
        }
        
        // Expenses
        // Rent / Housing bills on the 1st
        for (let m = 0; m < 3; m++) {
          const date = new Date(now.getFullYear(), now.getMonth() - m, 1, 10, 0, 0);
          txRows.push({
            type: 'expense',
            category_code: 'Housing',
            amount: randomRange(35, 65) * 100000,
            note: 'Tiền thuê nhà + dịch vụ chung cư',
            occurred_at: date,
          });
        }
        
        // Daily office expenses
        for (let i = 0; i < 92; i++) {
          const date = new Date(now.getTime() - randomRange(0, 90) * 24 * 3600000 - randomRange(0, 23) * 3600000);
          const cat = randomChoice(['Food', 'Food', 'Food', 'Transport', 'Housing', 'Shopping', 'Health', 'Social', 'Others']);
          const noteList = OFFICE_NOTES[cat] || OFFICE_NOTES['Others'];
          const note = randomChoice(noteList);
          
          let amount = 0;
          if (cat === 'Food') amount = randomRange(35, 250) * 1000;
          else if (cat === 'Transport') amount = randomRange(50, 150) * 1000;
          else if (cat === 'Housing') amount = randomRange(100, 500) * 1000;
          else if (cat === 'Shopping') amount = randomRange(150, 1200) * 1000;
          else if (cat === 'Health') amount = randomRange(50, 450) * 1000;
          else if (cat === 'Social') amount = randomRange(200, 800) * 1000;
          else amount = randomRange(30, 200) * 1000;
          
          txRows.push({
            type: 'expense',
            category_code: cat,
            amount,
            note,
            occurred_at: date,
          });
        }
        
      } else if (u.type === 'freelancer') {
        // Income: fluctuating payouts on random dates
        for (let i = 0; i < 9; i++) {
          const date = new Date(now.getTime() - randomRange(5, 85) * 24 * 3600000);
          txRows.push({
            type: 'income',
            category_code: 'business',
            amount: randomRange(45, 135) * 100000,
            note: `Thanh toán hợp đồng dự án Freelance`,
            occurred_at: date,
          });
        }
        
        // Expenses
        for (let i = 0; i < 91; i++) {
          const date = new Date(now.getTime() - randomRange(0, 90) * 24 * 3600000 - randomRange(0, 23) * 3600000);
          const cat = randomChoice(['Food', 'Food', 'Transport', 'Housing', 'Shopping', 'Social', 'Others']);
          const noteList = FREELANCER_NOTES[cat] || FREELANCER_NOTES['Others'];
          const note = randomChoice(noteList);
          
          let amount = 0;
          if (cat === 'Food') amount = randomRange(50, 400) * 1000;
          else if (cat === 'Transport') amount = randomRange(40, 250) * 1000;
          else if (cat === 'Housing') amount = randomRange(200, 1200) * 1000;
          else if (cat === 'Shopping') amount = randomRange(200, 2500) * 1000;
          else if (cat === 'Social') amount = randomRange(100, 1000) * 1000;
          else amount = randomRange(50, 300) * 1000;
          
          txRows.push({
            type: 'expense',
            category_code: cat,
            amount,
            note,
            occurred_at: date,
          });
        }
      }
      
      // Perform batch inserts for the user
      for (const row of txRows) {
        const catId = categoriesMap[row.category_code] || null;
        await client.query(
          `INSERT INTO transactions 
             (wallet_id, creator_id, category_id, category_code, amount, type, source, note, occurred_at)
           VALUES ($1, $2, $3, $4, $5, $6, 'manual', $7, $8)`,
          [u.walletId, u.id, catId, row.category_code, row.amount, row.type, row.note, row.occurred_at]
        );
        totalTransactionsInserted++;
      }
    }
    
    console.log(`=== Simulation Completed ===`);
    console.log(`Generated users: 150`);
    console.log(`Generated transactions: ${totalTransactionsInserted}`);
    
  } catch (err) {
    console.error('Simulation crashed:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

runSimulation();
