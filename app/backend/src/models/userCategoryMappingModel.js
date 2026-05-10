const { store, nextId } = require("./store");

function normalizeKeyword(value) {
  const normalized = String(value || "")
    .toLowerCase()
    .trim()
    .replace(/\d+[\d.,]*\s*(k|ngan|tr|trieu)?/gi, " ")
    .replace(/[^\p{L}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();

  return normalized || String(value || "").toLowerCase().trim();
}

function upsertUserCategoryMapping({ userId, keyword, categoryId }) {
  const normalizedKeyword = normalizeKeyword(keyword);
  if (!normalizedKeyword) {
    return null;
  }

  const existing = store.userCategoryMappings.find(
    (item) => item.userId === Number(userId) && item.keyword === normalizedKeyword
  );

  if (existing) {
    existing.categoryId = Number(categoryId);
    existing.updatedAt = new Date().toISOString();
    return existing;
  }

  const mapping = {
    id: nextId("userCategoryMapping"),
    userId: Number(userId),
    keyword: normalizedKeyword,
    categoryId: Number(categoryId),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };

  store.userCategoryMappings.push(mapping);
  return mapping;
}

function findMappedCategoryId(userId, text) {
  const normalizedText = normalizeKeyword(text);
  if (!normalizedText) {
    return null;
  }

  const candidates = store.userCategoryMappings
    .filter((item) => item.userId === Number(userId))
    .sort((a, b) => b.keyword.length - a.keyword.length);

  const matched = candidates.find((item) => normalizedText.includes(item.keyword));
  return matched ? matched.categoryId : null;
}

function listUserCategoryMappings(userId) {
  return store.userCategoryMappings.filter((item) => item.userId === Number(userId));
}

module.exports = {
  upsertUserCategoryMapping,
  findMappedCategoryId,
  listUserCategoryMappings
};
