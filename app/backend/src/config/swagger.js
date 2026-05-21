'use strict';

const path = require('path');
const swaggerJsdoc = require('swagger-jsdoc');

const swaggerSpec = swaggerJsdoc({
  definition: {
    openapi: '3.0.3',
    info: {
      title: 'MoneyStory Backend API',
      version: '1.0.0',
      description:
        'Backend orchestrator của hệ thống quản lý chi tiêu (Auth, Wallets, Transactions, Budgets, Stats, AI proxy, R2 upload).\n\n' +
        '**Authentication:** Bearer JWT (lấy qua `POST /api/v1/auth/login`).\n\n' +
        '**AI:** route `/api/v1/ai/*` proxy đến Python FastAPI service (mặc định http://localhost:8000).',
    },
    servers: [
      { url: 'http://localhost:4000', description: 'Local dev' },
    ],
    components: {
      securitySchemes: {
        bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      },
      responses: {
        Error: {
          description: 'Standard error envelope',
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  success: { type: 'boolean', example: false },
                  error: {
                    type: 'object',
                    properties: {
                      code: { type: 'string', example: 'validation_error' },
                      message: { type: 'string' },
                      details: { type: 'object' },
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
  },
  apis: [
    path.join(__dirname, '..', 'modules', '**', '*.routes.js'),
  ],
});

module.exports = swaggerSpec;
