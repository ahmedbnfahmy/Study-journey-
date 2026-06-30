# Data Structures

Specialized formats for organizing, processing, retrieving, and storing data.

**Practice problems:** [Problems.md](./Problems.md)

---

## Core Concepts

### Abstract Data Type (ADT)

- Logical description of operations (what they do)
- Implementation-independent specification
- Examples: List, Stack, Queue, Tree

### Time Complexity

- Measures how execution time grows with input size
- Expressed in Big O notation: O(1), O(log n), O(n), O(n²)

### Space Complexity

- Measures memory usage relative to input size

---

## Arrays

Contiguous memory locations storing elements.

**Types**

- Static (fixed size)
- Dynamic (resizable)

**Operations**

| Operation | Complexity |
| :--- | :--- |
| Access | O(1) |
| Search | O(n) |
| Insertion / Deletion | O(n) |

**Use cases:** Storing collections, matrix operations

---

## Hash Table

Stores key-value pairs and allows for fast data retrieval.

- **Hashing function** — converts a key into a numeric index (hash code)
- **Array storage** — holds entries at computed indices

**Operations**

| Operation | Complexity |
| :--- | :--- |
| Fast lookup | O(1) |
| Dynamic sizing | — |
| No duplicate keys | — |

**Use cases:** Databases, caching

---

## Linked Lists

Nodes containing data + pointer to next node.

**Types**

- Singly linked (unidirectional)
- Doubly linked (bidirectional)
- Circular (tail points to head)

**Operations**

| Operation | Complexity |
| :--- | :--- |
| Access | O(n) |
| Insertion / Deletion | O(1) at head/tail |

**Use cases:** Stacks, queues, memory management

---

## Trees

Hierarchical structure with parent-child relationships. Only one path between any two nodes.

**Operations**

| Operation | Complexity |
| :--- | :--- |
| Insert / Delete / Search | O(log n) |

**Use cases:** File systems, database indexing (B-trees)

---

## Queues

FIFO (First-In-First-Out) structure.

**Operations**

| Operation | Complexity |
| :--- | :--- |
| Enqueue (add) | O(1) |
| Dequeue (remove) | O(1) |

**Variations**

- Circular queue
- Priority queue
- Double-ended queue (Deque)

**Use cases:** Task scheduling, buffering, BFS algorithms

---

## Stacks

LIFO (Last-In-First-Out) structure.

**Operations**

| Operation | Complexity |
| :--- | :--- |
| Push (add) | O(1) |
| Pop (remove) | O(1) |
| Peek (top element) | O(1) |

**Implementation:** Arrays or linked lists

**Use cases:** Function calls, undo/redo, syntax parsing

---

## Graphs

Nodes (vertices) + edges (connections). Cycles allowed.

**Operations**

| Operation | Complexity |
| :--- | :--- |
| Traversal (typical) | O(V + E) |

**Use cases:** Social networks, routing, dependency graphs

---

## Summary Table

| Data Structure | Description | Key Operations | Types / Variations | Use Cases |
| :--- | :--- | :--- | :--- | :--- |
| **Array** | Contiguous memory locations storing elements | Access O(1), Search O(n), Insert/Delete O(n) | Static, Dynamic | Collections, matrix operations |
| **Hash Table** | Key-value pairs with fast retrieval via hashing | Lookup O(1), dynamic sizing, no duplicate keys | — | Databases, caching |
| **Linked List** | Nodes with data + pointer to next node | Access O(n), Insert/Delete O(1) at head/tail | Singly, Doubly, Circular | Stacks, queues, memory management |
| **Tree** | Hierarchical parent-child structure; one path between any two nodes | Insert/Delete/Search O(log n) | Binary, B-tree, etc. | File systems, database indexing |
| **Queue** | FIFO (First-In-First-Out) | Enqueue O(1), Dequeue O(1) | Circular, Priority, Deque | Task scheduling, buffering, BFS |
| **Stack** | LIFO (Last-In-First-Out) | Push O(1), Pop O(1), Peek O(1) | Array or linked list impl. | Function calls, undo/redo, parsing |
| **Graph** | Vertices + edges; cycles allowed | Traversal O(V + E) | Directed, Undirected, Weighted | Social networks, routing, dependencies |

---

## Notes

<!-- Add examples, links, and language-specific notes here -->
