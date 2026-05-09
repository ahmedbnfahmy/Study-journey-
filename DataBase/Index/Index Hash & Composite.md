# Database Hash & Composite Indexes

**Source:** [Tech Vault (Amr Elhelw)](https://www.youtube.com/watch?v=dH5SwQ5rndQ) | YouTube: `dH5SwQ5rndQ`

This document provides a detailed summary of the technical deep dive into Hash Indexes and Composite (Multi-column) Indexes, comparing their performance, structure, and ideal use cases in database management systems like PostgreSQL.

---

## 1. Hash Indexes
Hash indexes are a distinct alternative to the common B-Tree structures. They rely on hash tables and hash functions to locate data.

### Structure & Mechanism
*   **Components:** A hash table (consisting of buckets) and a hash function.
*   **Insertion:** The hash function maps a key (e.g., a "First Name") to a specific bucket number where the key and the corresponding Row ID (CTID) are stored.
*   **Search:** To find a value, the same hash function is applied to the search term, leading directly to the correct bucket.

### Complexity & Performance
*   **Point Queries:** Extremely efficient with a time complexity of **O(1)** (constant time), regardless of the index size.
*   **Comparison:** Faster than B-Trees, which have a complexity of **O(log n)**.

### The Trade-off
*   Hash indexes **do not store keys in a relative order**.
*   Therefore, they **cannot be used for range queries** (e.g., finding names between "Bob" and "Mike").

---

## 2. Composite (Multi-Column) Indexes
A Composite Index is built on multiple attributes (e.g., `Name` AND `Age`) to optimize queries filtering by multiple fields.

### Composite Hash Indexes
*   The hash function takes multiple inputs and maps the combination to a single bucket.
*   **Limitation:** Limited to Point Queries. PostgreSQL specifically **does not support** composite hash indexes (only B-Tree composites).

### Composite B-Tree Indexes
*   Each index entry contains multiple values (e.g., `[X, Y]`).
*   **Order Significance:** The sequence of columns is critical. An index on `(X, Y)` is sorted by `X` first, then by `Y` within each `X` value.

---

## 3. The Prefix Rule
One of the most important concepts for index optimization is the Prefix Rule.

An index on **(A, B, C)** can effectively answer queries on:
1.  **A** (First column)
2.  **A, B** (First two columns)
3.  **A, B, C** (All three)

**Limitation:** It cannot efficiently answer queries on **B** alone or **C** alone because they do not form a prefix.

---

## 4. Comparison Summary

| Feature | Hash Index | B-Tree Index |
| :--- | :--- | :--- |
| **Search Complexity** | O(1) (Fastest) | O(log n) (Fast) |
| **Point Queries** | Supported | Supported |
| **Range Queries** | Not Supported | Supported |
| **Sorting** | None | Maintains Order |
| **Composite Use** | Limited prefix support | Strong prefix support |

---

## 5. Practical PostgreSQL Commands

### Create Hash Index
```sql
CREATE INDEX name ON table USING HASH (column);
```

### Check Execution Plan
Use `EXPLAIN` before a query to see if the optimizer chose an index scan or a sequential scan:
```sql
EXPLAIN SELECT * FROM table WHERE column = 'value';
```

### Row IDs (CTID)
In PostgreSQL, the hidden `ctid` attribute represents the physical location (page and slot) of a row:
```sql
SELECT ctid, * FROM table;
```
