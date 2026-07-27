# Backend Debugging & Problem-Solving Practice — Part 2
### Exercises 11–34 with Solutions

*(Companion to `backend_debugging_practice.md`, which covers Exercises 1–10)*

---

## Exercise 11: Missing Error Handling in Express Route

```javascript
app.get('/user/:id', async (req, res) => {
  const user = await db.getUser(req.params.id);
  res.json(user);
});
```

**Bug:** If `db.getUser` throws (e.g., DB connection drops), there's no try/catch. In modern Express (4.x), an unhandled rejection in an async route handler either crashes the process or hangs the request (Express doesn't natively catch async errors pre-v5).

**Fix (per-route):**
```javascript
app.get('/user/:id', async (req, res, next) => {
  try {
    const user = await db.getUser(req.params.id);
    res.json(user);
  } catch (err) {
    next(err);
  }
});
```

**Better fix (app-wide):** Wrap all async routes with a helper, and add a global error-handling middleware:
```javascript
const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

app.get('/user/:id', asyncHandler(async (req, res) => {
  const user = await db.getUser(req.params.id);
  res.json(user);
}));

// Global error handler (must be last, with 4 args)
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});
```

**Follow-up:** They may ask about Express 5 (which handles async errors natively) or how you'd log/monitor these errors in production (e.g., Sentry).

---

## Exercise 12: NestJS Circular Dependency

```typescript
@Injectable()
export class UsersService {
  constructor(private ordersService: OrdersService) {}
}

@Injectable()
export class OrdersService {
  constructor(private usersService: UsersService) {}
}
```

**Bug:** Both services depend on each other directly through constructor injection, creating a circular dependency that NestJS's DI container can't resolve at startup.

**Fix 1 — Forward reference:**
```typescript
constructor(@Inject(forwardRef(() => OrdersService)) private ordersService: OrdersService) {}
```
(applied on both sides, plus `forwardRef(() => UsersModule)` in the module imports)

**Fix 2 — Refactor to remove the cycle (usually the better fix):** Extract the shared logic both services need into a third service, or use an event-driven approach (emit an event instead of directly calling the other service) so neither depends on the other directly.

**Follow-up:** Interviewers often want to hear that `forwardRef` is a workaround, and that a circular dependency is frequently a sign of a design/architecture issue worth revisiting.

---

## Exercise 13: N+1 Query Problem

```javascript
async function getUsersWithOrders() {
  const users = await db.query('SELECT * FROM users');
  for (const user of users) {
    user.orders = await db.query('SELECT * FROM orders WHERE user_id = ?', [user.id]);
  }
  return users;
}
```

**Bug:** This runs 1 query for users + 1 query per user for orders = N+1 total queries. With 1,000 users, that's 1,001 round trips to the database.

**Fix — single query with JOIN, then group in application code:**
```javascript
async function getUsersWithOrders() {
  const rows = await db.query(`
    SELECT users.*, orders.id as order_id, orders.total
    FROM users
    LEFT JOIN orders ON users.id = orders.user_id
  `);

  const usersMap = {};
  for (const row of rows) {
    if (!usersMap[row.id]) {
      usersMap[row.id] = { ...row, orders: [] };
    }
    if (row.order_id) {
      usersMap[row.id].orders.push({ id: row.order_id, total: row.total });
    }
  }
  return Object.values(usersMap);
}
```

**Alternative fix:** Use `WHERE user_id IN (...)` with all user IDs collected first, then group results — one query total instead of N+1, without a JOIN's row duplication.

**Follow-up:** Expect a question about ORMs (TypeORM/Prisma) and how they help avoid N+1 via eager loading / `relations` — and how those same ORMs can *hide* N+1 bugs if used carelessly (lazy loading in a loop).

---

## Exercise 14: Distributed Lock Bugs (Redis + Payment)

```javascript
async function processPayment(orderId) {
  const isProcessing = await redis.get(`lock:${orderId}`);
  if (isProcessing) return;

  await redis.set(`lock:${orderId}`, 'true');
  await chargeCustomer(orderId);
  await redis.del(`lock:${orderId}`);
}
```

