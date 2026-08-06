import glob, re

files = glob.glob(r'd:\Luan-Van\Project\app\frontend\mobile\lib\screens\report\*.dart')
for f in files:
    content = open(f, encoding='utf-8').read()
    # Tìm const Text với chuỗi dài (câu phân tích cứng)
    matches = re.findall(r"const Text\('([^']{40,})'", content)
    if matches:
        print(f.split('\\')[-1])
        for m in matches[:5]:
            print('  ->', m[:130])
        print()
