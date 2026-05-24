# Video summary: Data Partitioning

**Source:** [Data Partitioning (English) with Amr Elhelw — Tech Vault](https://www.youtube.com/watch?v=6emnnIL9Grc)  
**Channel:** Tech Vault · **Runtime:** ~35 min · **Published:** 2024-11-26  

---

## Why partitioning? Two motivating scenarios

**Scenario 1 — huge table, range query.** An `orders` table for an Amazon-scale shop (~9–10 M orders/day × 10 years → **billions of rows**). A common query asks for orders **between two dates** that are only 2 months apart.

- **Full table scan:** must check every row → far too slow.
- **Index on `order_date`:** avoids full scan, but matching rows still need random I/O on the table to fetch other columns (`amount`, `customer_id`, …). Better, but not enough at this scale.

**Scenario 2 — wide rows, narrow queries.** A `products` table with `product_id`, `name`, `category_id`, `quantity`, and a large `notes` column. Most queries don't touch `notes`.

- Full table scan reads the **whole row** including the huge `notes` field → wasted I/O.
- **Covering indexes** help, but:
  - You may need **many** combinations of keys.
  - Each extra index has a **maintenance cost** on every write.
  - Bad for **volatile** columns like `quantity` (changes on every sale).

Indexes alone aren't sufficient. In practice **partitioning and indexing are used together**.

---

## What is partitioning?

A logically large table is **physically split into multiple smaller tables (partitions)**. The original table becomes a **conceptual view**; data actually lives in the partitions.

Tables can be large in **rows**, in **row size**, or both.

### Main benefits

- **Query performance** — the engine can **skip** partitions that can't contain matching rows (partition pruning).
- **Parallelism** — multiple threads can read different partitions concurrently.
- **Concurrency control** — lock a partition, not the whole table; other partitions stay available.
- **Manageability** — backups, index rebuilds, archiving happen on smaller pieces.
- **Tiered storage** — hot partitions on SSDs, cold/historical on cheaper magnetic disks.

---

## Two high-level types

| Type | Splits by | Each partition holds |
|---|---|---|
| **Vertical partitioning** | Columns | A **subset of columns** (key column repeated for joins) |
| **Horizontal partitioning** | Rows | A **subset of rows**, same schema across all partitions |

---

## Vertical partitioning

Split columns by **access pattern**. Example: `products` → one partition with `{product_id, name, category_id, quantity}`, another with `{product_id, notes}`. Most queries hit only the small partition; `notes` is read only when needed. The **key column is repeated** so partitions can be joined back.

**When to use**

- Columns with **different access frequency** (hot vs. cold columns).
- **Sensitive data** — isolate restricted columns into a partition with stricter permissions; join only for authorized users.

**DBMS support**

- Most engines **don't** offer special syntax. You implement it as **separate tables with a 1:1 relationship**.
- The **application** must split `INSERT`s across both tables and `JOIN` them on the key when reading.

---

## Horizontal partitioning

Split rows according to a **partitioning key** (one or more columns). Three common strategies:

### 1. Range partitioning

Define **non-overlapping ranges** of the partitioning key; each range maps to one partition.

- Good for keys with **natural ordering / ranges**: dates, salaries, grades, prices.
- Example: `order_date` ranges per quarter.

### 2. List partitioning

Define an explicit **list of discrete values** per partition.

- Good for **categorical** keys: countries, regions, departments, categories.
- Example: `country IN ('AR','BR') → P0`, `country IN ('AT','BE') → P1`, …

### 3. Hash partitioning

`partition = hash(key) mod N`, where `N` is the number of partitions.

- Use when the key has **no natural ranges/lists** — gives a **uniform distribution**.
- Example: `hash(customer_id) mod 3`.

### When to pick which

| Strategy | Best when the key… |
|---|---|
| **Range** | Has natural ordered ranges queried in your workload (dates, numbers). |
| **List**  | Has discrete categorical values. |
| **Hash**  | Has no natural ordering — you want uniform spread. |

### DBMS support

Horizontal partitioning usually has **first-class syntax**. You query the **top-level table**, and the engine:

- Routes `INSERT`s to the correct partition based on the key.
- Performs **partition pruning** at query time — scans only relevant partitions.

---

## PostgreSQL demo (range partitioning)

```sql
CREATE TABLE orders (
    order_id   SERIAL,
    order_date DATE NOT NULL,
    amount     NUMERIC,
    PRIMARY KEY (order_id, order_date)
) PARTITION BY RANGE (order_date);
```

In PostgreSQL the **individual partitions must be created explicitly** (they inherit the schema):

```sql
CREATE TABLE orders_q1 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');
CREATE TABLE orders_q2 PARTITION OF orders
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');
-- … q3, q4
```

`INSERT`s go to `orders`; the engine routes each row to the partition whose range matches `order_date`.

### Query plans observed in the demo

| Query filter | What the planner does |
|---|---|
| `order_date BETWEEN 'Apr…' AND 'Jun…'` | Sequential scan on **`orders_q2` only**. Other partitions pruned. |
| `order_date BETWEEN 'Feb…' AND 'Jun 30'` | Scans **`q1` + `q2`**, then `Append` (union). |
| `order_date < '2023-12-…'` | **No partition** overlaps → empty result, no scans. |
| `SELECT * FROM orders` | Scans **all partitions** and appends — equivalent to no partitioning. |

This is partition pruning: query performance scales with the number of **relevant** partitions, not the total table size.

---

## Design considerations & best practices

- **Pick the right partitioning key.** It should appear in the **filters** of your common queries; otherwise the engine can't prune and you scan everything anyway.
- **Avoid over-partitioning.** Too many partitions → per-row routing overhead on writes and per-query pruning overhead on reads. Find a balance between **skip benefit** and **bookkeeping cost**.
- **Combine partitioning with indexes.** E.g. partition by date, then keep a local index on `order_date` inside each partition.
- **Monitor distribution over time.** Data shape changes; partitions can become skewed and may need **rebalancing** or range adjustments.

### Common challenges

- **Data skew** — one partition becomes huge while others stay tiny → effectively a full scan + overhead.
- **Queries touching too many partitions** — approaches full-scan cost plus pruning overhead. Ideally most queries touch only a few partitions.
- **Maintenance overhead** — monitoring, rebalancing, schema changes across partitions all cost engineering time.

---

## Partitioning vs. sharding

| Concept | Where the parts live |
|---|---|
| **Partitioning** | All partitions in the **same database / server**. |
| **Sharding** | Parts split across **different databases / servers / nodes** — a form of horizontal partitioning for **horizontal scaling** in distributed databases. |

Sharding adds coordination, cross-node queries, and data-movement costs — a separate, more complex topic.

---

## Summary takeaway

- **Partitioning** splits a large table into smaller pieces to improve performance, parallelism, manageability, and storage tiering.
- **Vertical** = split columns by access pattern / sensitivity; usually done manually as separate tables.
- **Horizontal** = split rows by a **partitioning key** using **range**, **list**, or **hash**; usually first-class in the DBMS with automatic pruning.
- Partitioning **complements indexing** — use both.
- Choose the key from your **query filters**, watch out for **skew** and **over-partitioning**.
- **Sharding** = horizontal partitioning across **separate servers** (distributed scale).

---
