'use strict';

const fs = require('fs');
const path = require('path');
const { query } = require('../src/config/db');
const aiService = require('../src/modules/ai/ai.service');

const testCases = [
  // 1. REPORT_GENERAL
  { text: "Hôm nay tôi đã tiêu hết bao nhiêu tiền rồi?", expectedAction: "REPORT_GENERAL" },
  { text: "Từ ngày 1 đến ngày 10 tháng này tôi chi bao nhiêu?", expectedAction: "REPORT_GENERAL" },
  { text: "Tuần qua tiêu bao nhiêu tiền ăn uống?", expectedAction: "REPORT_GENERAL" },
  { text: "Mua sắm trong tháng trước tốn bao nhiêu?", expectedAction: "REPORT_GENERAL" },
  { text: "Báo cáo tổng quan cho tôi", expectedAction: "REPORT_GENERAL" },
  // 2. REPORT_COMPARE
  { text: "Tháng này tôi tiêu nhiều hơn tháng trước không?", expectedAction: "REPORT_COMPARE" },
  { text: "Tháng 5/2023 so với tháng 5/2024 thì sao", expectedAction: "REPORT_COMPARE" },
  { text: "So sánh chi phí ăn uống và đi lại tháng này", expectedAction: "REPORT_COMPARE" },
  { text: "So sánh thu nhập và chi tiêu tháng này", expectedAction: "REPORT_COMPARE" },
  // 3. SET_LIMIT
  { text: "Đặt hạn mức tháng này 20 triệu", expectedAction: "SET_LIMIT" },
  { text: "Giới hạn ăn uống 3 triệu", expectedAction: "SET_LIMIT" },
  { text: "Đổi hạn mức tháng này thành 10 triệu", expectedAction: "SET_LIMIT" },
  // 4. SET_GOAL (và ADD_GOAL)
  { text: "Tạo mục tiêu mua xe 50 triệu", expectedAction: "SET_GOAL" },
  { text: "Tạo quỹ nhóm du lịch 50 triệu", expectedAction: "SET_GOAL" },
  { text: "Tạo thử thách tiết kiệm 5 triệu trong 30 ngày", expectedAction: "SET_GOAL" },
  { text: "Nhắc hẹn Nam trả nợ 2 triệu vào tuần sau", expectedAction: "SET_GOAL" },
  { text: "Tăng mục tiêu mua xe lên 50 triệu", expectedAction: "SET_GOAL" },
  { text: "Cập nhật mục tiêu quỹ du lịch sang tháng 12 năm nay", expectedAction: "SET_GOAL" },
  // Missing slot context test:
  { text: "Tạo mục tiêu mua điện thoại", expectedAction: "SET_GOAL" },
  { text: "15 triệu", expectedAction: "SET_GOAL" }, // LLM should contextualize this!
  // 5. SET_TONE
  { text: "Từ nay hãy nói chuyện nghiêm khắc với tôi nhé.", expectedAction: "SET_TONE" },
  { text: "Đổi sang giọng điệu dận dỗi đi", expectedAction: "SET_TONE" },
  { text: "Hãy đổi sang giọng ngọt ngào nhé", expectedAction: "SET_TONE" },
  // 6. SEARCH_RECORD
  { text: "Hôm qua có mua ly trà sữa nào không?", expectedAction: "SEARCH_RECORD" },
  { text: "Tìm cho tôi các khoản chi trên 500k trong tuần trước.", expectedAction: "SEARCH_RECORD" },
  { text: "Các khoản chi vào ngày 15/5 vừa rồi", expectedAction: "SEARCH_RECORD" },
  { text: "Tìm mua sắm trên 1 triệu trong tháng trước", expectedAction: "SEARCH_RECORD" },
  // 7. SUGGEST_BUDGET
  { text: "Gợi ý cách lập ngân sách giúp tôi.", expectedAction: "SUGGEST_BUDGET" },
  { text: "Gợi ý cho tôi cách lập ngân sách để tiết kiệm 3 triệu mỗi tháng", expectedAction: "SUGGEST_BUDGET" },
  // 9. SYSTEM_SETTING
  { text: "Chuyển ứng dụng sang chế độ tối (dark mode).", expectedAction: "SYSTEM_SETTING" },
  // 10. SET_USERNAME
  { text: "Hãy đổi tên tôi thành Sếp.", expectedAction: "SET_USERNAME" },
  { text: "Gọi tên tôi là Khang", expectedAction: "SET_USERNAME" },
  // 11. SET_ALERT
  { text: "Cài đặt cảnh báo chi tiêu 80% ngân sách tháng.", expectedAction: "SET_ALERT" },
  { text: "Nhắc tôi ghi chép chi tiêu vào lúc 8h tối mỗi ngày.", expectedAction: "SET_ALERT" },
  { text: "Tắt cảnh báo chi tiêu đi", expectedAction: "SET_ALERT" }
];

