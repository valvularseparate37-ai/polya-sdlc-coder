---
goal: "Secure Login Service"
version: "1.0.0"
date_created: "2026-10-27"
last_updated: "2026-10-27"
status: "Planned"
spec_ref: "docs/spec/secure-login-service-spec.md"
tags: ["polya", "plan", "tracer-bullets", "vertical-slicing", "clean-architecture", "authentication"]
---
<!-- markdownlint-disable -->

# Implementation Plan: Secure Login Service

> [!IMPORTANT]
> **THE PAUSE RULE & VERTICAL SLICING MANDATE:**
> All tasks in this plan are organized into **Vertical Feature Slices (Tracer Bullets)** spanning from storage/domain to API and UI. Horizontal layer-by-layer slicing is strictly prohibited.
> After each verified phase, execution MUST halt for explicit user approval before proceeding. Functional code MUST NOT be written until this plan is approved.

---

## 1. Overview & High-Level Mental Model

This plan implements a secure greenfield login service with explicit safety boundaries: password storage via strong adaptive hashing, short-lived access tokens, rotating refresh tokens, lockout/rate limiting, and typed auth failures.

The system is intentionally scoped to the authentication boundary only: login, token issuance, token refresh, session invalidation, and negative-path security handling. Registration, password reset, MFA, and RBAC are intentionally deferred to a later phase and are explicitly excluded from v1.

### Topological Data Flow Diagram
```text
[Login Form / API Client] ──▶ [Auth Controller Adapter] ──▶ [AuthenticateUser Use Case] ──▶ [Domain Auth Rules]
                                                         │
                                                         ▼
                                             [Password Hash + Session Store Ports] ──▶ [DB / Crypto / Token Service]
``` 

---

## 2. 📏 Task Sizing Matrix

| Size   | Files Impacted | Scope                                           | Example                                                 |
| :----- | :------------: | :---------------------------------------------- | :------------------------------------------------------ |
| **XS** |       1        | Single pure function or config change           | password policy rule / typed auth errors                 |
| **S**  |      1-2       | Small focused vertical interaction              | lockout guard + UI error toast                           |
| **M** |      3-5       | Standard Vertical Feature Slice (Tracer Bullet) | login flow: domain + use case + API + UI                 |
| **L**  |      5-8       | Multi-component vertical flow                   | session refresh + expiration + cleanup                    |
| **XL** |       8+       | **Strictly Prohibited (Too Large)**             | Must be decomposed into smaller slices                  |

---

## 3. Phased Implementation Sequence (Vertical Tracer Bullets)

> **EXECUTION DIRECTIVE FOR AI AGENTS (`/to-code` & `/to-code auto`):**
> - **Interactive Mode (`/to-code`):** Execute ticket by ticket. Run `check:task` after each slice, then pause for user confirmation at each `APPROVAL` gate.
> - **Autonomous Mode (`/to-code auto`):** Advance automatically through verified green tickets until all phases complete or one of the circuit breakers triggers.

### Implementation Phase 1: Land — Minimal End-to-End Tracer Bullet
*Goal: Deliver the minimal fully functional login flow without fluid scope expansion.*

| Task | Description | Ref ID | AC Ref | Dep | Files | Completed | Date |
| :--- | :--- | :--- | :--- | :--- | :---: | :---: | :---: |
| TASK-001 | Login success slice [Domain credential verification + AuthenticateUser + POST /login + login form] | REQ-001 | AC-001 | - | 3-5 (M) | [ ] |  |
| TASK-002 | Failed credential / generic response slice [typed auth error + normalized response + UI error state] | REQ-001, CON-003 | AC-002 | TASK-001 | 2-3 (S) | [ ] |  |
| TASK-00X | **VERIFY (`check:task`):** Execute scoped slice test + typecheck + lint for login flow | - | - | TASK-002 | - | [ ] |  |
| TASK-00Y | **APPROVAL:** 🛑 Stop and wait for explicit user confirmation to proceed to Phase 2 | - | - | - | - | [ ] |  |

### Implementation Phase 2: Expand — Robustness, Abuse Protection & Session Lifecycle
*Goal: Harden the baseline with lockouts, token rotation, and session invalidation.*

| Task | Description | Ref ID | AC Ref | Dep | Files | Completed | Date |
| :--- | :--- | :--- | :--- | :--- | :---: | :---: | :---: |
| TASK-003 | Password hashing + policy validation slice [hashing adapter + validation rules + secure storage contract] | REQ-002 | AC-001, AC-002 | TASK-001 | 2-4 (M) | [ ] |  |
| TASK-004 | Rate limit + lockout slice [failure counting + retry-after + lockout UI state] | REQ-004 | AC-003 | TASK-002 | 2-4 (M) | [ ] |  |
| TASK-005 | Access-token / refresh-token issuance and rotation slice [JWT or signed opaque tokens + refresh flow + session persistence] | REQ-003 | AC-001, AC-004 | TASK-001 | 3-5 (M) | [ ] |  |
| TASK-006 | Logout + session invalidation slice [revoke active session, invalid refresh rejection, logout button behavior] | REQ-005 | AC-004 | TASK-005 | 2-3 (S) | [ ] |  |
| TASK-007 | Negative invariant test slice [expired token, replay token, malformed payload, stale session, compromised token signature] | REQ-005, CON-002 | AC-004 | TASK-006 | 1-3 (S) | [ ] |  |
| TASK-00X | **VERIFY (`check:task`):** Execute security-focused validation and full auth slice verification | - | - | TASK-007 | - | [ ] |  |
| TASK-00Y | **APPROVAL:** 🛑 Stop and wait for explicit user confirmation before final quality gate | - | - | - | - | [ ] |  |

