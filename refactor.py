import sys

file_path = r'd:\Luan-Van\Project\app\frontend\mobile\lib\screens\chat\chat_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, line in enumerate(lines):
    if line.startswith('class _BudgetSuggestionItem {'):
        skip = True
    elif line.startswith('class _ReportStoryCard extends StatelessWidget {'):
        skip = False
    elif line.startswith('class _BudgetSuggestionModal extends StatefulWidget {'):
        skip = True
    elif line.startswith('class _BudgetSuggestionCard extends StatelessWidget {'):
        skip = False

    if not skip:
        # replace class names
        new_line = line.replace('_BudgetSuggestionPreview', 'BudgetSuggestionPreview')
        new_line = new_line.replace('_BudgetSuggestionItem', 'BudgetSuggestionItem')
        new_line = new_line.replace('_BudgetSuggestionModal(', 'BudgetSuggestionModal(')
        new_lines.append(new_line)

# Add import at line 5
new_lines.insert(5, "import '../../widgets/budget_suggestion_modal.dart';\n")

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('Refactored chat_screen.dart')
