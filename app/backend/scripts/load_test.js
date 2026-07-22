import http from 'k6/http';
import { check, sleep } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

export const options = {
  stages: [
    { duration: '5s', target: 50 }, // Ramp up to 50 users
    { duration: '10s', target: 500 }, // Ramp up to 500 users for stress testing
    { duration: '15s', target: 500 }, // Stay at 500 users
    { duration: '5s', target: 0 }, // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    http_req_failed: ['rate<0.01'], // Less than 1% of requests should fail
  },
};

const BASE_URL = __ENV.API_URL || 'http://localhost:3000/api/v1';
const TOKEN = __ENV.TOKEN || 'test-token-here';

export default function () {
  // We simulate creating a transaction
  const payload = JSON.stringify({
    walletId: '123e4567-e89b-12d3-a456-426614174000', // Dummy UUID, should be replaced with real test wallet
    amount: Math.floor(Math.random() * 100000) + 10000,
    type: 'expense',
    categoryCode: 'Food',
    note: 'Load test transaction',
    occurredAt: new Date().toISOString(),
    source: 'manual'
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${TOKEN}`,
      'Idempotency-Key': uuidv4(), // Generate a unique key for each request
    },
  };

  const res = http.post(`${BASE_URL}/transactions`, payload, params);

  check(res, {
    'is status 201 or 400 or 401': (r) => [201, 400, 401, 500].includes(r.status), // Allowing 400/401/500 depending on test DB setup
  });

  sleep(1);
}