**Bug 1 — Race condition on the lock itself:** The `get` then `set` is not atomic. Two concurrent calls can both read `null` for the lock before either sets it, so both proceed to charge the customer.

**Bug 2 — No TTL / no cleanup on failure:** If `chargeCustomer` throws, `redis.del` never runs, and the lock stays forever, blocking all future legitimate attempts (a different but related bug).

**Fix:**
```javascript
async function processPayment(orderId) {
  const acquired = await redis.set(`lock:${orderId}`, 'true', 'NX', 'EX', 30); // atomic set-if-not-exists with TTL
  if (!acquired) return;

  try {
    await chargeCustomer(orderId);
  } finally {
    await redis.del(`lock:${orderId}`);
  }
}
```
`SET key value NX EX seconds` is atomic — it only sets the key if it doesn't already exist, eliminating the race condition, and the TTL ensures the lock self-expires if something crashes.

**Follow-up:** They may ask about the Redlock algorithm for distributed locking across multiple Redis nodes, or why idempotency keys at the payment-gateway level are a more robust safety net than locking alone.

---

## Exercise 15: Missing Input Validation in NestJS

```typescript
@Post()
createUser(@Body() body: any) {
  return this.usersService.create(body);
}
```

**Bug:** `body: any` means no validation happens at all — literally anything can be sent and will reach the service/database layer, causing bad data or runtime type errors deep in the call stack (far from where the actual problem originated).

**Fix — the "NestJS way" using DTOs + class-validator:**
```typescript
export class CreateUserDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsEmail()
  email: string;

  @IsInt()
  @Min(0)
  age: number;
}

@Post()
createUser(@Body() body: CreateUserDto) {
  return this.usersService.create(body);
}
```
Plus enabling a global validation pipe in `main.ts`:
```typescript
app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }));
```

**Follow-up:** They may ask what `whitelist: true` does (strips unknown properties) and why validating at the edge (controller) is better than validating deep in the service — fail fast, with a clear 400 error instead of a confusing 500 later.

---

## Exercise 16: Duplicate Charge — Production Incident (Verbal)

**Scenario:** *"A customer reports they were charged twice. Logs show `processPayment` was only called once. How do you investigate?"*

**Strong answer structure:**
1. **Verify the claim first** — check the payment gateway's dashboard/logs directly, not just your own logs. Sometimes "only called once" in your logs is wrong if logging itself is incomplete or a retry happened at a layer you're not logging.
2. **Check the payment gateway side for retries** — many gateways (Stripe, etc.) retry on timeout. If your server called the charge API, didn't get a response in time (e.g., due to a network blip), and retried without an idempotency key, the gateway could process it twice even though your app logs show one call.
3. **Check for idempotency keys** — was one used on the charge request? If not, that's likely the root cause.
4. **Check RabbitMQ for message redelivery** — if `processPayment` is triggered by a queue consumer, check if the message was acked properly. A crash after charging but before acking would cause redelivery and a second charge — even though "processPayment was called once" per a single log line, it may have been invoked twice across two separate consumer instances/restarts.
5. **Check for double webhook handling** — if the payment gateway sends a webhook to confirm the charge, and that webhook itself triggers another charge somewhere (bug in webhook handler), that's another candidate.
6. **Reproduce methodically** — check timestamps of both charges, look for any gap that suggests a timeout/retry pattern.

**Follow-up:** They're testing whether you think about **distributed system failure modes** (network partitions, retries, at-least-once delivery) rather than just assuming it's "a bug in the function" — and whether idempotency is your instinct as the fix.

---

## Exercise 17: Closure Bug in a Loop (`var` vs `let`)

```javascript
function createHandlers() {
  const handlers = [];
  for (var i = 0; i < 3; i++) {
    handlers.push(() => console.log(i));
  }
  return handlers;
}
```

**Answer:** All three handlers log `3`, not `0, 1, 2`. `var` is function-scoped, not block-scoped, so there's only **one** `i` shared by all three closures. By the time the handlers run, the loop has finished and `i` is `3`.

