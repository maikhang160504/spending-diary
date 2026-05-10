function sumAmount(items) {
  return items.reduce((total, item) => total + Number(item.amount || 0), 0);
}

function getDateRangeExpenses(expenses, date, mode) {
  const current = new Date(date);
  const year = current.getUTCFullYear();
  const month = current.getUTCMonth();
  const day = current.getUTCDate();

  return expenses.filter((expense) => {
    const expenseDate = new Date(expense.createdAt || expense.transactionDate || Date.now());

    if (mode === "daily") {
      return (
        expenseDate.getUTCFullYear() === year &&
        expenseDate.getUTCMonth() === month &&
        expenseDate.getUTCDate() === day
      );
    }

    return expenseDate.getUTCFullYear() === year && expenseDate.getUTCMonth() === month;
  });
}

function getTopCategory(expenses, getCategoryById) {
  const bucket = expenses.reduce((acc, item) => {
    const category = getCategoryById(item.categoryId);
    const categoryName = category ? category.name : "Other";
    acc[categoryName] = (acc[categoryName] || 0) + Number(item.amount || 0);
    return acc;
  }, {});

  const entries = Object.entries(bucket).sort((a, b) => b[1] - a[1]);
  if (!entries.length) {
    return { topCategory: null, topAmount: 0 };
  }

  return {
    topCategory: entries[0][0],
    topAmount: entries[0][1]
  };
}

function buildEventInsight({ amount, categoryName, dailyTotal }) {
  return {
    type: "event",
    amount: Number(amount),
    category: categoryName,
    daily_total: Number(dailyTotal)
  };
}

function buildDailyInsight({ userExpenses, getCategoryById, now = new Date() }) {
  const dailyExpenses = getDateRangeExpenses(userExpenses, now, "daily");
  const total = sumAmount(dailyExpenses);
  const { topCategory, topAmount } = getTopCategory(dailyExpenses, getCategoryById);
  const percent = total > 0 ? Math.round((topAmount / total) * 100) : 0;

  return {
    type: "daily",
    total,
    top_category: topCategory,
    percent
  };
}

function buildMonthlyInsight({ userExpenses, getCategoryById, monthlyLimit = 0, now = new Date() }) {
  const currentMonthExpenses = getDateRangeExpenses(userExpenses, now, "monthly");
  const currentTotal = sumAmount(currentMonthExpenses);

  const previousMonthDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1));
  const previousMonthExpenses = getDateRangeExpenses(userExpenses, previousMonthDate, "monthly");
  const previousTotal = sumAmount(previousMonthExpenses);

  const { topCategory, topAmount } = getTopCategory(currentMonthExpenses, getCategoryById);
  const percent = currentTotal > 0 ? Math.round((topAmount / currentTotal) * 100) : 0;
  const change = previousTotal > 0 ? Math.round(((currentTotal - previousTotal) / previousTotal) * 100) : 0;

  return {
    type: "monthly",
    top_category: topCategory,
    percent,
    change,
    exceed_limit: monthlyLimit > 0 ? currentTotal > monthlyLimit : false
  };
}

module.exports = {
  buildEventInsight,
  buildDailyInsight,
  buildMonthlyInsight
};
