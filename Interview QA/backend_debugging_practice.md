# Backend Debugging & Problem-Solving Practice
### Prep for Technical Interview — Node.js / NestJS / SQL / Redis / RabbitMQ

---

## Exercise 1: Async/Await Bug

```javascript
async function getUserOrders(userId) {
  const orders = [];
  const orderIds = await db.getOrderIds(userId);

  orderIds.forEach(async (id) => {
    const order = await db.getOrder(id);
    orders.push(order);
  });

  console.log(`Found ${orders.length} orders`);
  return orders;
}
```

**Bug:** `forEach` does not wait for async callbacks. It fires off all the async functions but doesn't await any of them, so `console.log` and `return orders` execute immediately — before any order has actually been pushed. The function will almost always return an empty (or partially filled) array.

**Fix:** Use `Promise.all` with `map` instead:

```javascript
async function getUserOrders(userId) {
  const orderIds = await db.getOrderIds(userId);
  const orders = await Promise.all(orderIds.map(id => db.getOrder(id)));
  console.log(`Found ${orders.length} orders`);
  return orders;
}
```

**Interviewer follow-up:** They may ask about the difference between `Promise.all` (fails fast if one rejects) vs `Promise.allSettled` (waits for all, gives status per promise) — know when you'd use each.

---

## Exercise 2: Express Middleware Bug

```javascript
app.use((req, res, next) => {
  if (!req.headers.authorization) {
    res.status(401).json({ error: 'Unauthorized' });
  }
  next();
});

app.get('/profile', (req, res) => {
  res.json({ user: req.user });
});
```

**Bug:** `next()` is called unconditionally, even after sending a 401 response. This means the request continues to the route handler after the response was already sent, causing a "Cannot set headers after they are sent" error, or in some cases, the client gets a mixed/broken response.

**Fix:** Add a `return` (or wrap in `else`):

```javascript
app.use((req, res, next) => {
  if (!req.headers.authorization) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
});
```

**Interviewer follow-up:** They may ask you to also validate the token itself (not just check presence), or ask how you'd structure auth middleware to attach `req.user` for downstream handlers.

---

## Exercise 3: NestJS Shared State / Injection Scope Bug

```typescript
@Injectable()
export class CacheService {
  private cache = {};

  set(key: string, value: any) {
    this.cache[key] = value;
  }

  get(key: string) {
    return this.cache[key];
  }
}
```

**Bug:** By default, NestJS providers are **singletons** (`Scope.DEFAULT`) — one instance is shared across the entire application, across all requests and all users. If this service is used to store per-request or per-user data (instead of true shared/global cache), data from one user's request can leak into another's.

**Fix:** Depends on intent:
- If it's meant to be a true **shared cache** (e.g., product data), the singleton is correct — the bug is elsewhere, likely in how keys are generated (e.g., not namespacing by user).
- If it's meant to hold **per-request data**, use `Scope.REQUEST`:

```typescript
@Injectable({ scope: Scope.REQUEST })
export class CacheService { ... }
```

**Interviewer follow-up:** Expect a question on the trade-off — `Scope.REQUEST` creates a new instance per request, which has performance overhead. They may ask when you'd actually want that vs a singleton with proper key namespacing.

---

## Exercise 4: SQL — Missing Rows in JOIN

```sql
SELECT users.name, COUNT(orders.id) as order_count
FROM users
JOIN orders ON users.id = orders.user_id
GROUP BY users.name;
```

**Bug:** This uses an `INNER JOIN` (implicit with `JOIN`), which only returns rows where a match exists in both tables. Users with **zero orders** get excluded entirely because there's no matching row in `orders`.

**Fix:** Use a `LEFT JOIN` so all users are kept, and `COUNT` will correctly return 0 for users with no orders:

```sql
SELECT users.name, COUNT(orders.id) as order_count
FROM users
LEFT JOIN orders ON users.id = orders.user_id
GROUP BY users.name;
```