**Fix:** Use `let` instead of `var` — `let` is block-scoped, so each iteration gets its own `i`:
```javascript
for (let i = 0; i < 3; i++) {
  handlers.push(() => console.log(i));
}
```

**Follow-up:** They may ask you to explain *why* `let` works without using it — i.e., explain that each loop iteration with `let` creates a new binding, which is a common "explain the mechanism, not just the fix" follow-up.

---

## Exercise 18: `this` Binding Bug

```javascript
class Counter {
  constructor() { this.count = 0; }
  increment() { this.count++; }
}

const counter = new Counter();
const btn = { onClick: counter.increment };
btn.onClick();
```

**Answer:** This throws `TypeError: Cannot read properties of undefined` (or increments `undefined.count`) because `counter.increment` is passed as a plain function reference — it loses its binding to `counter`. When called as `btn.onClick()`, `this` inside `increment` refers to `btn`, not `counter`, and `btn.count` doesn't exist as expected (or `this` is `undefined` in strict mode/class methods).

**Fix 1 — Bind explicitly:**
```javascript
const btn = { onClick: counter.increment.bind(counter) };
```

**Fix 2 — Arrow function class field (auto-binds `this`):**
```javascript
class Counter {
  count = 0;
  increment = () => { this.count++; };
}
```

**Follow-up:** They may ask you to explain the four ways `this` gets determined in JS (default, implicit, explicit, `new` binding) — good to have a quick mental model ready.

---

## Exercise 19: Equality / Type Coercion Trap

```javascript
function isEmpty(value) {
  return value == null || value == '';
}
```

**Answer:**
- `isEmpty(0)` → `false` (0 is not "empty" by this check — but is that actually correct depends on intent)
- `isEmpty(false)` → `false`
- `isEmpty(undefined)` → `true` (because `undefined == null` is `true`)

**The real issue:** The function's name implies checking for "no meaningful value," but `0` and `false` might reasonably be considered "empty" in some contexts (e.g., an empty form field) and not others (e.g., a valid zero quantity). The bug here isn't necessarily wrong code — it's **ambiguous intent** hiding behind loose equality.

**Better, explicit version:**
```javascript
function isEmpty(value) {
  return value === null || value === undefined || value === '';
}
```

**Follow-up:** This is a great one to discuss the general principle: prefer `===` over `==` unless you have a specific, well-understood reason to rely on coercion (like the `null`/`undefined` shortcut, which is one of the few places `==` is arguably idiomatic).

---

## Exercise 20: Shallow Copy Bug

```javascript
function updateUser(user, updates) {
  return Object.assign({}, user, updates);
}

const user = { name: 'Ahmed', address: { city: 'Cairo' } };
const updated = updateUser(user, { address: { city: 'Giza' } });

console.log(user.address.city); // 'Cairo' — unaffected here, since 'address' was fully replaced
```

**First case:** `user.address.city` stays `'Cairo'` because `updates.address` completely replaces `user.address` at the top level — `Object.assign` does a shallow merge, but since `address` was fully overwritten (not deep-merged), the original object isn't touched here.

**Trickier case:** `updateUser(user, {})` then `updated.address.city = 'Alex'` — **this DOES affect `user.address.city`**, because `Object.assign` only copies top-level properties. `updated.address` and `user.address` still point to the **same nested object** in memory. Mutating one mutates both.

**Fix — deep clone when nested objects need independence:**
```javascript
const updatedUser = structuredClone(user); // modern, built-in deep clone
// or: JSON.parse(JSON.stringify(user)) — works but loses functions/dates/undefined
```

**Follow-up:** Expect a question on when `structuredClone` isn't sufficient (e.g., objects with functions, class instances, circular references) and libraries like `lodash.cloneDeep` as an alternative.

---

## Exercise 21: Promise Error Swallowing / Unhelpful Catch

```javascript
async function fetchData() {
  try {
    const data = await fetch('/api/data').then(res => res.json());
    processData(data);
  } catch (err) {
    console.log('Error occurred');
  }
}
```

