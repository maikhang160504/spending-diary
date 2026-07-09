import json
import re
import os

log_file = r'd:\Luan-Van\Project\bendmark.log'
out_file = r'd:\Luan-Van\Project\qwen_parsed_output.json'

data = []

with open(log_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

user_utterance = None
in_generated = False
generated_lines = []

for line in lines:
    user_match = re.search(r'Câu thoại của người dùng: (.*)<\|im_end\|>', line)
    if user_match:
        user_utterance = user_match.group(1).strip()
        continue
    
    if '--- DEBUG QWEN GENERATED ---' in line:
        in_generated = True
        generated_lines = []
        continue
        
    if in_generated and ('---------------------------' in line or '--- DEBUG QWEN PROMPT ---' in line):
        in_generated = False
        if user_utterance is not None:
            data.append({
                'user_utterance': user_utterance,
                'qwen_generated': '\n'.join(generated_lines).strip()
            })
            user_utterance = None
        continue
        
    if in_generated:
        generated_lines.append(line.rstrip('\n'))

with open(out_file, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f'Parsed {len(data)} items and saved to {out_file}')
