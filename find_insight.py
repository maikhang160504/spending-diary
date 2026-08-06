files = [
    (r'd:\Luan-Van\Project\app\frontend\mobile\lib\screens\report\cashflow_report_screen.dart', '_loadReportData'),
    (r'd:\Luan-Van\Project\app\frontend\mobile\lib\screens\report\category_spending_report_screen.dart', '_loadReportData'),
    (r'd:\Luan-Van\Project\app\frontend\mobile\lib\screens\report\cumulative_budget_report_screen.dart', '_loadReportData'),
    (r'd:\Luan-Van\Project\app\frontend\mobile\lib\screens\report\peer_compare_report_screen.dart', '_loadData'),
    (r'd:\Luan-Van\Project\app\frontend\mobile\lib\screens\report\saving_trend_report_screen.dart', '_loadReportData'),
]

for f, fn in files:
    content = open(f, encoding='utf-8').read()
    lines = content.split('\n')
    in_analyze = False
    found = []
    for i, line in enumerate(lines):
        if 'Future<void> _analyzeAI' in line:
            in_analyze = True
        # detect end of _analyzeAI (closing brace at same indent level)
        if in_analyze and i > 0 and line.strip() == '}' and '  }' == line.rstrip():
            in_analyze = False
        if not in_analyze and '_aiInsight =' in line and 'null' not in line:
            found.append((i+1, line.strip()[:120]))
    if found:
        print(f'\n=== {f.split(chr(92))[-1]} ===')
        for ln, text in found:
            print(f'  LINE {ln}: {text}')