**Bug:** If `data` is `null` (empty response body), `processData` throws (`Cannot read properties of null`) — and it **is** caught by the catch block, since it's inside the `try`. But the catch swallows the actual error message (`console.log('Error occurred')` instead of logging `err`), making it impossible to debug what actually went wrong from the logs.

**Fix:**
```javascript
async function fetchData() {
  try {
    const response = await fetch('/api/data');
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    if (!data) throw new Error('Empty response body');
    return processData(data);
  } catch (err) {
    console.error('fetchData failed:', err.message, err.stack);
    throw err; // or handle gracefully depending on context
  }
}
```

**Follow-up:** A big theme interviewers look for: **never swallow errors silently**. Always log enough detail (or re-throw) so the failure is traceable in production.

---

## Exercise 22: Debounce Argument Bug

```javascript
function debounce(fn, delay) {
  let timer;
  return function (...args) {
    clearTimeout(timer);
    timer = setTimeout(() => fn(args), delay);
  };
}
```

**Bug:** `fn(args)` calls `fn` with a single argument — the **array** of arguments — instead of spreading them as individual arguments. If the debounced function is called like `debouncedFn('a', 'b')`, the wrapped `fn` will receive `(['a', 'b'])` instead of `('a', 'b')`.

**Fix:**
```javascript
timer = setTimeout(() => fn(...args), delay);
```

**Follow-up:** They may ask you to also preserve `this` context using `.apply()` if the function relies on it, or to implement `throttle` alongside `debounce` and explain the difference (debounce waits for a pause; throttle limits to once per interval).

---

## Exercise 23: Event Loop Ordering (Microtasks vs Macrotasks)

```javascript
console.log('1');
setTimeout(() => console.log('2'), 0);
Promise.resolve().then(() => console.log('3'));
console.log('4');
```

**Answer — prints: `1, 4, 3, 2`**

**Why:**
1. `console.log('1')` runs synchronously — prints immediately.
2. `setTimeout(..., 0)` schedules a **macrotask** — it goes to the timer queue, not run immediately even with 0ms delay.
3. `Promise.resolve().then(...)` schedules a **microtask**.
4. `console.log('4')` runs synchronously — prints next.
5. After the synchronous code finishes, the event loop drains **all microtasks** before moving to the next macrotask — so the Promise's `.then` (`'3'`) runs before the `setTimeout` callback (`'2'`).

**Follow-up:** A very common deeper question: "What if there were two `.then()` chains and one `setTimeout`?" — make sure you understand that ALL pending microtasks (including ones queued by other microtasks) run before the next macrotask, not just one.

---

## Exercise 24: Array Mutation During Iteration

```javascript
function removeCompleted(tasks) {
  for (let i = 0; i < tasks.length; i++) {
    if (tasks[i].completed) {
      tasks.splice(i, 1);
    }
  }
  return tasks;
}
```

**Bug:** `splice` mutates the array in place, shifting all subsequent elements down by one index. But the loop's `i` keeps incrementing regardless — so after removing an element, the *next* element shifts into the current index and gets **skipped** (the loop moves past it).

Given `[{completed:true}, {completed:true}, {completed:false}]`: at `i=0` the first is removed, the second shifts to index 0, but the loop moves to `i=1`, skipping it entirely — it survives even though it should have been removed.

**Fix 1 — iterate backwards:**
```javascript
for (let i = tasks.length - 1; i >= 0; i--) {
  if (tasks[i].completed) tasks.splice(i, 1);
}
```

**Fix 2 — simpler and more idiomatic, use `filter` (no mutation):**
```javascript
function removeCompleted(tasks) {
  return tasks.filter(task => !task.completed);
}
```

**Follow-up:** Interviewers often want you to default to non-mutating approaches (`filter`, `map`) when possible — it's both safer and easier to reason about.

---

## Exercise 25: Default Parameter Trap

```javascript
function addItem(item, list = []) {
  list.push(item);
  return list;
}

console.log(addItem('a')); // ['a']
console.log(addItem('b')); // ['b']  — NOT ['a', 'b']
```

