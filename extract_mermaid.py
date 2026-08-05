import re

with open('d:/Luan-Van/Project/Luan_van_Hoan_chinh.md', 'r', encoding='utf-8') as f:
    text = f.read()

blocks = re.finditer(r'```mermaid(.*?)```', text, re.DOTALL)
with open('d:/Luan-Van/Project/mermaid_blocks_dump.txt', 'w', encoding='utf-8') as out:
    for i, b in enumerate(blocks):
        out.write(f'--- BLOCK {i} ---\n')
        out.write(b.group(1).strip() + '\n\n')
