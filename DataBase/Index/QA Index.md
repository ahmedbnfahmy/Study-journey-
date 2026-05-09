# Database Indexes — Q&A (English) — Summary

**Source:** [Database Indexes - Q&A (English) with Amr Elhelw - Tech Vault](https://www.youtube.com/watch?v=ozXWjqNsNYU)  
**Channel:** Tech Vault · **Length:** ~27 min · **Published:** 2024-04-02  

Follow-up Q&A to earlier index videos; answers comment questions. Arabic version: [youtu.be/wY_SxRMLTvA](https://youtu.be/wY_SxRMLTvA). Related: [B & B+ trees](https://youtu.be/1fETPYKyb70), [Composite Indexes](https://youtu.be/dH5SwQ5rndQ), [Index Intersection](https://youtu.be/J8prxz2KxeA).

---

## 1. Primary key vs. row ID

| Aspect | Primary key | Row ID |
|--------|-------------|--------|
| **Origin** | User-defined column(s) on the table | System-generated internal identifier |
| **Meaning** | Often maps to real-world IDs (order number, employee ID, etc.) | Internal only; encodes physical location (e.g. page + slot) |
| **Role** | Entity integrity, uniqueness | Locating tuples in storage |
| **Mutability** | Can change if no FK conflicts and uniqueness holds | Not user-changeable; tied to physical placement |
| **In indexes** | Often the *search key* when indexed | Usually the *payload* — index maps attribute values → row IDs |

Both can “appear” in indexes: you search by attribute values (sometimes the PK); the index entries typically point to row IDs for retrieval.

---

## 2. Bitmap indexes (not the same as bitmaps for intersection/union)

- **Bitmap index** = a full index *type* (like B-tree or hash), not just using bit operations inside index intersection.
- **Cardinality:** table cardinality = row count; **column cardinality** = number of **distinct** values in that column.
- **Good fit:** **low-cardinality** columns with **equality** or **IN** predicates (e.g. status in {P, A, D}, region in {Central, …}). Rarely range predicates like `region < West`.
- **Structure:** one bit vector per distinct value; length = number of rows. Bit *i* = 1 if row *i* has that value.
- **Queries:** equality → read one bitmap; OR / IN → bitwise OR of bitmaps; AND across columns → bitwise AND of bitmaps from each index.
- **Why low cardinality:** index size grows with (# distinct values) × (rows/8 bytes per bitmap). High cardinality spreads “ones” thinly; at extremes (e.g. unique PK) each bitmap is almost all zeros — inefficient; a B-tree is usually better. Rough guidance: tens/low hundreds of distinct values may still be OK; thousands+ is usually a poor match.

---

## 3. “Attribute” index vs. “page” index

- **Attribute index (user/query level):** `CREATE INDEX` style — maps **attribute value(s) → row ID(s)**. Visible to the optimizer; used for query planning and execution.
- **Page / storage-level index:** internal to the **storage manager** — maps **row ID → physical location** (or row ID → “latest” version in log-structured designs). Not exposed to users or the query engine the same way; implementation varies by system (e.g. opaque row IDs needing a second lookup).

---

## 4. Composite indexes vs. multiple indexes + index intersection

No universal winner — depends on workload, query patterns, and how the DBMS implements intersection.

**Composite (compound) index — pros**

- Faster for matching the indexed key prefix: one index probe vs. several indexes plus intersection.
- Simpler for the optimizer when you standardize on composites.

**Composite — cons**

- Can be larger than single-column indexes.
- Many query patterns → many different composite indexes → **more storage** and **higher write amplification** on updates.
- Less flexible: new predicate combinations may need new indexes.

**Single-column indexes + intersection — pros**

- Flexible combinations (ad-hoc / varied filters).
- Fewer indexes → less space and cheaper updates on write-heavy workloads.

**Intersection — cons**

- More work at query time: multiple index accesses + merge/intersect.

**Rule-of-thumb from the video**

- Prefer **composite** when reads dominate, writes are few, and queries repeatedly use the **same column combinations**.
- Prefer **intersection** (with efficient DB support) when you need **flexible** combinations or **write-heavy** workloads.

---

## 5. One-line takeaway

Indexes you design are usually **value → row ID**; storage may use separate **row ID → page/slot** structures. Bitmap indexes excel on **low-cardinality, equality-style** filters. **Composite vs. intersection** is a trade-off between **read speed and index count** vs. **flexibility and write cost**.