**Answer:** In JavaScript, a default parameter like `list = []` is evaluated **fresh on every call** — it is NOT shared across invocations (unlike, say, Python's classic "mutable default argument" gotcha). So each call gets a brand-new empty array; the output is `['a']` then `['b']`, not cumulative.

**Where it WOULD break:** If instead you wrote:
```javascript
const sharedList = [];
function addItem(item, list = sharedList) {
  list.push(item);
  return list;
}
```
Now every call without an explicit `list` argument mutates the **same** module-level array, and results accumulate unexpectedly across calls — a real bug if `sharedList` was meant to be a "safe default" rather than genuinely shared state.

**Follow-up:** Good opportunity to mention this is a common gotcha ported over incorrectly from other languages (Python devs especially expect JS defaults to behave like Python's, which they don't).

---

## Exercise 26: Object Key Type Coercion

```javascript
const cache = {};
cache[1] = 'first';
cache['1'] = 'second';

console.log(cache[1]);              // 'second'
console.log(Object.keys(cache).length); // 1
```

**Answer:** Plain JS object keys are always coerced to **strings**. `cache[1]` and `cache['1']` refer to the exact same key (`"1"`), so the second write overwrites the first. Only one key exists.

**Why this matters in real systems:** If IDs sometimes arrive as numbers (e.g., from a database driver) and sometimes as strings (e.g., from Express route params like `req.params.id`, which are always strings), a caching layer keyed naively by ID can silently create **duplicate-looking-but-actually-colliding** entries, or worse, overwrite valid cached data with data for a "different" key that's actually the same key in disguise.

**Fix:** Always normalize the key type before using it (`String(id)` consistently), or use a `Map` if you specifically need non-string keys (a `Map` preserves key type: `1` and `'1'` are distinct keys in a `Map`).

**Follow-up:** Good moment to mention `Map` vs plain object trade-offs — `Map` preserves key types and insertion order, has a real `.size`, and doesn't have prototype pollution risk.

---

## Exercise 27: Async Error Not Caught by try/catch

```javascript
function processItems(items) {
  try {
    items.forEach(item => {
      setTimeout(() => {
        if (!item.valid) throw new Error('Invalid item');
        console.log('processed', item.id);
      }, 100);
    });
  } catch (err) {
    console.log('Caught:', err.message);
  }
}
```

**Answer:** No, the `catch` block does **not** catch this error. `setTimeout`'s callback runs **asynchronously**, after the synchronous `try` block has already finished executing (and the try/catch's stack frame is long gone). When the timeout fires and throws, there's no enclosing try/catch anymore — it becomes an **uncaught exception**, which in Node.js will crash the process (or trigger an `uncaughtException` event) rather than being caught here.

**Fix:** Put the try/catch **inside** the callback that actually runs the risky code:
```javascript
items.forEach(item => {
  setTimeout(() => {
    try {
      if (!item.valid) throw new Error('Invalid item');
      console.log('processed', item.id);
    } catch (err) {
      console.log('Caught:', err.message);
    }
  }, 100);
});
```

**Follow-up:** This is a great one for testing whether you truly understand that try/catch only catches errors thrown **synchronously within its own execution context** — a very common real-world source of "silent" production crashes.

---

## Exercise 28: Array `sort` Default Comparator Bug

```javascript
const scores = [10, 2, 33, 4];
scores.sort();
console.log(scores); // [10, 2, 33, 4] → prints [10, 2, 33, 4]... actually [10, 2, 33, 4]
```

**Answer:** Prints `[10, 2, 33, 4]` sorted as `[10, 2, 33, 4]` → actually the real output is `[10, 2, 33, 4]` sorted lexicographically as strings: `[10, 2, 33, 4]` becomes **`[10, 2, 33, 4]` → `[10, 2, 33, 4]`**. Let me be precise: default `.sort()` converts elements to strings and compares them lexicographically (UTF-16 code unit order). So `[10, 2, 33, 4]` sorts as strings `"10", "2", "33", "4"` → alphabetical order is `"10" < "2" < "33" < "4"` → result: **`[10, 2, 33, 4]`**.

