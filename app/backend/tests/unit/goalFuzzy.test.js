'use strict';

const actionService = require('../../src/modules/ai/action.service');
const goalsService = require('../../src/modules/goals/goals.service');

jest.mock('../../src/modules/goals/goals.service');

describe('Saving Goal Fuzzy Matching', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  test('Fuzzy matches existing goal "Mua xe máy" when user inputs "đặt mục tiêu mua xe máy 20tr" (> 75% similarity)', async () => {
    // Mock goals list returns "Mua xe máy"
    goalsService.list.mockResolvedValue([
      { id: 'goal-1', name: 'Mua xe máy', target_amount: 15000000, current_amount: 5000000 }
    ]);
    goalsService.contribute.mockResolvedValue({
      id: 'goal-1',
      name: 'Mua xe máy',
      target_amount: 15000000,
      current_amount: 7000000
    });

    const payload = {
      actionType: 'SET_GOAL',
      goalName: 'mua xe máy 20tr',
      amount: 2000000,
      text: 'đặt mục tiêu mua xe máy 20tr'
    };

    const result = await actionService.executeSetGoal('user-1', payload);

    expect(goalsService.list).toHaveBeenCalledWith('user-1');
    expect(goalsService.contribute).toHaveBeenCalledWith('user-1', 'goal-1', 2000000);
    expect(goalsService.create).not.toHaveBeenCalled();
    expect(result.kind).toBe('goal_contribute');
    expect(result.message).toContain("Mimo đã ghi nhận 2.000.000đ tích lũy vào mục tiêu 'Mua xe máy'");
  });

  test('Creates a new goal when similarity is <= 75% (e.g. "Mua laptop" vs "Mua xe máy")', async () => {
    goalsService.list.mockResolvedValue([
      { id: 'goal-1', name: 'Mua xe máy', target_amount: 15000000, current_amount: 5000000 }
    ]);
    goalsService.create.mockResolvedValue({
      id: 'goal-2',
      name: 'Mua laptop',
      target_amount: 20000000,
      current_amount: 0
    });

    const payload = {
      actionType: 'SET_GOAL',
      goalName: 'Mua laptop',
      amount: 20000000,
      text: 'đặt mục tiêu mua laptop 20tr'
    };

    const result = await actionService.executeSetGoal('user-1', payload);

    expect(goalsService.list).toHaveBeenCalledWith('user-1');
    expect(goalsService.contribute).not.toHaveBeenCalled();
    expect(goalsService.create).toHaveBeenCalledWith('user-1', expect.objectContaining({
      name: 'Mua laptop',
      targetAmount: 20000000
    }));
    expect(result.kind).toBe('goal');
    expect(result.message).toContain('Đã tạo mục tiêu mới "Mua laptop"');
  });
});
