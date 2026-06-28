# 7 Authentication Concepts Every Developer Should Know

**Source:** [YouTube — Hayk Simonyan](https://www.youtube.com/watch?v=iX8g4LqF8p8) (~21 min)  
**Companion:** [Substack article](https://hayksimonyan.substack.com/p/7-authentication-concepts-every-developer)

The video’s on-screen **canvas** is a taxonomy: authentication methods on one side, federated protocols on another, with clear labels for what each thing *actually is* (method vs format vs framework vs UX pattern).

---

## Core idea

**Authentication** answers: *Who is this?*  
It runs **before** **authorization** (*What can they do?*). Invalid identity → `401 Unauthorized`.

Main point: developers often mix up **methods**, **token formats**, **frameworks**, and **UX patterns**. The canvas fixes that by placing each concept in the right bucket.
---

## Section-by-section summary

| Timestamp | Topic | Canvas takeaway |
|-----------|--------|-----------------|
| **0:00** | Intro | JWT = **format**, not a method. Bearer = **pattern**. OAuth2 = **authorization**. SSO = **UX**, not a method. |
| **1:30** | What is authentication? | Request hits API gateway → verify identity → then authorization. Flow: client → gateway → services → data. |
| **2:53** | Basic Auth | `Authorization: Basic base64(user:pass)`. Simple; reversible without HTTPS; credentials on every request. |
| **4:26** | Digest Auth | Challenge/response with MD5; better than plain Basic, still legacy. |
| **6:12** | API Keys | Key in `Authorization` or `X-API-Key`; server looks up hash + scopes in DB. No embedded claims; leaks are dangerous unless you add expiry. |
| **8:16** | Sessions | Login → session in Redis/DB → `Set-Cookie`. **Stateful**; fine for classic web, harder at API scale. |
| **10:00** | Bearer + JWT | Bearer = “whoever holds it.” JWT = signed JSON (user id, exp, roles). **Stateless** — verify signature locally, no DB per request. |
| **12:54** | Access + refresh | Access: short (15 min–1 hr). Refresh: long (days/weeks), **httpOnly cookie** (not `localStorage`). On 401, refresh silently renews access. |
| **14:38** | OAuth 2.0 | **Authorization**: “What can this app access on my behalf?” (e.g. Google Drive). Access token ≠ proof of *who* the user is. |
| **16:14** | OpenID Connect | **Authentication** on top of OAuth2. “Sign in with Google” → **ID token** (JWT) with identity (email, sub). Access token = OAuth; ID token = who you are. |
| **17:41** | SSO | **UX**: one login → Gmail, Drive, YouTube, etc. Global session + SSO cookie; each app reuses session. |
| **19:05** | SAML vs OIDC | **Identity protocols** under SSO. SAML: XML, enterprise (Salesforce, corp). OIDC: JWT ID token, modern (Google). |
| **20:44** | Authorization | Teaser only — separate video on permissions/frameworks. |

---

## Detailed notes

### What is authentication?

- Answers: **Who is this user?**
- Login request from user or service → confirm identity.
- Valid → grant access through API gateway to services and data.
- Invalid → `401 Unauthorized`.
- First step **before** authorization (what they can do once inside).

### Basic authentication

- Simplest form: request without credentials → `401` → client sends `Authorization: Basic <base64(username:password)>`.
- Server verifies; returns `200` + data or `401`.
- **Problem:** Base64 is easily reversed; insecure without HTTPS. Credentials sent on every request. Rare in production except internal tools.

### Digest authentication

- Similar flow; uses MD5 hashing instead of plain credentials in the header.
- Slightly better than Basic; still outdated.

### API keys

- Unique key per client; sent via `Authorization` or `X-API-Key`.
- Server looks up key hash + scopes in DB.
- **Unlike JWT:** random string, no embedded claims; must DB lookup for owner/permissions.
- **Risk:** leaked key = full access unless you implement expiration.

### Session-based authentication

- User logs in → server creates session in storage (memory, Redis, SQL, filesystem).
- **Redis** is common in production: fast, built-in expiration.
- Server sets session cookie; subsequent requests look up session ID.
- **Stateful:** server must remember sessions. Works for traditional web apps; harder to scale for APIs / distributed systems.

### Bearer tokens and JWTs

- **Bearer token:** pattern — whoever holds the token gets access (not a specific method).
- **JWT:** most common bearer token — signed JSON with user id, email, `exp`, roles, etc.
- **Stateless:** API verifies signature locally; no DB lookup per request.
- Pre-JWT tokens were opaque strings requiring DB/cache lookup (still stateful).
- Client sends `Authorization: Bearer <token>` on each request after initial login.

### Access and refresh tokens

| Token | Lifetime | Purpose |
|-------|----------|---------|
| Access | Short (15 min – 1 hr) | API calls |
| Refresh | Long (days – weeks) | Get new access tokens |

- On login, client receives both.
- Store refresh token in **httpOnly cookie** (not `localStorage`) to reduce XSS risk.
- When access token expires → `401` → client uses refresh token → new access token → retry request.

### OAuth 2.0

- **Authorization framework**, not authentication.
- Answers: *What can this app access on behalf of the user?*
- Flow: redirect to consent → user approves → authorization code → exchange for **access token** (e.g. Google Drive API).
- Access token proves the app may access resources; it does **not** tell the app who the user is.

### OpenID Connect (OIDC)

- Adds **authentication** on top of OAuth 2.
- “Sign in with Google/GitHub/Microsoft” uses OIDC.
- After code exchange: **access token** (OAuth authorization) + **ID token** (JWT with identity: email, `sub`, etc.).
- App verifies ID token → creates session / issues its own tokens.
- **OIDC = authentication layer; OAuth2 = authorization layer underneath.**

### Single sign-on (SSO)

- **User experience**, not an authentication method.
- Log in once to identity provider (Google, Okta) → access Gmail, Drive, YouTube, Calendar without re-login.
- Global session stored at IdP; SSO cookie on client; each service verifies existing session.

### Identity protocols (under SSO)

| Protocol | Format | Use case |
|----------|--------|----------|
| **SAML** | XML assertions | Enterprise, legacy (Salesforce, corporate dashboards) |
| **OIDC** | JWT ID token | Modern (Google, etc.) |

Both are secure and widely used; OIDC is the more modern approach.

### Authorization (brief)

- After authentication, **authorization** controls what the user can access and do.
- Covered in a separate video by the same author.

---

## Key distinctions (canvas emphasis)

1. **Authentication ≠ authorization** — know identity first, then permissions.
2. **API key ≠ JWT** — API key is opaque; JWT carries claims and is verified by signature.
3. **Session vs JWT** — sessions need server storage; JWTs scale without a lookup per request.
4. **OAuth2 vs OIDC** — OAuth2 delegates **access**; OIDC adds **identity** (ID token).
5. **SSO vs SAML/OIDC** — SSO is the experience; SAML/OIDC are the protocols underneath.
6. **JWT** is a **token format**, not an authentication method.
7. **Bearer** is a **pattern**, not synonymous with JWT.
8. **OAuth2** is an **authorization framework**, not an authentication method.
9. **SSO** is a **UX pattern**, not an authentication method.

---