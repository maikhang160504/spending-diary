'use strict';

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const { Pool } = require('pg');
const env = require('../src/config/env');

const pool = new Pool({
  connectionString: env.database.url,
  ssl: env.database.ssl,
});

const PASSWORD_HASH = '$2a$10$K37iZtbO6g2t4Jz/lqO1fe4h1vD4yJtOWhYw73xGle2B2.U1m3J4a'; // 'password123'

const NOTES = {
  Student: {
    Food: ['Ăn trưa KTX', 'Trà sữa KOI', 'Ăn sáng bánh mì', 'Bún bò Huế', 'Cơm tấm sinh viên', 'Gà rán KFC', 'Ăn vặt cổng trường'],
    Transport: ['Đổ xăng xe máy', 'GrabBike', 'Vé xe bus tháng', 'Gửi xe trường học', 'Sửa xe máy'],
    Entertainment: ['Xem phim rạp', 'Cà phê học bài', 'Billiard', 'Mua game Steam', 'Chơi net'],
    Education: ['In tài liệu học tập', 'Mua giáo trình', 'Khóa học online', 'Nộp học phí tiếng Anh'],
    Shopping: ['Mua áo thun Shopee', 'Mua ốp lưng điện thoại', 'Mua mỹ phẩm nhỏ'],
    Others: ['Mua đồ tạp hóa', 'Cắt tóc', 'Nạp tiền điện thoại'],
  },
  Office: {
    Food: ['Cơm trưa văn phòng', 'Đi siêu thị Coopmart', 'Ăn tối nhà hàng', 'Starbucks', 'Đặt đồ ăn ShopeeFood', 'Hải sản cuối tuần'],
    Transport: ['Đổ xăng ô tô/xe máy', 'Bảo dưỡng xe', 'Phí gửi xe chung cư', 'GrabCar đi tiệc', 'Rửa xe'],
    Housing: ['Thanh toán tiền điện', 'Tiền nước', 'Phí dịch vụ chung cư', 'Internet cáp quang', 'Truyền hình cáp'],
    Shopping: ['Mua quần áo Uniqlo', 'Giày Nike/Adidas', 'Mỹ phẩm chính hãng', 'Đồ gia dụng Tiki', 'Sắm đồ công nghệ'],
    Health: ['Mua thuốc', 'Khám tổng quát', 'Thực phẩm chức năng', 'Gói tập Gym/Yoga'],
    Social: ['Quà cưới đồng nghiệp', 'Ăn liên hoan công ty', 'Sinh nhật sếp', 'Nhậu cuối tuần'],
    Others: ['Cắt tóc gội đầu', 'Giặt là', 'Bảo hiểm'],
  },
  Freelancer: {
    Food: ['Ăn tối tiếp đối tác', 'Cafe làm việc', 'Cơm nhà tự nấu', 'Mua hải sản', 'Ăn sáng phở bò', 'Pizza order'],
    Transport: ['GrabCar đi gặp khách', 'Đổ xăng xe máy', 'Bảo dưỡng xe'],
    Housing: ['Thuê căn hộ studio', 'Phí điện nước văn phòng', 'Cước 4G/5G gói cước cao'],
    Shopping: ['Mua RAM máy tính', 'Bàn phím cơ', 'Chuột Logitech', 'Sách chuyên ngành', 'Phần mềm bản quyền', 'Ghế công thái học'],
    Social: ['Mời cafe khách hàng', 'Quà tặng đối tác', 'Giao lưu cộng đồng Freelancer'],
    Others: ['Đăng ký tên miền', 'Thuê server', 'Bảo hiểm y tế tự nguyện', 'Mua khóa học Udemy'],
  },
  Business: {
    Food: ['Nhà hàng 5 sao tiếp khách', 'Ăn trưa nhà hàng hải sản', 'Cafe doanh nhân', 'Mua rượu vang'],
    Transport: ['Đổ xăng xe hơi', 'Phí cao tốc (VETC)', 'Bảo dưỡng xe hơi', 'Thuê xe tự lái', 'Vé máy bay công tác'],
    Housing: ['Trả góp nhà', 'Điện nước biệt thự/nhà phố', 'Phí quản lý cao cấp', 'Trang trí nội thất'],
    Shopping: ['Mua đồ hiệu', 'Quà tặng doanh nghiệp cao cấp', 'Đồng hồ', 'Thiết bị thông minh'],
    Health: ['Gói khám VIP', 'Thực phẩm bảo vệ sức khỏe cao cấp', 'Golf', 'Tennis'],
    Social: ['Tiệc công ty', 'Từ thiện', 'Tài trợ', 'Mừng thọ'],
    Others: ['Bảo hiểm nhân thọ', 'Lệ phí hành chính', 'Dịch vụ vệ sinh nhà cửa'],
  },
  Other: {
    Food: ['Đi chợ', 'Siêu thị', 'Ăn sáng', 'Ăn tối'],
    Transport: ['Đổ xăng', 'Bảo dưỡng xe', 'Đi xe khách'],
    Housing: ['Tiền điện', 'Tiền nước', 'Tiền rác', 'Mạng internet'],
    Shopping: ['Quần áo', 'Đồ dùng gia đình'],
    Health: ['Khám bệnh', 'Mua thuốc'],
    Social: ['Thăm người ốm', 'Đám tiệc'],
    Others: ['Tạp hóa', 'Linh tinh'],
  }
};

