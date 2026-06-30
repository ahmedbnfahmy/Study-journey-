# MongoDB Aggregation

Framework for data processing — transform, analyze, and reshape data before it returns to your application.

---

## The Pipeline Concept

| Step | Description |
| :--- | :--- |
| **Input** | Raw documents |
| **Stages** | A series of operations (filtering, grouping, sorting) |
| **Output** | Final result — often a completely new data shape |

```javascript
db.collection.aggregate([
  { stage1 },
  { stage2 },
  { stage3 }
])
```

---

## Stages vs SQL

| Stage | SQL Equivalent | Description |
| :--- | :--- | :--- |
| `$match` | `WHERE` | Filters documents. Only matches pass to the next stage. |
| `$group` | `GROUP BY` | Groups docs by a specific `_id` and calculates totals (sum, avg). |
| `$project` | `SELECT` | Selects specific fields to keep, rename, or calculate. |
| `$sort` | `ORDER BY` | Orders documents (`1` ascending, `-1` descending). |
| `$limit` | `LIMIT` | Limits the number of resulting documents. |
| `$unwind` | N/A | Deconstructs an array field — one output document per element. |
| `$lookup` | `LEFT JOIN` | Joins data from another collection. |

---

## Common Workflow Pattern

Typical advanced pipeline flow:

1. **`$match`** — filter early to reduce workload
2. **`$lookup`** — bring in related data
3. **`$unwind`** — flatten joined data (if you need to filter related data)
4. **`$group`** — calculate statistics
5. **`$project`** — clean up final JSON for the frontend

---

## `$lookup` (Joins)

```javascript
db.users.aggregate([
  {
    $lookup: {
      from: "orders",           // target collection name in DB
      localField: "_id",        // field in 'users' collection
      foreignField: "userId",   // field in 'orders' collection
      as: "userOrders"          // name of the new output array
    }
  }
])
```
