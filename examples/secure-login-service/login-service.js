import crypto from 'node:crypto';

export const AUTH_ERRORS = Object.freeze({
  INVALID_CREDENTIALS: 'INVALID_CREDENTIALS',
  ACCOUNT_LOCKED: 'ACCOUNT_LOCKED',
  SESSION_EXPIRED: 'SESSION_EXPIRED',
  INVALID_TOKEN: 'INVALID_TOKEN',
});

function toBase64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function fromBase64Url(value) {
  return Buffer.from(value, 'base64url');
}

function parseJsonOrThrow(value, code) {
  try {
    return JSON.parse(value);
  } catch {
    throw new Error(code);
  }
}

export class SecureLoginService {
  constructor(options = {}) {
    this.secret = options.secret ?? 'change-me-in-prod';
    this.accessTokenTtlSeconds = options.accessTokenTtlSeconds ?? 300;
    this.refreshTokenTtlSeconds = options.refreshTokenTtlSeconds ?? 2_592_000;
    this.maxAttempts = options.maxAttempts ?? 5;
    this.lockoutWindowMs = options.lockoutWindowMs ?? 15 * 60 * 1000;
  }

  hashPassword(password) {
    const salt = crypto.randomBytes(16);
    const key = crypto.scryptSync(password, salt, 64);
    return `scrypt$${salt.toString('base64')}$${key.toString('base64')}`;
  }

  verifyPassword(password, storedHash) {
    if (typeof storedHash !== 'string' || !storedHash.startsWith('scrypt$')) {
      return false;
    }

    const [algorithm, saltB64, hashB64] = storedHash.split('$');
    if (algorithm !== 'scrypt' || !saltB64 || !hashB64) {
      return false;
    }

    const salt = Buffer.from(saltB64, 'base64');
    const expected = Buffer.from(hashB64, 'base64');
    const candidate = crypto.scryptSync(password, salt, expected.length);
    return crypto.timingSafeEqual(candidate, expected);
  }

  issueToken(payload, ttlSeconds) {
    const header = toBase64Url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
    const now = Math.floor(Date.now() / 1000);
    const body = toBase64Url(
      JSON.stringify({
        ...payload,
        iat: now,
        exp: now + ttlSeconds,
      })
    );
    const signatureInput = `${header}.${body}`;
    const signature = crypto
      .createHmac('sha256', this.secret)
      .update(signatureInput)
      .digest('base64url');

    return `${signatureInput}.${signature}`;
  }

  verifyToken(token) {
    const parts = token.split('.');
    if (parts.length !== 3) {
      throw new Error(AUTH_ERRORS.INVALID_TOKEN);
    }

    const [headerB64, payloadB64, signature] = parts;
    const expectedSignature = crypto
      .createHmac('sha256', this.secret)
      .update(`${headerB64}.${payloadB64}`)
      .digest('base64url');

    if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expectedSignature))) {
      throw new Error(AUTH_ERRORS.INVALID_TOKEN);
    }

    const payload = parseJsonOrThrow(fromBase64Url(payloadB64).toString('utf8'), AUTH_ERRORS.INVALID_TOKEN);
    const now = Math.floor(Date.now() / 1000);
    if (typeof payload.exp !== 'number' || payload.exp <= now) {
      throw new Error(AUTH_ERRORS.SESSION_EXPIRED);
    }

    return payload;
  }

  getRetryAfterSeconds(attemptState, now = Date.now()) {
    const remainingMs = Math.max(0, attemptState.until - now);
    return Math.ceil(remainingMs / 1000);
  }

  authenticateUser({ identifier, password, userStore, attemptTracker }) {
    const normalizedIdentifier = String(identifier ?? '').trim().toLowerCase();
    const existingAttempts = attemptTracker.get(normalizedIdentifier) ?? { count: 0, until: 0 };
    const now = Date.now();

    if (existingAttempts.until > now) {
      return {
        ok: false,
        code: AUTH_ERRORS.ACCOUNT_LOCKED,
        retryAfterSeconds: this.getRetryAfterSeconds(existingAttempts, now),
      };
    }

    const user = userStore.find(
      (entry) =>
        String(entry.username ?? '').toLowerCase() === normalizedIdentifier ||
        String(entry.email ?? '').toLowerCase() === normalizedIdentifier
    );

    const passwordMatches = user ? this.verifyPassword(password, user.passwordHash) : false;

    if (!user || !passwordMatches) {
      const nextState = {
        count: existingAttempts.count + 1,
        until: existingAttempts.count + 1 >= this.maxAttempts ? now + this.lockoutWindowMs : 0,
      };

      if (nextState.until > 0) {
        attemptTracker.set(normalizedIdentifier, nextState);
      } else {
        attemptTracker.set(normalizedIdentifier, { count: nextState.count, until: 0 });
      }

      return {
        ok: false,
        code: AUTH_ERRORS.INVALID_CREDENTIALS,
      };
    }

    attemptTracker.delete(normalizedIdentifier);

    const sessionId = crypto.randomUUID();
    const accessToken = this.issueToken(
      { sub: user.id, sessionId, type: 'access' },
      this.accessTokenTtlSeconds
    );
    const refreshToken = this.issueToken(
      { sub: user.id, sessionId, type: 'refresh' },
      this.refreshTokenTtlSeconds
    );

    return {
      ok: true,
      userId: user.id,
      sessionId,
      accessToken,
      refreshToken,
      expiresAt: new Date(Date.now() + this.accessTokenTtlSeconds * 1000).toISOString(),
    };
  }

  refreshSession({ refreshToken, sessionStore }) {
    try {
      const payload = this.verifyToken(refreshToken);
      if (payload.type !== 'refresh') {
        throw new Error(AUTH_ERRORS.INVALID_TOKEN);
      }

      const activeSession = sessionStore.get(payload.sessionId);
      if (!activeSession || activeSession.revoked) {
        throw new Error(AUTH_ERRORS.SESSION_EXPIRED);
      }

      const newAccessToken = this.issueToken(
        { sub: payload.sub, sessionId: payload.sessionId, type: 'access' },
        this.accessTokenTtlSeconds
      );

      return {
        ok: true,
        accessToken: newAccessToken,
        expiresAt: new Date(Date.now() + this.accessTokenTtlSeconds * 1000).toISOString(),
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : AUTH_ERRORS.INVALID_TOKEN;
      throw new Error(message);
    }
  }

  revokeSession({ sessionId, sessionStore }) {
    const session = sessionStore.get(sessionId);
    if (!session) {
      return { ok: false, code: AUTH_ERRORS.SESSION_EXPIRED };
    }

    session.revoked = true;
    sessionStore.set(sessionId, session);
    return { ok: true, sessionId };
  }
}

export function createInMemoryUserStore(users = []) {
  return users.map((user) => ({
    ...user,
    username: user.username ?? user.email,
  }));
}
