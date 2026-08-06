import codecs

def fix_mojibake(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove BOM if present
    if content.startswith('\ufeff'):
        content = content[1:]
        
    try:
        # Encode to cp1252 and decode as utf-8
        # We need to ignore characters that can't be encoded (like actual valid unicode chars added later)
        # Wait, if we use errors='replace' or something, it might ruin it. 
        # Let's try to just find substrings that are mojibake and fix them using regex.
        import re
        
        def replacer(match):
            text = match.group(0)
            try:
                return text.encode('cp1252').decode('utf-8')
            except:
                return text

        # Find sequences of typical mojibake characters (e.g. Ã, Ä, á, », etc.)
        # Typical latin-1 characters that shouldn't be there
        pattern = re.compile(r'[\xc2-\xf4][\x80-\xbf]+') 
        # Wait, utf-8 bytes when read as cp1252 look like Ã¡, etc. 
        # This is a bit tricky. Let's just fix the whole string character by character if it is in the range.
        
        fixed = content.encode('cp1252').decode('utf-8')
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(fixed)
        print("Fixed completely via cp1252 -> utf-8")
    except Exception as e:
        print("Failed:", e)

fix_mojibake('lib/screens/chat/chat_screen.dart')
