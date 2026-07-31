'use strict';

const aiService = require('../../src/modules/ai/ai.service');
const aiClient = require('../../src/services/aiClient');
const chatService = require('../../src/modules/chat/chat.service');
const { query } = require('../../src/config/db');

// Mock db
jest.mock('../../src/config/db', () => ({
  query: jest.fn(),
}));

// Mock aiClient
jest.mock('../../src/services/aiClient', () => ({
  aiChat: jest.fn(),
  inferText: jest.fn(),
}));

// Mock chatService
jest.mock('../../src/modules/chat/chat.service', () => ({
  getMessages: jest.fn(),
  addMessage: jest.fn(),
}));

// Mock wsHub
jest.mock('../../src/services/wsHub', () => ({
  sendToUser: jest.fn(),
}));

// Mock logger
jest.mock('../../src/config/logger', () => ({
  info: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
  debug: jest.fn(),
}));

describe('ai.service unit tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(global, 'setImmediate').mockImplementation((fn) => fn());
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('aiChat correctly slices messages, fetches profile MoM stats, summarizes older messages, and calls aiClient', async () => {
    // 1. Mock DB queries
    query.mockImplementation((sql, params) => {
      if (sql.includes('wallet_members') && sql.includes('LIMIT 1')) {
        return Promise.resolve({ rows: [{ wallet_id: 'wallet-123' }] });
      }
      if (sql.includes('user_settings') && sql.includes('verbal_style')) {
        return Promise.resolve({ rows: [{ verbal_style: 'funny' }] });
      }
      if (sql.includes('budgets') && sql.includes('transactions')) {
        // Wallet profile query
        return Promise.resolve({
          rows: [{ budget_total: 10000000, budget_remain: 8000000, frequency_week: 2, avg_amount: 150000, wallet_type: 'personal', member_count: 1 }]
        });
      }
      if (sql.includes('month_total') && sql.includes('category_code')) {
        // Categories stats
        return Promise.resolve({
          rows: [
            { category_code: 'Food', frequency_week: 1, avg_amount: 50000, month_total: 150000, pct: 15 }
          ]
        });
      }
      if (sql.includes('spent_today') && sql.includes('spent_week') && sql.includes('spent_month')) {
        // spendRes
        return Promise.resolve({
          rows: [{ spent_today: 50000, spent_week: 150000, spent_month: 2000000, spent_last_month: 4500000 }]
        });
      }
      if (sql.includes('user_corrections')) {
        return Promise.resolve({ rows: [] });
      }
      return Promise.resolve({ rows: [] });
    });

    // 2. Mock chat history with 6 messages (which is > 4, so it should slide and summarize)
    const mockDbMessages = [
      { role: 'user', content: 'Xem báo cáo tuần này', intent_action: { intent: 'Action', nlu: { action_type: 'REPORT' } } },
      { role: 'assistant', content: 'Báo cáo tuần này đây.', intent_action: { intent: 'Action', nlu: { action_type: 'REPORT', action_result: { kind: 'report', period_label: 'Tuần này', total_expense: 150000 } } } },
      { role: 'user', content: 'Chào Mimo', intent_action: { intent: 'Chitchat' } },
      { role: 'assistant', content: 'Chào bạn nha!', intent_action: { intent: 'Chitchat' } },
      { role: 'user', content: 'Tìm giao dịch đi lại', intent_action: { intent: 'Action', nlu: { action_type: 'SEARCH' } } },
      { role: 'assistant', content: 'Đây là các giao dịch.', intent_action: { intent: 'Action', nlu: { action_result: { kind: 'search', items: [{ note: 'xe bus', amount: 7000, categoryCode: 'Transport' }] } } } },
    ];
    chatService.getMessages.mockResolvedValue({ messages: mockDbMessages });

    // 3. Mock AI client response
    aiClient.aiChat.mockResolvedValue({
      intent: 'Chitchat',
      response: 'Mimo hiểu rồi nha!',
      gemini_json: { response: 'Mimo hiểu rồi nha!', mimo_emotion: 'Happy' },
      backend: 'gemini',
      latency_ms: 120,
    });

    // 4. Call aiChat
    const result = await aiService.aiChat('user-123', 'session-456', 'Ủa thế giao dịch thứ hai là gì?');

    // 5. Assertions
    expect(chatService.getMessages).toHaveBeenCalledWith('user-123', 'session-456', { limit: 20 });

    // Verify sliding window (last 4 messages of history + the new message)
    // The history fetched is 6. We pushed the new message, making it 7.
    // Sliced to last 4 messages:
    // Index -4: assistant ('Báo cáo tuần này đây.')
    // Index -3: user ('Tìm giao dịch đi lại')
    // Index -2: assistant ('Đây là các giao dịch.')
    // Index -1: user ('Ủa thế giao dịch thứ hai là gì?')
    expect(aiClient.aiChat).toHaveBeenCalled();
    const passedMessages = aiClient.aiChat.mock.calls[0][0];
    expect(passedMessages).toHaveLength(4);
    expect(passedMessages[3].content).toBe('Ủa thế giao dịch thứ hai là gì?');

    // Verify options passed to aiClient includes correct profile, spent_last_month, and summary
    const passedOptions = aiClient.aiChat.mock.calls[0][2];
    expect(passedOptions.profile).toBeDefined();
    expect(passedOptions.profile.spent_last_month).toBe(4500000);
    expect(passedOptions.chat_summary).toContain('REPORT');

    expect(result.response).toBe('Mimo hiểu rồi nha!');
    expect(chatService.addMessage).toHaveBeenCalledWith('user-123', 'session-456', expect.objectContaining({
      role: 'assistant',
      content: 'Mimo hiểu rồi nha!',
    }));
  });

  test('aiChat generates fallback text when LLM response is empty and intent is Record', async () => {
    query.mockImplementation((sql, params) => {
      if (sql.includes('wallet_members') && sql.includes('LIMIT 1')) {
        return Promise.resolve({ rows: [{ wallet_id: 'wallet-123' }] });
      }
      if (sql.includes('user_settings') && sql.includes('verbal_style')) {
        return Promise.resolve({ rows: [{ verbal_style: 'funny' }] });
      }
      if (sql.includes('user_corrections')) {
        return Promise.resolve({ rows: [] });
      }
      return Promise.resolve({ rows: [] });
    });

    chatService.getMessages.mockResolvedValue({ messages: [] });

    aiClient.aiChat.mockResolvedValue({
      intent: 'Record',
      record_type: 'Expense',
      category: 'Food',
      amount: 50000,
      backend: 'mock',
      latency_ms: 10,
    });

    const result = await aiService.aiChat('user-123', 'session-456', 'cơm sườn 50k');

    expect(result.response).toBe('Mimo đã ghi nhận khoản chi 50.000đ cho Ăn uống vào ví của bạn. Hãy cân đối chi tiêu hợp lý nhé!');
    expect(chatService.addMessage).toHaveBeenCalledWith('user-123', 'session-456', expect.objectContaining({
      role: 'assistant',
      content: 'Mimo đã ghi nhận khoản chi 50.000đ cho Ăn uống vào ví của bạn. Hãy cân đối chi tiêu hợp lý nhé!',
    }));
  });
});
