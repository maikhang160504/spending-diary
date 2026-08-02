const fs = require('fs');

try {
  let content = fs.readFileSync('src/pages/DashboardPage.jsx', 'utf-8');

  // Fix 1: duplicate error
  content = content.replace('      {error && (error && (', '      {error && (');

  // Fix 2: TogglePremium refresh
  content = content.replace(
    '      // Refresh orders\n      const o = await getMonetizationOrders(100);\n      setMonetOrders(Array.isArray(o) ? o : []);',
    '      // Refresh orders\n      const o = await getMonetizationOrders(100);\n      const ordersData = o?.data || o;\n      setMonetOrders(Array.isArray(ordersData) ? ordersData : []);'
  );

  // Fix 3: Promise.all extraction
  content = content.replace(
    '      .then(([analyticsData, readinessData, trainHistoryData, ocrHistoryData, llmHistoryData, benchmarkData, settingsData, mStats, mHistory, mOrders]) => {\n        setMonetStats(mStats);\n        setMonetHistory(Array.isArray(mHistory) ? mHistory : []);\n        setMonetOrders(Array.isArray(mOrders) ? mOrders : []);',
    '      .then(([analyticsData, readinessData, trainHistoryData, ocrHistoryData, llmHistoryData, benchmarkData, settingsData, mStats, mHistory, mOrders]) => {\n        setMonetStats(mStats?.data || mStats);\n        const historyData = mHistory?.data || mHistory;\n        const ordersData = mOrders?.data || mOrders;\n        setMonetHistory(Array.isArray(historyData) ? historyData : []);\n        setMonetOrders(Array.isArray(ordersData) ? ordersData : []);'
  );

  fs.writeFileSync('src/pages/DashboardPage.jsx', content);
  console.log('Fixed API data extraction!');
} catch (e) {
  console.error(e);
}
