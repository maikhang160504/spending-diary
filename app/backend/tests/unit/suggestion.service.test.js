'use strict';

// ── Unit tests for suggestion.service.js (pure functions) ────────────
// These tests verify the core algorithm: denoising, weighted MA,
// income factor, holiday factor, saving rate, and story generation.

const {
  stddev,
  getPrev3Months,
  getHolidayFactor,
  getSavingRate,
  isHolidayMonth,
  denoiseCategory,
  computeBaseSpending,
  computeVarianceAdjustment,
  computeIncomeFactor,
  buildSuggestionStory,
  formatVnd,
} = require('../../src/modules/budgets/suggestion.service');

// ── stddev ───────────────────────────────────────────────────────────

describe('stddev', () => {
  it('returns 0 for single-element array', () => {
    expect(stddev([100])).toBe(0);
  });

  it('returns 0 for empty array', () => {
    expect(stddev([])).toBe(0);
  });

  it('computes correct stddev for uniform data', () => {
    expect(stddev([5, 5, 5, 5])).toBe(0);
  });

  it('computes correct stddev for varied data', () => {
    const sd = stddev([10, 20, 30]);
    // mean=20, variance = ((100+0+100)/3) ≈ 66.67, stddev ≈ 8.165
    expect(sd).toBeCloseTo(8.165, 2);
  });
});

// ── getPrev3Months ──────────────────────────────────────────────────

describe('getPrev3Months', () => {
  it('returns 3 previous months for mid-year', () => {
    const months = getPrev3Months('2026-07');
    expect(months).toEqual(['2026-06', '2026-05', '2026-04']);
  });

  it('handles year boundary (January)', () => {
    const months = getPrev3Months('2026-01');
    expect(months).toEqual(['2025-12', '2025-11', '2025-10']);
  });

  it('handles February', () => {
    const months = getPrev3Months('2026-02');
    expect(months).toEqual(['2026-01', '2025-12', '2025-11']);
  });

  it('handles March', () => {
    const months = getPrev3Months('2026-03');
    expect(months).toEqual(['2026-02', '2026-01', '2025-12']);
  });
});

// ── getHolidayFactor ────────────────────────────────────────────────

describe('getHolidayFactor', () => {
  it('returns 1.50 for Tết (February)', () => {
    expect(getHolidayFactor('2026-02')).toBe(1.50);
  });

  it('returns 1.20 for pre-Tết (January)', () => {
    expect(getHolidayFactor('2026-01')).toBe(1.20);
  });

  it('returns 0.85 for post-Tết (March)', () => {
    expect(getHolidayFactor('2026-03')).toBe(0.85);
  });

  it('returns 1.15 for school opening (September)', () => {
    expect(getHolidayFactor('2026-09')).toBe(1.15);
  });

  it('returns 1.25 for Christmas (December)', () => {
    expect(getHolidayFactor('2026-12')).toBe(1.25);
  });

  it('returns 1.00 for normal month (July)', () => {
    expect(getHolidayFactor('2026-07')).toBe(1.00);
  });
});

// ── isHolidayMonth ──────────────────────────────────────────────────

describe('isHolidayMonth', () => {
  it('January is a holiday month', () => {
    expect(isHolidayMonth('2026-01')).toBe(true);
  });

  it('February is a holiday month', () => {
    expect(isHolidayMonth('2026-02')).toBe(true);
  });

  it('December is a holiday month', () => {
    expect(isHolidayMonth('2026-12')).toBe(true);
  });

  it('July is NOT a holiday month', () => {
    expect(isHolidayMonth('2026-07')).toBe(false);
  });
});

// ── getSavingRate ────────────────────────────────────────────────────

describe('getSavingRate', () => {
  it('returns 0 for essential category (Food)', () => {
    expect(getSavingRate('Food', false)).toBe(0);
    expect(getSavingRate('Food', true)).toBe(0);
  });

  it('returns 0 for essential category (Housing)', () => {
    expect(getSavingRate('Housing', true)).toBe(0);
  });

  it('returns 0.05 for discretionary (Entertainment, not exceeded)', () => {
    expect(getSavingRate('Entertainment', false)).toBe(0.05);
  });

  it('returns 0.10 for discretionary (Shopping, peer exceeded)', () => {
    expect(getSavingRate('Shopping', true)).toBe(0.10);
  });

  it('returns 0 for non-categorized category', () => {
    expect(getSavingRate('Charity', false)).toBe(0);
  });
});

// ── denoiseCategory ─────────────────────────────────────────────────

