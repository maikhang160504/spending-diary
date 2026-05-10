const { store } = require("./store");

function getAllUsers() {
  return store.users;
}

function getUserById(userId) {
  return store.users.find((user) => user.id === Number(userId));
}

module.exports = {
  getAllUsers,
  getUserById
};
