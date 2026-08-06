import codecs
import re

line = b"    'Th\xe1\xbb\x91ng k\xc3\xaa chi ti\xc3\xaau tu\xe1\xba\xa7n n\xc3\x83\xc2\xa0y',\r\n".decode('utf-8')
new_line = ""
parts = re.split(r'(\s+|[\[\]\(\)\{\}\'",<>.!?;:])', line)
for part in parts:
    if not part:
        continue
    try:
        if all(ord(c) < 256 for c in part):
            fixed_part = part.encode('latin1').decode('utf-8')
            new_line += fixed_part
        else:
            new_line += part
    except Exception as e:
        new_line += part

print(new_line.encode('utf-8'))
