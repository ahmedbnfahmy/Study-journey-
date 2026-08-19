
# Backend Caching Reference

Inventory of **all cache layers** in this backend (`back2` / XPro): Redis keys, Postgres mirror tables, and process-local memory. Use this when provisioning Redis, debugging stale auth/permissions, or deciding what must be warmed/invalidated.

---

## 1. Overview

| Layer             | Store                                                | Typical use                                                                  |
| ----------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------- |
| Redis (primary)   | `REDIS_HOST` / `REDIS_PORT` / `REDIS_PASSWORD` | Sessions, permissions, fraud counters, RAG, WhatsApp, rate limits, analytics |
| Postgres mirror   | `cached_credit_rates`, `account_permissions`     | Credit rates + permission warm standby                                       |
| In-process memory | Node`Map`                                          | WhatsApp intent classification, currency rates after load, Zoho sync helpers |

**Multiple Redis clients exist** (same Redis instance is expected; they are separate connections):

| Module                                                       | Role                                                                   |
| ------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `services/redisSessionService.js`                          | Sessions + generic get/set (`setGeneric` / `getGeneric`)           |
| `utils/redisClient.js`                                     | Permissions helpers, seller metadata, RAG answer cache, WhatsApp state |
| `services/RedisConfig.service.js`                          | Fraud V1, inactive-customer checks                                     |
| `config/redis.js` + `services/redisAnalytics.service.js` | Event/analytics counters (`eventSystem.redis.*`)                     |
| `middlewares/rateLimiter.js`                               | IP rate limiting (own client)                                          |
| `controllers/subscriptionController.js`                    | Legacy webhook permission write (own client)                           |
| `middleware/security.js`                                   | Webhook-style rate limit via`config/redis`                           |

Env defaults: host `127.0.0.1` (rate limiter default host is `redis`), port `6379`.

---

## 2. Redis key catalog

### 2.1 Auth sessions

| Key pattern                                | TTL                        | Value (JSON)                  | Written by                                  | Read by                                                      |
| ------------------------------------------ | -------------------------- | ----------------------------- | ------------------------------------------- | ------------------------------------------------------------ |
| `session:{accountId}:{timestamp}_{rand}` | **86400** (24h)      | Full session blob (see below) | `authController`, Zoho/Google login flows | `sessionAuth`, `flexibleAuthAndOps`, logout              |
| `session:{realmId}:{email}`              | **86400**            | Same shape                    | Keycloak / customer auth paths              | Session middleware                                           |
| `session:customer:{sellerId}:{hex}`      | **86400**            | Customer portal session       | `CustomerAuth.Controller`                 | Customer auth middleware                                     |
| `session:cashier:{cashierId}`            | Session TTL / until revoke | Cashier session               | Cashier login                               | `CashierSessionRevocationService` deletes on seller delete |

**Default session TTL constant:** `SESSION_TTL_SECONDS = 86400` in `controllers/authController.js`.
`redisSessionService.storeSessionData` default arg is `36000` if callers omit TTL — prefer always passing explicit TTL.

**Session payload fields (must be present for product flows):**

```json
{
  "keycloak_id": "string",
  "account_id": 123,
  "subdomain": "string",
  "roles": [2],
  "email": "user@example.com",
  "keycloak_email": "string|null",
  "user_id": 1,
  "first_name": "",
  "last_name": "",
  "role_id": 2,
  "access_token": "…",
  "refresh_token": "…|null",
  "expires_in": 300,
  "token_type": "Bearer",
  "authenticated_at": "ISO-8601",
  "realm_id": "promotly-test-realm",
  "id_token": "…|null",
  "seller_ids": [1, 2],
  "seller_id": 1,
  "cashier_ids": [10],
  "assigned_earning_type": "…|null",
  "is_global_settings": true,
  "is_global_redemption": true,
  "account_country_code": "EG",
  "account_country_id": 1,
  "seller_permissions": {},
  "billing_access": true,
  "credit_access": true,
  "campaign_management": true,
  "customer_management": true,
  "zoho_auth": false
}
```

**Invalidation:** On permission update, `AccountPermissionService` scans `session:*`, matches `"account_id":{id}`, and **deletes** those sessions (forces re-login with fresh flags). Cashier revoke deletes `session:cashier:{id}`.