describe('denoiseCategory', () => {
  it('returns sum for < 3 amounts (no filtering)', () => {
    expect(denoiseCategory('Food', [100, 200], '2026-06')).toBe(300);
  });

  it('returns sum for single amount', () => {
    expect(denoiseCategory('Food', [500], '2026-06')).toBe(500);
  });

  it('filters outlier > 3σ', () => {
    // Normal: [100, 110, 105, 95, 100], Extreme outlier: 50000
    // mean ≈ 8402, sd ≈ 17833, threshold = 8402+3*17833 ≈ 61901
    // A truly extreme outlier well beyond 3σ:
    const amounts = [100, 110, 105, 95, 100, 100, 100, 100, 100, 100, 50000];
    // mean ≈ 4637, sd ≈ 14387, threshold = 4637 + 3*14387 = 47798
    // 50000 > 47798 → filtered
    const result = denoiseCategory('Food', amounts, '2026-06');
    expect(result).toBe(1010); // sum of all except 50000
  });

  it('returns full sum when all values are uniform', () => {
    const amounts = [100, 100, 100, 100, 100];
    const result = denoiseCategory('Food', amounts, '2026-06');
    expect(result).toBe(500);
  });

  it('does NOT filter Shopping during holiday months', () => {
    const amounts = [100, 110, 105, 95, 100, 1500];
    const result = denoiseCategory('Shopping', amounts, '2026-01');
    expect(result).toBe(2010); // All included during holiday
  });

  it('does NOT filter Social during holiday months', () => {
    const amounts = [50, 60, 55, 1000];
    const result = denoiseCategory('Social', amounts, '2026-02');
    expect(result).toBe(1165); // All included during Tết
  });

  it('DOES filter Shopping extreme outlier in non-holiday months', () => {
    // Same pattern: many small values + one extreme outlier
    const amounts = [100, 110, 105, 95, 100, 100, 100, 100, 100, 100, 50000];
    const result = denoiseCategory('Shopping', amounts, '2026-06');
    expect(result).toBe(1010); // 50000 filtered out
  });
});

// ── computeBaseSpending ─────────────────────────────────────────────

describe('computeBaseSpending', () => {
  it('computes weighted MA for 3 months: 0.5, 0.3, 0.2', () => {
    const result = computeBaseSpending([1000000, 800000, 600000]);
    // 1000000*0.5 + 800000*0.3 + 600000*0.2 = 500000+240000+120000 = 860000
    expect(result).toBe(860000);
  });

  it('computes 60/40 split for 2 months', () => {
    const result = computeBaseSpending([1000000, 800000]);
    // 1000000*0.6 + 800000*0.4 = 600000+320000 = 920000
    expect(result).toBe(920000);
  });

  it('returns single value for 1 month', () => {
    expect(computeBaseSpending([500000])).toBe(500000);
  });

  it('returns null for empty data', () => {
    expect(computeBaseSpending([])).toBe(null);
  });

  it('filters null/undefined values', () => {
    const result = computeBaseSpending([1000000, null, undefined]);
    expect(result).toBe(1000000);
  });
});

// ── computeIncomeFactor ─────────────────────────────────────────────

describe('computeIncomeFactor', () => {
  it('returns 1.0 when income is stable', () => {
    expect(computeIncomeFactor([10000000, 10000000, 10000000])).toBe(1.0);
  });

  it('returns 1.0 with insufficient data (single income)', () => {
    expect(computeIncomeFactor([5000000])).toBe(1.0);
  });

  it('returns 1.0 when all incomes are 0', () => {
    expect(computeIncomeFactor([0, 0, 0])).toBe(1.0);
  });

  it('caps at 0.7 when income drops drastically', () => {
    // recent=3M, older avg=10M → ratio=0.3, capped to 0.7
    expect(computeIncomeFactor([3000000, 10000000, 10000000])).toBe(0.7);
  });

  it('caps at 1.0 when income increases', () => {
    // recent=15M, older avg=10M → ratio=1.5, capped to 1.0
    expect(computeIncomeFactor([15000000, 10000000, 10000000])).toBe(1.0);
  });

  it('returns proportional factor for moderate decrease', () => {
    // recent=8M, older avg=10M → ratio=0.8
    expect(computeIncomeFactor([8000000, 10000000, 10000000])).toBe(0.8);
  });
});

// ── buildSuggestionStory ────────────────────────────────────────────

describe('buildSuggestionStory', () => {
  it('returns "not enough data" message for empty suggestions', () => {
    const story = buildSuggestionStory([], '2026-07');
    expect(story).toContain('Chưa có đủ dữ liệu');
  });

  it('returns "not enough data" for null', () => {
    const story = buildSuggestionStory(null, '2026-07');
    expect(story).toContain('Chưa có đủ dữ liệu');
  });

  it('builds saving story when suggested < base', () => {
    const suggestions = [
      { categoryCode: 'Food', suggestedAmount: 2500000, baseSpending: 3000000, reason: 'test' },
      { categoryCode: 'Shopping', suggestedAmount: 1000000, baseSpending: 1200000, reason: 'test' },
    ];
    const story = buildSuggestionStory(suggestions, '2026-07');
    expect(story).toContain('tiết kiệm');
    expect(story).toContain('áp dụng');
  });

  it('builds holiday story when suggested > base', () => {
    const suggestions = [
      { categoryCode: 'Food', suggestedAmount: 4500000, baseSpending: 3000000, reason: 'test' },
    ];
    const story = buildSuggestionStory(suggestions, '2026-02');
    expect(story).toContain('nới rộng');
    expect(story).toContain('lễ');
  });

  it('builds stable story when suggested === base', () => {
    const suggestions = [
      { categoryCode: 'Food', suggestedAmount: 3000000, baseSpending: 3000000, reason: 'test' },
    ];
    const story = buildSuggestionStory(suggestions, '2026-07');
    expect(story).toContain('ổn định');
  });

  it('includes top 3 category details', () => {
    const suggestions = [
      { categoryCode: 'Food', suggestedAmount: 3000000, baseSpending: 3200000, reason: '' },
      { categoryCode: 'Shopping', suggestedAmount: 1500000, baseSpending: 1800000, reason: '' },
      { categoryCode: 'Transport', suggestedAmount: 800000, baseSpending: 900000, reason: '' },
      { categoryCode: 'Entertainment', suggestedAmount: 500000, baseSpending: 600000, reason: '' },
    ];
    const story = buildSuggestionStory(suggestions, '2026-07');
    expect(story).toContain('Food');
    expect(story).toContain('Shopping');
    expect(story).toContain('Transport');
    // 4th category (Entertainment) should NOT be in the details line
  });
});

