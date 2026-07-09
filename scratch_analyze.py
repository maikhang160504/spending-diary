import json
import re

with open('d:/Luan-Van/Project/benchmark_extracted.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

print(f'Total samples: {len(data)}')
errors = []

for idx, item in enumerate(data):
    utt = item['utterance'].lower()
    gen = item.get('generated', {})
    
    intent = gen.get('intent')
    action_type = gen.get('action_type')
    slots = gen.get('slots') or {}
    record_type = gen.get('record_type')
    cat = slots.get('category') or gen.get('category')
    time_range = slots.get('time_range')
    verb = slots.get('verb')
    
    issues = []
    
    # Check REPORT_COMPARE time_range issue
    if action_type == 'REPORT_COMPARE':
        if not time_range or ('vs' not in time_range and 'với' not in time_range):
             issues.append(f'time_range for COMPARE is missing vs/với: {time_range}')
             
    # Check general REPORT_GENERAL time_range
    if action_type == 'REPORT_GENERAL':
        if 'hôm nay' in utt and time_range not in ['hôm nay', 'today', 'hôm nay thế nào']:
            issues.append(f'time_range should be hôm nay, got {time_range}')
        if 'tháng này' in utt and time_range not in ['tháng này', 'tháng', 'this month']:
            issues.append(f'time_range should be tháng này, got {time_range}')
            
    # Check SET_LIMIT verb
    if action_type == 'SET_LIMIT':
        if not verb:
            issues.append('verb is missing for SET_LIMIT')
            
    # Check record type matching
    if intent == 'Record':
        if 'cổ phiếu' in utt and record_type != 'Income':
            issues.append(f'cổ phiếu should be Income, got {record_type}')
        if 'cưới' in utt and cat != 'Social':
            issues.append(f'ăn cưới should be Social, got {cat}')
        if 'son' in utt and cat != 'Beauty':
            issues.append(f'son should be Beauty, got {cat}')
            
    if issues:
        errors.append({'utterance': item['utterance'], 'issues': issues, 'generated': gen})

for e in errors:
    print(f"Utterance: {e['utterance']}")
    print(f"Issues: {e['issues']}")
    print('-'*40)
print(f'Found {len(errors)} utterances with slot/logic issues.')
