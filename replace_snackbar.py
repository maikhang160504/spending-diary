import os
import re

lib_dir = r'd:\Luan-Van\Project\app\frontend\mobile\lib'

# Regex to match ScaffoldMessenger.of(context).showSnackBar(...)
# Note: This is a simplified regex and might not catch multi-line perfectly if it's very complex,
# but we can try to match the common pattern.

pattern = re.compile(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\((.*?)\)(?:,\s*backgroundColor:\s*(AppColors\.[a-zA-Z]+))?[^\)]*\)\s*,\s*\);',
    re.DOTALL
)

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'ScaffoldMessenger.of(context).showSnackBar' not in content:
        return

    # We need a custom replacement function
    # Because Dart formatting can span multiple lines.
    # A more robust regex:
    regex = r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\((.*?)\)(.*?)\)\s*,\s*\);"
    
    def replacer(match):
        text_arg = match.group(1).strip()
        rest = match.group(2)
        
        # Determine type based on rest
        if 'AppColors.danger' in rest:
            method = 'showError'
        elif 'AppColors.teal' in rest:
            method = 'showSuccess'
        else:
            method = 'showInfo'
            
        return f"MimoSnackBar.{method}(context, message: {text_arg});"
        
    new_content = re.sub(regex, replacer, content, flags=re.DOTALL)
    
    # Check if we made changes
    if new_content != content:
        # Calculate import path
        # filepath is absolute. We need to find relative path to lib/widgets/mimo_snackbar.dart
        rel_path = os.path.relpath(os.path.join(lib_dir, 'widgets', 'mimo_snackbar.dart'), os.path.dirname(filepath))
        rel_path = rel_path.replace(os.sep, '/')
        
        import_stmt = f"import '{rel_path}';"
        
        if import_stmt not in new_content:
            # Add import after the last import
            last_import_idx = new_content.rfind('import ')
            if last_import_idx != -1:
                end_of_line = new_content.find('\n', last_import_idx)
                new_content = new_content[:end_of_line+1] + import_stmt + '\n' + new_content[end_of_line+1:]
            else:
                new_content = import_stmt + '\n\n' + new_content
                
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart') and file != 'mimo_snackbar.dart':
            process_file(os.path.join(root, file))

print('Done')
