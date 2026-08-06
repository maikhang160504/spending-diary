import codecs

with open('lib/screens/chat/chat_screen.dart', 'rb') as f:
    for i, line in enumerate(f):
        if b"_candidateSuggestions" in line:
            for j in range(25):
                print(f.readline())
            break
