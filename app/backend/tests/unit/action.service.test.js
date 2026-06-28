'use strict';

const actionService = require('../../src/modules/ai/action.service');

// Mock statsService and budgetsService
jest.mock('../../src/modules/stats/stats.service', () => ({
  dashboard: jest.fn().mockResolvedValue({
    totals: { expense: 5450000, income: 0, countExpense: 10, countIncome: 0 },
    byCategory: [
      { categoryCode: 'Food', total: 1200000, count: 3 },
      { categoryCode: 'Shopping', total: 2100000, count: 2 },
    ],
    byDay: [
      { day: '2026-06-01', expense: 1000000, income: 0 },
      { day: '2026-06-02', expense: 1200000, income: 0 },
      { day: '2026-06-06', expense: 2100000, income: 0 }, // peak day
    ],
    topNotes: [],
    range: { from: '2026-06-01T00:00:00.000Z', to: '2026-06-07T23:59:59.999Z' }
  })
}));

jest.mock('../../src/modules/budgets/budgets.service', () => ({
  list: jest.fn().mockResolvedValue([
    { period: 'month', categoryCode: null, amountLimit: 10000000 }
  ])
}));

jest.mock('../../src/config/db', () => ({
  query: jest.fn().mockImplementation((sql, params) => {
    // Return mock query results depending on query
    if (sql.includes('transactions') && sql.includes('ORDER BY t.amount DESC LIMIT 1')) {
      return Promise.resolve({
        rows: [{ note: 'mua sắm', category_code: 'Shopping', amount: 900000 }]
      });
    }
    if (sql.includes('transactions') && sql.includes('ORDER BY t.amount DESC LIMIT 3')) {
      return Promise.resolve({
        rows: [
          { id: '1', amount: 1200000, note: 'Sửa xe máy', category_code: 'Transport', occurred_at: '2026-06-02T10:00:00.000Z' },
          { id: '2', amount: 850000, note: 'Đi ăn lẩu với công ty', category_code: 'Food', occurred_at: '2026-06-06T19:00:00.000Z' }
        ]
      });
    }
    if (sql.includes('user_settings') && sql.includes('age_group')) {
      return Promise.resolve({
        rows: [{ age_group: '18-22 tuổi', job_type: 'Sinh viên' }]
      });
    }
    if (sql.includes('group_spending_benchmarks')) {
      return Promise.resolve({
        rows: [{ avg_amount: 2800000, p80_amount: 3800000 }]
      });
    }
    return Promise.resolve({ rows: [] });
  })
}));

describe('actionService report scenarios', () => {
  test('inferTimeRangeFromText formats correctly', () => {
    const range = actionService.inferTimeRangeFromText('tuần này');
    expect(range.granularity).toBe('week');
    expect(range.period_label).toContain('Tuần này');
  });

  test('buildReportStory for Kịch bản 1: Báo cáo Tổng chi tiêu (General)', () => {
    const reportResult = {
      period_label: 'Tháng này',
      total_expense: 5450000,
      total_income: 0,
      report_kind: 'expense',
      report_sub_type: 'general',
      compare_percent: 12,
      limit_amount: 10000000,
      limit_progress: 54.5
    };
    const story = actionService.buildReportStory(reportResult);
    expect(story).toContain('5.450.000đ');
    expect(story).toContain('nhanh hơn 12%');
    expect(story).toContain('54.5% của hạn mức tháng (10.000.000đ)');
  });

  test('buildReportStory for Kịch bản 2: Báo cáo Chi tiêu cao nhất (Highest)', () => {
    const reportResult = {
      period_label: 'Tuần này',
      total_expense: 2100000,
      total_income: 0,
      report_kind: 'expense',
      report_sub_type: 'highest',
      highest_transactions: [
        { note: 'Sửa xe máy', amount: 1200000, occurredAt: '2026-06-02T00:00:00.000Z' },
        { note: 'Đi ăn lẩu với công ty', amount: 850000, occurredAt: '2026-06-06T00:00:00.000Z' }
      ]
    };
    const story = actionService.buildReportStory(reportResult);
    expect(story).toContain("Quán quân 'đốt ví'");
    expect(story).toContain('Sửa xe máy');
    expect(story).toContain('1.200.000đ');
    expect(story).toContain('Đi ăn lẩu với công ty');
    expect(story).toContain('850.000đ');
    expect(story).toContain('chiếm 98% chi tiêu tuần');
  });

  test('buildReportStory for Kịch bản 3: Báo cáo Chi tiêu theo chu kỳ (Cycle)', () => {
    const reportResult = {
      period_label: 'Tuần này',
      total_expense: 2100000,
      total_income: 0,
      report_kind: 'expense',
      report_sub_type: 'cycle',
      peak_day: {
        day: '2026-06-06',
        day_of_week: 'thứ Bảy',
        amount: 900000,
        note: 'mua sắm'
      }
    };
    const story = actionService.buildReportStory(reportResult);
    expect(story).toContain('2.100.000đ');
    expect(story).toContain('thứ Bảy bùng nổ nhất với hơn 900.000đ cho mua sắm');
  });

  test('buildReportStory for Kịch bản So sánh đồng trang lứa (Peer Comparison)', () => {
    const reportResult = {
      period_label: 'Tháng này',
      total_expense: 3500000,
      total_income: 0,
      report_kind: 'expense',
      report_sub_type: 'compare',
      peer_benchmark: {
        age_group: '18-22 tuổi',
        job_type: 'Sinh viên',
        avg_amount: 2800000,
        p80_amount: 3800000,
        target_category: 'Food'
      }
    };
    const story = actionService.buildReportStory(reportResult);
    expect(story).toContain('3.500.000đ');
    expect(story).toContain('ăn uống');
    expect(story).toContain('cao hơn 25%');
    expect(story).toContain('nhóm 18-22 tuổi làm nghề Sinh viên (2.800.000đ)');
  });

  test('executeReport returns correct payload structure', async () => {
    const payload = await actionService.executeReport('user-1', {
      text: 'Báo cáo chi tiêu tuần này',
      timeRange: { from: '2026-06-01T00:00:00Z', to: '2026-06-07T23:59:59Z', period_label: 'Tuần này', granularity: 'week' }
    });
    expect(payload.kind).toBe('report');
    expect(payload.total_expense).toBe(5450000);
    expect(payload.report_sub_type).toBe('cycle'); // weekly report defaults to cycle when no highest keywords are present
    expect(payload.message).toContain('bùng nổ nhất với hơn 2.100.000đ cho chi tiêu');
  });

  test('executeReport returns peer comparison payload when subType is compare', async () => {
    const payload = await actionService.executeReport('user-1', {
      text: 'So sánh chi tiêu của mình với các bạn sinh viên khác',
      subType: 'compare',
      categoryCode: 'Food',
      timeRange: { from: '2026-06-01T00:00:00Z', to: '2026-06-07T23:59:59Z', period_label: 'Tháng này', granularity: 'month' }
    });
    expect(payload.kind).toBe('report');
    expect(payload.report_sub_type).toBe('compare');
    expect(payload.peer_benchmark).toEqual({
      age_group: '18-22 tuổi',
      job_type: 'Sinh viên',
      avg_amount: 2800000,
      p80_amount: 3800000,
      target_category: 'Food'
    });
    expect(payload.message).toContain('cao hơn 95%');
    expect(payload.message).toContain('nhóm 18-22 tuổi làm nghề Sinh viên');
  });
});