**Fix — always provide a numeric comparator:**
```javascript
scores.sort((a, b) => a - b); // ascending: [2, 4, 10, 33]
```

**Follow-up:** They may ask you to sort objects by a property (e.g., `users.sort((a,b) => a.age - b.age)`) or handle descending order — make sure the comparator pattern is second nature.

---

## Exercise 29: WHERE Clause on Aggregate (Should Be HAVING)

```sql
SELECT department, AVG(salary) as avg_salary
FROM employees
WHERE AVG(salary) > 50000
GROUP BY department;
```

**Bug:** `WHERE` filters rows **before** grouping/aggregation happens, so it can't reference an aggregate function like `AVG()` — that value doesn't exist yet at the point `WHERE` is evaluated. This throws a SQL error.

**Fix — use `HAVING`, which filters after aggregation:**
```sql
SELECT department, AVG(salary) as avg_salary
FROM employees
GROUP BY department
HAVING AVG(salary) > 50000;
```

**Follow-up:** Good to know the conceptual SQL execution order: `FROM` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `ORDER BY`. `WHERE` filters raw rows; `HAVING` filters aggregated groups.

---

## Exercise 30: NULL Comparison Trap

```sql
SELECT * FROM users WHERE deleted_at != NULL;
```

**Bug:** In SQL, `NULL` represents "unknown," so any comparison to `NULL` using `=` or `!=` returns `NULL` (neither true nor false) — never matches any row, so the query always returns zero rows.

**Fix — use `IS NOT NULL`:**
```sql
SELECT * FROM users WHERE deleted_at IS NOT NULL;
-- or, for "non-deleted" users:
SELECT * FROM users WHERE deleted_at IS NULL;
```

**Follow-up:** A common trick question: "What does `NULL = NULL` return?" — answer: `NULL`, not `true`. Worth knowing `IS DISTINCT FROM` (Postgres) as a null-safe equality operator too.

---

## Exercise 31: Duplicate Rows Inflating a SUM (Fan-out JOIN)

```sql
SELECT users.name, SUM(orders.total) as total_spent
FROM users
JOIN orders ON users.id = orders.user_id
JOIN order_items ON orders.id = order_items.order_id
GROUP BY users.name;
```

**Bug:** Joining `orders` to `order_items` creates one row **per item**, not per order. If an order has 3 items, `orders.total` gets duplicated across all 3 resulting rows, and `SUM(orders.total)` triple-counts that order's total — a classic "fan-out" bug from joining a one-to-many relationship into an aggregate on the "one" side.

**Fix — aggregate order_items separately first, or don't join it at all if unnecessary:**
```sql
SELECT users.name, SUM(orders.total) as total_spent
FROM users
JOIN orders ON users.id = orders.user_id
GROUP BY users.name;
```
If you *do* need item-level data too, use a subquery or a separate aggregation to avoid the fan-out:
```sql
SELECT u.name, SUM(DISTINCT_order_totals.total) as total_spent
FROM users u
JOIN (SELECT DISTINCT id, user_id, total FROM orders) as DISTINCT_order_totals 
  ON u.id = DISTINCT_order_totals.user_id
GROUP BY u.name;
```

**Follow-up:** This is a very common real-world bug. Interviewers love it because it looks correct at a glance — they'll want to hear you explain *why* the row count changed due to the join, not just that the number is wrong.

---

## Exercise 32: Subquery vs JOIN Performance

```sql
SELECT * FROM products
WHERE id IN (SELECT product_id FROM order_items WHERE order_id = 12345);
```

**Why it can be slow:** Depending on the SQL engine and query planner, an `IN` subquery can sometimes be executed inefficiently (e.g., as a correlated subquery re-evaluated per row, rather than a single materialized set) — though modern optimizers (Postgres, MySQL 8+) often handle this fine. Still, it's a common interview point to know the alternatives.

**Alternative 1 — JOIN:**
```sql
SELECT DISTINCT products.*
FROM products
JOIN order_items ON products.id = order_items.product_id
WHERE order_items.order_id = 12345;
```

