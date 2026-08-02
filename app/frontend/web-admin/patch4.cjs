const fs = require('fs');
let content = fs.readFileSync('src/pages/DashboardPage.jsx', 'utf-8');

// 1. Update imports
content = content.replace(
  /  getOcrTrainHistory\r?\n\} from "\.\.\/services\/api";/,
  '  getOcrTrainHistory,\n  getMonetizationStats,\n  getMonetizationHistory,\n  getMonetizationOrders,\n  toggleUserPremium\n} from "../services/api";'
);

// 2. Add catch blocks to Promise.all
content = content.replace(
  /    Promise\.all\(\[\r?\n      getAdminAnalytics\(\),\r?\n      getRetrainReadiness\(\),\r?\n      getNluTrainHistory\(\),/,
  '    Promise.all([\n      getAdminAnalytics().catch(() => null),\n      getRetrainReadiness().catch(() => null),\n      getNluTrainHistory().catch(() => []),',
);

fs.writeFileSync('src/pages/DashboardPage.jsx', content);
console.log('Patch 4 completed');
