---
title: "Secure Login Service"
version: "1.0.0"
date_created: "2026-10-27"
last_updated: "2026-10-27"
status: "Draft"
prd_ref: "docs/prd/secure-login-service-prd.md"
tags: ["polya", "spec", "clean-architecture", "authentication"]
---
<!-- markdownlint-disable-->

# Technical Specification: Secure Login Service

## 1. Pólya Phase 1: Understanding the Problem

### 1.1 The Unknown (Goal & Desired State)
- We need a secure user authentication feature that allows a user to sign in with a username or email and a password, verify identity, and establish a trusted authenticated session.
- A successful implementation will produce a safe authentication flow with strong credential handling, short-lived sessions, secure token issuance, and observable protection against abuse.
- The feature must not introduce insecure password storage, indefinite session lifetimes, or silent fallback behavior in the security boundary.

**Explicit Non-Goals (Out of Scope):**
- Social login, SSO federation, and enterprise IdP integrations in v1.
- Password reset and account recovery flows.
- User registration and profile management.
- Authorization beyond the login/session boundary; role-based access control is out of scope unless explicitly added later.

### 1.2 The Data (Inputs, State & Source-Grounded Context)
- The project currently presents a general-purpose AI coding framework with no dedicated application auth layer confirmed in the repository. The only source-grounded evidence is the project overview and scaffold conventions in `[VERIFIED: README.md:19-33]`.
- Inputs for the login flow include:
  - `identifier`: email or username.
  - `password`: secret credential from the client.
  - `rememberMe`: optional boolean for extended session lifetime.
  - `deviceInfo`: optional client metadata for audit logging.
  - `requestMetadata`: IP address, user-agent, request ID.
- Security state includes:
  - hashed password records, login attempt counters, lockout timestamps, and refresh/session token state.
  - current time and time zone for expiration checks.
- Existing repository seams that are relevant to future implementation are conceptual only because no app auth package was found in the source tree: `README.md` establishes a general software project context, while no actual auth domain or DB schema was discovered in the codebase.

### 1.3 The Condition (Requirements, Constraints & Invariants)
- **REQ-001 `[PRD Ref: US-01 / FR-01]`:** The system shall authenticate a user by verifying the provided identifier and password against the stored credential record and shall return a typed success or failure result without revealing whether the identifier or password was incorrect.
- **REQ-002 `[PRD Ref: US-02 / FR-02]`:** The system shall enforce a secure password policy, reject blank or overlong credentials, and store password hashes using a strong adaptive algorithm such as Argon2id or bcrypt with per-user salt.
- **REQ-003 `[PRD Ref: US-03 / FR-03]`:** The system shall issue a short-lived access token and a refresh token with rotation semantics; the refresh token shall be invalidated after use and replaced with a new one.
- **REQ-004 `[PRD Ref: US-04 / FR-04]`:** The system shall rate-limit repeated login failures and enforce temporary or permanent lockout thresholds based on failure count and time window.
- **REQ-005 `[PRD Ref: US-05 / FR-05]`:** The system shall reject expired, malformed, or replayed sessions and ensure logout invalidates the active session state.
- **CON-001 (Performance / SLA & Quality Ratchets):** Login verification shall complete within 500 ms p95 for a single valid request under normal load; the system shall not perform blocking password verification on a cold cache path beyond the configured threshold.
- **CON-002 (Security & Invariants):** Passwords shall never be stored or logged in plaintext; all credentials and tokens shall be transmitted only over HTTPS/TLS; sensitive security failures shall be logged with redacted metadata and correlation IDs.
- **CON-003 (Security & Invariants):** A failed login attempt shall not reveal account existence or password validity; all validation errors shall be normalized into a generic authentication failure response.

### 1.4 Condition Sanity Check & Completeness Audit (Pólya, p. 7, 33)
- **Is the condition sufficient to determine the unknown?** Yes, for a v1 secure login feature, the condition defines the authentication path, token lifecycle, failure handling, and security guardrails required for completion.
- **Is it insufficient?** The repository does not yet include a persistence schema or explicit UI flow; therefore, the exact storage model and client presentation layer must be treated as implementation-level decisions under assumption tags.
- **Is it redundant or contradictory?** No direct contradictions are apparent; the constraints remain consistent with secure authentication practice.
- **Did you use ALL the data?** The brief provides the requirement for a secure login service, but not domain-specific auth tables or user models; therefore, the specification intentionally defines the minimum domain contract without inventing unverified DB fields.
- **Did you use the WHOLE condition?** Yes, the requirements cover authentication success, failure, session validity, hashed storage, and lockout enforcement.

