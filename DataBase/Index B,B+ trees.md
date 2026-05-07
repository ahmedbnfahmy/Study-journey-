# Database indexes: B-trees and B+ trees — notes & diagrams

**Source:** [Database Indexes - B and B+ Trees (English) with Amr Elhelw — Tech Vault](https://youtu.be/1fETPYKyb70)  
**Channel:** Tech Vault · **Runtime:** ~35 min · **Published:** 2024-03-12  

**Slides:** [TechVault_Database_Indexes_Btrees.pdf](https://github.com/aelhelw/techvault/blob/main/Relational_Database_Internals/TechVault_Database_Indexes_Btrees.pdf)

---

## Goal

Explain how database indexes speed up lookups, how they are stored on disk, and why **B-trees** and especially **B+ trees** are the usual choice—versus full scans, parallelism, partitioning, and simpler structures like sorted lists or binary search trees.

---

## Finding rows without an index

- **Full table scan:** Read every page, check each tuple for the predicate (e.g. `X = 25`). Simple but expensive on large tables (lots of I/O).
- **Parallel scans:** Multiple threads over disjoint page ranges improve wall-clock time but still touch essentially all pages; adds threading and CPU scheduling complexity.
- **Partitioning:** Split the table by ranges of a key so you can prune whole partitions for predicates on that key. Caveats: uneven partition sizes, extra write path cost to route inserts, and **no help** when filtering on a non-partitioned column (e.g. searches on `Y` when partitioned on `X`).

**Theme:** Indexing (like partitioning and parallelism) aims to **shrink the search space**—fewer pages read means less I/O and faster queries.

---

## What an index is

Conceptually like a **book index**: sorted keys plus **pointers** to where matching rows live. Helps:

- **Point queries:** a single value (may return one or many rows if non-unique).
- **Range queries:** predicates such as `X > 10`, `X BETWEEN 20 AND 30`, etc.

---

## Naive storage: sorted list of (key, pointer)

- Better than scanning the whole table once you find the key, but finding the key may require scanning **many index pages** → **O(n)** in the worst case along the index.
- **Binary search** on a disk-backed sorted list implies **random jumps** between pages—often bad for disk (and still awkward with paging).
- **Inserts/updates** require keeping sort order (shifting entries)—costly.

So real systems use tree structures suited to **paged, sequential-friendly** access.

---

## Binary search tree (BST) as an idea

- Each comparison narrows to left/right subtrees; in a **balanced** BST, search is about **O(log n)**.
- **Problem:** Insert order can produce a **degenerate** (almost linear) tree—back to **O(n)** behavior.
- Nodes still tie keys to data pointers; design must account for **balance** under updates.

---

## B-tree

- Generalization of BST: each node holds **up to K children** and **K−1 keys** (degree **K**). Nodes are typically kept **at least half full** (except root edge cases).
- **Always balanced** via splits/merges on insert/delete—predictable height.
- **More keys per node** → **shorter trees** → fewer node (page) reads—good for I/O when each node maps to a page.
- **Tradeoff:** maintaining balance increases **write** cost vs. a static structure.
- **Range queries** are awkward: following in-order structure means moving **up and down** the tree, re-reading nodes; parent pointers are often not stored, which makes sequential leaf traversal harder.

---

## B+ tree

Two defining differences from the classic B-tree as presented:

1. **Data row pointers only at leaves.** Internal nodes hold **separator keys only** (often **duplicates** of keys that appear in leaves). More keys fit in internal pages → **even fewer levels** and less I/O for root-to-leaf navigation.
2. **Leaf nodes linked in sorted order** (sibling pointers). After locating one boundary of a range, **scan the leaf chain** for the rest—efficient **range queries** without bouncing up the tree.

**Costs:** Duplicated keys in internal nodes use extra space; **writes** still pay for splits and rebalancing.

---

## Diagrams (B-tree vs B+ tree)

Small examples below use **maximum 3 children per node** (at most **2 keys** per node). Real databases use much larger fan-out (hundreds–thousands of keys per page).

### B-tree (classic)

**Ideas**

- Keys appear in **every** level (internal nodes and leaves).
- Each key is paired with a **record pointer** (or child pointer for internals).
- No mandatory leaf-to-leaf links.

**Example**

```
                         [ 25 ]
                        /      \
               [ 10, 18 ]        [ 35, 40 ]
              /    |    \      /    |    \
            ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐
            │…│   │…│   │…│   │…│   │…│   │…│
            └─┘   └─┘   └─┘   └─┘   └─┘   └─┘
             ↑     ↑     ↑     ↑     ↑     ↑
          subtrees / leaves hold keys + row pointers
```

**Lookup `27`:** start at root → `27 > 25` → right child → `27` between `18` and `35` → middle subtree → … until key found at some node, then follow **that key’s row pointer**.

**Range `18 … 35`:** find `18`, then walk in-order up/down (often **re-reads internal nodes**); without parent pointers or leaf chain this is awkward—motivation for B+ trees.

### B+ tree

**Ideas**

- **Internal nodes:** only **separator keys** (routing); **no data pointers** here.
- **Leaves:** **all** keys (often duplicate of separators), each with **row pointer** (or clustered index: whole row).
- **Leaves linked left-to-right** in key order (sibling pointers).

**Same logical keys as above — schematic**

```
                         [ 25 ]
                        /      \
               [ 18 ]             [ 35 ]
              /      \           /      \
            /          \       /          \
      … leads down to sorted leaf level …

Leaves (double-linked in practice; shown as one-way →):

    ┌──────────────────────────────────────────────────────────┐
    │  [5,10]  ──→  [15,18]  ──→  [25,30]  ──→  [35,40]  ──→   │
    └──────────────────────────────────────────────────────────┘
         ↑ each leaf entry: (key, pointer to row / heap TID)
```

**Lookup `25`:** root → internal comparisons → **leaf** only → `(25, ptr)`.

**Range `18 … 35`:** navigate to leaf containing `18`, then **follow leaf links** until past `35` — **no bouncing up** the internal tree.

### Side-by-side (conceptual)

```
B-tree                          B+ tree
────────────────────────────    ────────────────────────────────────
Internal node:                  Internal node:
  key + ptr per key               separator keys only, child ptrs
                                  (more keys fit → shorter tree)

Range scan:                     Range scan:
  climb/descend tree             scan leaf chain after left bound

Space:                          Space:
  ptrs at every level            dup keys in internal nodes;
                                  leaves hold authoritative keys + ptrs
```

### One minimal numeric picture (fan-out 3)

**B-tree** — keys and pointers at internal nodes (`*` = subtree / record):

```
            [ 20 ]
           /      \
    [ 8, 12 ]      [ 30 ]
    /  |  \        /    \
   *   *   *      *      *
```

**B+ tree** — internal `[20]` only splits ranges; **all** keys live in leaves:

```
            [ 20 ]
           /      \
    [ 12 ]          [ 30 ]
    /    \          /    \

Leaves:

    [4,8] ──→ [12,15] ──→ [20,22] ──→ [30]
```

(Numbers are illustrative; duplicates like `20` in internal vs leaf are normal for B+.)

---

## What real DBMSs do

- Most relational engines use **B+ trees or close variants** for secondary indexes.
- **Naming confusion:** “B-tree” in product docs sometimes means the **whole family** (B-tree, B+ tree, hybrids), not only the classic structure.
- **PostgreSQL** example from the video: index structure resembles B-tree branding but **stores tuple identifiers only at leaves** (B+-like); **leaf sibling links** may be absent or differ from textbook B+ trees—implementation-specific hybrids are common.
- **Index-organized tables (IOTs):** table rows live **in** the index leaf pages (Oracle, SQL Server, MySQL, SQLite mentioned)—larger leaves but one less indirection for lookups.

---

## Summary takeaway

- Indexes reduce **read** cost by avoiding full scans; they add **write** and storage overhead (especially with splits/rebalancing in B/B+ trees).
- **Choose indexes** with workload in mind: read-heavy vs write-heavy, and which predicates (point vs range) dominate.
- Advanced topics (clustered indexes, covering indexes, multi-column indexes) are called out as material for a future video.

---