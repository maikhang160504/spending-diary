const { store } = require("./store");

function getAllCategories() {
  return store.categories;
}

function getCategoryById(categoryId) {
  return store.categories.find((category) => category.id === Number(categoryId));
}

function getCategoryByName(name) {
  if (!name) {
    return null;
  }

  return store.categories.find(
    (category) => category.name.toLowerCase() === String(name).toLowerCase()
  );
}

module.exports = {
  getAllCategories,
  getCategoryById,
  getCategoryByName
};
