const { store, nextId } = require("./store");

function createAiLog(payload) {
  const log = {
    id: nextId("aiLog"),
    createdAt: new Date().toISOString(),
    ...payload
  };

  store.aiLogs.push(log);
  return log;
}

function listAiLogs(limit) {
  const sorted = [...store.aiLogs].sort((a, b) => (a.id < b.id ? 1 : -1));

  if (!limit) {
    return sorted;
  }

  return sorted.slice(0, Number(limit));
}

module.exports = {
  createAiLog,
  listAiLogs
};
