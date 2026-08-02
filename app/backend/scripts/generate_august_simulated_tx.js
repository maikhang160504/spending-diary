'use strict';

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const { Pool } = require('pg');
const env = require('../src/config/env');

const pool = new Pool({
  connectionString: env.database.url,
  ssl: env.database.ssl,
});

const NOTES = {
  Student: {
    Food: ['Ăn sáng bánh mì', 'Xôi mặn cổng trường', 'Ăn trưa KTX', 'Cơm tấm sinh viên', 'Bún bò Huế', 'Trà sữa KOI', 'Cà phê học bài', 'Ăn vặt cổng trường', 'Cơm bình dân'],
    Transport: ['Đổ xăng xe máy', 'Gửi xe trường học', 'Vé xe bus tháng', 'GrabBike đi học', 'Sửa lốp xe máy'],
    Housing: ['Tiền trọ KTX', 'Tiền điện nước phòng trọ', 'Phí quản lý ký túc xá', 'Tiền internet phòng trọ'],
    Education: ['In tài liệu học tập', 'Mua giáo trình học kỳ', 'Khóa học online', 'Mua vở viết và bút'],
    Entertainment: ['Xem phim rạp cuối tuần', 'Chơi net cùng bạn', 'Billiard cuối tuần', 'Mua game Steam'],
    Shopping: ['Mua áo thun Shopee', 'Mua ốp lưng điện thoại', 'Mua sắm đồ cá nhân nhỏ'],
    Social: ['Sinh nhật bạn cùng phòng', 'Góp tiền liên hoan nhóm', 'Quà tặng bạn bè'],
    Health: ['Mua thuốc cảm', 'Khám mắt'],
    Others: ['Mua đồ tạp hóa', 'Cắt tóc', 'Nạp tiền điện thoại'],
  },
  Office: {
    Food: ['Ăn sáng phở bò', 'Cà phê sáng văn phòng', 'Cơm trưa văn phòng', 'Bún chả hà nội', 'Starbucks chiều', 'Đặt đồ ăn ShopeeFood', 'Ăn tối nhà hàng', 'Đi siêu thị Coopmart mua đồ ăn'],
    Transport: ['Đổ xăng xe máy', 'Đổ xăng ô tô', 'Phí gửi xe chung cư', 'GrabCar đi tiệc', 'Bảo dưỡng xe định kỳ', 'Rửa xe cuối tuần'],
    Housing: ['Thanh toán tiền điện', 'Tiền nước sinh hoạt', 'Phí dịch vụ chung cư', 'Internet cáp quang', 'Truyền hình cáp'],
    Shopping: ['Mua quần áo Uniqlo', 'Giày đi làm chính hãng', 'Mỹ phẩm chăm sóc da', 'Đồ gia dụng Tiki', 'Sắm phụ kiện công nghệ'],
    Social: ['Ăn liên hoan công ty', 'Quà cưới đồng nghiệp', 'Sinh nhật sếp', 'Nhậu cuối tuần cùng bạn'],
    Health: ['Mua thuốc bổ', 'Khám sức khỏe tổng quát', 'Thực phẩm chức năng', 'Gói tập Gym theo tháng'],
    Beauty: ['Cắt tóc tạo kiểu', 'Chăm sóc da mặt', 'Mua nước hoa'],
    Others: ['Giặt ủi quần áo', 'Phí chuyển khoản', 'Mua đồ tạp hóa gia đình'],
  },
  Freelancer: {
    Food: ['Cafe làm việc buổi sáng', 'Cà phê Highlands', 'Cơm nhà tự nấu', 'Ăn tối tiếp đối tác', 'Pizza order buổi tối', 'Đi siêu thị mua thực phẩm'],
    Transport: ['GrabCar đi gặp khách', 'Đổ xăng xe máy', 'Bảo dưỡng xe máy'],
    Housing: ['Thuê căn hộ studio', 'Phí điện nước văn phòng làm việc', 'Cước internet 5G tốc độ cao'],
    Shopping: ['Mua RAM máy tính', 'Bàn phím cơ làm việc', 'Chuột Logitech không dây', 'Sách chuyên ngành', 'Phần mềm bản quyền', 'Ghế công thái học'],
    Social: ['Mời cafe khách hàng', 'Quà tặng đối tác', 'Giao lưu cộng đồng Freelancer'],
    Entertainment: ['Xem phim rạp', 'Đăng ký Netflix', 'Mua game trọn gói'],
    Health: ['Thực phẩm bảo vệ mắt', 'Khám định kỳ', 'Gói tập Yoga'],
    Others: ['Đăng ký tên miền', 'Thuê máy chủ đám mây', 'Bảo hiểm y tế tự nguyện'],
  },
  Business: {
    Food: ['Nhà hàng 5 sao tiếp khách', 'Ăn trưa nhà hàng hải sản', 'Cafe doanh nhân buổi sáng', 'Mua rượu vang cao cấp', 'Tiệc chiêu đãi đối tác'],
    Transport: ['Đổ xăng xe hơi', 'Phí cao tốc tự động VETC', 'Bảo dưỡng xe hơi định kỳ', 'Vé máy bay công tác'],
    Housing: ['Trả góp biệt thự', 'Điện nước biệt thự', 'Phí quản lý cao cấp', 'Bảo trì nội thất'],
    Shopping: ['Mua trang phục đồ hiệu', 'Quà tặng doanh nghiệp cao cấp', 'Đồng hồ chính hãng', 'Thiết bị thông minh gia đình'],
    Social: ['Tiệc thường niên công ty', 'Quà tặng đối tác chiến lược', 'Mừng thọ đối tác', 'Tài trợ hoạt động cộng đồng'],
    Health: ['Gói khám VIP định kỳ', 'Thực phẩm bảo vệ sức khỏe cao cấp', 'Thẻ hội viên Golf'],
    Others: ['Bảo hiểm nhân thọ', 'Lệ phí hành chính doanh nghiệp', 'Dịch vụ vệ sinh nhà cửa chuyên nghiệp'],
  },
  Other: {
    Food: ['Đi chợ hôm nay', 'Siêu thị mua thực phẩm', 'Ăn sáng phở', 'Ăn tối gia đình'],
    Transport: ['Đổ xăng xe máy', 'Bảo dưỡng sửa xe', 'Đi xe khách'],
    Housing: ['Tiền điện tháng này', 'Tiền nước sinh hoạt', 'Tiền rác và an ninh', 'Mạng internet'],
    Shopping: ['Mua sắm quần áo', 'Đồ dùng gia đình thiết yếu'],
    Health: ['Khám bệnh', 'Mua thuốc tiệm Tây'],
    Social: ['Thăm người ốm', 'Đám tiệc cưới hỏi'],
    Others: ['Mua đồ tạp hóa', 'Chi tiêu linh tinh'],
  },
};

