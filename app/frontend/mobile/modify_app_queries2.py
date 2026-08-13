import re

with open(r'd:\Luan-Van\Project\app\frontend\mobile\lib\services\app_queries.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Replace Map<String, dynamic>
text = re.sub(
    r'(static\s+Query<Map<String,\s*dynamic>>[^{]+?=>\s*Query<Map<String,\s*dynamic>>\([^;]+?)(?=\s*\);)',
    r'\1, serializer: (dynamic json) => Map<String, dynamic>.from(json as Map)',
    text
)

# Replace List<dynamic>
text = re.sub(
    r'(static\s+Query<List<dynamic>>[^{]+?=>\s*Query<List<dynamic>>\([^;]+?)(?=\s*\);)',
    r'\1, serializer: (dynamic json) => List<dynamic>.from(json as List)',
    text
)

with open(r'd:\Luan-Van\Project\app\frontend\mobile\lib\services\app_queries.dart', 'w', encoding='utf-8') as f:
    f.write(text)
