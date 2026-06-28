# Document Data Model — Study Guide

**What this covers:** How document databases (e.g. MongoDB, Couchbase) model data, when they beat relational tables, and how to **link** records (**embed** vs **reference**). Includes a full **design workflow** (requirements → representation → physical design).

---

## Part 1 — Core Concepts

### 1. Vocabulary (relational ↔ document)

| Relational | Document |
|------------|----------|
| Table / relation | **Collection** |
| Row / tuple | **Document** |
| Column / attribute | **Field** |

**Key idea:** A **collection** holds many **documents** of the same *kind* (e.g. `customers`, `products`). Each document is one instance of that entity.

**Fields** are key–value pairs. Values can be:

- **Atomic** — string, number, date, boolean, …
- **Nested document** — object inside a document
- **Array** — list of atoms or nested docs (nesting can go several levels deep)

**Example — city document:**

```json
{
  "city": "Paris",
  "population": 2100000,
  "location": { "lat": 48.8566, "lng": 2.3522 },
  "top_attractions": ["Eiffel Tower", "Louvre"],
  "neighborhoods": [
    { "name": "Le Marais", "rating": 4.5 },
    { "name": "Montmartre", "rating": 4.7 }
  ]
}
```

---

### 2. `_id`, JSON, and BSON

| Concept | What to remember |
|---------|------------------|
| **`_id`** | System-generated unique id on each top-level document; used for lookups and references |
| **JSON** | What apps usually send/receive over the API |
| **BSON** | Binary JSON — how MongoDB stores and processes data on disk/network; faster than plain JSON for the engine |

**Why it matters:** You think in JSON; the database works in BSON under the hood.

---

### 3. Flexible schema

Unlike a fixed relational table, documents in the **same collection do not need the same fields**.

- User A: `{ "name": "Alice", "city": "Cairo" }`
- User B: `{ "name": "Bob", "email": "bob@example.com" }` — no `city`, no NULL column

**Key idea:** Schema is **flexible**, not absent. You still design for your queries.

---

### 4. Why document DBs help (vs relational pain)

**Relational problems** (e.g. users with phones, emails, optional fields):

| Problem | What happens |
|---------|----------------|
| Second phone | Add `phone2` column → Alice gets **NULL** for unused columns |
| New optional field | **ALTER TABLE** again → more NULLs |
| Many optional / multi-valued attrs | Normalize into `Phones`, `Emails` + **foreign keys** |
| Read user + phones + email | **JOIN** across tables (correct, but not free) |

**Document approach** (`users` collection):

```json
{ "name": "Bob", "phone": ["98765", "56789"] }
{ "name": "Tom", "email": "tom@example.com" }
```

| Benefit | Explanation |
|---------|---------------|
| No NULL padding | Missing fields simply aren’t stored |
| Multi-valued data | Natural **arrays** (`phone: [...]`) |
| Variable shape | New document shapes without global migration |
| Locality | Related data for one entity often in **one document** → one read, no join for that pattern |

**Caveat:** Flexibility ≠ no design. Plan for **query patterns** and **embed vs reference** (Part 2).

---

### 5. Linking data: embed vs reference

Two ways to relate entities (e.g. **user** ↔ **employer**):

#### Embedding (nesting)

Employer stored **inside** the user document.

| Pros | Cons |
|------|------|
| Single read/update | **Duplication** if many users share one company |
| Great when you **always** need both together | Same risks as **denormalization**: update anomalies, stale copies |

#### Referencing

`users` and `companies` collections; user has `employer_id` → company `_id` (like a **foreign key**).

| Pros | Cons |
|------|------|
| Company stored **once**; centralized updates | Need **two reads** (or join-like op) for user + company |
| No duplicate-company inconsistency | Join-like access is possible but **not the sweet spot** |

**Design rule:** Choose embed vs reference from **how the app reads data**, not from “flexible schema” alone.

---

### Part 1 — One-minute recap

1. **Collection** → **documents** → **fields** (atomic, nested, arrays).
2. Shine when shape **varies**, values are **multi-valued**, and **one document = one logical object**.
3. Link via **embed** (fast reads, duplication risk) or **reference** (normalized, extra reads).

---

## Part 2 — How to Design a Document Database

**Goal:** Requirements → DBMS choice → identify data → represent (embed/reference) → physical design → load → maintain.

Document design is more **application-driven** than classic relational normalization.

---

### Step 1 — Gather requirements

Same as any DB design: know **what the app does** and **what data it needs**.

Ask:

- **Domain** — e-commerce, health, social, blog, …
- **Relationships** between data types
- **Operations** — reads vs writes, frequency, reports
- **Users** — one role or many? permissions? different views?

**Blog example — sample operations:**

| Operation | Type | Frequency (example) | Data involved |
|-----------|------|---------------------|---------------|
| Submit article | Write | ~10/day | Author, article text |
| Submit comment | Write | ~1,000/day | Comment text, commenter name |
| View article | Read | ~1M/day | Article, comments, metadata |

**Why it matters:** Read-heavy “view article” at 1M/day pushes you toward **embedding** comments in the article document.

---

### Step 2 — Choose the DBMS (when document?)

Document DBs fit when:

- **Flexible / sparse schema** — optional profile fields, avoid wide NULL-heavy tables
- Data is already **JSON/XML** or naturally **hierarchical**
- **Content systems** — blogs, CMS: articles + nested comments, tags, categories

This guide assumes document DB is already the right choice.

---

### Step 3 — Identify the data

**“No schema” is misleading.** You need a mental model:

- **Entity types** (high level)
- **Relationships** — 1:1, 1:N, N:M
- **Schema map** — light ER diagram: entities, relationships, sample attributes (not every column/type upfront)