**Interviewer follow-up:** They may ask why `COUNT(orders.id)` (not `COUNT(*)`) matters here — `COUNT(*)` would count 1 even for unmatched rows in some edge cases, while `COUNT(column)` correctly ignores NULLs from the LEFT JOIN.

---

## Exercise 5: Redis Stale Cache Bug

```javascript
async function getProduct(productId) {
  const cached = await redis.get(`product:${productId}`);
  if (cached) {
    return JSON.parse(cached);
  }

  const product = await db.getProduct(productId);
  await redis.set(`product:${productId}`, JSON.stringify(product));
  return product;
}
```

**Bug:** There's no expiration (TTL) on the cached key, and no cache invalidation when the product is updated (e.g., price change). Once cached, the data stays stale indefinitely until the key is manually cleared or the server restarts.

**Fix:** Add a TTL, and/or actively invalidate the cache on update:

```javascript
await redis.set(`product:${productId}`, JSON.stringify(product), 'EX', 3600); // 1 hour TTL
```

And in the update function:

```javascript
async function updateProduct(productId, data) {
  await db.updateProduct(productId, data);
  await redis.del(`product:${productId}`); // invalidate on write
}
```

**Interviewer follow-up:** Expect questions on cache invalidation strategies (write-through, write-behind, cache-aside) and how you'd handle a "thundering herd" problem if many requests hit a cold cache at once.

---

## Exercise 6: RabbitMQ — Duplicate Processing / Lost Messages

```javascript
channel.consume(queue, async (msg) => {
  const data = JSON.parse(msg.content.toString());
  await processOrder(data);
  channel.ack(msg);
});
```

**Bug:** Two separate issues:
1. **Duplicate processing:** If `processOrder` succeeds but the process crashes *before* `channel.ack(msg)` runs, RabbitMQ will redeliver the message once the consumer reconnects — reprocessing an already-completed order.
2. **Lost messages:** If there's no error handling and `processOrder` throws, the message is never acked or nacked properly — depending on config it could be silently dropped instead of requeued.

**Fix:** Make `processOrder` idempotent (e.g., check if the order was already processed using an order ID/idempotency key), and explicitly handle failures:

```javascript
channel.consume(queue, async (msg) => {
  const data = JSON.parse(msg.content.toString());
  try {
    const alreadyProcessed = await checkIdempotency(data.orderId);
    if (!alreadyProcessed) {
      await processOrder(data);
      await markProcessed(data.orderId);
    }
    channel.ack(msg);
  } catch (err) {
    channel.nack(msg, false, true); // requeue on failure
  }
});
```

**Interviewer follow-up:** They may ask about "at-least-once" vs "exactly-once" delivery guarantees, and why exactly-once is very hard to achieve in distributed systems (idempotency is usually the practical answer).

---

## Exercise 7: Debugging a Slow API Endpoint (Verbal/Process Question)

**Scenario:** *"This API endpoint used to respond in ~50ms, now it's taking 3-4 seconds. You have access to logs, the database, and the code. Walk me through how you'd debug this."*

**Strong answer structure:**

1. **Reproduce and isolate:** Confirm it's consistently slow (not a one-off spike). Check if it's slow for all requests or only certain inputs/users.
2. **Check recent changes:** Was there a recent deploy, migration, or config change around when the slowdown started? Check git history / deployment logs.
3. **Check the database first** (most common culprit):
   - Run `EXPLAIN ANALYZE` on the query used by this endpoint
   - Look for missing indexes, sequential scans, or a query that used to be indexed but now isn't (e.g., after a migration)
   - Check if table size grew significantly (a query that was fine at 10k rows can be terrible at 10M)
4. **Check for N+1 query problems:** A common regression — code that used to do 1 query now does 1 query per item in a loop.
5. **Check external dependencies:** Is this endpoint calling another service, third-party API, or doing a Redis/cache lookup that's now failing or timing out (falling through to a slow path)?
6. **Check infrastructure:** CPU/memory on the server, connection pool exhaustion, too many concurrent DB connections queuing.
7. **Add timing/instrumentation:** If not obvious, add logging around each step (DB call, external call, processing) to see exactly where the time is going.
8. **Form a hypothesis, test it, narrow down** — don't guess randomly; use logs and data to rule things in/out systematically.

