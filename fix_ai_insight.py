"""
Fix: Reset _aiInsight = null ở đầu hàm _loadReportData() trong 4 màn hình báo cáo chưa có.
Khi bộ lọc thay đổi => tải lại dữ liệu => xóa phân tích cũ để MiMo phân tích lại dựa trên dữ liệu mới.
"""

import re

files = [
    r'd:\Luan-Van\Project\app\frontend\mobile\lib\screens\report\cashflow_report_screen.dart',
    r'd:\Luan-Van\Project\app\frontend\mobile\lib\screens\report\category_spending_report_screen.dart',
    r'd:\Luan-Van\Project\app\frontend\mobile\lib\screens\report\peer_compare_report_screen.dart',
    r'd:\Luan-Van\Project\app\frontend\mobile\lib\screens\report\saving_trend_report_screen.dart',
]

for filepath in files:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    if '_aiInsight = null' in content:
        print(f'SKIP (already has reset): {filepath.split(chr(92))[-1]}')
        continue

    # Tìm dòng setState isLoading = true trong _loadReportData và thêm reset _aiInsight ngay trước
    # Pattern: setState(() => _isLoading = true); trong body của _loadReportData
    # Thêm _aiInsight = null; ngay trước setState
    old = 'setState(() => _isLoading = true);'
    new = '_aiInsight = null;\n    setState(() => _isLoading = true);'
    if old in content:
        content = content.replace(old, new, 1)  # chỉ thay lần đầu (trong _loadReportData)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'FIXED: {filepath.split(chr(92))[-1]}')
    else:
        # Fallback: thêm vào ngay đầu hàm _loadReportData
        print(f'WARNING - pattern not found in: {filepath.split(chr(92))[-1]}')
