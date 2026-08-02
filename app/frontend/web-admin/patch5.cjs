const fs = require('fs');

const monetContent = fs.readFileSync('src/pages/MonetizationPage.jsx', 'utf-8');
const dashboardContent = fs.readFileSync('src/pages/DashboardPage.jsx', 'utf-8');

// Extract RevenueChart and OrderStatusBadge from MonetizationPage.jsx
const startIndex = monetContent.indexOf('function RevenueChart({ data }) {');
const endIndex = monetContent.indexOf('export default function MonetizationPage() {');

if (startIndex !== -1 && endIndex !== -1) {
  let components = monetContent.substring(startIndex, endIndex);
  
  // Remove any lingering comments at the end
  components = components.replace(/\/\/ ─── .*$/g, '').trim();

  // Insert before function DashboardPage()
  const insertionPoint = 'function DashboardPage() {';
  
  if (!dashboardContent.includes('function RevenueChart')) {
    const newContent = dashboardContent.replace(insertionPoint, components + '\n\n' + insertionPoint);
    fs.writeFileSync('src/pages/DashboardPage.jsx', newContent);
    console.log('Successfully added components to DashboardPage.jsx');
  } else {
    console.log('Components already exist in DashboardPage.jsx');
  }
} else {
  console.log('Could not find components in MonetizationPage.jsx');
}