### 1.5 Indirect Proof & Negative Invariant Analysis (Pólya, p. 162–171)
- **Negative Hypothesis (Assume Violation):** If a user attempts authentication with an expired refresh token or using a tampered token, the system must reject it without creating a new session.
- **Contradiction & Safe Rejection:** The system rejects invalid states by verifying token signature, expiry, nonce, and session ownership before granting access; invalid states result in typed auth errors, not 500s or silent fallback.
- **Negative Hypothesis (Assume Violation):** If the database stores plaintext passwords or logs them during failure events, the security invariant is broken.
- **Contradiction & Safe Rejection:** The auth service must perform hashing before persistence, never emit raw secrets to logs, and enforce redacted telemetry emission.

---

## 2. Ubiquitous Language & Domain Glossary (`CONTEXT.md`)
- **User Account:** The persistent identity record representing a human or service principal eligible to authenticate.
- **Credential Pair:** The identifier and secret used to prove identity during login.
- **Password Hash:** A one-way, salted representation of the user secret that cannot be reversed without brute-force cost.
- **Access Token:** A short-lived bearer token used to authorize subsequent protected requests.
- **Refresh Token:** A longer-lived token used to obtain a new access token without re-entering user credentials.
- **Session:** The authenticated state established after successful verification, tied to a user, device, and expiry window.
- **Rate Limit / Lockout:** A guardrail that slows or blocks repeated failed login attempts to prevent brute-force abuse.

_Avoid_: user id, login secret, password string, session cookie, auth token aliasing as equivalent domain concepts without explicit semantics.

---

## 3. Assumptions & Open Clarifications

> [!WARNING] [ASSUMPTION-001]: The repository does not contain an existing auth domain or persistence schema; this specification therefore defines a clean greenfield authentication boundary for a future implementation.
> *Risk / Trade-off:* If the codebase later adds a different user model or session store, the auth contract may need to be adapted.
> *Proposed Verification:* Confirm the target app stack, persistence database, and user table before implementation.

- **CLARIFICATION-001:** Should v1 support multi-factor authentication (MFA) or only single-factor email/username + password?
- **CLARIFICATION-002:** Should the initial deployment target a web application, API-only service, or both?
- **CLARIFICATION-003:** Is lockout policy per user, per IP, or both?

---

## 4. Setting Up Equations & Expressive Notation (Pólya, p. 134–141)

- **Type-Driven Domain Invariants:** The auth domain should use value objects and typed results such as `LoginIdentifier`, `PasswordHash`, `AccessToken`, `SessionId`, and `AuthResult` to ensure invalid states do not exist at compile time.

### 4.1 Data Transfer Objects (DTOs) & Interfaces
```typescript
export interface LoginRequestDTO {
  readonly identifier: string;
  readonly password: string;
  readonly rememberMe?: boolean;
}

export interface LoginResponseDTO {
  readonly success: boolean;
  readonly userId: string;
  readonly accessToken: string;
  readonly refreshToken: string;
  readonly expiresAt: string;
}

export interface AuthErrorDTO {
  readonly code: 'INVALID_CREDENTIALS' | 'ACCOUNT_LOCKED' | 'SESSION_EXPIRED' | 'INVALID_TOKEN';
  readonly message: string;
  readonly retryAfterSeconds?: number;
}
```

### 4.2 Database Schema / Persistence Models & Migration Strategy
- **Schema / Indexes:**
  - `users` table with unique `email` or `username` and a stored password hash.
  - `user_sessions` table with `user_id`, `session_id`, `issued_at`, `expires_at`, `revoked_at`, `device_info`, and `last_seen_at`.
  - `login_attempts` table with `user_id`, `ip_hash`, `attempted_at`, `success`, and `failed_count`.
- **Indexes:** unique index on `users.email` and `users.username`; composite index on `login_attempts(user_id, attempted_at)`; composite index on `user_sessions(user_id, expires_at)`.
- **Backward Compatibility (Expand-Migrate-Contract):** Add new tables and indexes without breaking existing schema; use additive migration patterns and facility for token revocation status.

### 4.3 API Error Contract, Idempotency & 5 UI States Matrix
- **Error Contract (RFC 7807 / Typed Domain Errors):**
  - `INVALID_CREDENTIALS` -> HTTP 401
  - `ACCOUNT_LOCKED` -> HTTP 423 or 429 with `Retry-After`
  - `SESSION_EXPIRED` -> HTTP 401
  - `INVALID_TOKEN` -> HTTP 401
- **Idempotency & Pagination:** User login is not idempotent by default; the implementation shall enforce a correlation ID and record a single session issuance per request ID. List endpoints for session history should use cursor pagination and a maximum page size of 50.
- **5 UI States Matrix:**
  - **Loading:** disabled form and spinner after submit.
  - **Empty:** no sessions to display; show “Sign in to continue”.
  - **Error:** show one actionable message without revealing password validity state.
  - **Partial:** if session list or device history loads gradually, show remaining devices state.
  - **Populated:** show authenticated landing screen and session status.

### 4.4 Observability, Telemetry & SLIs (RED / USE Metrics)
- **Structured Logging:** log `user_id_hash`, event type, correlation ID, IP hash, request ID, and outcome; do not log cleartext password or access token values.
- **Metrics & Alerts:** track login success rate, login failure rate, lockout rate, session issuance latency, and refresh-token rotation failures.

