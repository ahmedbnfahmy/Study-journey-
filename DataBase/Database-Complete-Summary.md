# Database Complete Summary

This file combines the most important ideas from the database notes: relational vs non-relational databases, indexing, normalization, joins, SQL execution flow, and document data modeling.

---

## 1. Relational vs Non-Relational Databases

| Database type            | Description                                                                                                                                          | Best for                                                                                                                                                                  | Examples                                                                      |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Relational databases     | Store data in tables made of rows and columns. Relationships are modeled with primary keys and foreign keys, and queries are usually written in SQL. | Structured, stable data; transaction-heavy systems; data integrity and consistency; reporting and complex multi-table analysis                                            | PostgreSQL, MySQL, SQLite, SQL Server                                         |
| Non-relational databases | Do not follow the default table + SQL model. They include document, key-value, column-family, and graph stores.                                      | Flexible or evolving schemas; large-scale or high-throughput workloads; special access patterns such as caching, session storage, graph traversal, and content-heavy data | MongoDB (document), Redis (key-value), Cassandra (wide-column), Neo4j (graph) |

### Rule of thumb

If the data is stable, relational, and report-heavy, start with a relational database. If the data shape varies, scale patterns are extreme, or a specialized model fits the workload better, consider a non-relational approach.

### In short

* Relational databases are best when the schema is stable and integrity matters.
* Non-relational databases are best when the access patterns or data shape match a specialized model.
* Indexes, partitioning, and good query design are essential for performance.
* SQL execution involves parsing, analysis, optimization, and execution.
* Document databases shine when data is hierarchical, flexible, or naturally fits arrays and nested objects.
* Embedding and referencing are both valid; the choice depends on read patterns, update frequency, and data size.

---

## 2. Core Database Concepts

| Concept       | What it does                                    | Pros                                                      | Cons / trade-off                              |
| ------------- | ----------------------------------------------- | --------------------------------------------------------- | --------------------------------------------- |
| Normalization | Splits large tables into smaller related tables | Removes redundancy, reduces anomalies, improves integrity | More joins are needed to rebuild related data |

## 3. Indexing

| Type                | Best for                                | Example                                                       | Pros                                                    | Cons / watchouts                                               | Good use cases                                                     |
| :------------------ | :-------------------------------------- | :------------------------------------------------------------ | :------------------------------------------------------ | :------------------------------------------------------------- | :----------------------------------------------------------------- |
| **B-tree**    | Range queries, sorting, ordered lookups | `WHERE age > 25`                                            | Fast reads, supports order and range predicates         | Extra storage, slower writes, needs maintenance                | High-read systems,`WHERE`, `JOIN`, `ORDER BY`, PK/FK columns |
| **Hash**      | Exact match lookups                     | `WHERE id = 123`                                            | Very fast point lookups                                 | No range queries, no sorting, weak for prefix/range patterns   | Unique IDs, lookup-heavy exact-match queries                       |
| **Full-text** | Keyword / text search                   | `WHERE text LIKE '%database%'` or a trigram/full-text index | Great for searching words or substrings in text         | More storage and maintenance; not suitable for all query types | Search-heavy text fields, content search                           |
| **Composite** | Multi-column queries                    | `WHERE city = 'Cairo' AND age > 30`                         | Efficient for query patterns using the leftmost columns | Column order matters; non-prefix columns are weak              | Multi-filter queries, common access patterns on several columns    |

**Avoid over-indexing**

Avoid indexing every column in write-heavy tables or very small tables, especially when the query can just scan the table efficiently.

---

## 4. Partitioning

splitting a large table into smaller pieces for better scalability;

- good for large tables, time-series data, and frequent range queries; common methods are range, list, hash, and key partitioning;
- pros are faster scans and easier maintenance, while cons are more complexity and harder cross-partition joins.

---

## 5. SQL Query Life Cycle

| Stage            | What happens                                    | Key checks / decisions                                                            |
| ---------------- | ----------------------------------------------- | --------------------------------------------------------------------------------- |
| SQL string       | Query is submitted in SQL                       | Declarative: you state what you want, not how to fetch it                         |
| Parser           | Checks syntax and builds an internal parse tree | Catches bad keywords, parentheses, incomplete clauses                             |
| Analyzer         | Validates meaning against the database catalog  | Confirms tables, columns, functions, and compatible types                         |
| Catalog          | Stores metadata about the database              | Includes tables, columns, types, indexes, constraints                             |
| Optimizer        | Chooses the cheapest execution plan             | Selects join order, join algorithm, scan type, filter placement                   |
| Statistics       | Estimates costs from DB metadata                | Uses row counts, NULL ratios, distinct counts, histograms, common values          |
| Execution engine | Runs the chosen plan                            | Produces the final result set; use`EXPLAIN` / `EXPLAIN ANALYZE` to inspect it |

Query flow: SQL string → parser → analyzer → optimizer → execution engine → results

---

## 6. Logical Execution Order of SQL

