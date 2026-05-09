# Database indexes 

## 1. What an index is

- A **separate data structure** on top of a table; it does not replace the table. It maps **search keys** (column values) to **row locators** (e.g. row ID / `ctid` / heap TID) so the engine avoids reading every page for selective predicates.
- **Analogy:** letter tabs in a phone book — jump to the right section instead of scanning from page one.
- **Trade-off:** faster **reads** on indexed predicates; **extra storage** and **write cost** (every insert/update/delete that touches indexed columns must maintain the index).

```sql
SELECT id, name FROM employees WHERE id = 2000;
```

---

## 2. Why indexes exist — shrinking the search space

- **Full table scan:** read every page, check each row — simple but expensive on large tables.
- **Parallel scans:** better wall-clock time, still ~all pages.
- **Partitioning:** prune whole partitions when the partition key matches the predicate; no help when filtering on non-partition keys.
- **Goal:** read **fewer pages** → less I/O, faster queries.

---

## 3. Naive structures and why trees won

- **Sorted list of (key, pointer):** finding a key can scan many index pages (**O(n)** worst case along the index); binary search implies **random page jumps** (bad for disk); inserts require keeping order (expensive).
- **Binary search tree:** balanced BST is ~**O(log n)**; skewed insert order → degenerate tree → **O(n)**; nodes hold keys + pointers — need **balance** under updates.

---

## 4. B-tree

- Generalization of BST: each node holds up to **K** children and **K−1** keys; nodes typically **at least half full** (except root edge cases).
- **Always balanced** (splits/merges) → predictable height.
- **Many keys per node** → **shorter tree** → fewer page reads (good when a node ≈ a disk page).
- **Writes** pay for balance maintenance.
- **Range queries** are awkward: in-order walk may **re-read internal nodes**; without parent pointers or a leaf chain, sequential traversal is painful.

### B-tree (schematic, max 3 children)

```
                         [ 25 ]
                        /      \
               [ 10, 18 ]        [ 35, 40 ]
              /    |    \      /    |    \
            ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐
            │…│   │…│   │…│   │…│   │…│   │…│
            └─┘   └─┘   └─┘   └─┘   └─┘   └─┘
          subtrees / leaves: keys + row pointers
```

---

## 5. B+ tree

**Two differences from classic B-tree (as usually taught):**

1. **Data / row pointers only at leaves.** Internal nodes hold **separator keys** only (often duplicates of leaf keys). More keys per internal page → **fewer levels**, less I/O on root-to-leaf path.
2. **Leaves linked in sorted order** (sibling pointers). After finding one end of a range, **scan the leaf chain** — efficient ranges without bouncing up the tree.

**Costs:** duplicated keys in internal nodes; splits/rebalancing on write.

### B+ tree (schematic)

```
                         [ 25 ]
                        /      \
               [ 18 ]             [ 35 ]
              /      \           /      \

Leaves (linked in key order):

    ┌──────────────────────────────────────────────────────────┐
    │  [5,10]  ──→  [15,18]  ──→  [25,30]  ──→  [35,40]  ──→   │
    └──────────────────────────────────────────────────────────┘
         each leaf entry: (key, pointer to row / heap TID)
```

### Side-by-side

```
B-tree                          B+ tree
────────────────────────────    ────────────────────────────────────
Internal: key + ptr per key     Internal: separators + child ptrs
                                (shorter tree)

Range scan: climb/descend       Range scan: scan leaf chain after left bound

Space: ptrs at every level      Dup keys in internals; leaves authoritative
```

### Minimal numeric picture (fan-out 3)

**B-tree**

```
            [ 20 ]
           /      \
    [ 8, 12 ]      [ 30 ]
    /  |  \        /    \
   *   *   *      *      *
```

**B+ tree**

```
            [ 20 ]
           /      \
    [ 12 ]          [ 30 ]
    /    \          /    \

Leaves:  [4,8] ──→ [12,15] ──→ [20,22] ──→ [30]
```

---

## 6. What real DBMSs do