---

## 5. Clean Architecture Seams & Component Boundaries

> [!NOTE]
> **Architectural Pragmatism Check:** This feature is a greenfield authentication flow and should use a pragmatic but clean 4-layer boundary without over-engineering beyond the login/session domain.

```text
Entities (Domain Layer)
   └── Credential, PasswordHash, Session, RefreshToken, LockoutPolicy
Use Cases (Application Layer)
   └── AuthenticateUser, IssueSession, RefreshSession, RevokeSession
Interface Adapters (Controllers, Gateways, Presenters)
   └── AuthController, PasswordHasherAdapter, TokenIssuerAdapter, SessionRepository
Frameworks & Drivers (DB, Web Server, UI Runtimes)
   └── Web framework, crypto library, persistence engine, HTTP client
```

- **Domain Layer:** `CredentialVerifier`, `PasswordHash`, `SessionPolicy`, and typed auth errors.
- **Use Case Layer:** `AuthenticateUser`, `RefreshSession`, `LogoutUser`, `EnforceLoginAttemptGuard`.
- **Adapter Layer:** HTTP login controller, password hash adapter, refresh token repository, lockout tracker.
- **Dependency Inversion Seams:** ports for `PasswordHashingPort`, `SessionStorePort`, `TokenIssuerPort`, and `RateLimitPort`.

---

## 6. Acceptance Criteria (Given-When-Then)

- **AC-001 (Happy Path for REQ-001 / REQ-003):**  
  *Given* a user record exists and the password matches the stored hash,  
  *When* the client calls the login endpoint with a valid identifier and password,  
  *Then* the system returns a success DTO with a short-lived access token and a refresh token, along with an expiration timestamp.

- **AC-002 (Failed Credentials for REQ-001 / REQ-004):**  
  *Given* a user record exists but the submitted password is incorrect,  
  *When* the login endpoint is called,  
  *Then* the system returns a normalized auth failure response and increments the failure count without revealing account existence.

- **AC-003 (Lockout / Abuse Protection for REQ-004):**  
  *Given* a user has exceeded the configured login failure threshold within the lockout window,  
  *When* another login attempt is submitted,  
  *Then* the system rejects the request with `ACCOUNT_LOCKED` and includes a `Retry-After` duration.

- **AC-004 (Expired or Replayed Session for REQ-005):**  
  *Given* a session or refresh token has expired or has already been rotated,  
  *When* the protected endpoint or refresh endpoint is called,  
  *Then* the system returns `SESSION_EXPIRED` or `INVALID_TOKEN` and does not grant access.

### 6.1 Value Sourcing & Positive Input Coverage Table

| Required Output / Computed / Displayed Value | AC Ref | Named Source (`Input DTO` / `DB Column [file:line]` / `Derivation Formula` / `Config`) | Boundary / Edge Variation |
| :--- | :---: | :--- | :--- |
| `authenticationResult` | `AC-001` | `Derived: verifyHash(identifier, password)` + token issuance policy | valid user, wrong password, null identifier |
| `accessToken` | `AC-001` | `Derived: tokenIssuer.issue(userId, sessionId, ttl=5m)` | TTL expiry and rotation |
| `refreshToken` | `AC-001` | `Derived: tokenIssuer.issue(userId, sessionId, ttl=30d)` | rotation after use |
| `expiresAt` | `AC-001` | `Config: accessTokenTtlSeconds` | timezone-consistent UTC |
| `retryAfterSeconds` | `AC-003` | `Derived: max(0, lockoutWindow - elapsedSeconds)` | zero, positive integer |
| `authFailureCode` | `AC-002` | `Derived: generic failure enum` | invalid user, invalid password |

---

## 7. Testing Strategy & Dimensional Bounds

- **Testing Seam:** The public boundary should be the auth API endpoint and the session refresh endpoint.
- **Dimension Checks:** verify all time-based values in UTC, enforce a cap on token TTL values, and keep token sizes bounded under the configured HTTP header size.
- **Extreme Limiting Cases (Specialization):** null identifier, empty password, long password payload, repeated breach attempts, expired refresh token, stale session after logout, concurrent revocation, and malformed JWT payloads.

---

## 8. Architectural Decision Records (ADRs)

- [ADR-0001: Auth token strategy](docs/adr/0001-auth-token-strategy.md) — Short-lived access token with rotating refresh token is the default secure pattern for stateless authenticated APIs.

---

## 9. Implementation Notes for Downstream Phases
- The next planning phase should break this specification into tracer bullets across domain validation, persistence, token issuance, and API error handling.
- No application code should be written before the implementation plan is reviewed and approved under the Pause Rule.
- If a project-specific schema or existing auth layer is later discovered, this draft should be revised so it aligns with the actual repository seams rather than the greenfield assumptions above.

```