Even though SQL is written in a certain order, the database evaluates clauses in a different logical sequence.

Logical order: FROM / JOIN → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → ORDER BY → LIMIT / OFFSET

Important notes:

- `WHERE` runs before grouping, so it cannot use aggregate results.
- `HAVING` is used to filter groups after aggregation.
- `ORDER BY` can use aliases created by `SELECT`.
- `WHERE` cannot reference column aliases defined in `SELECT`.

Example:

```sql
SELECT department, COUNT(*) AS employee_count
FROM employees
GROUP BY department
HAVING COUNT(*) > 10;
```

Here, `HAVING` is used because the filter is on the grouped result.

---

## 7. Join Types

| Join type  | Meaning                                                                 | Best practice                                         |
| ---------- | ----------------------------------------------------------------------- | ----------------------------------------------------- |
| INNER JOIN | Returns only rows that match in both tables                             | Use for required matches                              |
| LEFT JOIN  | Returns all rows from the left table and matched rows from the right    | Good for preserving left-side records                 |
| RIGHT JOIN | Returns all rows from the right table and matched rows from the left    | Less common; use when right-side is primary           |
| FULL JOIN  | Returns rows from both tables when there is a match in either direction | Useful for complete comparison sets                   |
| SELF JOIN  | Joins a table to itself                                                 | Use for hierarchical or related rows inside one table |

**Performance tips:** join on indexed columns, avoid `SELECT *`, and review `EXPLAIN` for expensive joins.

---

## 8. WHERE vs HAVING

| Clause | Use Case                        | Timing          |
| ------ | ------------------------------- | --------------- |
| WHERE  | Filter rows before grouping     | Before GROUP BY |
| HAVING | Filter groups after aggregation | After GROUP BY  |

Examples:

- `WHERE age > 30` filters individual rows
- `HAVING COUNT(*) > 10` filters grouped results

---

## 9. Document Data Model

| Item               | Meaning                                                     |
| ------------------ | ----------------------------------------------------------- |
| Collection         | Similar to a table                                          |
| Document           | Similar to a row                                            |
| Field              | Similar to a column                                         |
| Example field type | Scalar, nested object, array                                |
| Why it helps       | Flexible schema, no NULL-heavy columns, natural nested data |

```json
{
  "city": "Paris",
  "population": 2100000,
  "location": { "lat": 48.8566, "lng": 2.3522 },
  "top_attractions": ["Eiffel Tower", "Louvre"]
}
```

MongoDB stores documents in BSON, which is binary JSON used internally for efficiency, while applications usually work with JSON.

---

## 10. Embed vs Reference

| Pattern   | Best when                                                        | Pros                                                                | Cons                                                             |
| --------- | ---------------------------------------------------------------- | ------------------------------------------------------------------- | ---------------------------------------------------------------- |
| Embed     | Data is frequently read together and belongs to one logical unit | Single read, better locality, good for read-heavy access            | Duplicates data, harder updates, document size limit issues      |
| Reference | Data is shared across many documents or updated centrally        | Avoids duplication, centralized updates, better for shared entities | Needs extra reads or join-like operations, more app coordination |

**Decision rule:** choose embed for locality; choose reference for shared or large data.

---

## 11. Designing a Document Database

Good document design follows application needs, not just abstract normalization.

### Recommended design steps

1. Gather requirements
2. Choose the database model
3. Identify entities and relationships
4. Choose representation: embed vs reference
5. Add physical design features such as indexes, partitioning, and replication
6. Monitor and evolve as query patterns change

### Example patterns

#### One-to-one

Usually embed if the data is read together.

#### One-to-many

Could be embedded or referenced depending on read patterns and update behavior.

#### Many-to-many

Usually reference because the relationship is shared and naturally cross-linked.

---

## 12. MongoDB Aggregation

MongoDB aggregation is a pipeline of transformations applied to documents.

Common stages:

- `$match` → filter documents
- `$project` → select or reshape fields
- `$group` → aggregate values
- `$sort` → order results
- `$limit` → restrict number of documents
- `$lookup` → join with another collection
- `$unwind` → flatten arrays

Example mapping:

| Mongo stage  | SQL concept |
| ------------ | ----------- |
| `$match`   | WHERE       |
| `$group`   | GROUP BY    |
| `$project` | SELECT      |
| `$sort`    | ORDER BY    |
| `$lookup`  | LEFT JOIN   |

Aggregation is very useful for reporting, analytics, and reshaping data before it reaches the application.

---

## 14. Quick Exam Cheat Sheet

- Relational = tables + SQL + keys + joins
- Document = collections + docs + fields + nested arrays
- Indexing improves lookup and sorting speed
- Normalization reduces duplication
- Constraints enforce correctness
- `WHERE` filters rows, `HAVING` filters groups
- `EXPLAIN` helps inspect query plans
- Embedding improves local reads; referencing reduces duplication and keeps shared data centralized
- MongoDB aggregation is a pipeline of transformations