- Most relational engines use **B+ trees or close variants** for secondary indexes.
- **Naming:** product docs often say “B-tree” for the **whole family** (B-tree, B+, hybrids).
- **PostgreSQL:** index branding may say B-tree but structure is often **B+-like** (tuple IDs at leaves); leaf sibling links may differ from textbooks — **implementation-specific hybrids** are common.
- **Index-organized tables (IOTs):** rows live **in** index leaf pages (Oracle, SQL Server, MySQL, SQLite, etc.) — one less indirection for primary-key lookups.

---

## 7. Hash indexes

- **Structure:** hash function + **buckets**; key (and row ID / `ctid`) stored in the bucket the hash selects.
- **Point lookup:** **O(1)** average — very fast vs **O(log n)** B-tree.
- **Trade-off:** keys are **not ordered** → **no range queries** (e.g. between two names).
- **Composite hash:** hash combines multiple columns → still **point-query** oriented. **PostgreSQL does not support composite hash indexes** (composite hash is conceptual; use B-tree composites in PG).

| Feature | Hash | B-tree |
|--------|------|--------|
| Point queries | O(1) | O(log n) |
| Range queries | No | Yes |
| Sort order | None | Yes |
| Composite | Limited / not in PG composites | Strong prefix behavior |

```sql
CREATE INDEX name ON table USING HASH (column);
EXPLAIN SELECT * FROM table WHERE column = 'value';
```

**Row ID in PostgreSQL:** hidden `ctid` = physical page + slot:

```sql
SELECT ctid, * FROM table;
```

---

## 8. Composite (multi-column) indexes

- One index entry holds multiple values, e.g. `(X, Y)`. **Column order matters:** sorted by **X**, then **Y** within each **X**.
- Also called **compound** indexes.

### Prefix (left-prefix) rule

Index on **(A, B, C)** efficiently supports predicates that use a **prefix**:

1. **A** alone  
2. **A, B**  
3. **A, B, C**  

It does **not** efficiently support **B** alone or **C** alone (no leading **A**).

```sql
CREATE INDEX idx_orders_customer_status ON orders (customer_id, status);
-- Good: customer_id present (and optionally status)
SELECT * FROM orders WHERE customer_id = 42 AND status = 'open';
-- Often poor: only status — composite can't replace index on status alone
SELECT * FROM orders WHERE status = 'open';
```

### Composite vs multiple single-column indexes + index intersection

- **Composite pros:** one probe, faster when the query matches the key prefix; simpler optimizer if you standardize patterns.
- **Composite cons:** larger indexes; many query shapes → many composites → **more storage** and **higher write amplification**; inflexible for new predicate combinations.
- **Intersection pros:** flexible (ad-hoc combinations); fewer indexes → less space and cheaper updates on **write-heavy** workloads.
- **Intersection cons:** multiple index accesses + merge/intersect at query time.

**Rule of thumb:** favor **composite** for **read-heavy** workloads with **repeated same column combinations**; favor **intersection** (if the engine does it well) for **flexible** filters or **write-heavy** workloads.

---

## 9. Bitmap indexes

