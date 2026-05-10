const store = {
  users: [
    { id: 1, name: "Lan", email: "lan@example.com", role: "user" },
    { id: 2, name: "Minh", email: "minh@example.com", role: "user" },
    { id: 100, name: "Admin", email: "admin@example.com", role: "admin" }
  ],
  categories: [
    { id: 1, name: "Food", type: "expense" },
    { id: 2, name: "Transport", type: "expense" },
    { id: 3, name: "Shopping", type: "expense" },
    { id: 4, name: "Utilities", type: "expense" },
    { id: 5, name: "Other", type: "expense" }
  ],
  expenses: [],
  aiLogs: [],
  userCategoryMappings: [],
  commentLogs: []
};

const counters = {
  expense: 1,
  aiLog: 1,
  userCategoryMapping: 1,
  commentLog: 1
};

function nextId(type) {
  const current = counters[type] || 1;
  counters[type] = current + 1;
  return current;
}

module.exports = {
  store,
  nextId
};
