'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./transactions.service');

exports.list = asyncHandler(async (req, res) => {
  const data = await service.listForUser(req.user.id, req.valid?.query || {});
  res.json({ success: true, data });
});

exports.get = asyncHandler(async (req, res) => {
  const data = await service.getById(req.user.id, req.params.id);
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
  await service.softDelete(req.user.id, req.params.id);
  res.json({ success: true });
});

exports.exportCsv = asyncHandler(async (req, res) => {
  const { period, date } = req.query;
  const range = service.inferRangeForExport(period, date);
  const list = await service.listForUser(req.user.id, {
    from: range.from,
    to: range.to,
    pageSize: 10000
  });

  // UTF-8 BOM prefix for Excel Vietnamese characters display
  let csvContent = '\uFEFF';
  csvContent += 'Mã giao dịch,Ngày phát sinh,Loại,Danh mục,Số tiền,Ghi chú,Nguồn nhập,Độ tin cậy\n';
  
  const VI_CATEGORY_LABELS = {
    'Food': 'Ăn uống',
    'Transport': 'Di chuyển',
    'Housing': 'Nhà ở',
    'Shopping': 'Mua sắm',
    'Entertainment': 'Giải trí',
    'Health': 'Sức khỏe',
    'Education': 'Giáo dục',
    'Beauty': 'Làm đẹp',
    'Social': 'Xã hội',
    'Others': 'Tiêu dùng khác',
    'salary': 'Lương',
    'bonus': 'Thưởng',
    'investment': 'Đầu tư',
    'business': 'Kinh doanh'
  };

  for (const tx of list.items) {
    const dateStr = new Date(tx.occurredAt).toLocaleString('vi-VN');
    const typeLabel = tx.type === 'income' ? 'Thu nhập' : 'Chi tiêu';
    const catLabel = VI_CATEGORY_LABELS[tx.categoryCode] || tx.categoryCode || 'Khác';
    const sourceLabel = tx.source === 'manual' ? 'Thủ công' : tx.source === 'text' ? 'Trò chuyện' : tx.source === 'bill' ? 'Hóa đơn' : tx.source;
    const confidence = tx.aiConfidence != null ? `${Math.round(tx.aiConfidence * 100)}%` : 'N/A';
    
    const noteClean = (tx.note || '').replace(/"/g, '""');
    csvContent += `"${tx.id}","${dateStr}","${typeLabel}","${catLabel}",${tx.amount},"${noteClean}","${sourceLabel}","${confidence}"\n`;
  }

  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename=transactions_export_${period || 'all'}.csv`);
  res.send(csvContent);
});
