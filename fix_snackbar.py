import os
import re

lib_dir = r'd:\Luan-Van\Project\app\frontend\mobile\lib'

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Look for MimoSnackBar.showXXX(context, message: something;
    # and replace with MimoSnackBar.showXXX(context, message: something);
    # Actually, the regex in the first script replaced it with MimoSnackBar.showXXX(context, message: {text_arg});
    # BUT if {text_arg} had no closing parenthesis... wait, text_arg is the inside of Text(...).
    # Ah! MimoSnackBar.showInfo(context, message: e.toString(); -> this is missing ) for the showInfo call.
    # Because my replacer returned MimoSnackBar.{method}(context, message: {text_arg});
    # I forgot the closing ) before ;!
    
    new_content = re.sub(r'(MimoSnackBar\.show[a-zA-Z]+\(context,\s*message:\s*.*?)(?<!\));', r'\1);', content)
    
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed {filepath}")

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))

print('Done')
