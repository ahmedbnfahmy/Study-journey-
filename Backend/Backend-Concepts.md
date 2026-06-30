# Backend concepts

Core server-side and HTTP concepts for APIs and web backends.

| Topic                      | Section                                                     |
| :------------------------- | :---------------------------------------------------------- |
| REST API                   | [below](#rest-api)                                             |
| Middleware vs Interceptors | [below](#middleware-vs-interceptors)                           |
| CORS                       | [below](#cors)                                                 |
| Memory leaks               | [below](#memory-leaks-best-practices)                          |
| Authentication             | [7-Authentication-Concepts.md](./7-Authentication-Concepts.md) |
|                            |                                                             |

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

## Middleware vs Interceptors

Both process HTTP requests and responses in a **pipeline** before they reach application logic (or after). They serve similar goals but run on different sides of the stack.

|                        | **Middleware**                                              | **Interceptors**                                          |
| :--------------------- | :---------------------------------------------------------------- | :-------------------------------------------------------------- |
| **Where**        | Server / application level (globally or per route)                | HTTP client level (e.g. Angular`HttpClient`, Axios)           |
| **Scope**        | Incoming requests before route handlers; outgoing responses after | Outgoing requests before send; incoming responses after receive |
| **Can block?**   | Yes — terminate early (e.g. unauthorized user)                   | No — only transform; cannot stop the request pipeline          |
| **Typical role** | Logging, auth, CORS, body parsing                                 | Add headers, error handling, unwrap payloads                    |

**Middleware use cases**

- Authentication / authorization
- Request logging
- Rate limiting
- Body parsing (e.g. `express.json()`)

**Interceptor use cases**

- Adding auth tokens to headers
- Global error handling (e.g. `401` redirects)
- Response formatting (e.g. unwrapping API payloads)

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
