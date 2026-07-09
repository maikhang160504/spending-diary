import os

file_path = "d:/Luan-Van/Project/app/frontend/mobile/lib/screens/financial_tools/financial_tools_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("\\'", "'")
content = content.replace("context.palette.bg", "Theme.of(context).scaffoldBackgroundColor")
content = content.replace("context.palette.card", "Theme.of(context).cardColor")
content = content.replace("context.palette.textPrimary", "Theme.of(context).textTheme.bodyLarge!.color!")
content = content.replace("context.palette.muted", "Colors.grey")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Fixed financial_tools_screen.dart")
