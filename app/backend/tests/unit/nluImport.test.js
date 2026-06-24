'use strict';

process.env.JWT_SECRET = 'test-secret';
process.env.NODE_ENV = 'test';

const request = require('supertest');
const fs = require('fs');
const path = require('path');
const app = require('../../src/app');

describe('POST /api/admin/nlu/import-csv', () => {
  let existsSpy;
  let readSpy;
  let appendSpy;

  beforeEach(() => {
    existsSpy = jest.spyOn(fs, 'existsSync').mockImplementation((p) => {
      if (p.includes('intent_record.csv')) return true;
      return false;
    });

    readSpy = jest.spyOn(fs, 'readFileSync').mockImplementation((p) => {
      if (p.includes('intent_record.csv')) {
        return 'text,label,type,is_money\n"Ăn sáng",Food,expense,1\n';
      }
      throw new Error('File not found');
    });

    appendSpy = jest.spyOn(fs, 'appendFileSync').mockImplementation(() => {});
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('returns 400 if no file uploaded', async () => {
    const res = await request(app)
      .post('/api/admin/nlu/import-csv')
      .send();
    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Vui lòng chọn file CSV');
  });

  test('returns 400 if CSV is empty', async () => {
    const res = await request(app)
      .post('/api/admin/nlu/import-csv')
      .attach('file', Buffer.from(''), 'empty.csv');
    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Tập tin CSV rỗng');
  });

  test('returns 400 if header is invalid', async () => {
    const invalidHeader = 'wrong_col,label,type,is_money\n"Ăn trưa",Food,expense,1';
    const res = await request(app)
      .post('/api/admin/nlu/import-csv')
      .attach('file', Buffer.from(invalidHeader), 'test.csv');
    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Dòng tiêu đề (header) không hợp lệ');
  });

  test('returns 400 if data row is missing columns (is_money)', async () => {
    const badRow = 'text,label,type,is_money\n"Ăn trưa",Food,expense';
    const res = await request(app)
      .post('/api/admin/nlu/import-csv')
      .attach('file', Buffer.from(badRow), 'test.csv');
    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Thiếu cột dữ liệu');
  });

  test('returns 400 if data row has invalid category', async () => {
    const badCategory = 'text,label,type,is_money\n"Ăn trưa",InvalidCategory,expense,1';
    const res = await request(app)
      .post('/api/admin/nlu/import-csv')
      .attach('file', Buffer.from(badCategory), 'test.csv');
    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Danh mục (label) \'InvalidCategory\' không hợp lệ');
  });

  test('returns 400 if data row has invalid type', async () => {
    const badType = 'text,label,type,is_money\n"Ăn trưa",Food,bad_type,1';
    const res = await request(app)
      .post('/api/admin/nlu/import-csv')
      .attach('file', Buffer.from(badType), 'test.csv');
    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Loại giao dịch (type) phải là \'expense\' hoặc \'income\'');
  });

  test('returns 400 if data row has invalid is_money', async () => {
    const badIsMoney = 'text,label,type,is_money\n"Ăn trưa",Food,expense,3';
    const res = await request(app)
      .post('/api/admin/nlu/import-csv')
      .attach('file', Buffer.from(badIsMoney), 'test.csv');
    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Cột \'is_money\' phải là \'0\' hoặc \'1\'');
  });

  test('returns 200 and imports valid data, skipping duplicate header lines', async () => {
    const validCsv = 'text,label,type,is_money\n"Ăn trưa",Food,expense,1\ntext,label,type,is_money\n"Cà phê",Food,expense,0';
    const res = await request(app)
      .post('/api/admin/nlu/import-csv')
      .attach('file', Buffer.from(validCsv), 'test.csv');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.addedCount).toBe(2);

    expect(appendSpy).toHaveBeenCalled();
    const appendedData = appendSpy.mock.calls[0][1];
    expect(appendedData).toContain('"Ăn trưa",Food,expense,1\n');
    expect(appendedData).toContain('"Cà phê",Food,expense,0\n');
    expect(appendedData).not.toContain('text,label,type,is_money');
  });

  test('returns 400 if data row has too many columns', async () => {
    const badRow = 'text,label,type,is_money\n"Ăn trưa",Food,expense,1,extra';
    const res = await request(app)
      .post('/api/admin/nlu/import-csv')
      .attach('file', Buffer.from(badRow), 'test.csv');
    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Thiếu cột dữ liệu hoặc số lượng cột không hợp lệ');
  });
});