// ── formatVnd ───────────────────────────────────────────────────────

describe('formatVnd', () => {
  it('formats with thousands separators', () => {
    const result = formatVnd(2500000);
    // Vietnamese locale uses . as separator: 2.500.000
    expect(result).toMatch(/2[.,]500[.,]000/);
  });

  it('handles 0', () => {
    expect(formatVnd(0)).toBe('0');
  });

  it('handles null/undefined', () => {
    expect(formatVnd(null)).toBe('0');
    expect(formatVnd(undefined)).toBe('0');
  });
});

// ── Full formula integration (B × I × (1-S) × H) ───────────────────

describe('Full Smart Budget Formula', () => {
  it('applies correct formula: B × I × (1-S) × H', () => {
    const B = computeBaseSpending([3000000, 2800000, 2600000]);
    // B = 3000000*0.5 + 2800000*0.3 + 2600000*0.2 = 1500000+840000+520000 = 2860000
    expect(B).toBe(2860000);

    const I = computeIncomeFactor([8000000, 10000000, 10000000]);
    // I = 8M / 10M = 0.8
    expect(I).toBe(0.8);

    const S = getSavingRate('Entertainment', true);
    // S = 0.10 (discretionary + peer exceeded)
    expect(S).toBe(0.10);

    const H = getHolidayFactor('2026-02');
    // H = 1.50 (Tết)
    expect(H).toBe(1.50);

    const suggested = Math.round(B * I * (1 - S) * H);
    // 2860000 * 0.8 * 0.9 * 1.5 = 3088800
    expect(suggested).toBe(3088800);
  });

  it('essential category: no saving rate, normal month', () => {
    const B = computeBaseSpending([4000000, 4000000, 4000000]);
    expect(B).toBe(4000000);

    const I = 1.0;
    const S = getSavingRate('Food', true); // essential → 0
    const H = getHolidayFactor('2026-06'); // normal → 1.0

    const suggested = Math.round(B * I * (1 - S) * H);
    expect(suggested).toBe(4000000); // Unchanged
  });

  it('post-Tết adjustment reduces budget by 15%', () => {
    const B = 5000000;
    const I = 1.0;
    const S = 0; // Food (essential)
    const H = getHolidayFactor('2026-03'); // 0.85

    const suggested = Math.round(B * I * (1 - S) * H);
    expect(suggested).toBe(4250000); // 5M * 0.85
  });
});

// ── computeVarianceAdjustment ───────────────────────────────────────

describe('computeVarianceAdjustment', () => {
  it('returns 0 adjustment when no last month limit is present', () => {
    expect(computeVarianceAdjustment(3000000, 0)).toEqual({
      adjustment: 0,
      reasonText: null,
      variance: 0,
    });
  });

  it('returns positive adjustment when last month spending exceeded budget limit', () => {
    // spent 5,000,000 > limit 4,000,000 -> variance +1,000,000 -> alpha 0.35 -> +350,000
    const res = computeVarianceAdjustment(5000000, 4000000, false);
    expect(res.adjustment).toBe(350000);
    expect(res.variance).toBe(1000000);
    expect(res.reasonText).toContain('tăng 350.000đ do vượt hạn mức tháng trước');
  });

  it('returns negative adjustment when last month spending was below budget limit', () => {
    // spent 3,000,000 < limit 5,000,000 -> variance -2,000,000 -> beta 0.25 -> -500,000
    const res = computeVarianceAdjustment(3000000, 5000000, false);
    expect(res.adjustment).toBe(-500000);
    expect(res.variance).toBe(-2000000);
    expect(res.reasonText).toContain('giảm 500.000đ do chi tiêu dưới hạn mức tháng trước');
  });

  it('uses conservative factors for fixed cost categories', () => {
    // spent 6,000,000 > limit 5,000,000 -> variance +1,000,000 -> alpha 0.20 -> +200,000
    const res = computeVarianceAdjustment(6000000, 5000000, true);
    expect(res.adjustment).toBe(200000);
  });
});

