'use strict';

// Boot the express app without hitting the DB and check basic routes.
process.env.JWT_SECRET = 'test-secret';
process.env.NODE_ENV = 'test';

const request = require('supertest');
const app = require('../../src/app');

describe('app smoke', () => {
  test('GET / returns service banner', async () => {
    const r = await request(app).get('/');
    expect(r.status).toBe(200);
    expect(r.body.service).toBe('moneystory-backend');
  });

  test('GET /api/v1/health returns ok', async () => {
    const r = await request(app).get('/api/v1/health');
    expect(r.status).toBe(200);
    expect(r.body.status).toBe('ok');
  });

  test('GET /openapi.json returns OpenAPI document', async () => {
    const r = await request(app).get('/openapi.json');
    expect(r.status).toBe(200);
    expect(r.body.openapi).toBeDefined();
    expect(r.body.paths['/api/v1/auth/login']).toBeDefined();
  });

  test('Protected route without token returns 401', async () => {
    const r = await request(app).get('/api/v1/wallets');
    expect(r.status).toBe(401);
    expect(r.body.error.code).toBe('unauthorized');
  });

  test('404 for unknown route', async () => {
    const r = await request(app).get('/api/v1/nope');
    expect(r.status).toBe(404);
  });
});