Cookie paired with session: `httpOnly`, `secure`, `sameSite: None`, `maxAge` = TTL ms, `domain` from `FRONTEND_DOMAIN`.

---

### 2.2 Feature permissions (tenant)

| Key pattern                         | TTL                     | Value                                   | Notes                                                                                                        |
| ----------------------------------- | ----------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `permissions:tenant:{accountId}`  | **3600** (1h)     | Aggregated permissions JSON             | **Primary** key used by `AccountPermissionService` + `utils/redisClient`                           |
| `permissions:account:{accountId}` | n/a (delete only today) | —                                      | Cleared on add-on update in`InternalPermissionController` — **does not match tenant key** (see §7) |
| `permissions:{tenantId}`          | **none**          | Raw`feature_permissions` from webhook | Legacy`subscriptionController` — different key shape                                                      |

**Cached permissions shape (subs-mgmt source of truth only):**

```json
{
  "featureFlags": {
    "dashboard-access": true,
    "campaign-management": true,
    "credits-access": true,
    "rag-ask-access": true
  },
  "quotas": {
    "customers": 500,
    "campaigns": 20,
    "api_calls": 50000,
    "rag_questions": 500
  },
  "allowedEndpoints": ["/api/..."],
  "disallowedEndpoints": [".*"]
}
```

**Cache rules:**

1. Lookup order: Redis → subs-mgmt API → local subscription/tier / `account_permissions` → restricted default.
2. Redis is **written only** when source is `subs-mgmt` (or explicit `updateAccountPermissions`). Local-DB / restricted defaults must **not** poison Redis.
3. After successful API fetch, DB `account_permissions.permissions_json` is warm-updated asynchronously.

---

### 2.3 Seller metadata

| Key                   | TTL             | Value                                                                       |
| --------------------- | --------------- | --------------------------------------------------------------------------- |
| `seller:{sellerId}` | **86400** | `{ seller_type, earning_type, structure_type, account_id, account_type }` |

Helpers: `cacheSellerInfo` / `getCachedSellerInfo` / `invalidateSellerCache` in `utils/redisClient.js`.
Invalidate when seller or account type changes.

---

### 2.4 OAuth CSRF state (Google)

| Key                           | TTL                    | Value                                                                     |
| ----------------------------- | ---------------------- | ------------------------------------------------------------------------- |
| `oauth_state:{base64State}` | **600** (10 min) | `{ subdomain, seller_id, account_id, app_domain, redirect, timestamp }` |

Written in `authController.googleLogin`; validated on callback then deleted.

---

### 2.5 Email ↔ Keycloak mapping

| Key                                 | TTL            | Value                                                         |
| ----------------------------------- | -------------- | ------------------------------------------------------------- |
| `mapping:{realEmail}:{accountId}` | **3600** | Mapping row fields (+ wrapper used by`emailMappingService`) |

Invalidate on mapping update/delete (`DEL` same key).

---

### 2.6 Credit rates (Postgres cache, not Redis)

Table: **`cached_credit_rates`** (`models/CachedCreditRate.model.js`).

| Column                 | Meaning / default                |
| ---------------------- | -------------------------------- |
| `account_id`         | Unique per account               |
| `campaign_rate`      | Credits per campaign (100)       |
| `mall_campaign_rate` | Per mall campaign / tenant (100) |
| `transaction_rate`   | Per 1K transactions (10)         |
| `storage_rate`       | Per 100MB (5)                    |
| `api_call_rate`      | Per 10K API calls (15)           |
| `webhook_rate`       | Per 1K webhooks (20)             |
| `integration_rate`   | Per integration (100)            |
| `branch_rate`        | Extra branch (500)               |
| `tenant_rate`        | Extra tenant (1000)              |
| `customer_rate`      | Extra customer (50)              |
| `reward_rate`        | Reward option (25)               |
| `is_custom`          | Negotiated custom rates          |
| `synced_at`          | Last sync time                   |

**Also used by `CreditConsumptionService` (defaults if columns missing):** `aiTokenRate`, `ragQuestionRate`, `ragSearchRate` (typically 1). Ensure DB/migrations and sync payloads include RAG/AI rates if billing those quotas.

