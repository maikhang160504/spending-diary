'use strict';

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const env = require('./config/env');
const logger = require('./config/logger');
const swaggerSpec = require('./config/swagger');
const swaggerUi = require('swagger-ui-express');

const requestId = require('./middlewares/requestId');
const requestLogger = require('./middlewares/requestLogger');
const { notFound, errorHandler } = require('./middlewares/errorHandler');

const router = require('./routes');
const adminRouter = require('./routes/admin.routes');
const { requireAuth, requireRole } = require('./middlewares/auth');

const app = express();

app.disable('x-powered-by');
app.use(
  helmet({
    crossOriginResourcePolicy: false,
    contentSecurityPolicy: false,
  })
);
app.use(
  cors({
    origin: env.cors.origins.includes('*') ? true : env.cors.origins,
    credentials: true,
  })
);
app.use(
  express.json({
    limit: '2mb',
    verify: (req, _res, buf) => {
      req.rawBody = buf;
    },
  })
);
app.use(express.urlencoded({ extended: true }));
app.use(requestId);
if (env.nodeEnv !== 'test') {
  app.use(morgan('tiny', { stream: { write: (msg) => logger.debug(msg.trim()) } }));
}
app.use(requestLogger);

// Swagger UI
app.use('/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, { explorer: true }));
app.get('/openapi.json', (_req, res) => res.json(swaggerSpec));

// Root + meta
app.get('/', (_req, res) =>
  res.json({
    success: true,
    service: 'moneystory-backend',
    docs: '/docs',
    openapi: '/openapi.json',
    api: '/api/v1',
  })
);

app.use('/hooks', require('./routes/hooks.routes'));
app.use('/api/v1', router);
app.use('/api/admin', requireAuth, requireRole('admin'), adminRouter);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
