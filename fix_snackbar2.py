import os

lib_dir = r'd:\Luan-Van\Project\app\frontend\mobile\lib'

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            changed = False
            for i, line in enumerate(lines):
                if 'MimoSnackBar.show' in line and line.strip().endswith(';') and not line.strip().endswith(');'):
                    lines[i] = line.replace(';', ');')
                    changed = True
            
            if changed:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.writelines(lines)
                print(f"Fixed {filepath}")
