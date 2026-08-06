import codecs
import re

def reverse_corruption(char):
    try:
        b = char.encode('cp1252')
        return b
    except UnicodeEncodeError:
        pass
    
    c = ord(char)
    if c in [0x81, 0x8d, 0x8f, 0x90, 0x9d]:
        return bytes([c])
        
    raise ValueError(f'Cannot reverse map {char}')

def fix_custom(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    new_lines = []
    for line in content.split('\n'):
        try:
            raw_bytes = bytearray()
            for char in line:
                raw_bytes.extend(reverse_corruption(char))
            fixed_line = raw_bytes.decode('utf-8')
            new_lines.append(fixed_line)
        except Exception as e:
            new_line = ""
            parts = re.split(r'(\s+)', line)
            for part in parts:
                if not part:
                    continue
                try:
                    raw_bytes = bytearray()
                    for char in part:
                        raw_bytes.extend(reverse_corruption(char))
                    fixed_part = raw_bytes.decode('utf-8')
                    new_line += fixed_part
                except:
                    new_line += part
            new_lines.append(new_line)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))
    print("Fixed mojibake with custom cp1252/latin1 hybrid.")

fix_custom('lib/screens/chat/chat_screen.dart')
