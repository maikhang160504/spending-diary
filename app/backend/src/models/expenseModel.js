const { store, nextId } = require("./store");

function createExpense(payload) {
  const expense = {
    id: nextId("expense"),
    createdAt: new Date().toISOString(),
    ...payload
  };

  store.expenses.push(expense);
  return expense;
}

function getExpensesByUser(userId) {
  if (!userId) {
    return store.expenses;
  }

  return store.expenses.filter((expense) => expense.userId === Number(userId));
}

module.exports = {
  createExpense,
  getExpensesByUser
};
