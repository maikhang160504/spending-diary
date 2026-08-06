import os
import re

lib_dir = r'd:\Luan-Van\Project\app\frontend\mobile\lib'

def fix_snackbars(content, filepath):
    changed = False
    
    def replacer(match):
        text_content = match.group(1)
        rest = match.group(2)
        
        method = 'showInfo'
        if 'AppColors.danger' in rest:
            method = 'showError'
        elif 'AppColors.teal' in rest:
            method = 'showSuccess'
            
        return f"MimoSnackBar.{method}(context, message: {text_content});"

    pattern_single = re.compile(
        r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s+)?SnackBar\(\s*content:\s*Text\((.*?)\)(.*?)\)\s*,?\s*\);',
        re.DOTALL
    )
    
    new_content = pattern_single.sub(replacer, content)
    
    if new_content != content:
        changed = True
        content = new_content
        
    if changed:
        rel_path = os.path.relpath(os.path.join(lib_dir, 'widgets', 'mimo_snackbar.dart'), os.path.dirname(filepath))
        rel_path = rel_path.replace(os.sep, '/')
        import_stmt = f"import '{rel_path}';"
        
        if import_stmt not in content:
            last_import_idx = content.rfind('import ')
            if last_import_idx != -1:
                end_of_line = content.find('\n', last_import_idx)
                content = content[:end_of_line+1] + import_stmt + '\n' + content[end_of_line+1:]
            else:
                content = import_stmt + '\n\n' + content
                
    return content if changed else None

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart') and file != 'mimo_snackbar.dart':
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            new_content = fix_snackbars(content, filepath)
            if new_content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"Updated {filepath}")

