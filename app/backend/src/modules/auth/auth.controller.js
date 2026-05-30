'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const authService = require('./auth.service');

exports.register = asyncHandler(async (req, res) => {
  const result = await authService.register(req.body);
  res.status(201).json({ success: true, data: result });
});

exports.login = asyncHandler(async (req, res) => {
  const result = await authService.login(req.body);
  res.json({ success: true, data: result });
});

exports.refresh = asyncHandler(async (req, res) => {
  const result = await authService.refresh(req.body);
  res.json({ success: true, data: result });
});

exports.logout = asyncHandler(async (req, res) => {
  await authService.logout(req.body);
  res.json({ success: true });
});

exports.me = asyncHandler(async (req, res) => {
  const user = await authService.findUserById(req.user.id);
  res.json({ success: true, data: { user } });
});

exports.changePassword = asyncHandler(async (req, res) => {
  await authService.changePassword(req.user.id, req.body);
  res.json({ success: true, message: 'Password changed successfully.' });
});

exports.getStreak = asyncHandler(async (req, res) => {
  const data = await authService.getStreak(req.user.id);
  res.json({ success: true, data });
});

exports.googleLogin = asyncHandler(async (req, res) => {
  const result = await authService.googleLogin(req.body);
  res.json({ success: true, data: result });
});
exports.updateProfile = asyncHandler(async (req, res) => {
  const user = await authService.updateProfile(req.user.id, req.body);
  res.json({ success: true, data: { user } });
});