- A full index **type** (not the same as using bitmasks *inside* index intersection/union implementations elsewhere).
- **Cardinality:** table cardinality = row count; **column cardinality** = **distinct** value count.
- **Best for:** **low-cardinality** columns + **equality** / **IN** predicates (status, region flags). Unusual for meaningful range predicates on categorical columns.
- **Structure:** one **bit vector per distinct value**, length = row count; bit *i* = 1 iff row *i* has that value.
- **Evaluation:** equality → one bitmap; OR / IN → **bitwise OR**; AND across columns → **bitwise AND** of bitmaps from each index.
- **Why low cardinality:** size grows with (#distinct values) × (rows/8). High cardinality → sparse bitmaps; near-unique columns (e.g. PK) → almost one bit set per vector — use **B-tree** instead. Roughly: tens/low hundreds of distinct values may be OK; thousands+ often poor.

---

## 10. Primary key vs row ID

| Aspect | Primary key | Row ID |
|--------|-------------|--------|
| Origin | User-defined column(s) | System-generated |
| Meaning | Often real-world / business ID | Internal; often page + slot (or opaque) |
| Role | Uniqueness, integrity | Locating tuples in storage |
| Mutability | Can change if allowed | Not user-controlled |
| In indexes | Often the **search key** when indexed | Usually the **payload** (index maps values → row IDs) |

---

## 11. “Attribute” index vs storage / “page” index

- **Attribute index:** `CREATE INDEX` — **attribute value(s) → row ID(s)**; visible to the **query optimizer**.
- **Storage-level index:** internal to **storage manager** — **row ID → physical location**, or row ID → latest version in log-structured stores; not the same as user-created indexes.

---

## 12. Full scan vs index scan vs index-only scan (physical work)

Performance is largely about how much **physical work** the database does — especially reading data pages from disk into memory.

### 1. Full table scan (“brute force”)

- **Work:** read **every** data page of the table from disk (into buffer cache as needed).
- **Cost:** very high on large tables.
- **Complexity:** **O(n)** in table size.

### 2. Index scan (“map & hop”)

- **Work:**
  1. Search the small, sorted **index** to find the pointer(s) — typically **O(log n)** per probe for a B-tree–style index.
  2. Use that pointer to **hop** to the page(s) in the **heap** (main table) where the full row lives.
- **Why it can still feel “expensive”:** each matching row may mean a **separate** trip to a different table page. Fetching 1,000 rows can mean many random heap visits — still usually far better than scanning the whole table because you only touch pages for rows that qualify.

### 3. Index-only scan (“shortcut”)

- **Work:** search the index and **stop** — no heap fetch for covered columns.
- **Requirement:** the query needs only columns **present in the index** (including `INCLUDE` columns where supported), and the engine can trust the index alone (e.g. visibility / MVCC rules satisfied — in PostgreSQL this ties to the **visibility map** for heap bypass).
- **Result:** avoids the **table hop** when conditions align — often the cheapest path for covered queries.

### Real-world analogy (address book)

| Access path | Analogy |
|-------------|---------|
| **Full scan** | You ignore alphabetical tabs; start at page 1 and read every name until you find “Ahmed.” |
| **Index scan** | You use the “A” tab, find “Ahmed,” see only an **address** (pointer); you **drive to the house** to get the phone number (full row). |
| **Index-only scan** | You use the “A” tab; the **phone number is written right there** next to the name — no trip needed. |

### Clustered primary keys

Many systems tie the **primary key** to a **clustered index**: table rows are stored **in PK order** in the same structure as (or tightly aligned with) the PK index, so PK lookups do little extra I/O.

**PostgreSQL:** default tables are a **heap**; the PK is a **B-tree** with **TIDs** pointing into the heap — not a SQL Server–style clustered index on the heap. **InnoDB** (MySQL) and **SQL Server** commonly use **clustered** PK storage.

---

## 13. PostgreSQL: families, demos, and `EXPLAIN`

- Default secondary index method is often **`btree`**. Other access methods: `hash`, `gist`, `gin`, … — not LSM (LSM is a different family common elsewhere).

```sql
CREATE INDEX idx_employees_name ON employees USING btree (name);
SELECT amname FROM pg_am WHERE amhandler <> 0 ORDER BY amname;
```

- **`EXPLAIN (ANALYZE, BUFFERS)`** shows real plans, timing, buffer usage — use it on hot queries.

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, name FROM employees WHERE id = 2000;
```

- Large table pattern: **indexed PK** (`id`) vs **unindexed** `name` — selective `id` uses index scan; equality on `name` without index often **seq scan**.

---

## 14. When a normal B-tree often does not help (PostgreSQL)

- **`LIKE '%substring%'`** (leading wildcard): no fixed prefix → btree on raw column rarely helps → often **seq scan**. **`ILIKE`** similar for arbitrary patterns.
- **What can help:** **`pg_trgm`** (`gin`/`gist`), or **full-text** (`tsvector` / `tsquery`) for token/word search.

```sql
-- Prefix-friendly
SELECT * FROM employees WHERE name LIKE 'zs%';

-- Substring: consider trigram
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_employees_name_trgm ON employees USING gin (name gin_trgm_ops);
SELECT id, name FROM employees WHERE name LIKE '%zs%';
```

- **Expression on column:** `lower(name) = ...` with index only on `name` → match with **expression index** on `(lower(name))`.
- **Composite order:** filter only on trailing columns → left-prefix rule; may need separate index.
- **Regex** (`~`, `~*`, `SIMILAR TO`): not ordinary btree range/equality — specialized indexes may be needed.
- **Low selectivity:** condition matches most rows → planner may prefer **seq scan**.
- **Tiny tables:** seq scan can win.
- **`OR` across columns:** may need **`UNION`** of two index-friendly queries or broader scans.
- **Type mismatch / casts on indexed column:** can block simple index use; align types or index the expression.
- **JSON, arrays, ranges, geo:** use **GIN**, **GiST**, **BRIN**, etc., not only btree.

Always verify with **`EXPLAIN (ANALYZE, BUFFERS)`**; refresh stats with **`ANALYZE`** after bulk loads.

---

## 15. Optimization workflow (PostgreSQL)

1. **Evidence first:** `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)` — seq scans on big tables, bad row estimates, unexpected heap fetches.
2. **Align indexes** with filters/joins: btree on equality/range/join keys; composite with **most selective column first** when queries always use a prefix; **`INCLUDE`** to reduce heap visits when useful.
3. **Sargable predicates:** avoid functions on the indexed side when possible; match `LIKE` style to index type; fix types; rewrite `OR` to `UNION` when each branch can use an index.
4. **Statistics:** `ANALYZE`; consider **extended statistics** for correlated columns.
5. **Less data:** avoid `SELECT *` in hot paths; **keyset pagination** (`WHERE id > $last ORDER BY id LIMIT n`) vs huge `OFFSET`.
6. **FK / join hygiene:** index the **referencing** (child) columns.
7. **Don’t disable seq_scan/nestloop globally** without proof; tune `random_page_cost` / `effective_cache_size` from measured I/O.
8. **Operations:** autovacuum, bloat, `pg_stat_user_tables` (`last_analyze`, `n_dead_tup`).

```sql
CREATE INDEX idx_orders_cust_status_inc ON orders (customer_id, status)
  INCLUDE (created_at);

