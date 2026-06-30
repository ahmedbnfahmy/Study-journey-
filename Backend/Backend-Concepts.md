# Backend concepts

Core server-side and HTTP concepts for APIs and web backends.

| Topic | Section |
| :--- | :--- |
| REST API | [below](#rest-api) |
| CORS | [below](#cors) |
| Memory leaks | [below](#memory-leaks-best-practices) |
| Authentication | [7-Authentication-Concepts.md](./7-Authentication-Concepts.md) |
| MongoDB Aggregation | [../DataBase/MongoDB-Aggregation.md](../DataBase/MongoDB-Aggregation.md) |

---

## REST API

**Representational State Transfer** — a set of principles for designing web-based software systems. Used to build **web APIs** (Application Programming Interface) for web applications.

- Client sends **HTTP requests** to the server; server responds with **HTTP responses**
- Uses **HTTP** as the underlying protocol
- Data represented as **JSON** or **XML**

A **RESTful API** is an API that follows the REST architectural style.

**Request** typically includes:

- Resource identifier (**URI**)
- HTTP method (`GET`, `POST`, `PUT`, `DELETE`)
- Data in the request body or query parameters (when needed)

**Response** contains the requested data, metadata, and **status codes** (e.g. `200`, `201`, `404`).

---

## CORS

**Cross-Origin Resource Sharing** — a browser security mechanism that controls whether a web page can request resources from a different domain than the one that served the page.

CORS prevents unauthorized cross-domain requests. Enable it server-side by setting the appropriate response headers (e.g. `Access-Control-Allow-Origin`).

---

## Memory Leaks — Best Practices

- **Avoid globals** — keep variables scoped
- **Limit caches** — use TTL or LRU caching
- **Remove event listeners** — always clean them up
- **Clear timers** — use `clearInterval` and `clearTimeout`
- **Stream large files** — avoid loading huge files into memory
- **Monitor memory** — track usage in production
