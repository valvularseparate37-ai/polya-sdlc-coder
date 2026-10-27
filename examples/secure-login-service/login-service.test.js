import test from 'node:test';
import assert from 'node:assert/strict';

import {
  AUTH_ERRORS,
  SecureLoginService,
  createInMemoryUserStore,
} from './login-service.js';

test('hash and verify password works', () => {
  const service = new SecureLoginService();
  const password = 'CorrectHorseBatteryStaple!';
  const hash = service.hashPassword(password);

  assert.equal(service.verifyPassword(password, hash), true);
  assert.equal(service.verifyPassword('wrong', hash), false);
});

test('authenticateUser succeeds with valid credentials and returns tokens', () => {
  const service = new SecureLoginService({ secret: 'test-secret' });
  const userStore = createInMemoryUserStore([
    {
      id: 'u-1',
      username: 'alice',
      email: 'alice@example.com',
      passwordHash: service.hashPassword('StrongPass!23'),
    },
  ]);
  const attemptTracker = new Map();

  const result = service.authenticateUser({
    identifier: 'alice',
    password: 'StrongPass!23',
    userStore,
    attemptTracker,
  });

  assert.equal(result.ok, true);
  assert.equal(result.userId, 'u-1');
  assert.ok(result.accessToken.includes('.'));
  assert.ok(result.refreshToken.includes('.'));
  assert.ok(result.expiresAt);
});

test('invalid credentials are normalized and increment lockout counter', () => {
  const service = new SecureLoginService({ maxAttempts: 3, lockoutWindowMs: 60_000, secret: 'test-secret' });
  const userStore = createInMemoryUserStore([
    {
      id: 'u-2',
      username: 'bob',
      email: 'bob@example.com',
      passwordHash: service.hashPassword('Secret123!'),
    },
  ]);
  const attempts = new Map();

  const result1 = service.authenticateUser({
    identifier: 'bob',
    password: 'WrongPassword!',
    userStore,
    attemptTracker: attempts,
  });

  assert.equal(result1.ok, false);
  assert.equal(result1.code, AUTH_ERRORS.INVALID_CREDENTIALS);

  const result2 = service.authenticateUser({
    identifier: 'bob',
    password: 'WrongPasswordAgain!',
    userStore,
    attemptTracker: attempts,
  });

  assert.equal(result2.ok, false);
  assert.equal(result2.code, AUTH_ERRORS.INVALID_CREDENTIALS);

  const result3 = service.authenticateUser({
    identifier: 'bob',
    password: 'WrongPasswordAgain!',
    userStore,
    attemptTracker: attempts,
  });

  assert.equal(result3.ok, false);
  assert.equal(result3.code, AUTH_ERRORS.ACCOUNT_LOCKED);
});

test('token verification rejects expired tokens', () => {
  const service = new SecureLoginService({ secret: 'expires-soon' });
  const expiredToken = service.issueToken({ sub: 'u-9', sessionId: 's-9', type: 'access' }, -1);

  assert.throws(() => service.verifyToken(expiredToken), { message: AUTH_ERRORS.SESSION_EXPIRED });
});

test('refreshSession rotates access token and rejects invalid session state', () => {
  const service = new SecureLoginService({ secret: 'refresh-secret' });
  const sessionStore = new Map([
    ['session-1', { userId: 'u-3', revoked: false }],
  ]);

  const refreshToken = service.issueToken(
    { sub: 'u-3', sessionId: 'session-1', type: 'refresh' },
    86400
  );

  const result = service.refreshSession({ refreshToken, sessionStore });
  assert.equal(result.ok, true);
  assert.ok(result.accessToken.includes('.'));

  const revokedResult = service.revokeSession({ sessionId: 'session-1', sessionStore });
  assert.equal(revokedResult.ok, true);

  assert.throws(
    () => service.refreshSession({ refreshToken, sessionStore }),
    { message: AUTH_ERRORS.SESSION_EXPIRED }
  );
});