function randomRange(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomChoice(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function getDemographic() {
  const rAge = Math.random();
  let ageGroup;
  if (rAge < 0.2) ageGroup = '18-22 tuổi';
  else if (rAge < 0.6) ageGroup = '23-30 tuổi';
  else if (rAge < 0.85) ageGroup = '31-40 tuổi';
  else if (rAge < 0.95) ageGroup = '41-50 tuổi';
  else ageGroup = 'Trên 50';

  let jobType;
  const rJob = Math.random();
  if (ageGroup === '18-22 tuổi') {
    if (rJob < 0.9) jobType = 'Sinh viên';
    else jobType = 'Khác';
  } else if (ageGroup === '23-30 tuổi') {
    if (rJob < 0.6) jobType = 'Văn phòng';
    else if (rJob < 0.8) jobType = 'Freelancer';
    else if (rJob < 0.95) jobType = 'Kinh doanh';
    else jobType = 'Khác';
  } else if (ageGroup === '31-40 tuổi') {
    if (rJob < 0.5) jobType = 'Văn phòng';
    else if (rJob < 0.8) jobType = 'Kinh doanh';
    else if (rJob < 0.9) jobType = 'Freelancer';
    else jobType = 'Khác';
  } else {
    // 41-50 and Trên 50
    if (rJob < 0.5) jobType = 'Kinh doanh';
    else if (rJob < 0.8) jobType = 'Văn phòng';
    else jobType = 'Khác';
  }

  return { ageGroup, jobType };
}

function getProfileMultiplier(ageGroup, jobType) {
  let baseMulti = 1.0;
  if (jobType === 'Sinh viên') baseMulti = 0.3; // 3-6M VND
  else if (jobType === 'Văn phòng' && ageGroup === '23-30 tuổi') baseMulti = 1.0; // 10-25M VND
  else if (jobType === 'Văn phòng' && ['31-40 tuổi', '41-50 tuổi', 'Trên 50'].includes(ageGroup)) baseMulti = 1.5; // 20-40M
  else if (jobType === 'Freelancer') baseMulti = 1.2; // 15-30M
  else if (jobType === 'Kinh doanh') baseMulti = 2.5; // 30-100M
  else baseMulti = 0.6; // Khác (Part-time, lao động tự do...)
  return baseMulti;
}

function getProfileKey(jobType) {
  if (jobType === 'Sinh viên') return 'Student';
  if (jobType === 'Văn phòng') return 'Office';
  if (jobType === 'Freelancer') return 'Freelancer';
  if (jobType === 'Kinh doanh') return 'Business';
  return 'Other';
}

async function runSimulation() {
  const client = await pool.connect();
  try {
    console.log('=== Initializing Realistic Database Simulator ===');
    
    // 1. Fetch categories
    const catCheck = await client.query('SELECT id, code FROM categories');
    if (catCheck.rows.length === 0) {
      console.log('Error: Categories table is empty! Please run database migrations first.');
      return;
    }
    const categoriesMap = {};
    for (const row of catCheck.rows) {
      categoriesMap[row.code] = row.id;
    }

    // 2. Update existing simulated users
    console.log('Fixing demographics for existing simulated users (user_*)...');
    const existingUsers = await client.query(`SELECT id, username FROM users WHERE username LIKE 'user_%'`);
    let updatedCount = 0;
    for (const u of existingUsers.rows) {
      const { ageGroup, jobType } = getDemographic();
      await client.query(`UPDATE user_settings SET age_group = $1, job_type = $2 WHERE user_id = $3`, [ageGroup, jobType, u.id]);
      updatedCount++;
    }
    console.log(`Updated ${updatedCount} existing users with realistic age/job profiles.`);

    // 3. Find highest existing index to avoid duplicate email errors
    const highestIdxResult = await client.query(`
      SELECT MAX(CAST(SUBSTRING(username FROM 6) AS INTEGER)) as max_idx 
      FROM users 
      WHERE username ~ '^user_[0-9]+$'
    `);
    
    // There might be users named user_student_1 etc from previous script.
    const highestLegacyIdxResult = await client.query(`
      SELECT COUNT(*) as cnt FROM users WHERE username LIKE 'user_%'
    `);
    
    let startIndex = (parseInt(highestIdxResult.rows[0].max_idx) || parseInt(highestLegacyIdxResult.rows[0].cnt) || 0) + 1;
    
    console.log(`Generating 150 NEW realistic users starting at index ${startIndex}...`);
    
    const newUsers = [];
    for (let i = 0; i < 150; i++) {
      const idx = startIndex + i;
      const username = `user_${idx}`;
      const email = `${username}@mimo.vn`;
      const { ageGroup, jobType } = getDemographic();

      // Ensure no conflict
      try {
        const userRes = await client.query(
          `INSERT INTO users (username, email, password_hash, preferred_vibe, role, is_active)
           VALUES ($1, $2, $3, 'funny', 'user', true)
           RETURNING id`,
          [username, email, PASSWORD_HASH]
        );
        const userId = userRes.rows[0].id;
        
        await client.query(
          `INSERT INTO user_settings (user_id, verbal_style, age_group, job_type)
           VALUES ($1, 'funny', $2, $3)`,
          [userId, ageGroup, jobType]
        );
        
        const walletRes = await client.query(
          `INSERT INTO wallets (owner_id, name, type, balance)
           VALUES ($1, $2, 'personal', 0)
           RETURNING id`,
          [userId, `Ví cá nhân`]
        );
        const walletId = walletRes.rows[0].id;
        
        await client.query(
          `INSERT INTO wallet_members (wallet_id, user_id, role)
           VALUES ($1, $2, 'owner')`,
          [walletId, userId]
        );
        
        newUsers.push({ id: userId, walletId, ageGroup, jobType });
      } catch (e) {
        if (e.code === '23505') {
          // duplicate email, ignore and continue
          continue;
        }
        throw e;
      }
    }
    
    console.log(`Successfully created ${newUsers.length} new users.`);
    console.log('Generating ~90 days of transactions for new users...');
    
    let totalTransactionsInserted = 0;
    const now = new Date();
    
    for (const u of newUsers) {
      const txRows = [];
      const multi = getProfileMultiplier(u.ageGroup, u.jobType);
      const profileKey = getProfileKey(u.jobType);
      const notes = NOTES[profileKey];
      
      // Income Generation
      if (u.jobType === 'Sinh viên') {
        for (let dayOffset = 0; dayOffset < 90; dayOffset += 7) {
          const date = new Date(now.getTime() - dayOffset * 24 * 3600000);
          txRows.push({ type: 'income', category_code: 'salary', amount: randomRange(10, 20) * 100000, note: 'Gia đình chu cấp tuần', occurred_at: date });
        }
      } else if (u.jobType === 'Freelancer') {
        for (let i = 0; i < 9; i++) {
          const date = new Date(now.getTime() - randomRange(5, 85) * 24 * 3600000);
          txRows.push({ type: 'income', category_code: 'business', amount: randomRange(30 * multi, 100 * multi) * 100000, note: 'Thanh toán hợp đồng', occurred_at: date });
        }
      } else {
        // Office / Business / Others -> Monthly salary
        for (let m = 0; m < 3; m++) {
          const date = new Date(now.getFullYear(), now.getMonth() - m, 5, 9, 0, 0);
          txRows.push({ type: 'income', category_code: 'salary', amount: randomRange(100 * multi, 200 * multi) * 100000, note: 'Lương tháng', occurred_at: date });
        }
        // Occasional bonus
        if (Math.random() > 0.5) {
          const date = new Date(now.getTime() - randomRange(10, 80) * 24 * 3600000);
          txRows.push({ type: 'income', category_code: 'bonus', amount: randomRange(10 * multi, 50 * multi) * 100000, note: 'Thưởng', occurred_at: date });
        }
      }

      // Expenses Generation
      const expenseCount = u.jobType === 'Sinh viên' ? 70 : 90; // Students might have fewer recorded transactions
      for (let i = 0; i < expenseCount; i++) {
        const date = new Date(now.getTime() - randomRange(0, 89) * 24 * 3600000 - randomRange(0, 23) * 3600000);
        let catOptions = ['Food', 'Food', 'Food', 'Transport', 'Shopping', 'Social', 'Others'];
        if (u.jobType !== 'Sinh viên') catOptions.push('Housing', 'Health');
        else catOptions.push('Education');
        
        const cat = randomChoice(catOptions);
        const noteList = notes[cat] || notes['Others'];
        const note = randomChoice(noteList);
        
        let amount = 0;
        if (cat === 'Housing') amount = randomRange(30 * multi, 100 * multi) * 100000; // Rent/Bills
        else if (cat === 'Shopping') amount = randomRange(3 * multi, 20 * multi) * 100000;
        else if (cat === 'Food') amount = randomRange(30 * multi, 150 * multi) * 1000;
        else if (cat === 'Transport') amount = randomRange(20 * multi, 100 * multi) * 1000;
        else if (cat === 'Health') amount = randomRange(2 * multi, 15 * multi) * 100000;
        else if (cat === 'Social') amount = randomRange(3 * multi, 10 * multi) * 100000;
        else amount = randomRange(20 * multi, 100 * multi) * 1000; // Others, Education
        
        txRows.push({ type: 'expense', category_code: cat, amount, note, occurred_at: date });
      }
      
      // Batch insert transactions
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
    console.log(`Total new transactions inserted: ${totalTransactionsInserted}`);
    
  } catch (err) {
    console.error('Simulation crashed:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

runSimulation();