**Interviewer follow-up:** They're mainly evaluating your *process*, not whether you land on the exact right answer. Structured, methodical thinking (isolate → hypothesize → verify) scores much higher than jumping straight to "maybe it's the database."

---

## Exercise 8: Off-by-One / Array Logic Bug

```javascript
function getLastNItems(arr, n) {
  return arr.slice(arr.length - n, arr.length - 1);
}
```

**Bug:** `slice`'s end index is exclusive, so `arr.length - 1` cuts off the actual last element. For `[1,2,3,4,5]` and `n=3`, this returns `[3,4]` instead of `[3,4,5]`.

**Fix:**

```javascript
function getLastNItems(arr, n) {
  return arr.slice(arr.length - n);
}
```

(Omitting the end index automatically goes to the end of the array — simpler and correct.)

**Interviewer follow-up:** They may ask what happens if `n > arr.length` (answer: `slice` handles it gracefully and just returns the whole array, no error) — good to know so you don't over-engineer a fix.

---

## Exercise 9: Memory Leak from Uncleaned Event Listeners

```javascript
const listeners = [];

function subscribeToUpdates(socket) {
  const handler = (data) => socket.emit('update', data);
  eventEmitter.on('dataChanged', handler);
  listeners.push(handler);
}
```

**Bug:** Every time a user connects, a new listener is added to `eventEmitter`, but there's no corresponding cleanup when the user disconnects. Listeners (and their closures, including the `socket` reference) stay in memory forever, even for long-disconnected sockets. Over days, this accumulates and leaks memory — and can also cause `emit` to try sending data to dead sockets.

**Fix:** Remove the listener on disconnect:

```javascript
function subscribeToUpdates(socket) {
  const handler = (data) => socket.emit('update', data);
  eventEmitter.on('dataChanged', handler);

  socket.on('disconnect', () => {
    eventEmitter.off('dataChanged', handler);
  });
}
```

**Interviewer follow-up:** They may ask how you'd *detect* this in production (heap snapshots, monitoring memory over time, Node's `--inspect` + Chrome DevTools memory profiler) — good to have a one-line answer ready.

---

## Exercise 10: Race Condition in Stock Reservation

```typescript
@Injectable()
export class InventoryService {
  async reserveStock(productId: string, quantity: number) {
    const product = await this.productRepo.findOne(productId);
    if (product.stock < quantity) {
      throw new Error('Insufficient stock');
    }
    product.stock -= quantity;
    await this.productRepo.save(product);
  }
}
```

**Bug:** Classic **check-then-act race condition**. Between `findOne` (read) and `save` (write), multiple concurrent requests can all read the same stock value before any of them writes the update. Each thinks stock is sufficient and proceeds, so stock can go negative under concurrent load.

**Fix:** Options, from simplest to most robust:

1. **Database-level atomic update** (best for most cases):
```sql
UPDATE products SET stock = stock - :quantity 
WHERE id = :productId AND stock >= :quantity;
```
Then check the affected row count — if 0 rows updated, stock was insufficient.

2. **Pessimistic locking** (`SELECT ... FOR UPDATE`) to lock the row during the transaction.

3. **Optimistic locking** using a version column, retrying on conflict.

**Interviewer follow-up:** They'll likely ask you to compare pessimistic vs optimistic locking — pessimistic is simpler but hurts throughput under high concurrency; optimistic scales better but requires handling retries in application code.

---

## General Tips for the Interview

- **Talk through your reasoning out loud**, even when unsure — the process matters as much as the answer.
- **Ask clarifying questions** before diving into code (expected input size? concurrency? is this read-heavy or write-heavy?).
- **State assumptions explicitly** if the problem is ambiguous.
- For debugging questions, follow a clear process: **reproduce → isolate → hypothesize → verify → fix**.
- It's fine to say "I'd check the logs first" or "let me think through this step by step" — interviewers want to see structured thinking, not instant recall.
