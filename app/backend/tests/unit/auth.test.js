'use strict';

// Pure-unit test: validates that the auth schemas reject bad payloads.
const { registerSchema, loginSchema } = require('../../src/modules/auth/auth.schema');

describe('auth schemas', () => {
  test('register requires email + password >= 8 + username', () => {
    expect(registerSchema.safeParse({ email: 'bad', password: '123', username: 'a' }).success).toBe(false);
    expect(
      registerSchema.safeParse({ email: 'ok@a.com', password: '12345678', username: 'AB' }).success
    ).toBe(true);
  });

  test('login accepts minimal payload', () => {
    expect(loginSchema.safeParse({ email: 'a@b.com', password: 'x' }).success).toBe(true);
    expect(loginSchema.safeParse({ email: 'no-at', password: 'x' }).success).toBe(false);
  });
});
