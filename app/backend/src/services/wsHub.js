'use strict';

const { WebSocketServer } = require('ws');
const { verifyAccessToken } = require('../utils/jwt');
const logger = require('../config/logger');

/** @type {Map<string, Set<import('ws').WebSocket>>} userId → set of sockets */
const _clients = new Map();

/**
 * Attach a WebSocket server to an existing HTTP server.
 * Clients connect to ws://<host>/ws?token=<accessToken>
 * After connection, client sends JSON: { type: 'subscribe', transactionId: '...' }
 * Server sends JSON: { type: 'transaction_done' | 'transaction_failed', transactionId, data }
 */
function attachWsServer(httpServer) {
  const wss = new WebSocketServer({ server: httpServer, path: '/ws' });

  wss.on('connection', (ws, req) => {
    const url = new URL(req.url, 'ws://localhost');
    const token = url.searchParams.get('token');
    let userId = null;

    try {
      const payload = verifyAccessToken(token);
      userId = payload?.sub || payload?.userId || payload?.id;
    } catch {
      ws.close(4001, 'Unauthorized');
      return;
    }

    if (!userId) {
      ws.close(4001, 'Unauthorized');
      return;
    }

    if (!_clients.has(userId)) _clients.set(userId, new Set());
    _clients.get(userId).add(ws);
    logger.debug({ userId }, 'ws: client connected');

    ws.on('close', () => {
      _clients.get(userId)?.delete(ws);
      if (_clients.get(userId)?.size === 0) _clients.delete(userId);
    });

    ws.on('error', (err) => logger.warn({ err: err.message, userId }, 'ws: client error'));
  });

  logger.info('WebSocket server attached at /ws');
  return wss;
}

/**
 * Send a message to all WebSocket connections of a user.
 * @param {string} userId
 * @param {object} payload  Plain object — will be JSON-serialised.
 */
function sendToUser(userId, payload) {
  const sockets = _clients.get(String(userId));
  if (!sockets || sockets.size === 0) return;
  const msg = JSON.stringify(payload);
  for (const ws of sockets) {
    try {
      if (ws.readyState === ws.OPEN) ws.send(msg);
    } catch (err) {
      logger.warn({ err: err.message, userId }, 'ws: send failed');
    }
  }
}

module.exports = { attachWsServer, sendToUser };
