import codecs
import re

def fix_double_utf8(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    new_lines = []
    for line in content.split('\n'):
        try:
            # Try fixing the whole line
            # We encode to latin1 to get the raw bytes, then decode as utf-8
            fixed_line = line.encode('latin1').decode('utf-8')
            new_lines.append(fixed_line)
        except:
            # If the whole line fails (e.g. contains valid Vietnamese characters that can't be encoded to latin1),
            # we fix word by word, or chunk by chunk.
            # Using regex to find sequences of characters that are all < 256
            # Actually, let's just do it by finding words that only contain latin1 characters
            # and try to decode them as utf-8.
            new_line = ""
            parts = re.split(r'(\s+|[\[\]\(\)\{\}\'",<>.!?;:])', line)
            for part in parts:
                if not part:
                    continue
                try:
                    # If part only contains latin1 chars, we can try to fix it
                    if all(ord(c) < 256 for c in part):
                        fixed_part = part.encode('latin1').decode('utf-8')
                        new_line += fixed_part
                    else:
                        new_line += part
                except:
                    new_line += part
            new_lines.append(new_line)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))
    print("Fixed mojibake with latin1 -> utf-8.")

fix_double_utf8('lib/screens/chat/chat_screen.dart')
