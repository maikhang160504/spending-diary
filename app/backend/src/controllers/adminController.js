const { getAllUsers } = require("../models/userModel");
const { getExpensesByUser } = require("../models/expenseModel");
const { getCategoryById } = require("../models/categoryModel");
const { listAiLogs } = require("../models/aiLogModel");

async function getAdminUsers(_req, res, next) {
  try {
    return res.status(200).json({
      count: getAllUsers().length,
      users: getAllUsers()
    });
  } catch (error) {
    return next(error);
  }
}

async function getAdminAnalytics(_req, res, next) {
  try {
    const expenses = getExpensesByUser();
    const totalExpense = expenses.reduce((sum, item) => sum + Number(item.amount || 0), 0);

    const byCategory = expenses.reduce((acc, item) => {
      const category = getCategoryById(item.categoryId);
      const categoryName = category ? category.name : "Unknown";
      acc[categoryName] = (acc[categoryName] || 0) + Number(item.amount || 0);
      return acc;
    }, {});

    return res.status(200).json({
      totalUsers: getAllUsers().filter((user) => user.role === "user").length,
      totalExpenses: expenses.length,
      totalExpenseAmount: totalExpense,
      expenseByCategory: byCategory
    });
  } catch (error) {
    return next(error);
  }
}

async function getAdminAiLogs(req, res, next) {
  try {
    const limit = req.query.limit;

    return res.status(200).json({
      count: listAiLogs(limit).length,
      logs: listAiLogs(limit)
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  getAdminUsers,
  getAdminAnalytics,
  getAdminAiLogs
};
