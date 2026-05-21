'use strict';

const ApiError = require('../utils/ApiError');

/**
 * Wraps a Zod schema into Express middleware.
 *
 *   router.post('/x', validate({ body: zSchema }), handler)
 *   router.get('/y',  validate({ query: zSchema, params: zSchema }), handler)
 *
 * On success the parsed values are stored on `req.valid` so handlers can use
 * the typed payload (and the original `req.body` is also replaced).
 */
module.exports = function validate(schemas) {
  return function validator(req, _res, next) {
    try {
      req.valid = req.valid || {};
      for (const key of ['body', 'query', 'params']) {
        if (schemas[key]) {
          const parsed = schemas[key].safeParse(req[key]);
          if (!parsed.success) {
            return next(
              ApiError.validation({
                source: key,
                issues: parsed.error.issues.map((i) => ({
                  path: i.path,
                  message: i.message,
                  code: i.code,
                })),
              })
            );
          }
          req.valid[key] = parsed.data;
          if (key === 'body') req.body = parsed.data;
        }
      }
      return next();
    } catch (err) {
      return next(err);
    }
  };
};
