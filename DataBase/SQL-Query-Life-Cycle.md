# Video summary: SQL Query Life Cycle

**Source:** [SQL Query Life Cycle (English) with Amr Elhelw — Tech Vault](https://www.youtube.com/watch?v=Wr7cd6p8hvQ&list=PLE8kQVoC67PywFpq0VXxGFbStvtskNVkW&index=8)
---

## SQL vs. Relational Algebra

- **SQL** is **declarative (non-procedural)**: you specify *what* you want, not *how* to get it.
- **Relational Algebra** is **procedural**: you specify the *order of operations*.
- The **query engine** is responsible for translating SQL into an efficient execution plan.

---

## CRUD operations

Four basic data operations, mapped to SQL:

| Operation | SQL statement |
|-----------|---------------|
| Create    | `INSERT`      |
| Read      | `SELECT`      |
| Update    | `UPDATE`      |
| Delete    | `DELETE`      |

`SELECT` is the focus because it is the **most common** (data is read many more times than it is written) and the **most complex** (sub-queries, joins, aggregation, sorting, …). It is also embedded inside many `INSERT` / `UPDATE` statements.

---

## The Query Engine pipeline

The query engine is often treated as a black box. Internally a SQL query flows through these stages:

```
SQL string → Parser → Analyzer → Optimizer → Execution Engine → Results
                ↑          ↑          ↑              ↑
                └──────── Catalog & Statistics ──────┘
```

---

## 1. Parser — syntax checks

A SQL query is initially **just a string of characters**. The parser converts it into structured data.

### Tokenization

Scans the text character-by-character and produces **tokens** of these types:

- **Keywords** — `SELECT`, `FROM`, `WHERE`, `AND`, `OR`, `NULL`, `GROUP`, …
- **Operators** — `=`, `<`, `>`, `+`, `-`, …
- **Symbols** — parentheses, quotes, comma, dot, …
- **Constants** — string (`'active'`), numeric (`20`), date, …
- **Identifiers** — anything else (assumed to be a table / column / function name).

At this stage, the parser does **not** validate identifiers; it only checks **syntactic correctness**:

- Unclosed string literal → syntax error.
- Missing required clauses (e.g. no `FROM` when required) → syntax error.

### Parse tree

After tokenization, the parser builds a **parse tree** that groups tokens by clause (`SELECT`, `FROM`, `WHERE`, `ORDER BY`, `GROUP BY`, …). The tree structure is **DBMS-specific** (PostgreSQL ≠ MySQL).

---

## 2. Analyzer — semantic checks

Takes the parse tree and performs **semantic validation** using the **catalog**:

- Do the referenced **tables** actually exist?
- Do the referenced **columns** exist on those tables?
- Are column references **unambiguous** (qualified when needed)?
- Do called **functions** exist with matching signatures?
- Are **types** compatible in comparisons (e.g. `status = 'active'` requires `status` to be string-compatible)?

Example error: `WHERE agee > 20` → analyzer reports that column `agee` does not exist.

### Initial query plan

After validation, the analyzer produces an **initial query plan** — the relational-algebra equivalent of the query (scan → filter → project → …). Plans are read **bottom-up**.

> **Note:** Some systems (and some literature) merge **Parser + Analyzer** into a single "parse" stage.

---

## 3. Catalog — metadata storage

A collection of **metadata** about tables, columns, indexes, types, constraints, etc. It is stored as **system tables** that the DB maintains automatically (every `CREATE TABLE`, `ALTER`, `CREATE INDEX` updates it).

### PostgreSQL examples

| Catalog table   | What it stores                                                            |
|-----------------|---------------------------------------------------------------------------|
| `pg_class`      | Relations (tables, views, indexes, …): oid, name, namespace, pages, tuples |
| `pg_attribute`  | Columns: relation id, name, type id, length, position, not-null flag      |
| `pg_type`       | Type definitions referenced by `pg_attribute.atttypid`                    |
| `pg_namespace`  | Schemas / namespaces (`public`, `pg_catalog`, …)                          |

System (built-in) columns have **negative** `attnum` values (e.g. `ctid`); user columns start at `1`.

Useful queries:

```sql
SELECT oid, relname, relpages, reltuples
FROM pg_class
WHERE relname = 'foo';

SELECT attrelid, attname, atttypid, attlen, attnum, attnotnull
FROM pg_attribute
WHERE attrelid = (SELECT oid FROM pg_class WHERE relname = 'foo');

SELECT relname
FROM pg_class
WHERE relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'pg_catalog');
```

---

## 4. Query Optimizer

Transforms the initial plan into the **best (cheapest) execution plan**. Does two main jobs:

### a) Plan enumeration

Generates many **equivalent** alternative plans by:

- Reordering operations.
- Choosing different **join orders** and **join types** (hash join, nested-loop join, merge join, …).
- **Pushing down** filters.
- Choosing whether and which **indexes** to use, possibly combining via **index intersection**.
- Choosing **sorting algorithms**.

Example alternatives for `… WHERE status = 'active' AND age > 20`:

1. Full table scan → filter → project.
2. Index scan on `age` → filter on `status` → project.
3. Index scan on `status` → filter on `age` → project.
4. Index scan on both → intersect row-ids → fetch tuples → project.

### b) Costing

Each operation has a **cost formula** in the optimizer's **cost model**, primarily a function of the **estimated number of input rows**. The plan with the **lowest estimated cost** is chosen.

> The search space is bounded; optimizers consider a **finite** (though large) set of candidate plans.

---

## 5. Database Statistics

Statistics feed the cost model with row-count and data-distribution estimates.

### PostgreSQL: `pg_stats`

Per-attribute info:

- `null_frac` — fraction of NULLs.
- `avg_width` — average value width in bytes.
- `n_distinct` — number of distinct values.
- `most_common_vals` / `most_common_freqs` — MCV list.
- `histogram_bounds` — equi-depth histogram buckets used to approximate distribution.

```sql
SELECT attname, avg_width, histogram_bounds
FROM pg_stats
WHERE tablename = 'foo';
```

---

## 6. Execution Engine

Receives the chosen execution plan, accesses the data via tables and indexes, runs the operators **in plan order**, and produces the **query results**.

### Inspecting plans in PostgreSQL

```sql
EXPLAIN <query>;             -- estimated plan + costs
EXPLAIN VERBOSE <query>;     -- adds output columns, inner-unique, …
EXPLAIN (FORMAT JSON) ...;   -- machine-readable output (also XML, YAML)
EXPLAIN ANALYZE <query>;     -- executes and shows actual rows + time per node
```

`EXPLAIN ANALYZE` is the main tool for verifying whether **estimates match reality** — large gaps usually mean **stale or insufficient statistics**.

Use the [Postgres Explain Visualizer](https://www.pgexplain.dev/) to view plans as trees.

---

## Query execution order (logical clause order)

SQL is **declarative**, so the order you **write** the clauses is **not** the order the engine **evaluates** them. Knowing the logical evaluation order explains why some aliases work in `ORDER BY` but not in `WHERE`, why `WHERE` cannot reference aggregates, etc.

### Written order vs. logical execution order

| # | Written (typing order) | Logical execution order            |
|---|------------------------|------------------------------------|
| 1 | `SELECT`               | `FROM` (+ `JOIN`)                  |
| 2 | `FROM` / `JOIN`        | `WHERE`                            |
| 3 | `WHERE`                | `GROUP BY`                         |
| 4 | `GROUP BY`             | `HAVING`                           |
| 5 | `HAVING`               | `SELECT` (expressions + aliases)   |
| 6 | `SELECT`               | `DISTINCT`                         |
| 7 | `ORDER BY`             | `ORDER BY`                         |
| 8 | `LIMIT` / `OFFSET`     | `LIMIT` / `OFFSET`                 |

### What each step does

1. **`FROM` / `JOIN`** — build the working set: read base tables, apply joins, produce the combined row set.
2. **`WHERE`** — filter individual rows. Cannot reference aggregates or `SELECT` aliases (the alias does not exist yet).
3. **`GROUP BY`** — collapse rows into groups by the grouping keys.
4. **`HAVING`** — filter the **groups** produced by `GROUP BY`. This is where aggregate conditions live (`HAVING COUNT(*) > 10`).
5. **`SELECT`** — evaluate the projection list, including aggregates and column aliases.
6. **`DISTINCT`** — remove duplicate rows from the projected result.
7. **`ORDER BY`** — sort the final rows. Can reference `SELECT` aliases because projection already ran.
8. **`LIMIT` / `OFFSET`** — return only the requested slice of rows.

### Practical consequences

- `WHERE` cannot use a `SELECT` alias:

  ```sql
  SELECT salary * 12 AS annual
  FROM   employees
  WHERE  annual > 100000;       -- ❌ alias not visible yet
  ```

  Use the expression directly, or wrap in a sub-query / CTE.

- `WHERE` cannot use aggregates — use `HAVING`:

  ```sql
  SELECT department, COUNT(*) AS n
  FROM   employees
  GROUP  BY department
  HAVING COUNT(*) > 10;         -- ✅
  ```

- `ORDER BY` **can** use a `SELECT` alias because it runs after projection.

### Full example — query and its execution flow

Given the query:

```sql
SELECT   department,
         COUNT(*)        AS employee_count,
         AVG(salary)     AS avg_salary
FROM     employees       e
JOIN     departments     d  ON d.id = e.department_id
WHERE    e.hired_at >= '2024-01-01'
GROUP BY department
HAVING   AVG(salary) > 5000
ORDER BY avg_salary DESC
LIMIT    5;
```

The clauses are evaluated in this logical order:

```
FROM employees e JOIN departments d ON d.id = e.department_id
                              │  build the working row set (joined rows)
                              ▼
WHERE e.hired_at >= '2024-01-01'
                              │  keep only rows hired in 2024+
                              ▼
GROUP BY department
                              │  collapse rows into one group per department
                              ▼
HAVING AVG(salary) > 5000
                              │  drop groups whose average salary ≤ 5000
                              ▼
SELECT department, COUNT(*) AS employee_count, AVG(salary) AS avg_salary
                              │  evaluate projections + aliases
                              ▼
DISTINCT  (not used here)
                              │
                              ▼
ORDER BY avg_salary DESC
                              │  sort using the SELECT alias
                              ▼
LIMIT 5
                              │  keep only the top 5 rows
                              ▼
                           Results
```

### Logical vs. physical order

This is the **logical** order defined by the SQL standard — it guarantees the **result**. The **optimizer** is free to choose any **physical** execution order (push filters down, reorder joins, evaluate aggregates differently) as long as the final result matches the logical semantics.

---

## Summary

1. **Parser** — string → tokens → parse tree; syntax checks.
2. **Analyzer** — semantic checks against the **catalog**; produces the initial relational-algebra plan.
3. **Catalog** — system tables describing schemas, tables, columns, types, indexes.
4. **Optimizer** — enumerates equivalent plans and picks the lowest-cost one using a **cost model** + **statistics**.
5. **Statistics** — row counts, NULL fractions, distinct counts, histograms, MCVs.
6. **Execution Engine** — runs the chosen plan and returns the results.
