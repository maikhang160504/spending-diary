import os

with open('d:/Luan-Van/Project/patch_report.py', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    '  }\n}\n\nclass _MimoInsightCard extends StatelessWidget {',
    '  }\n}\n\"\"\"\n\nmimo_insight = \"\"\"\nclass _MimoInsightCard extends StatelessWidget {'
)

with open('d:/Luan-Van/Project/patch_report.py', 'w', encoding='utf-8') as f:
    f.write(content)

print('Fixed patch_report.py')
