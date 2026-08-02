const fs = require('fs');
const babel = require('@babel/parser');

try {
  const content = fs.readFileSync('src/pages/DashboardPage.jsx', 'utf-8');
  babel.parse(content, {
    sourceType: 'module',
    plugins: ['jsx']
  });
  console.log('Parsed successfully!');
} catch (e) {
  console.error(e.message);
  if (e.loc) {
    const lines = fs.readFileSync('src/pages/DashboardPage.jsx', 'utf-8').split('\n');
    const start = Math.max(0, e.loc.line - 5);
    const end = Math.min(lines.length, e.loc.line + 5);
    for (let i = start; i < end; i++) {
      console.log(`${i + 1}: ${lines[i]}`);
    }
  }
}
