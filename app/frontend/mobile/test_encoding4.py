import re

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

line = b"    'Th\xe1\xbb\x91ng k\xc3\xaa chi ti\xc3\xaau tu\xe1\xba\xa7n n\xc3\x83\xc2\xa0y',\r\n".decode('utf-8')
print("Original:", line.encode('utf-8'))
new_line = re.sub(r'[\x00-\xff]+', repl, line)
print("Fixed:", new_line.encode('utf-8'))
