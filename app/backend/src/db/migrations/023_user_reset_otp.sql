-- Thêm cột lưu trữ mã OTP và thời gian hết hạn cho chức năng Quên mật khẩu
ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_otp VARCHAR(6);
ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_otp_expires TIMESTAMP;
