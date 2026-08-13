import re

with open(r'd:\Luan-Van\Project\app\frontend\mobile\lib\services\app_queries.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add serializer for Query<Map<String, dynamic>>
content = re.sub(
    r'(Query<Map<String, dynamic>>\()([^)]*?)(?=\s*\))',
    lambda m: m.group(0) + (', serializer: (json) => Map<String, dynamic>.from(json as Map)' if 'serializer:' not in m.group(2) else ''),
    content
)

# Add serializer for Query<List<dynamic>>
content = re.sub(
    r'(Query<List<dynamic>>\()([^)]*?)(?=\s*\))',
    lambda m: m.group(0) + (', serializer: (json) => List<dynamic>.from(json as List)' if 'serializer:' not in m.group(2) else ''),
    content
)

with open(r'd:\Luan-Van\Project\app\frontend\mobile\lib\services\app_queries.dart', 'w', encoding='utf-8') as f:
    f.write(content)