**Blog schema map — entities:**

| Entity | Sample attributes |
|--------|-------------------|
| User / author | name, email |
| Article | title, text, date |
| Tag | name, url |
| Category | name, url |
| Comment | text, name |

**Relationships:** user → articles (1:N), article → comments (1:N), article ↔ tags (N:M), …

---

### Step 4 — Data representation (the big decision)

| Relational idea | Document term | Shape |
|-----------------|---------------|-------|
| Normalization | **Referencing** | Multiple collections + ids |
| Denormalization | **Embedding** | Nested docs inside one document |

| | Referencing | Embedding |
|---|-------------|-----------|
| **Updates** | Easy when data is **shared** (one copy) | Hard if same data is **duplicated** in many docs |
| **Reads** | Slower when you need a “joined” view | Faster when everything lives in **one document** |

#### Blog — embedding pattern

One **article** document: title, text, date, nested **author**, arrays of **tags** and **comments**.

**Pros:** One query for article + author + tags + comments; one atomic update for the bundle.

**Cons:**

- **16 MB document limit** (MongoDB)
- **Author duplicated** on every article
- Author name change → update **every** article doc (cost + inconsistency risk)

#### Blog — referencing pattern

`authors` collection + `articles` collection; article stores `author_id` only.

**Pros:** No author duplication; smaller articles; cheap read when author not needed.

**Cons:** Article + author → multiple reads + join; new article + new author → **multiple writes**.

---

### Choosing layout by cardinality

#### One-to-one (e.g. user ↔ address)

→ Usually **embed** one inside the other.

Pick the **top-level** document by what the app centers on:

- User-centric app → user doc with embedded address
- Address-centric app → address doc with embedded user (rare)

#### One-to-many (e.g. author ↔ articles)

Three common patterns:

| Pattern | Best when | Trade-off |
|---------|-----------|-----------|
| **Embed author in each article** | Reads are **per article** with author | Author duplicated |
| **Reference** (`authors` + `articles`) | Author updated often; many articles share author | Join when you need both |
| **Embed articles array in author** | App loads **all articles by one author** at once | Weak for article-centric reads without author |

#### Many-to-many (e.g. students ↔ courses)

→ Usually **referencing** across two collections.

Put references on the side your queries favor:

- Query “all courses for this student” → course refs inside student docs, or
- Query “all students in this course” → student refs inside course docs

**General bias:** Document DBs **lean toward embedding**; **reference** when duplication, size limits, or update consistency dominate.

**Key distinction from relational design:** Layout follows **application queries**, not abstract normalization alone.

---

### Step 5 — Physical design

After logical design, before loading data:

- **Indexes** on fields you filter/sort often
- **Partitioning** for scan efficiency
- **Sharding** across nodes for scale
- **Replication** for availability

**After go-live:** Monitor performance; add/drop indexes; **evolve** embed/reference choices if query patterns change.

---

### Part 2 — One-minute recap

1. **Requirements** first — especially read/write volume and access paths.
2. **Schema map** at entity/relationship level, not full column specs.
3. **Embed** for read locality; **reference** for shared, frequently updated data and size limits.
4. **Physical design** and **maintenance** are ongoing, not one-shot.

---

## Decision cheat sheet (exam-style)

```
Need user + employer together on every read?
  YES → consider EMBED
  NO  → consider REFERENCE

Is the same sub-document shared by many parents?
  YES → lean REFERENCE (avoid duplication anomalies)

Is one read = whole "object" for the UI?
  YES → lean EMBED

Will embedded data blow past 16 MB (MongoDB)?
  YES → REFERENCE or split collection

Is shared data updated often?
  YES → REFERENCE
```

---

## Quick comparison: relational vs document modeling

| Topic | Relational | Document |
|-------|------------|----------|
| Schema | Fixed up front | Flexible per document |
| Multi-valued | Extra table or nullable columns | Arrays |
| Missing data | NULLs | Omit field |
| Relationships | FK + JOIN | Embed or reference id |
| Design driver | Normalize + integrity | **Query patterns** + locality |

---

## Self-check (cover answers, then verify)

1. Map table / row / column to document terms.
2. What can a **field value** be besides a scalar?
3. Why does MongoDB use BSON if apps use JSON?
4. Name two relational pains that arrays and flexible docs address.
5. When is **embedding** better than **referencing**? When is it worse?
6. What is the MongoDB per-document size limit, and why does it matter for a blog with thousands of comments?
7. For **1:N** author–articles, name all three layout options and one use case for each.
8. Why is “no schema” a misleading phrase?
9. List the six design steps in order.
10. What drives document layout more than pure normalization?

**Answers (skim after trying):**

1. Collection / document / field  
2. Nested document, array (of atoms or nested docs)  
3. Efficiency on disk and in the query engine; JSON at the boundary  
4. e.g. NULL padding for unused columns; ALTER TABLE for new optional fields; JOINs for related rows  
5. Better: always read together, few shared copies. Worse: shared entity duplicated, large updates, size limit  
6. 16 MB — huge embedded comment arrays can force referencing or pagination  
7. Embed author in article (article page); reference collections (frequent author updates); embed articles in author (author profile page)  
8. You still need entity/relationship design; only field-level shape is flexible  
9. Requirements → DBMS → identify data → representation → physical design → load/maintain  
10. Application access patterns (reads/writes, frequency, which entity is “first class”)

---

## Related topics (study later)

- MongoDB query operators and aggregation
- Index types and query plans on document stores
- Transactions and consistency in document DBs
- Sharding and replication in depth
