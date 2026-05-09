# Video summary: Transactions (1) — ACID properties

**Source:** [Transactions (1) - ACID Properties (English) with Amr Elhelw — Tech Vault](https://www.youtube.com/watch?v=ac6zw6sn-Wo)  
**Channel:** Tech Vault · **Runtime:** ~37 min · **Published:** 2024-10-01  

**Slides:** [TechVault_Transactions_Part1_ACID.pdf](https://github.com/aelhelw/techvault/blob/main/Relational_Database_Internals/TechVault_Transactions_Part1_ACID.pdf)  

**Arabic:** [Transactions Part 1 (Arabic)](https://youtu.be/ziH5Y4tvQJE)

---

## Transaction processing systems

Systems with a **large shared database**, **many concurrent users**, and expectations for **high availability** and **fast responses**.

Examples: banks, card payments, reservations, e-commerce. Many users perform logical operations at once (withdrawals, transfers, bookings, checkout).

---

## What is a transaction?

From the **application** side: one logical operation made of **several steps** that must succeed **together**.

**Payment example:** read balance → verify funds → debit account → pay merchant → write new balance. If the final persist fails after money moved, the story breaks—so either **all steps commit** or the work is **undone**.

From the **database** side: a **sequence of read and write operations** on **database objects** (tables, rows, columns—abstract “things” the DB can read/write). Middleware/application logic between reads/writes is invisible to the storage layer.

**SQL:** wrap work in a transaction—typically `BEGIN` … `COMMIT` or `ROLLBACK`. If you do not declare a block, **each statement is often its own transaction** (product-dependent). Syntax differs slightly across MySQL, PostgreSQL, Oracle, SQL Server, etc.

---

## Why concurrency?

**Strict serial queue** (one transaction at a time) avoids interference but hurts **throughput**, **latency**, and **resource utilization** (CPU idle during I/O and vice versa).

Real systems run transactions **concurrently** (interleaved operations) but must control correctness—that motivates **ACID** and **isolation levels**.

---

## Concurrent execution example (lost correctness)

Two cardholders on **one account** ($200): pay $50 and $30 **at the same time**. Both read **200**, both subtract locally, both write—last writer wins → balance **170** instead of **120**. Classic **lost update**–style inconsistency when interleaving is unchecked.

---

## ACID (overview)

| Letter | Name          | One-line idea |
|--------|---------------|----------------|
| **A**  | Atomicity     | All steps commit, or none (rollback). |
| **C**  | Consistency   | Move from one **valid** DB state to another (constraints hold). |
| **I**  | Isolation     | Ideally behave like no other transaction ran at the same time. |
| **D**  | Durability    | After **commit**, effects survive later crashes (disk/recovery story). |

---

## Atomicity

**All-or-nothing:** partial progress after failure is invalid (e.g. debit recorded but credit missing → money “vanishes”). On failure before commit, **undo** prior writes of that transaction—restore prior visible state so the transaction can be **retried** cleanly.

Uncommitted writes are **provisional** until `COMMIT`.

---

## Consistency

**Consistency** = database satisfies **declared rules**: primary/foreign keys, nullability, check constraints, business invariants (“A + B = 100”), etc.

A transaction assumes it starts from a **consistent** state and must leave the DB **consistent** after commit.

**Distributed / replicated** systems: one node may be updated before replicas catch up—reads routed elsewhere can see **stale** data. **Eventual consistency:** temporary divergence, convergence over time (e.g. comment not visible immediately after post).

---

## Isolation

**Goal:** concurrent schedules should behave **as if** transactions ran **one after another** (serial **meaning**), without requiring actual serial execution.

**Serial execution** example: transfer T1 finishes (A=400, B=300), then T2 adds 50 to A → **A=450, B=300**. Some **interleavings** reproduce that result; others do not.

### Common anomalies

- **Lost update:** one transaction’s write **overwrites** another’s (e.g. second write uses stale read—first update effectively disappears).
- **Dirty read:** read **uncommitted** data from another transaction. Harmless in some schedules; dangerous if the writer **rolls back**—reader built on **ghost** state (example: T2 reads A=400, T1 aborts → A back to 500, but T2 committed **450**).
- **Non-repeatable read:** same transaction reads the same row **twice** and sees **different committed values** because another transaction **committed** in between—not dirty, but unstable from T1’s perspective.

Isolation is a **spectrum**: stricter isolation → safer results, often **less concurrency**.

---

## Isolation levels (SQL-style ladder)

From weakest to strongest:

1. **Read uncommitted** — may read uncommitted data. **No** dirty-read protection; highest concurrency, weakest correctness guarantees.
2. **Read committed** — reads see only **committed** data. **Prevents dirty reads**; **does not** prevent non-repeatable reads.
3. **Repeatable read** — reads within a transaction see a **stable snapshot** as of transaction start (effectively: repeated reads of the same key get the **same** answer). Addresses **non-repeatable reads** (as typically defined at this level).
4. **Serializable** — execution equivalent to **some serial order** of transactions. Strongest guarantees; most restrictive on concurrency.

Exact behavior varies by product (especially **phantom reads** and edge cases—video focuses on dirty / non-repeatable / lost update intuition).

---

## Durability

Once the system acknowledges **commit**, effects must **persist** across power loss, disk faults, etc.—typically **write-ahead logging**, redo/recovery, replicated disks, etc.

**In-memory databases** may offer weaker or optional durability (volatile RAM).

---

## Summary takeaway

- A **transaction** groups DB **reads/writes** into one logical unit with **begin/commit/rollback**.
- **Concurrency** is required for performance but enables **lost updates**, **dirty reads**, and **non-repeatable reads** unless the engine enforces **isolation**.
- **ACID** names the guarantees: **atomicity**, **consistency** (constraint-level + replication nuances), **isolation** (levels trade safety vs throughput), **durability** after commit.

---

