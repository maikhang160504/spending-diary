import re
import codecs

def repl(m):
    s = m.group(0)
    try:
        return s.encode('latin1').decode('utf-8')
    except:
        res = []
        for word in s.split(' '):
            try:
                res.append(word.encode('latin1').decode('utf-8'))
            except:
                res.append(word)
        return ' '.join(res)

with open('lib/screens/chat/chat_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

new_content = re.sub(r'[\x00-\xff]+', repl, content)

with open('lib/screens/chat/chat_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)
    
print("Fixed remaining double utf-8")
