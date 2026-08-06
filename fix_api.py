import os

filepath = r'd:\Luan-Van\Project\app\frontend\mobile\lib\services\api_client.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("'walletId': ?walletId", "if (walletId != null) 'walletId': walletId")
content = content.replace("'type': ?type", "if (type != null) 'type': type")
content = content.replace("'categoryCode': ?categoryCode", "if (categoryCode != null) 'categoryCode': categoryCode")
content = content.replace("'from': ?from", "if (from != null) 'from': from")
content = content.replace("'to': ?to", "if (to != null) 'to': to")
content = content.replace("'timeRange': ?timeRange", "if (timeRange != null) 'timeRange': timeRange")
content = content.replace("'periodOffset': ?periodOffset?.toString()", "if (periodOffset != null) 'periodOffset': periodOffset.toString()")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
