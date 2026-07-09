import json

with open(r'd:\Luan-Van\Project\benchmark_extracted.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

for idx, d in enumerate(data[:15]):
    if 'generated' in d:
        resp = d['generated'].get('response', '')
        print(f"{idx+1}. {d['utterance']} -> {resp}")
