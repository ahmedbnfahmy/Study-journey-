# Video summary: Database Storage — Part 2

**Source:** [Database Storage - Part 2 (English) with Amr Elhelw — Tech Vault](https://www.youtube.com/watch?v=lpkEwChGFH8)  
**Channel:** Tech Vault · **Runtime:** ~34 min · **Published:** 2024-03-05  

**Slides:** [TechVault_Database_Storage_Part2.pdf](https://github.com/aelhelw/techvault/blob/main/Relational_Database_Internals/TechVault_Database_Storage_Part2.pdf)

**Prerequisite:** [Database Storage — Part 1](https://youtu.be/sE-PWl_fd40) · **Arabic:** [Part 2 (Arabic)](https://youtu.be/8-LJyyAjOhE)

---

## Goal

Go inside a **data page**: page metadata, how **tuples** are laid out, how reads/updates work, tradeoffs between **slotted** vs **log-structured** layouts, and how a **tuple’s bytes** are interpreted (including alignment and large fields).

**Scope:** Row-oriented (**tuple-based**) table pages—not column stores, index pages, or log/WAL pages unless noted.

---

## Page header

Each page has a **header** with metadata, for example:

- Page size  
- Compression / encoding hints  
- Which DBMS wrote the page  
- Free space and similar bookkeeping  

Actual row data sits below that header using some layout strategy.

---

## Naive layout (same-size tuples, append-only)

Idea: header stores **tuple count**; tuples are **fixed size** and appended sequentially.

**Problems**

- **Deletes:** count drops but gaps remain—you cannot infer the next insert offset from `count × size` without compaction or extra bookkeeping.  
- **Variable-length tuples:** same counting trick breaks.

So production systems use richer structures (typically **slotted pages**).

---

## Slotted pages

Used in systems such as **PostgreSQL** and **SQL Server** (as described in the video).

**Structure**

- **Slot directory** at one end of the page (fixed-size slots): each slot is effectively an **offset/pointer** to a tuple.  
- **Tuple bodies** grow from the **other** end of the page inward.

Growth meets in the middle—good space utilization.

**Operations**

- **Insert:** write tuple body at the next free spot toward the middle; add/update slot entry.  
- **Delete:** remove tuple body (or leave hole); mark slot empty / null pointer—slot array may keep a placeholder.  
- **Compaction:** optionally shuffle tuple bodies to consolidate free space.

**Locating a tuple:** slot index → read pointer → fetch tuple at offset.

---

## Record ID (row ID / tuple ID)

A **physical locator** for a tuple: unique within the table (naming varies by product).

Typically encodes or maps to something like:

- **File ID** → which data file  
- **Page ID** → which page (often via the file’s **page directory**)  
- **Slot number** → which entry in the slot array  

Mapping may be an encoding, a function, or an internal structure.

Some systems expose a **hidden “row id” column**; often it is **not** stored redundantly inside every tuple.

**Read path (conceptual):** split record ID → open file → page directory finds page on disk → load page → use slot → follow pointer to tuple bytes.

---

## Insert / update I/O (slotted pages)

Rough accounting from the video:

- **Insert:** often read **page directory** + target **data page** → **at least two page reads** before writing (assuming deferred flush).  
- **Update:** directory + data page; **in-place** if new values fit the same tuple size (e.g. same-sized types).  
- If **variable-size change** (e.g. longer string): **delete old tuple + insert new version** (new location), similar cost pattern to insert.

**Downsides of slotted-page style**

- Multiple **random I/O** touches (directory + scattered pages for many updates).  
- **Fragmentation:** holes after deletes; new tuple may not fit remaining slack → spill to another page → wasted space inside pages.

---

## Log-structured pages (append-only log per page / LSM flavor)

Used in systems mentioned such as **HBase**, **Cassandra**, **RocksDB** (log-structured merge).

**Idea:** treat the page as an **append-only log** of **operations**, each tagged with **tuple ID**:

- **Set** — insert or update (full tuple payload for that write).  
- **Delete** — tombstone for that ID (no payload).

Latest **visible state** for an ID is the **last log entry** for that ID when scanning **newest → oldest**.

**Writes**

- Always **append** at the end (in memory, then flush full pages sequentially).  
- **Sequential disk writes** when flushing; no in-place rewrite of old pages for each update.  
- **No internal fragmentation** like slotted holes—but **version duplication**: many SETs for one ID waste space until compaction.

**Reads**

- Naively scan backward for the last entry with that ID — costly across memory + many on-disk pages.  
- **Per-ID index** can map tuple ID → **latest entry** (RAM or disk); index must be maintained on each append.

**Compaction**

- Merge old pages: keep **only the latest** SET per ID (and honor DELETEs).  
- Write **new** pages sequentially; old pages marked obsolete / GC’d separately.  
- After compaction, tuples can be **sorted by ID** on that compacted segment to speed lookup (binary search), while **new** writes stay **time-ordered** until the next compaction.

**Compaction cost**

- Heavy **read + CPU** (scan, pick winners, rewrite).  
- May **lock** files or segments → can slow concurrent access.  
- Trade **write amplification vs read efficiency vs space**.

---

## Tuple layout (single row)

At lowest level a tuple is **bytes**: **header** (metadata) + **payload** interpreted using **catalog/schema** (names, types, order—not something the OS understands natively).

---

## Alignment and padding (word boundaries)

CPUs read in **word-sized** chunks (e.g. 32/64-bit). Attributes that **span word boundaries** are awkward to load.

**Typical approach:** **padding** so attributes start on word boundaries and avoid spanning words where possible—slightly **larger on-disk size** than raw sum of attribute sizes, simpler reads.

---

## Large / variable-length attributes

If a field **fits in a word** (or fixed layout rules allow), store inline.

If **too large** (long text, `VARBINARY`, etc.):

- Store **pointer** in the tuple → overflow area (**another page**).  
- Very large objects (**BLOB**s) may live in **separate files** with only a locator in the tuple; those files may be managed externally.

---

## Summary takeaway

| Aspect | Slotted pages | Log-structured |
|--------|----------------|----------------|
| Writes | In-place / relocate; more random I/O | Append-only; sequential flush |
| Reads | Direct via slot | Needs latest-version resolution (+ index helps) |
| Space | Fragmentation possible | Duplicate versions until compaction |
| Compaction | Optional per-page | Central to reclaiming space |

No single layout wins everywhere—**read vs write ratio**, data size, and product constraints drive the choice; many engines expose **different storage/page strategies** for different workloads.
