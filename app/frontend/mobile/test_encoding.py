import codecs

s = 'Ä áº·t'
# wait, 'Ä áº·t' in the file might literally have a space if \x90 was replaced with space!
# Let's read the exact bytes from the file at line 105
with open('lib/screens/chat/chat_screen.dart', 'rb') as f:
    lines = f.readlines()
    print(lines[104])
