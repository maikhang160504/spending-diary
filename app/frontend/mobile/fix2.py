import codecs
import re

def fix_mojibake(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    new_lines = []
    for line in content.split('\n'):
        try:
            # Try fixing the whole line
            fixed_line = line.encode('cp1252').decode('utf-8')
            new_lines.append(fixed_line)
        except:
            # If it fails, try fixing chunks separated by ascii non-alphanumeric (like quotes, brackets)
            # Actually, let's just split by non-word characters or spaces
            new_line = ""
            # A safer regex: find sequences of chars that don't include valid unicode Vietnamese chars
            # But wait, splitting by (\s+) is simple.
            parts = re.split(r'(\s+|[\[\]\(\)\{\}\'",<>])', line)
            for part in parts:
                try:
                    if part:
                        fixed_part = part.encode('cp1252').decode('utf-8')
                        new_line += fixed_part
                except:
                    new_line += part
            new_lines.append(new_line)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))
    print("Fixed mojibake safely.")

fix_mojibake('lib/screens/chat/chat_screen.dart')