CREATE STATISTICS IF NOT EXISTS st_orders_cust_status (dependencies)
  ON customer_id, status FROM orders;
ANALYZE orders;
```

---

## 16. Master takeaway

- Indexes **shrink read path**; they **cost writes and space** (splits/rebalancing in B/B+ trees; many indexes → heavy updates).
- **Choose by workload:** point vs range; read-heavy vs write-heavy; predicate shapes.
- **B+** (and btree family): default workhorse for **order + range + point**. **Hash:** **point-only**, O(1). **Bitmap:** **low cardinality**, equality/IN. **Composite vs intersection:** **speed + specificity** vs **flexibility + write cost**.
- **PostgreSQL:** validate every assumption with **`EXPLAIN (ANALYZE, BUFFERS)`**; use the right access method (btree, hash, gin, gist, trgm, FTS, …) for the predicate.

---

## Sources

| Topic | Reference |
|--------|-----------|
| B-tree / B+ tree | [Tech Vault — B and B+ Trees](https://youtu.be/1fETPYKyb70) · [Slides (PDF)](https://github.com/aelhelw/techvault/blob/main/Relational_Database_Internals/TechVault_Database_Indexes_Btrees.pdf) |
| Hash & composite | [Tech Vault — Hash & Composite](https://www.youtube.com/watch?v=dH5SwQ5rndQ) |
| Indexes Q&A (bitmap, PK vs row ID, intersection) | [Tech Vault — Q&A](https://www.youtube.com/watch?v=ozXWjqNsNYU) · Arabic: [wY_SxRMLTvA](https://youtu.be/wY_SxRMLTvA) · Related: [Index Intersection](https://youtu.be/J8prxz2KxeA) |
| PostgreSQL indexing & optimization | [Hussein Nasser — YouTube](https://www.youtube.com/watch?v=-qNSXK7s7_w) |

*Merged from: `Index B,B+ trees.md`, `Index Hash & Composite.md`, `Database_Indexes_QA_Tech_Vault_Summary.md`, `PS indexing.md`.*