async function runTests() {
  console.log("Starting test action flow...");
  
  // 1. Get a valid user (preferably a test user)
  const userRes = await query(`
    SELECT u.id as user_id, wm.wallet_id, u.username 
    FROM users u 
    JOIN wallet_members wm ON u.id = wm.user_id 
    ORDER BY (u.username ILIKE '%test%') DESC, u.id ASC
    LIMIT 1
  `);
  
  if (userRes.rows.length === 0) {
    console.error("No valid user with wallet found.");
    process.exit(1);
  }
  const user = userRes.rows[0];
  const userId = user.user_id;
  const walletId = user.wallet_id;
  console.log(`Testing with User ID: ${userId} (${user.username}), Wallet ID: ${walletId}`);

  const crypto = require('crypto');
  let sessionId = crypto.randomUUID();
  const sessionRes = await query('SELECT id FROM chat_sessions WHERE user_id = $1 LIMIT 1', [userId]);
  if (sessionRes.rows.length > 0) {
    sessionId = sessionRes.rows[0].id;
  } else {
    await query('INSERT INTO chat_sessions (id, user_id, title, wallet_id) VALUES ($1, $2, $3, $4)', [sessionId, userId, 'Test Session', walletId]);
  }
  
  let md = `# Kết quả Kiểm thử LLM Actions & RAG Flow\n\n`;
  md += `**Thời gian:** ${new Date().toLocaleString()}\n`;
  md += `**User ID:** ${userId} (${user.username}) | **Wallet ID:** ${walletId}\n\n---\n\n`;

  for (let i = 0; i < testCases.length; i++) {
    const tc = testCases[i];
    console.log(`Running test ${i+1}/${testCases.length}: ${tc.expectedAction} - "${tc.text}"`);
    
    try {
      const contextMeta = {
        local_hour: 15,
        local_day_of_month: 15,
        lat: 10.762622,
        lng: 106.660172
      };

      const pendingRes = await aiService.aiChat(userId, sessionId, tc.text, contextMeta, walletId);
      const pendingMsgId = pendingRes.messageId;
      
      // Poll database for background job completion (up to 60 seconds)
      let responseMsg = null;
      for (let wait = 0; wait < 60; wait++) {
        await new Promise(resolve => setTimeout(resolve, 1000));
        const msgRes = await query('SELECT * FROM chat_messages WHERE id = $1', [pendingMsgId]);
        if (msgRes.rows.length > 0) {
           const msg = msgRes.rows[0];
           let ia = msg.intent_action || {};
           if (typeof ia === 'string') {
              try { ia = JSON.parse(ia); } catch(e) {}
           }
           if (!ia.llmPending) {
              responseMsg = msg;
              responseMsg.intent_action = ia;
              break;
           }
        }
      }
      
      if (!responseMsg) {
          md += `## ${i+1}. ${tc.expectedAction} - ❌ FAIL (Timeout after 60s waiting for AI)\n\n---\n\n`;
          continue;
      }
      const intentAction = responseMsg.intent_action || {};
      const aiResponse = intentAction.nlu || {};
      
      const intent = aiResponse.intent;
      const actualAction = aiResponse.action_type || 'NONE';
      const actionMatch = (actualAction === tc.expectedAction) ? '✅ PASS' : '❌ FAIL';
      
      const slots = aiResponse.slots || aiResponse.action_details || {};
      const amountStr = aiResponse.amount ? aiResponse.amount : (slots.amount || 'N/A');
      const categoryStr = aiResponse.category ? aiResponse.category : (slots.category || 'N/A');
      const timeRangeStr = aiResponse.time_range ? JSON.stringify(aiResponse.time_range) : (slots.time_range ? JSON.stringify(slots.time_range) : 'N/A');
      
      md += `## ${i+1}. ${tc.expectedAction} - ${actionMatch}\n`;
      md += `**Câu lệnh:** "${tc.text}"\n\n`;
      md += `- **Intent:** \`${intent}\`\n`;
      md += `- **Action Type (Thực tế):** \`${actualAction}\`\n`;
      md += `- **Slots (Bóc tách dữ liệu):**\n`;
      md += `  - **Amount:** \`${amountStr}\`\n`;
      md += `  - **Category:** \`${categoryStr}\`\n`;
      md += `  - **Time Range:** \`${timeRangeStr}\`\n`;
      md += `  - **Raw Slots:** \`${JSON.stringify(slots)}\`\n`;
      md += `- **NLG Response (Câu thoại của AI):** ${aiResponse.gemini_json?.response || aiResponse.gemini_json?.story || aiResponse.nlg_response || aiResponse.content || responseMsg.content || 'Không có'}\n\n`;
      
      md += `### Mô phỏng Mobile UI hiển thị:\n`;
      if (actualAction === tc.expectedAction) {
        if (actualAction === 'REPORT_GENERAL') {
          md += `> 📱 Hiển thị Widget **ReportGeneralWidget** (Biểu đồ tổng quan hoặc thống kê danh mục).\n`;
          md += `> Dữ liệu RAG trả về: \`${JSON.stringify(aiResponse.action_result || {}).substring(0, 200)}...\`\n`;
        } else if (actualAction === 'REPORT_COMPARE') {
          md += `> 📱 Hiển thị Widget **ReportCompareWidget** (So sánh tăng/giảm giữa 2 mốc).\n`;
          md += `> Dữ liệu RAG trả về: \`${JSON.stringify(aiResponse.action_result || {}).substring(0, 200)}...\`\n`;
        } else if (actualAction === 'SEARCH_RECORD') {
          md += `> 📱 Hiển thị Widget **SearchRecordWidget** (Danh sách các giao dịch tìm thấy).\n`;
          md += `> Số lượng tìm thấy: ${aiResponse.action_result?.data?.length || 0} giao dịch.\n`;
        } else if (actualAction === 'SUGGEST_BUDGET') {
          md += `> 📱 Hiển thị Widget **SuggestBudgetWidget** (Các thẻ mẹo tiết kiệm và phân bổ).\n`;
          md += `> Số lượng gợi ý: ${aiResponse.action_result?.suggestions?.length || 0} mẹo.\n`;
        } else if (['SET_LIMIT', 'SET_GOAL', 'ADD_GOAL', 'SET_TONE', 'SYSTEM_SETTING', 'SET_USERNAME', 'SET_ALERT'].includes(actualAction)) {
          md += `> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.\n`;
          md += `> Dữ liệu RAG trả về: \`${JSON.stringify(aiResponse.action_result || {}).substring(0, 200)}...\`\n`;
        } else {
          md += `> 📱 Trả về dạng Text Message bình thường.\n`;
        }
      } else {
         md += `> 📱 Lỗi luồng, hiển thị text message thông thường.\n`;
      }
      
      md += `\n---\n\n`;
      
    } catch (err) {
      console.error(`Error on ${tc.expectedAction}:`, err.message);
      md += `## ${i+1}. ${tc.expectedAction} - ❌ ERROR\n`;
      md += `**Câu lệnh:** "${tc.text}"\n`;
      md += `**Lỗi:** \`${err.message}\`\n\n---\n\n`;
    }
  }

  const outPath = 'C:\\Users\\LENOVO\\.gemini\\antigravity-ide\\brain\\c9e59bec-2162-4282-ab0e-1823ce0a180e\\test_action_results.md';
  fs.writeFileSync(outPath, md, 'utf-8');
  console.log(`Completed. Results saved to ${outPath}`);
  process.exit(0);
}

runTests();
