import codecs

with open('lib/screens/chat/chat_screen.dart', 'rb') as f:
    for i, line in enumerate(f):
        if b"chi ti" in line and b"Th" in line:
            print(f"Line {i+1}: {line}")
            break