**Fill paths:**

1. Lazy fetch from subs-mgmt on cache miss → upsert.
2. RabbitMQ worker `credit_rates_sync_queue` (`workers/creditRatesSyncWorker.js`).
3. Internal API `POST /api/internal/accounts/:account_id/credit-rates`.

---

### 2.7 Fraud V1 (rules + counters)

| Key                                        | TTL                                                              | Value / type                                                         |
| ------------------------------------------ | ---------------------------------------------------------------- | -------------------------------------------------------------------- |
| `fraud_rules_v1:{ownerUserId}`           | **1** second                                               | Active`FraudRule` plain object                                     |
| `cashier:{cashierId}`                    | **1800** (30 min)                                          | Full`UserCashier` JSON (numeric id only; not `cashier:orders:*`) |
| `tx_count:{cashierId}:{period}`          | hour**3600** / day **86400** / else **604800** | Integer counter (`INCR`)                                           |
| `redemptions_count:{cashierId}:{period}` | same as period                                                   | Integer counter                                                      |
| `earned_points_24h:{accountId}`          | **86400** on first write                                   | Rolling points earned total (`INCRBY`)                             |

Invalidation helper: `invalidateFraudRuleV1RedisCaches({ all | cashier_id | owner_id })`.

---

### 2.8 Inactive customer

| Key                                | TTL                   | Value                                                         |
| ---------------------------------- | --------------------- | ------------------------------------------------------------- |
| `inactive:customer:{customerId}` | **300** (5 min) | `{ status, is_reset?, id? }` or `{ status: "no_record" }` |

Block when `status` is `pending` or `applied`. Cleared by inactivity event subscriber on status changes.

---

### 2.9 Cashier order list (query cache)

| Key                                                     | TTL          | Value                 |
| ------------------------------------------------------- | ------------ | --------------------- |
| `cashier:orders:{cashierId}:{sellerId}:{filtersJson}` | **60** | Paginated orders JSON |

Filters include type, dates, search, phone, page, limit. Short TTL; no explicit invalidation on new orders (stale ≤ 60s).

---

### 2.10 RAG answer cache

| Key                            | TTL                                                | Value                          |
| ------------------------------ | -------------------------------------------------- | ------------------------------ |
| `rag:answer:{hash16}`        | **3600** (Gemini path)                       | Answer entry (below)           |
| `rag:simple-answer:{hash16}` | **86400** default (`RAG_BYPASS_CACHE_TTL`) | Same shape, simple/bypass path |

Hash input (`generateQueryHash`): version salt `RAG_BYPASS_CACHE_SALT` / `v1`, lowercased trimmed query, options (collections, limit, scoreThreshold, perspective, optional `fileKey`), **not** mode (mode is in key prefix).

```json
{
  "answer": "…",
  "reply": "…",
  "steps": [],
  "sources": [],
  "intent": "…",
  "suggested_actions": [],
  "perspective": "ui|api|null",
  "tokenUsage": null,
  "query": "original",
  "created": 1710000000000,
  "cached": false
}
```

**Invalidate** on business-doc reindex (`scripts/rag/reindex-business-docs.js` clears `rag:simple-answer:*`). Bump `RAG_BYPASS_CACHE_SALT` to soft-evict all simple answers.

---

### 2.11 WhatsApp conversation state

| Key                         | TTL                         | Value                                           |
| --------------------------- | --------------------------- | ----------------------------------------------- |
| `whatsapp:conv:{phone}`   | **90000** (25h)       | `{ phone, startedAt, updatedAt, …metadata }` |
| `whatsapp:optin:{phone}`  | **7776000** (90 days) | `{ phone, optedIn, timestamp, … }`           |
| `whatsapp:ctx:{phone}`    | **90000**             | Ring buffer ≤ 10 messages                      |
| `whatsapp:intent:{phone}` | **90000**             | Current intent context                          |

---

### 2.12 Currency exchange rates

| Key                       | TTL            | Value                                                  |
| ------------------------- | -------------- | ------------------------------------------------------ |
| `exchange_rates:latest` | **3600** | `{ rates: { EGP: …, … }, timestamp, base: "USD" }` |