function randomRange(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomChoice(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function getProfileKey(jobType) {
  if (jobType === 'Sinh viên') return 'Student';
  if (jobType === 'Văn phòng') return 'Office';
  if (jobType === 'Freelancer') return 'Freelancer';
  if (jobType === 'Kinh doanh') return 'Business';
  return 'Other';
}

function getProfileMultiplier(ageGroup, jobType) {
  let baseMulti = 1.0;
  if (jobType === 'Sinh viên') baseMulti = 0.35;
  else if (jobType === 'Văn phòng' && ageGroup === '23-30 tuổi') baseMulti = 1.0;
  else if (jobType === 'Văn phòng' && ['31-40 tuổi', '41-50 tuổi', 'Trên 50'].includes(ageGroup)) baseMulti = 1.5;
  else if (jobType === 'Freelancer') baseMulti = 1.25;
  else if (jobType === 'Kinh doanh') baseMulti = 2.8;
  else baseMulti = 0.7;
  return baseMulti;
}

function getRealisticTime(type) {
  // Returns { hour, minute, second } realistic for the time of day
  if (type === 'breakfast') return { hour: randomRange(6, 8), minute: randomRange(0, 59), second: randomRange(0, 59) };
  if (type === 'morning_coffee') return { hour: randomRange(8, 10), minute: randomRange(0, 59), second: randomRange(0, 59) };
  if (type === 'lunch') return { hour: randomRange(11, 13), minute: randomRange(10, 50), second: randomRange(0, 59) };
  if (type === 'afternoon_snack') return { hour: randomRange(14, 16), minute: randomRange(0, 59), second: randomRange(0, 59) };
  if (type === 'dinner') return { hour: randomRange(18, 20), minute: randomRange(0, 59), second: randomRange(0, 59) };
  if (type === 'evening_shopping') return { hour: randomRange(19, 22), minute: randomRange(0, 59), second: randomRange(0, 59) };
  if (type === 'commute_morning') return { hour: randomRange(7, 8), minute: randomRange(15, 59), second: randomRange(0, 59) };
  if (type === 'commute_evening') return { hour: randomRange(17, 19), minute: randomRange(0, 59), second: randomRange(0, 59) };
  if (type === 'daytime_bill') return { hour: randomRange(9, 16), minute: randomRange(0, 59), second: randomRange(0, 59) };
  // Default daytime
  return { hour: randomRange(8, 20), minute: randomRange(0, 59), second: randomRange(0, 59) };
}

function makeTimestamp(year, monthIndex, day, timeType) {
  const { hour, minute, second } = getRealisticTime(timeType);
  return new Date(year, monthIndex, day, hour, minute, second);
}

async function runAugustSimulation() {
  const client = await pool.connect();
  try {
    console.log('=== Bắt đầu tạo dữ liệu giao dịch từ 1/8 đến 20/8 cho các simulate user ===');

    // 1. Fetch categories
    const catCheck = await client.query('SELECT id, code FROM categories');
    if (catCheck.rows.length === 0) {
      console.log('Lỗi: Bảng categories trống!');
      return;
    }
    const categoriesMap = {};
    for (const row of catCheck.rows) {
      categoriesMap[row.code] = row.id;
    }

    // 2. Fetch all simulated users
    const usersRes = await client.query(`
      SELECT u.id, u.username, u.email, w.id AS wallet_id, us.age_group, us.job_type
      FROM users u
      JOIN wallets w ON u.id = w.owner_id
      LEFT JOIN user_settings us ON u.id = us.user_id
      WHERE u.email LIKE 'user_%@mimo.vn'
    `);

    const users = usersRes.rows;
    console.log(`Đã tìm thấy ${users.length} tài khoản người dùng mô phỏng.`);

    // 3. Clear existing transactions between 2026-08-01 and 2026-08-20 for these users (to avoid duplicates)
    console.log('Làm sạch dữ liệu giao dịch cũ từ ngày 1/8 đến 20/8 (nếu có)...');
    const userIds = users.map((u) => u.id);
    if (userIds.length > 0) {
      await client.query(
        `DELETE FROM transactions 
         WHERE creator_id = ANY($1::uuid[]) 
           AND occurred_at >= '2026-08-01 00:00:00' 
           AND occurred_at < '2026-08-21 00:00:00'`,
        [userIds]
      );
    }

    let totalTransactions = 0;
    const allTxRows = [];

    // Year 2026, month index 7 (August is 0-indexed month 7)
    const year = 2026;
    const monthIndex = 7;

    for (const u of users) {
      const jobType = u.job_type || 'Khác';
      const ageGroup = u.age_group || '23-30 tuổi';
      const multi = getProfileMultiplier(ageGroup, jobType);
      const profileKey = getProfileKey(jobType);
      const notes = NOTES[profileKey];

      // ---- A. GENERATE INCOME ----
      if (jobType === 'Sinh viên') {
        // Weekly allowance on Mondays: Aug 3, Aug 10, Aug 17
        [3, 10, 17].forEach((day) => {
          const date = makeTimestamp(year, monthIndex, day, 'daytime_bill');
          allTxRows.push({
            wallet_id: u.wallet_id,
            creator_id: u.id,
            category_code: 'salary',
            amount: randomRange(12, 20) * 100000,
            note: 'Gia đình chu cấp tuần',
            occurred_at: date,
          });
        });
        // Occasional part-time job income on Aug 15 (30% chance)
        if (Math.random() < 0.3) {
          const date = makeTimestamp(year, monthIndex, 15, 'daytime_bill');
          allTxRows.push({
            wallet_id: u.wallet_id,
            creator_id: u.id,
            category_code: 'salary',
            amount: randomRange(15, 25) * 100000,
            note: 'Lương làm thêm bán thời gian',
            occurred_at: date,
          });
        }
      } else if (jobType === 'Freelancer') {
        // 2 to 3 contract payments on random days between Aug 3 and Aug 19
        const paymentDays = [randomRange(2, 7), randomRange(9, 14), randomRange(15, 19)];
        paymentDays.forEach((day) => {
          const date = makeTimestamp(year, monthIndex, day, 'daytime_bill');
          allTxRows.push({
            wallet_id: u.wallet_id,
            creator_id: u.id,
            category_code: 'business',
            amount: randomRange(70 * multi, 150 * multi) * 100000,
            note: 'Thanh toán hợp đồng dự án',
            occurred_at: date,
          });
        });
      } else {
        // Office / Business / Others: Monthly salary on August 5th
        const salaryDate = makeTimestamp(year, monthIndex, 5, 'daytime_bill');
        let salaryAmount = randomRange(120 * multi, 220 * multi) * 100000;
        if (jobType === 'Kinh doanh') salaryAmount = randomRange(300 * multi, 550 * multi) * 100000;

        allTxRows.push({
          wallet_id: u.wallet_id,
          creator_id: u.id,
          category_code: 'salary',
          amount: salaryAmount,
          note: 'Lương tháng 8',
          occurred_at: salaryDate,
        });

        // Occasional bonus or investment income (40% chance) on Aug 12 or 16
        if (Math.random() < 0.4) {
          const bonusDay = randomChoice([12, 16]);
          const bonusDate = makeTimestamp(year, monthIndex, bonusDay, 'daytime_bill');
          allTxRows.push({
            wallet_id: u.wallet_id,
            creator_id: u.id,
            category_code: jobType === 'Kinh doanh' ? 'investment' : 'bonus',
            amount: randomRange(30 * multi, 100 * multi) * 100000,
            note: jobType === 'Kinh doanh' ? 'Cổ tức đầu tư' : 'Thưởng hiệu suất công việc',
            occurred_at: bonusDate,
          });
        }
      }

      // ---- B. GENERATE HOUSING / MONTHLY BILLS (Aug 1 - Aug 5) ----
      const housingDay = randomRange(1, 5);
      const housingDate = makeTimestamp(year, monthIndex, housingDay, 'daytime_bill');
      let housingAmount = randomRange(30 * multi, 90 * multi) * 100000;
      if (jobType === 'Sinh viên') housingAmount = randomRange(8, 20) * 100000;
      const housingNoteList = notes['Housing'] || NOTES['Other']['Housing'];
      allTxRows.push({
        wallet_id: u.wallet_id,
        creator_id: u.id,
        category_code: 'Housing',
        amount: housingAmount,
        note: randomChoice(housingNoteList),
        occurred_at: housingDate,
      });

      // ---- C. GENERATE DAILY EXPENSES FROM AUG 1 TO AUG 20 ----
      for (let day = 1; day <= 20; day++) {
        // Every day has 1 to 3 expenses
        // 1. Always have a main Food expense (Lunch or Breakfast/Dinner)
        const mealType = randomChoice(['breakfast', 'lunch', 'dinner']);
        const mealDate = makeTimestamp(year, monthIndex, day, mealType);
        let foodAmount = randomRange(30 * multi, 90 * multi) * 1000;
        if (jobType === 'Sinh viên') foodAmount = randomRange(15, 35) * 1000;

        allTxRows.push({
          wallet_id: u.wallet_id,
          creator_id: u.id,
          category_code: 'Food',
          amount: foodAmount,
          note: randomChoice(notes['Food'] || NOTES['Other']['Food']),
          occurred_at: mealDate,
        });

        // 2. Second daily expense (70% chance): Coffee, Transport, or Snack
        if (Math.random() < 0.7) {
          const secondCat = randomChoice(['Food', 'Transport']);
          const timeType = secondCat === 'Food' ? randomChoice(['morning_coffee', 'afternoon_snack']) : randomChoice(['commute_morning', 'commute_evening']);
          const secondDate = makeTimestamp(year, monthIndex, day, timeType);
          let secondAmount = 0;
          if (jobType === 'Sinh viên') {
            secondAmount = secondCat === 'Food' ? randomRange(15, 30) * 1000 : randomRange(10, 25) * 1000;
          } else {
            secondAmount = secondCat === 'Food' ? randomRange(30 * multi, 65 * multi) * 1000 : randomRange(25 * multi, 80 * multi) * 1000;
          }
          allTxRows.push({
            wallet_id: u.wallet_id,
            creator_id: u.id,
            category_code: secondCat,
            amount: secondAmount,
            note: randomChoice(notes[secondCat] || NOTES['Other'][secondCat]),
            occurred_at: secondDate,
          });
        }

        // 3. Third occasional expense (40% chance): Shopping, Entertainment, Education, Social, Health, Beauty, Others
        if (Math.random() < 0.4) {
          let optionCats = ['Shopping', 'Social', 'Others'];
          if (jobType === 'Sinh viên') optionCats.push('Education', 'Entertainment');
          else if (jobType === 'Văn phòng') optionCats.push('Beauty', 'Health', 'Entertainment');
          else optionCats.push('Health', 'Entertainment');

          const optCat = randomChoice(optionCats);
          const optDate = makeTimestamp(year, monthIndex, day, 'evening_shopping');
          let optAmount = 0;
          if (jobType === 'Sinh viên') {
            if (optCat === 'Shopping') optAmount = randomRange(60, 180) * 1000;
            else if (optCat === 'Education') optAmount = randomRange(30, 200) * 1000;
            else if (optCat === 'Entertainment') optAmount = randomRange(50, 120) * 1000;
            else optAmount = randomRange(30, 100) * 1000;
          } else {
            if (optCat === 'Shopping') optAmount = randomRange(250 * multi, 1500 * multi) * 1000;
            else if (optCat === 'Social') optAmount = randomRange(200 * multi, 1000 * multi) * 1000;
            else if (optCat === 'Health') optAmount = randomRange(150 * multi, 800 * multi) * 1000;
            else optAmount = randomRange(100 * multi, 500 * multi) * 1000;
          }

          allTxRows.push({
            wallet_id: u.wallet_id,
            creator_id: u.id,
            category_code: optCat,
            amount: optAmount,
            note: randomChoice(notes[optCat] || NOTES['Other']['Others']),
            occurred_at: optDate,
          });
        }
      }
    }

    console.log(`Đã chuẩn bị xong ${allTxRows.length} giao dịch từ ngày 1/8 đến 20/8.`);
    console.log('Đang ghi dữ liệu vào cơ sở dữ liệu theo lô (batch insert)...');

    // Batch insert in chunks of 100
    const BATCH_SIZE = 100;
    for (let i = 0; i < allTxRows.length; i += BATCH_SIZE) {
      const chunk = allTxRows.slice(i, i + BATCH_SIZE);
      const valueStrings = [];
      const queryParams = [];
      let paramIdx = 1;

      for (const row of chunk) {
        const catId = categoriesMap[row.category_code] || null;
        const txType = ['salary', 'business', 'bonus', 'investment'].includes(row.category_code) ? 'income' : 'expense';

        valueStrings.push(
          `($${paramIdx}, $${paramIdx + 1}, $${paramIdx + 2}, $${paramIdx + 3}, $${paramIdx + 4}, $${paramIdx + 5}, 'manual', $${paramIdx + 6}, $${paramIdx + 7})`
        );
        queryParams.push(row.wallet_id, row.creator_id, catId, row.category_code, row.amount, txType, row.note, row.occurred_at);
        paramIdx += 8;
        totalTransactions++;
      }

      const sql = `
        INSERT INTO transactions 
          (wallet_id, creator_id, category_id, category_code, amount, type, source, note, occurred_at)
        VALUES ${valueStrings.join(', ')}
      `;

      await client.query(sql, queryParams);
    }

    console.log('=== Hoàn tất mô phỏng dữ liệu tháng 8 (1/8 - 20/8) ===');
    console.log(`Tổng số giao dịch mới đã thêm: ${totalTransactions}`);

    // Verify statistics by demographic group
    const statsRes = await client.query(`
      SELECT 
        us.job_type,
        COUNT(t.id) as total_tx,
        ROUND(AVG(t.amount), 0) as avg_amount
      FROM transactions t
      JOIN users u ON t.creator_id = u.id
      JOIN user_settings us ON u.id = us.user_id
      WHERE u.email LIKE 'user_%@mimo.vn'
        AND t.occurred_at >= '2026-08-01 00:00:00'
        AND t.occurred_at < '2026-08-21 00:00:00'
      GROUP BY us.job_type
      ORDER BY total_tx DESC
    `);

    console.log('Thống kê giao dịch mới thêm (1/8 - 20/8) theo nhóm nghề nghiệp:');
    console.table(statsRes.rows);

  } catch (err) {
    console.error('Lỗi khi chạy mô phỏng:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

runAugustSimulation();
