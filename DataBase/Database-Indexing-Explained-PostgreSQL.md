# Database Indexing Explained (with PostgreSQL)

**Source:** [YouTube — Hussein Nasser](https://www.youtube.com/watch?v=-qNSXK7s7_w) · ~18 min · Science & Technology

Notes from the video: what indexes are, how they affect PostgreSQL query plans, and a demo on a large table.

---
### **1. What is an index?**

An **index** is a separate **data structure** built on top of a table. It does not replace the table; it gives the database a faster way to locate rows (shortcuts) instead of scanning the whole table for every query.

* **Analogy:** Like letter tabs in a phone book—you jump to “Z” to find “Zebra” instead of reading from the first page.

```sql
-- Selective lookup on an indexed key (cheap when a suitable index exists)
SELECT id, name FROM employees WHERE id = 2000;
```

---
### **2. Common index families (overview only)**

The video mentions **B-tree** and **LSM-tree** style structures as important categories. It does **not** go deep into internal construction; treat that as follow-up reading.

* **B-tree:** Very common in relational DBs (including PostgreSQL primary keys).

```sql
-- Default index method in PostgreSQL is btree
CREATE INDEX idx_employees_name ON employees USING btree (name);
```

* **LSM:** Common in other systems; different tradeoffs for writes vs reads.

```sql
-- Built-in index access methods in PostgreSQL (btree, hash, gist, …) — not LSM
SELECT amname FROM pg_am WHERE amhandler <> 0 ORDER BY amname;
```

---
### **3. Demo setup (PostgreSQL)**

* Table **`employees`**, on the order of **~11 million rows**.
* **`id`:** integer, sequential, **NOT NULL**, **primary key** → PostgreSQL creates a **B-tree index** on the primary key by default.
* **`name`:** text/varchar, **no index** (random strings for testing).

```sql
CREATE TABLE employees (
  id         integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  name       text NOT NULL
);
-- PK creates a unique btree index on id automatically.
-- No index on name unless you add one.
```

---
### **4. Measuring performance: `EXPLAIN ANALYZE`**

Use **`EXPLAIN ANALYZE`** before a query to see:

* The **execution plan** (e.g. index scan vs sequential scan).
* **Timing** and row estimates vs actuals.

Example pattern from the video: `SELECT * FROM employees WHERE id = 2000` uses the primary key index; similar filters on **`name`** without an index force a different (typically much more expensive) access path.

```sql
-- Usually: Index Scan / Index Only Scan on employees_pkey
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, name FROM employees WHERE id = 2000;

-- Often: Seq Scan on name if there is no index on name
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, name FROM employees WHERE name = 'some_exact_value';
```

---
### **5. Takeaway**

Indexes speed up **reads and selective lookups** on columns you filter or join on often. They cost **extra storage** and add work on **writes** (the index must stay consistent). The video contrasts **indexed `id`** vs **unindexed `name`** on the same large table to make that concrete.

```sql
-- Write path: every INSERT/UPDATE that touches indexed columns maintains indexes too
INSERT INTO employees (name) VALUES ('new row');
UPDATE employees SET name = name || ' (updated)' WHERE id = 2000;
```

---
### **6. `LIKE` patterns such as `'%zs%'`**

In SQL, **`%`** is a wildcard in **`LIKE`**: it matches any sequence of characters (including empty). So **`'%zs%'`** means: *any value that contains the substring **`zs`** anywhere*—for example `"...zs..."`, `"azsb"`, `"foo zs bar"`.

```sql
-- Substring match; plain btree on name rarely helps
SELECT id, name FROM employees WHERE name LIKE '%zs%';
```

**Why a normal B-tree index often does not help**

* A **B-tree** is great for equality (`=`) and ordered **range** bounds (e.g. `>= 'zs' AND < 'zt'`) or **prefix** style constraints.

```sql
-- Range on text (can use btree on name when indexed)
SELECT id, name FROM employees WHERE name >= 'zs' AND name < 'zt';

-- Prefix only after the literal (sometimes uses btree on name)
SELECT id, name FROM employees WHERE name LIKE 'zs%';
```

* With a **leading** wildcard (`'%zs%'`), there is **no fixed prefix** to anchor a range scan on the whole string. The engine usually cannot use a plain B-tree index to skip straight to matches; plans often fall back to **sequential scan** (or other scans that still touch many rows), especially on large tables—similar in spirit to “unindexed or not index-friendly.”

```sql
-- Leading % → typically no btree shortcut on plain name index
SELECT id, name FROM employees WHERE name LIKE '%zs%';
```

* With **only a trailing** wildcard (`'zs%'`), PostgreSQL can sometimes use a **B-tree** for a **prefix** search (depends on type, collation, and the exact plan).

```sql
SELECT id, name FROM employees WHERE name LIKE 'zs%';
```

**`ILIKE`** (case-insensitive `LIKE`) follows the same **wildcard / prefix** intuition for standard B-tree indexes: arbitrary **`%zs%`**-style patterns are still hard to accelerate with a plain btree.

```sql
SELECT id, name FROM employees WHERE name ILIKE '%zs%';
```

**When you really need fast “contains” queries in PostgreSQL**

* **`pg_trgm`** (trigram) indexes (**GIN** or **GiST**) on the text column — a common approach for `LIKE '%...%'`.

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_employees_name_trgm ON employees USING gin (name gin_trgm_ops);

SELECT id, name FROM employees WHERE name LIKE '%zs%';
```

* **Full-text search** (`tsvector` / `tsquery`) — when the need is **word- or token-based** search rather than arbitrary substrings.

```sql
ALTER TABLE employees ADD COLUMN name_tsv tsvector
  GENERATED ALWAYS AS (to_tsvector('english', name)) STORED;
CREATE INDEX idx_employees_name_tsv ON employees USING gin (name_tsv);

SELECT id, name FROM employees WHERE name_tsv @@ plainto_tsquery('english', 'zebra');
```

Always confirm with **`EXPLAIN (ANALYZE, BUFFERS)`** whether the plan uses an index scan you expect.

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, name FROM employees WHERE name LIKE '%zs%';
```

---
### **7. Other cases where an index often does not help (or is not chosen)**

These are common reasons a **B-tree** (or your existing index) may **not** appear in the plan, or may **not** speed up the query the way you expect.

* **Expression on the column** — If the predicate wraps the indexed column, the planner usually cannot use a plain index on the raw column. Example: `WHERE lower(name) = 'ann'` with an index only on `name`. Fix: match the expression in the index (**expression index** / **`CREATE INDEX ... ON t ((lower(name)))`**), or rewrite so the column is compared without a function on that side when possible.

```sql
-- Plain index on (name) does not satisfy lower(name)
SELECT id, name FROM employees WHERE lower(name) = 'ann';

-- Fix: index the same expression the query uses
CREATE INDEX idx_employees_lower_name ON employees ((lower(name)));
SELECT id, name FROM employees WHERE lower(name) = 'ann';
```

* **Composite index column order** — For **`CREATE INDEX ON t (a, b)`**, equality/range on **`a`** can use the index; a filter **only on `b`** generally does **not** use that index the way a single-column `b` index would (**left-prefix** rule).

```sql
CREATE TABLE orders (id int PRIMARY KEY, customer_id int, status text);
CREATE INDEX idx_orders_customer_status ON orders (customer_id, status);

-- Can use idx_orders_customer_status (leading column present)
SELECT * FROM orders WHERE customer_id = 42 AND status = 'open';

-- Often cannot use that composite index well for status alone
SELECT * FROM orders WHERE status = 'open';
```

* **Regex and rich pattern ops** — Operators like **`~`**, **`~*`**, **`SIMILAR TO`** are not ordinary B-tree equality/range; a btree on the text column usually does not make them cheap. Trigram (**`pg_trgm`**) or other specialized access paths may be needed.

```sql
SELECT id, name FROM employees WHERE name ~ '[0-9]{3}';
```

* **Low selectivity** — If the condition matches **a large fraction** of rows, a **sequential scan** plus filter can be cheaper than lots of random heap lookups via index. The planner may skip the index even when one exists.

```sql
-- Example: boolean / flag that is true for most rows — seq scan may win
SELECT * FROM employees WHERE is_active = true;
```

* **Very small tables** — Reading the whole heap in one pass can be cheaper than index bookkeeping; expect **seq scans** until the table grows.

```sql
SELECT * FROM employees WHERE id = 3;  -- on a tiny table, still often Index Scan,
                                       -- but very small heaps are cheap to seq scan too
```

* **Cross-column `OR`** — `WHERE a = 1 OR b = 2` often needs **two** index-friendly paths or degenerates to broader scans unless you rewrite (**`UNION`**, separate queries) or have a structure that fits the pattern.

```sql
SELECT * FROM orders WHERE customer_id = 1 OR status = 'shipped';

-- Sometimes clearer for the planner as two indexed probes + dedupe
SELECT * FROM orders WHERE customer_id = 1
UNION
SELECT * FROM orders WHERE status = 'shipped';
```

* **Type mismatch** — Comparing a column to a value that forces a **cast on the column side** (implicit or explicit) can block a simple index match until types align or you add an expression index on the casted form.

```sql
-- If code is text but you compare to integer, the column may be cast
SELECT * FROM orders WHERE customer_id::text = '42';

-- Prefer same type as the column so the index applies cleanly
SELECT * FROM orders WHERE customer_id = 42;
```

* **Operators / extensions** — JSON containment, arrays, ranges, full-text, geography, etc. need **appropriate** index types (**GIN**, **GiST**, **BRIN**, …), not only default btree.

```sql
CREATE TABLE docs (id int PRIMARY KEY, data jsonb);
CREATE INDEX idx_docs_data_gin ON docs USING gin (data);

SELECT * FROM docs WHERE data @> '{"role": "admin"}';
```

For any of the above, **`EXPLAIN (ANALYZE, BUFFERS)`** shows what PostgreSQL actually did; adjust the predicate, index definition, or statistics (**`ANALYZE`**) rather than assuming an index is always used.

```sql
ANALYZE employees;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, name FROM employees WHERE lower(name) = 'ann';
```

---
### **8. How to optimize a query (PostgreSQL workflow)**

Work **evidence-first**: see what the planner does, then change predicates, indexes, or statistics—not the other way around.

* **Inspect the real plan and cost** — Use **`EXPLAIN (ANALYZE, BUFFERS)`** (and optionally **`VERBOSE`**) on the slow query. Look for **Seq Scan** on large tables, **Nested Loop** with huge row counts, **high actual rows** vs estimates, and **heap fetches** you did not expect.

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT e.id, e.name
FROM employees e
JOIN orders o ON o.customer_id = e.id
WHERE e.name LIKE 'prefix%'
  AND o.status = 'open';
```

* **Align indexes with how you filter and join** — Add **btree** on equality/range/join keys; use **composite** indexes in **most-selective column first** order when you always filter on a leading prefix; use **`INCLUDE`** to cover extra columns and cut heap visits when it helps.

```sql
-- Composite for common filter shape; INCLUDE avoids extra heap hits for listed columns
CREATE INDEX idx_orders_cust_status_inc ON orders (customer_id, status)
  INCLUDE (created_at);

SELECT customer_id, status, created_at
FROM orders
WHERE customer_id = 42 AND status = 'open';
```

* **Make predicates “index-friendly”** — Compare columns to values **without** wrapping the column in functions; match **`LIKE`** patterns to indexes (**prefix** + btree, **substring** + **`pg_trgm`**); fix **types** so the column is not cast; rewrite **OR** into **`UNION`** when each branch can use its own index.

```sql
-- Before: not sargable
-- SELECT * FROM employees WHERE id + 0 = 2000;

-- After: sargable
SELECT * FROM employees WHERE id = 2000;
```

* **Keep planner statistics fresh** — After large loads or DDL, run **`ANALYZE`** on affected tables. For correlated filters, consider **extended statistics** so estimates improve.

```sql
ANALYZE employees;
ANALYZE orders;

CREATE STATISTICS IF NOT EXISTS st_orders_cust_status (dependencies)
  ON customer_id, status FROM orders;
ANALYZE orders;
```

* **Ship less data** — Select **only columns** you need (avoid **`SELECT *`** in hot paths); use **`LIMIT`** when the UI only needs a page; for deep pagination, prefer **keyset** (`WHERE id > $last ORDER BY id LIMIT 50`) over huge **`OFFSET`** when possible.

```sql
-- Keyset-style page (stable, index-friendly on id)
SELECT id, name FROM employees WHERE id > 100000 ORDER BY id LIMIT 50;
```

* **Support foreign keys and heavy joins** — Index the **referencing** side (**child** **`customer_id`**) so joins and deletes on the parent stay fast.

```sql
CREATE INDEX idx_orders_customer_id ON orders (customer_id);
```

* **Don’t fight the planner without proof** — Avoid turning off **`seq_scan`** or **`nestloop`** globally. If costs look wrong for your hardware, tune **`random_page_cost`** / **`effective_cache_size`** only after measuring I/O behavior.

* **Operational hygiene** — **Autovacuum** keeps visibility maps and statistics healthy; extreme bloat or stale stats shows up as slow scans and bad plans—check **`pg_stat_user_tables`**, **`last_analyze`**, **`n_dead_tup`**.

```sql
SELECT relname, last_analyze, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_dead_tup DESC
LIMIT 10;
```

---
### **9. Keywords (from video metadata)**

database indexing, btree, LSM tree, index scan, full table scan, PostgreSQL, `EXPLAIN ANALYZE`, primary key, `LIKE`, `pg_trgm`, full-text search, expression index, composite index, selectivity, query optimization, `INCLUDE`, extended statistics, keyset pagination.