Also kept in-process (`CurrencyExchangeService.rates` Map) after load. Floor rates (e.g. EGP) in env protect undercharge if cache/API wrong.

Requires `global.redis` with `get` / `setex` wired at boot.

---

### 2.13 Rate limiting & idempotency

| Key                                             | TTL                      | Notes                           |
| ----------------------------------------------- | ------------------------ | ------------------------------- |
| `{keyPrefix}:{ip}`                            | window seconds           | `middlewares/rateLimiter.js`  |
| `rate_limit:{identifier}:{windowBucket}`      | window seconds           | `middleware/security.js`      |
| `rate:webhook:{webhookId}:count:{yyyymmddhh}` | **3600**           | Analytics service webhook guard |
| `dedup:event:{eventId}`                       | **7 days** default | Event idempotency               |

---

### 2.14 Analytics counters (event Redis)

| Key                                                     | TTL               | Type                    |
| ------------------------------------------------------- | ----------------- | ----------------------- |
| `analytics:account:{id}:total_points`                 | none              | counter                 |
| `analytics:account:{id}:points_issued`                | none              | counter                 |
| `analytics:account:{id}:transactions:count`           | none              | counter                 |
| `analytics:account:{id}:customers:{action}:count`     | none              | counter                 |
| `analytics:account:{id}:customers:total:count`        | none              | counter                 |
| `analytics:account:{id}:reward_type:{type}:count`     | none              | counter                 |
| `analytics:account:{id}:rewards:total:count`          | none              | counter                 |
| `analytics:seller:{id}:points_earned`                 | none              | counter                 |
| `analytics:seller:{id}:transactions:count`            | none              | counter                 |
| `analytics:seller:{id}:rewards:count`                 | none              | counter                 |
| `analytics:account:{id}:daily_points:{YYYY-MM-DD}`    | **7 days**  | ZSET                    |
| `analytics:account:{id}:daily_customers:{YYYY-MM-DD}` | **30 days** | ZSET                    |
| `seller:{sellerId}:campaign_enrollments`              | —                | ZSET (stream processor) |

These are **live aggregates**, not short-lived caches; treat persistence/replay carefully if Redis is wiped.

---

## 3. In-memory caches (not Redis)

| Location                                 | Data                                             | TTL / size             | Persist?                   |
| ---------------------------------------- | ------------------------------------------------ | ---------------------- | -------------------------- |
| `whatsapp/intentClassifier.service.js` | Intent classification by message snippet         | 5 min, max 100 entries | No — lost on restart      |
| `CurrencyExchangeService`              | Rate Map after Redis/API load                    | Until refresh          | Reloads from Redis on init |
| Zoho sync brand/category`Map`          | Request/job scoped                               | Job lifetime           | No                         |
| `Customer.points` (DB column)          | Denormalized points total synced by FIFO service | N/A                    | Yes (DB) — not Redis      |

---

## 4. What must be available for a healthy deploy

Minimum Redis data/capabilities:

1. **Writable Redis** with expiry (`SET` + `EX`, `INCR`, `INCRBY`, `EXPIRE`, `DEL`, `SCAN`/`KEYS`, optionally `ZADD`/`ZINCRBY`/`MGET`).
2. Ability to store **session blobs ≤ few KB** with 24h TTL (tokens + permissions flags).
3. Ability to store **permission JSON** per tenant (`permissions:tenant:*`) with 1h TTL.
4. Fraud counter keys and short-lived rule keys under `fraud_rules_v1:*`, `tx_count:*`, `redemptions_count:*`, `earned_points_24h:*`, `cashier:{n}`.
5. For billing: Postgres rows in **`cached_credit_rates`** (or subs-mgmt reachable to populate on miss).
6. For AI assistant: `rag:answer:*` / `rag:simple-answer:*` optional but expected for cost/latency.
7. For WhatsApp: keys under `whatsapp:*`.
8. For Google login: `oauth_state:*`.
9. For FX billing: `exchange_rates:latest` + floor envs.
10. Memory: do not rely on intent-classifier Map across instances (stateless/multi-pod).

**Warm / sync workers:** credit rates sync queue; permission webhooks into `updateAccountPermissions`; optional analytics stream processor.

---

## 5. Invalidation cheat sheet

