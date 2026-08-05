'use strict';

const suggestionService = require('../../src/modules/budgets/suggestion.service');
const budgetsService = require('../../src/modules/budgets/budgets.service');
const { query } = require('../../src/config/db');

jest.mock('../../src/modules/budgets/budgets.service');
jest.mock('../../src/config/db', () => ({
  query: jest.fn(),
  withTransaction: jest.fn((cb) => cb({ query: jest.fn() }))
}));

describe('SUGGEST_BUDGET Active Restrictions & Calibrations', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  test('Restricts suggestions only to active budget categories', async () => {
    // User has active budgets for Food and Transport only
    budgetsService.list.mockResolvedValue([
      { categoryCode: 'Food', amountLimit: 5000000 },
      { categoryCode: 'Transport', amountLimit: 1500000 }
    ]);

    // Mock query returns spending data for 3 previous months for Food, Transport, and Shopping
    // YYYY-MM queries will be executed for prev3Months
    query.mockImplementation((sql, params) => {
      if (sql.includes('transactions') && sql.includes('type = \'expense\'')) {
        // Return Food, Transport, and Shopping (Shopping is not in active budgets, so it should be filtered out)
        return Promise.resolve({
          rows: [
            { category_code: 'Food', amount: 4500000 },
            { category_code: 'Transport', amount: 1200000 },
            { category_code: 'Shopping', amount: 2000000 }
          ]
        });
      }
      if (sql.includes('transactions') && sql.includes('type = \'income\'')) {
        return Promise.resolve({ rows: [{ total: 10000000 }] });
      }
      return Promise.resolve({ rows: [] });
    });

    const suggestions = await suggestionService.computeSuggestionsForUser('user-1', '2026-07');

    // Should only contain Food and Transport suggestions
    const categories = suggestions.map(s => s.category_code);
    expect(categories).toContain('Food');
    expect(categories).toContain('Transport');
    expect(categories).not.toContain('Shopping');
  });

  test('Applies Dynamic Adjustments rule when Needs exceeds 50%', async () => {
    // Active budgets for Food, Transport, and Shopping
    budgetsService.list.mockResolvedValue([
      { categoryCode: 'Food', amountLimit: 6000000 },
      { categoryCode: 'Transport', amountLimit: 1000000 },
      { categoryCode: 'Shopping', amountLimit: 4000000 }
    ]);

    // Total income = 10,000,000. Needs = Food + Transport = 7,000,000 (which is 70% > 50%)
    // Wants = Shopping = 4,000,000 (which is 40%)
    query.mockImplementation((sql, params) => {
      if (sql.includes('transactions') && sql.includes('type = \'expense\'')) {
        return Promise.resolve({
          rows: [
            { category_code: 'Food', amount: 6000000 },
            { category_code: 'Transport', amount: 1000000 },
            { category_code: 'Shopping', amount: 4000000 }
          ]
        });
      }
      if (sql.includes('transactions') && sql.includes('type = \'income\'')) {
        return Promise.resolve({ rows: [{ total: 10000000 }] });
      }
      return Promise.resolve({ rows: [] });
    });

    const suggestions = await suggestionService.computeSuggestionsForUser('user-1', '2026-07');

    const food = suggestions.find(s => s.category_code === 'Food');
    const transport = suggestions.find(s => s.category_code === 'Transport');
    const shopping = suggestions.find(s => s.category_code === 'Shopping');

    // Essential needs (Food, Transport) should keep their values as Needs limit is adjusted to initialNeedsSum
    expect(food.suggested_amount).toBe(6000000);
    expect(transport.suggested_amount).toBe(1000000);

    // Wants (Shopping) should be scaled down to 50% of initial wants (initial is 4M - 5% saving rate = 3.8M; 50% is 1.9M)
    expect(shopping.suggested_amount).toBe(1900000);
    expect(shopping.reason).toContain('Linh hoạt điều chỉnh (giảm 50%)');
  });

  test('Adjusts suggested amount up or down based on last month budget variance (sử dụng - hạn mức)', async () => {
    budgetsService.list.mockResolvedValue([
      { categoryCode: 'Food', amountLimit: 4000000 },       // spent 5M > limit 4M -> variance +1M -> alpha 0.35 -> +350k
      { categoryCode: 'Entertainment', amountLimit: 3000000 } // spent 2M < limit 3M -> variance -1M -> beta 0.25 -> -250k
    ]);

    query.mockImplementation((sql, params) => {
      if (sql.includes('transactions') && sql.includes('type = \'expense\'')) {
        return Promise.resolve({
          rows: [
            { category_code: 'Food', amount: 5000000 },
            { category_code: 'Entertainment', amount: 2000000 }
          ]
        });
      }
      if (sql.includes('transactions') && sql.includes('type = \'income\'')) {
        return Promise.resolve({ rows: [{ total: 20000000 }] });
      }
      return Promise.resolve({ rows: [] });
    });

    const suggestions = await suggestionService.computeSuggestionsForUser('user-1', '2026-07');

    const food = suggestions.find(s => s.category_code === 'Food');
    const ent = suggestions.find(s => s.category_code === 'Entertainment');

    expect(food.suggested_amount).toBe(5350000);
    expect(food.reason).toContain('tăng 350.000đ do vượt hạn mức tháng trước');

    expect(ent.suggested_amount).toBe(1660000);
    expect(ent.reason).toContain('giảm 250.000đ do chi tiêu dưới hạn mức tháng trước');
  });
});