**Alternative 2 — EXISTS (often faster for existence checks, avoids full materialization):**
```sql
SELECT * FROM products p
WHERE EXISTS (
  SELECT 1 FROM order_items oi
  WHERE oi.product_id = p.id AND oi.order_id = 12345
);
```

**Follow-up:** They may ask you to run `EXPLAIN ANALYZE` on all three versions and compare — a good habit to mention even if you can't run it live: "I'd check the query plan to see if it's doing a seq scan vs index scan before assuming which is faster."

---

## Exercise 33: Function on Indexed Column Breaks Index Usage

```sql
SELECT * FROM orders WHERE YEAR(created_at) = 2026;
```

**Bug:** Wrapping an indexed column in a function (`YEAR(created_at)`) means the database can't use the index directly — it has to compute `YEAR()` for **every row** in the table before it can compare, forcing a full table scan even though `created_at` is indexed.

**Fix — rewrite as a range condition on the raw column:**
```sql
SELECT * FROM orders 
WHERE created_at >= '2026-01-01' AND created_at < '2027-01-01';
```
This lets the database use the index on `created_at` directly via a range scan.

**Follow-up:** This is a very common real "gotcha" — expect a follow-up like "what other patterns break index usage?" (Answer: leading wildcard `LIKE '%abc'`, implicit type casts, `OR` across different columns without a composite index, functions/expressions on the indexed column in general.)

---

## Exercise 34: Missing Transaction + Isolation Level

```javascript
async function transferFunds(fromId, toId, amount) {
  const from = await db.query('SELECT balance FROM accounts WHERE id = ?', [fromId]);
  const to = await db.query('SELECT balance FROM accounts WHERE id = ?', [toId]);

  if (from.balance < amount) throw new Error('Insufficient funds');

  await db.query('UPDATE accounts SET balance = ? WHERE id = ?', [from.balance - amount, fromId]);
  await db.query('UPDATE accounts SET balance = ? WHERE id = ?', [to.balance + amount, toId]);
}
```

**Bug 1 — No transaction, crash risk:** If the process crashes after the first `UPDATE` but before the second, money disappears from one account without appearing in the other — the operation isn't atomic.

**Bug 2 — Concurrency risk even with a transaction:** If two transfers involving the same account happen concurrently, both could read the same starting `balance` before either writes (a read-then-write race, same pattern as the stock example in Exercise 10) — resulting in an incorrect final balance, depending on the isolation level used.

**Fix — wrap in a transaction, and use atomic updates instead of read-then-write where possible:**
```javascript
async function transferFunds(fromId, toId, amount) {
  await db.transaction(async (trx) => {
    const [updatedRows] = await trx.query(
      'UPDATE accounts SET balance = balance - ? WHERE id = ? AND balance >= ?',
      [amount, fromId, amount]
    );
    if (updatedRows === 0) throw new Error('Insufficient funds');

    await trx.query('UPDATE accounts SET balance = balance + ? WHERE id = ?', [amount, toId]);
  });
}
```
Using `balance = balance - ?` (atomic, computed by the DB) instead of reading the value in application code and writing it back avoids the race condition entirely, and wrapping both updates in a transaction ensures atomicity if a crash occurs mid-operation.

**Follow-up:** Expect questions on isolation levels (Read Committed vs Repeatable Read vs Serializable) and the trade-off between correctness and throughput — Serializable is safest but can cause more contention/retries under load.

---

## Quick Reference — Concepts to Be Able to Explain in 1-2 Sentences

- Event loop: microtasks vs macrotasks
- `var` vs `let`/`const` scoping
- Shallow vs deep copy
- `this` binding rules (default, implicit, explicit, `new`)
- N+1 query problem and how to avoid it
- `WHERE` vs `HAVING`
- Why functions on indexed columns break index usage
- Atomic operations vs read-then-write races
- Idempotency in message queues and payment systems
- Cache invalidation strategies (TTL, write-through, cache-aside)
- NestJS provider scopes (`DEFAULT`/singleton vs `REQUEST`)
- Transactions and isolation levels
