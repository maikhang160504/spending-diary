import re

filepath = r'd:\Luan-Van\Project\app\frontend\mobile\lib\screens\chat\chat_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace downloading
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*const SnackBar\(content: Text\('⏳ Đang tải xuống báo cáo Excel/CSV\.\.\.'\)\),\s*\);",
    r"MimoSnackBar.showInfo(context, message: '⏳ Đang tải xuống báo cáo Excel/CSV...');",
    content
)

# Replace success
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content: Text\('✅ Đã tải xuống báo cáo chi tiêu: \Sfilename'\),\s*backgroundColor: AppColors\.teal,\s*duration: const Duration\(seconds: 4\),\s*\),\s*\);".replace('S', '$'),
    r"MimoSnackBar.showSuccess(context, message: f'✅ Đã tải xuống báo cáo chi tiêu: \Sfilename');".replace('S', '$').replace("f'", "'").replace("\S", "$"),
    content
)

# Replace error
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content: Text\('❌ Lỗi tải tệp: \S{e.toString\(\)}'\),\s*backgroundColor: AppColors\.danger,\s*\),\s*\);".replace('S', '$'),
    r"MimoSnackBar.showError(context, message: f'❌ Lỗi tải tệp: \S{{e.toString()}}');".replace('S', '$').replace("f'", "'").replace("\S", "$"),
    content
)

if 'MimoSnackBar' in content and 'import \'../../widgets/mimo_snackbar.dart\';' not in content:
    content = content.replace("import '../../widgets/typing_indicator.dart';", "import '../../widgets/typing_indicator.dart';\nimport '../../widgets/mimo_snackbar.dart';")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