### Implementation Phase 3: Final Quality Gate & Observability
*Goal: Confirm the auth contract is measurable, resilient, and ready for review.*

| Task | Description | Ref ID | AC Ref | Dep | Files | Completed | Date |
| :--- | :--- | :--- | :--- | :--- | :---: | :---: | :---: |
| TASK-008 | Observability and telemetry slice [correlation IDs, redacted logs, login metrics, lockout and token failure alerts] | CON-001, CON-002 | AC-001, AC-002, AC-003 | TASK-004 | 1-2 (S) | [ ] |  |
| TASK-009 | Boundary validation & fuzz slice [empty input, max-length input, unicode, concurrent attempts, replay attack] | REQ-001, REQ-004, REQ-005 | AC-002, AC-003, AC-004 | TASK-007 | 1-2 (S) | [ ] |  |
| TASK-00X | **VERIFY (`check:full`):** Run full verification suite, security checks, and quality ratchets | - | - | TASK-009 | - | [ ] |  |
| TASK-00Y | **APPROVAL:** 🛑 Stop and wait for explicit user confirmation to declare plan complete | - | - | - | - | [ ] |  |

---

## 4. Contingency Plan B (Have Two Strings to Your Bow)

*Pólya Heuristic: Prepare for failure of the primary strategy.*

- **Risk / Failure Point:** Token verification via a stateless JWT approach may create signature or revocation difficulties in systems that require immediate session invalidation across many active sessions.
- **Primary Strategy (Plan A):** Use short-lived signed access tokens plus rotating refresh tokens, with server-side session records for revocation and expiry checks.
- **Contingency Strategy (Plan B):** Use opaque session tokens stored server-side and an internal token lookup table, enabling immediate invalidation and partial revocation without broad token signature maintenance.
- **Trigger Condition:** Switch to Plan B if immediate invalidation, replay prevention, or single-session termination becomes operationally difficult or if the target stack requires a stateful session model.

---

## 5. Symmetry, Invariants & Problem Variation (Pólya, p. 199–214)

- **Symmetric Operations & Round-Trip Invertibility ($f^{-1}(f(x)) = x$):**
  - `hashPassword` ↔ `verifyPassword`
  - `issueAccessToken` ↔ `verifyAccessToken`
  - `issueRefreshToken` ↔ `consumeRefreshToken`
  - `createSession` ↔ `revokeSession`
- **Variation of the Problem (Property-Based & Fuzz Exploration):**
  - Empty identifier, blank password, password over the max length, repeated failed attempts, user lockout expiry, timestamp skew, duplicated refresh requests, replayed tokens, and unicode edge cases.
- **SOLID Checks at Blueprint Stage:**
  - *Single Responsibility (SRP):* each class or module owns exactly one security responsibility (hashing, token validation, lockout enforcement, session persistence).
  - *Dependency Inversion (DIP):* use cases depend on ports (`PasswordHashingPort`, `SessionStorePort`, `TokenIssuerPort`, `RateLimitPort`) rather than concrete frameworks.

---

## 6. Risks & Extracted Assumptions

*Extracted from upstream Spec `[ASSUMPTION]` tags:*

- **[ASSUMPTION-001]:** The repository does not yet contain an existing auth domain or persistence schema; implementation will target a clean greenfield auth seam with the minimal required storage tables and ports.
  - *Mitigation:* Validate actual application stack before implementation; adapt the domain model to real DB and framework constraints if discovered.
- **[RISK-001]:** The chosen auth model may not match the final application's persistence or session architecture.
  - *Mitigation:* Keep the auth layer behind ports and attach a minimal adapter to the real user/session store once the real stack is confirmed.
- **[RISK-002]:** The absence of a user management flow may cause password reset and MFA to be deferred incorrectly.
  - *Mitigation:* Keep all non-login flows explicitly outside v1 scope and document them as follow-on work.

---

## 7. Rollback & Recovery Strategy

1. Revert git commits using `git revert HEAD~N..HEAD` if the feature introduces destructive regressions.
2. Roll back auth-specific migrations or schema changes with the project migration rollback procedure.
3. Invalidate any issued sessions, rotate refresh token secrets if compromised, and reset lockout counters if the system is in a bad state.
4. Restore the baseline login path and recommence from the last verified green feature slice.

---

## 8. 🚩 Pre-Flight Self-Correction Checklist (Anti-Patterns)

Before presenting this plan to the user, verify it is free from these anti-patterns:
- [ ] **No Horizontal Slicing:** Tasks are not grouped by DB table or framework layer; each task is a vertical feature slice from domain to UI.
- [ ] **No Bloated Tasks (XL):** No task touches 8+ files or combines unrelated subdomains.
- [ ] **Strict Traceability:** Every actionable task has valid `Ref ID` and `AC Ref` links to the spec.
- [ ] **Deterministic Dependencies:** The `Dep` column points strictly bottom-up to previously scheduled tasks.
- [ ] **Mandatory Verification & Approval:** Every phase ends with `VERIFY` and `APPROVAL` checkpoints.

---

## 9. Readiness Summary

This plan is ready for review because it:
- aligns directly to the secure login specification,
- defines the minimum viable secure auth flow,
- includes guardrails for lockout, session invalidation, and replay protection,
- and breaks implementation into vertical slices with explicit approval gates.

The next step is not coding but confirmation: we must pause before implementation and verify that this architecture matches your intended product direction.

> *"Does this understanding and architectural plan align with your vision? Shall we proceed to implementation?"*