describe('SUGGEST_BUDGET action integration', () => {
  test('needsConfirm returns false for SUGGEST_BUDGET', () => {
    expect(actionService.needsConfirm('SUGGEST_BUDGET')).toBe(false);
    expect(actionService.needsConfirm('SUGGEST')).toBe(false);
  });

  test('actionPreviewLabel returns Vietnamese label for SUGGEST_BUDGET', () => {
    expect(actionService.actionPreviewLabel('SUGGEST_BUDGET')).toBe('Gợi ý hạn mức thông minh');
    expect(actionService.actionPreviewLabel('SUGGEST')).toBe('Gợi ý hạn mức thông minh');
  });

  test('needsConfirm still returns true for LIMIT/GOAL', () => {
    expect(actionService.needsConfirm('SET_LIMIT')).toBe(true);
    expect(actionService.needsConfirm('DELETE')).toBe(false);
    expect(actionService.needsConfirm('GOAL')).toBe(true);
  });

  test('resolveTargetMonthFromPayload maps Vietnamese time phrases', () => {
    const next = actionService.getNextMonthRef();
    const current = actionService.getCurrentMonthRef();
    expect(actionService.resolveTargetMonthFromPayload({ text: 'gợi ý chi tiêu tháng sau' })).toBe(next);
    expect(actionService.resolveTargetMonthFromPayload({ text: 'gợi ý ngân sách tháng này' })).toBe(current);
    expect(actionService.resolveTargetMonthFromPayload({
      actionDetails: { time: 'tuần này' },
      text: 'gợi ý chi tiêu tuần này',
    })).toBe(current);
    expect(actionService.resolveTargetMonthFromPayload({ targetMonth: '2026-08' })).toBe('2026-08');
  });

  test('needsConfirm matches sensitive profile actions', () => {
    expect(actionService.needsConfirm('SET_USERNAME')).toBe(true);
    expect(actionService.needsConfirm('SET_INCOME')).toBe(false);
    expect(actionService.needsConfirm('UPDATE_RECORD')).toBe(false);
    expect(actionService.needsConfirm('DELETE')).toBe(false);
    expect(actionService.needsConfirm('SET_ALERT')).toBe(true);
    expect(actionService.needsConfirm('EXPORT_DATA')).toBe(false);
  });

  test('resolveCategoryCode maps Vietnamese category phrases', () => {
    expect(actionService.resolveCategoryCode(null, { target: 'ăn uống' }, 'thống kê ăn uống tháng này')).toBe('Food');
    expect(actionService.resolveCategoryCode(null, null, 'tìm giao dịch đi lại')).toBe('Transport');
  });

  test('disambiguateActionType fixes limit vs goal confusion', () => {
    expect(actionService.disambiguateActionType('đặt hạn mức ăn uống 3 triệu', 'SET_GOAL')).toBe('SET_LIMIT');
    expect(actionService.disambiguateActionType('bù 200k vào mục tiêu mua điện thoại', 'SET_GOAL')).toBe('ADD_GOAL');
  });
});

