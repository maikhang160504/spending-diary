/**
 * Idempotency Guard Middleware
 * Prevents duplicate requests from being processed if they have the same Idempotency-Key header.
 */
const cache = new Map();
// Clear expired keys every minute to prevent memory leak
setInterval(() => {
  const now = Date.now();
  for (const [key, value] of cache.entries()) {
    if (now > value.expiresAt) {
      cache.delete(key);
    }
  }
}, 60 * 1000);

const idempotencyGuard = (options = { ttl: 60000 }) => {
  return (req, res, next) => {
    // Only apply to POST, PUT, PATCH, DELETE
    if (['GET', 'OPTIONS', 'HEAD'].includes(req.method)) {
      return next();
    }

    const idempotencyKey = req.headers['idempotency-key'] || req.headers['x-idempotency-key'];

    if (!idempotencyKey) {
      // If no key provided, just continue normally
      return next();
    }

    // Include user ID in the key to prevent cross-user key collisions if user is authenticated
    const userId = req.user ? req.user.id : 'anonymous';
    const compositeKey = `${userId}:${idempotencyKey}`;

    if (cache.has(compositeKey)) {
      const cached = cache.get(compositeKey);
      
      // If request is already processed and response is cached, return it
      if (cached.status === 'completed') {
        return res.status(cached.statusCode).json(cached.body);
      }
      
      // If request is still processing, return 409 Conflict
      if (cached.status === 'processing') {
        return res.status(409).json({
          error: {
            code: 'CONFLICT',
            message: 'A request with this Idempotency-Key is already being processed.'
          }
        });
      }
    }

    // Mark as processing
    cache.set(compositeKey, {
      status: 'processing',
      expiresAt: Date.now() + options.ttl
    });

    // Intercept response to cache the result
    const originalJson = res.json;
    res.json = function (body) {
      cache.set(compositeKey, {
        status: 'completed',
        statusCode: res.statusCode,
        body: body,
        expiresAt: Date.now() + options.ttl
      });
      return originalJson.call(this, body);
    };

    next();
  };
};

module.exports = idempotencyGuard;