| Event                                    | Action                                                                                                                |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Plan / permissions change from subs-mgmt | Set`permissions:tenant:{id}`; delete matching `session:*` for account                                             |
| Add-on change                            | Should delete`permissions:tenant:{id}` (today may only clear `permissions:account:` — fix consumers accordingly) |
| Seller update / delete                   | `invalidateSellerCache(sellerId)`; revoke `session:cashier:*` for seller                                          |
| Fraud rule edit                          | Delete`fraud_rules_v1:{ownerId}` (or use invalidate helper)                                                         |
| Customer inactivity change               | Delete`inactive:customer:{id}`                                                                                      |
| RAG docs reindexed                       | Clear`rag:simple-answer:*` and/or bump `RAG_BYPASS_CACHE_SALT`                                                    |
| Credit rates changed in subs-mgmt        | Upsert`cached_credit_rates` via worker/webhook                                                                      |
| Email mapping changed                    | `DEL mapping:{email}:{accountId}`                                                                                   |
| Logout                                   | `DEL` session key                                                                                                   |

---

## 6. Environment variables (caching-related)

| Variable                                                  | Purpose                                   |
| --------------------------------------------------------- | ----------------------------------------- |
| `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`        | Primary Redis                             |
| `eventSystem.redis.*` (config)                          | Analytics Redis (may use password file)   |
| `RAG_BYPASS_CACHE_TTL`                                  | Simple answer TTL (default 86400)         |
| `RAG_BYPASS_CACHE_SALT`                                 | Hash salt / soft eviction                 |
| `EXCHANGE_RATE_API_URL`, `EXCHANGE_RATE_API_KEY`      | FX source                                 |
| `EXCHANGE_RATE_FLOOR_EGP`                               | Fail-closed FX floor                      |
| `SUBS_MGMT_BACKEND_URL`, `SUBS_MGMT_INTERNAL_API_KEY` | Permissions + credit rate source of truth |
| `FRONTEND_DOMAIN`                                       | Session cookie domain                     |

---

## 7. Known inconsistencies (operators / agents)

1. **Permission key drift:** `permissions:tenant:{id}` (current) vs `permissions:account:{id}` (add-on clear) vs `permissions:{id}` (legacy webhook, no TTL). Prefer **tenant** everywhere when touching cache.
2. **Several Redis client modules** — same logical DB intended; connection storms possible under scale.
3. **Fraud rule cache TTL = 1s** — almost a no-op; still document key for invalidation.
4. **`CachedCreditRate` Sequelize model** may lag `CreditConsumptionService` fields (`aiTokenRate`, `ragQuestionRate`, `ragSearchRate`) — keep schema/sync payloads aligned.
5. Rate limiters **fail open** if Redis is down (requests allowed).

---

## 8. Quick test checklist

```bash
# Session
redis-cli GET 'session:…'
redis-cli TTL 'session:…'

# Permissions
redis-cli GET 'permissions:tenant:123'

# Seller
redis-cli GET 'seller:45'

# Fraud
redis-cli KEYS 'fraud_rules_v1:*'
redis-cli GET 'tx_count:10:hour'

# RAG
redis-cli KEYS 'rag:simple-answer:*'

# FX
redis-cli GET 'exchange_rates:latest'
```

Postgres:

```sql
SELECT * FROM cached_credit_rates WHERE account_id = 123;
SELECT account_id, last_updated_from_subs_mgmt_at FROM account_permissions WHERE account_id = '123';
```

---

## 9. Source files (authority)

- `services/redisSessionService.js`, `utils/redisClient.js`, `services/RedisConfig.service.js`
- `services/AccountPermissionService.js`, `controllers/authController.js`
- `models/CachedCreditRate.model.js`, `services/CreditConsumptionService.js`, `workers/creditRatesSyncWorker.js`
- `services/Fraud/V1/*`, `middlewares/Fraud/*`
- `services/rag/answer-cache.js`, `config/rag.config.js`
- `services/whatsapp/conversationState.service.js`, `intentClassifier.service.js`
- `services/CurrencyExchangeService.js`, `services/emailMappingService.js`
- `services/redisAnalytics.service.js`, `middlewares/rateLimiter.js`

_Last surveyed from codebase: 2026-08-05._
