'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./budgets.service');
const suggestionService = require('./suggestion.service');

exports.list = asyncHandler(async (req, res) => {
  const data = await service.list(req.user.id);
  res.json({ success: true, data });
});

exports.summary = asyncHandler(async (req, res) => {
  const data = await service.summary(req.user.id);
  res.json({ success: true, data });
});

exports.create = asyncHandler(async (req, res) => {
  const data = await service.create(req.user.id, req.body);
  res.status(201).json({ success: true, data });
});

exports.update = asyncHandler(async (req, res) => {
  const data = await service.update(req.user.id, req.params.id, req.body);
  res.json({ success: true, data });
});

exports.remove = asyncHandler(async (req, res) => {
  await service.remove(req.user.id, req.params.id);
  res.json({ success: true });
});

// ── Smart Budget Suggestions ──────────────────────────────────────

exports.getSuggestions = asyncHandler(async (req, res) => {
  const now = new Date();
// Removed last week restriction

  const month = req.query.month || getNextMonth();
  // Tự động tính toán lại để luôn cập nhật theo số liệu chi tiêu mới nhất và làm tròn chuẩn
  await suggestionService.generateForUser(req.user.id, month);
  const suggestions = await suggestionService.getSuggestions(req.user.id, month);
  const story = suggestionService.buildSuggestionStory(suggestions, month);
  res.json({ success: true, data: { targetMonth: month, suggestions, story } });
});

exports.applySuggestions = asyncHandler(async (req, res) => {
  const month = req.body.month || getNextMonth();
  const overrides = req.body.overrides || {};
  const result = await suggestionService.applySuggestions(req.user.id, month, overrides);
  res.json({
    success: true,
    data: result,
    message: `✅ Đã áp dụng ${result.applied} hạn mức thông minh cho tháng tới!`,
  });
});

exports.dismissSuggestions = asyncHandler(async (req, res) => {
  const month = req.body.month || getNextMonth();
  await suggestionService.dismissSuggestions(req.user.id, month);
  res.json({ success: true, message: 'Đã bỏ qua gợi ý. Bạn có thể tự đặt hạn mức trong Cài đặt.' });
});

function getNextMonth() {
  const now = new Date();
  const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  const y = nextMonth.getFullYear();
  const m = String(nextMonth.getMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

