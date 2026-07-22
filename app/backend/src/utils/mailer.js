'use strict';

const nodemailer = require('nodemailer');
const env = require('../config/env');
const logger = require('../config/logger');

let transporter = null;

if (env.mail.user && env.mail.pass) {
  transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: env.mail.user,
      pass: env.mail.pass,
    },
  });
} else {
  logger.warn('Nodemailer config is missing. Email features will be disabled or simulated.');
}

async function sendMail(options) {
  if (!transporter) {
    logger.info(`[SIMULATED EMAIL] To: ${options.to}, Subject: ${options.subject}`);
    return;
  }
  
  const mailOptions = {
    from: `"SpendDiary" <${env.mail.user}>`,
    ...options
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    logger.info(`Email sent to ${options.to}: ${info.messageId}`);
    return info;
  } catch (error) {
    logger.error('Error sending email:', error);
    throw error;
  }
}

async function sendBanNotification(email, reason) {
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333;">
      <h2 style="color: #ef4444;">Tài khoản bị khóa</h2>
      <p>Xin chào,</p>
      <p>Tài khoản SpendDiary của bạn đã bị khóa với lý do sau:</p>
      <blockquote style="border-left: 4px solid #ef4444; padding-left: 16px; margin-left: 0; font-weight: bold; background: #fef2f2; padding: 12px;">
        ${reason || 'Vi phạm điều khoản sử dụng'}
      </blockquote>
      <p>Nếu bạn cho rằng đây là một sự nhầm lẫn, vui lòng mở ứng dụng SpendDiary và chọn mục <b>"Gửi khiếu nại"</b> tại màn hình đăng nhập để yêu cầu mở khóa tài khoản.</p>
      <p>Trân trọng,<br/>Đội ngũ SpendDiary</p>
    </div>
  `;

  return sendMail({
    to: email,
    subject: 'Thông báo khóa tài khoản SpendDiary',
    html
  });
}

module.exports = {
  sendMail,
  sendBanNotification
};
