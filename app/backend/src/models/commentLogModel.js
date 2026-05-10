const { store, nextId } = require("./store");

function createCommentLog(payload) {
  const commentLog = {
    id: nextId("commentLog"),
    createdAt: new Date().toISOString(),
    ...payload
  };

  store.commentLogs.push(commentLog);
  return commentLog;
}

function listCommentLogs(limit) {
  const sorted = [...store.commentLogs].sort((a, b) => (a.id < b.id ? 1 : -1));
  if (!limit) {
    return sorted;
  }

  return sorted.slice(0, Number(limit));
}

module.exports = {
  createCommentLog,
  listCommentLogs
};
