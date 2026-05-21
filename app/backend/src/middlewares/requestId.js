'use strict';

const { v4: uuid } = require('uuid');

module.exports = function requestId(req, res, next) {
  const id = req.headers['x-request-id'] || uuid().slice(0, 12);
  req.id = id;
  res.setHeader('X-Request-ID', id);
  next();
};
