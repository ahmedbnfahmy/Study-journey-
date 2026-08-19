# Performance, Scalability, Database, Caching, Microservices, Queues, Memory, and Security Interview Answers

## ⚡ Performance & Scalability

### 1. An API latency jumps from 100ms to 2 seconds in production. How would you diagnose it?

I would start by checking the full request path rather than assuming one layer is responsible. I would review metrics for p50/p95/p99 latency, error rate, CPU, memory, disk I/O, network, and dependency latency, then correlate them with the time of the spike. Next, I would inspect application logs, distributed traces, and database slow-query logs to find whether the bottleneck is in the app, database, cache, or an upstream service. Common causes include a slow database query, increased lock contention, GC pauses, a failing dependency, or a traffic spike that exceeded capacity.

### 2. Your service suddenly receives 10K+ requests/second. How would you scale it?

I would make the service stateless, place it behind a load balancer, and scale horizontally by adding more instances. I would also enable autoscaling based on CPU, memory, and request rate, and use caching for frequently accessed reads. On the data layer, I would optimize queries, add indexes, use connection pooling, and consider read replicas or sharding if the database becomes the bottleneck. For burst traffic, I would also apply rate limiting, CDN caching, queue-based processing for non-critical work, and async background jobs.

### 3. During peak traffic, the Node.js application stops responding. What would you investigate first?

The first thing I would investigate is whether the event loop is being blocked or the process is under CPU or memory pressure. I would check event loop lag, CPU utilization, heap size, garbage collection behavior, active handles, and database connection usage. I would also inspect whether requests are piling up because of slow external calls, unbounded queues, poor concurrency handling, or a connection pool exhaustion issue.

### 4. How do you detect Event Loop blocking in a production environment?

I would monitor event loop lag using tools such as Node’s `perf_hooks` or APM solutions that expose event loop metrics. A sudden increase in lag, especially in the 100ms+ range, is a strong signal that the event loop is blocked. I would also inspect slow requests, high CPU usage, and stack traces from production profiling to identify which code path is monopolizing the event loop.

### 5. CPU-intensive operations are slowing every request. What architectural changes would you make?

I would move CPU-heavy work off the request path and into background workers or separate services. In Node.js, I would consider worker threads or child processes for heavy computation, and I would also look at reducing unnecessary work, batching operations, and caching results. If the workload is very intensive, I would split it into a dedicated service or use a more suitable runtime for heavy computation.

## 🗄 Database Optimization

### 6. Your database connection pool is exhausted. How do you identify the root cause?

I would check the application’s connection usage, pool size, and the number of active connections versus the database max connection limit. Then I would inspect whether the app is leaking connections, holding them for too long, or creating too many concurrent queries. Slow queries, long transactions, missing transaction cleanup, and improper connection release are common causes. I would also look at DB logs and metrics for waiting queries and lock contention.

### 7. A MongoDB query becomes significantly slower overnight. What would you check?

I would check whether the collection grew unexpectedly, whether indexes are still being used, and whether the query plan changed. I would review the explain plan, query execution statistics, index usage, collection stats, and recent schema changes. I would also inspect whether data distribution changed, whether the server is under load, and whether the query is hitting a large portion of the collection due to missing selectivity.

### 8. Database CPU utilization suddenly reaches 90%. How would you troubleshoot it?

I would identify the highest-cost queries and look for missing indexes, inefficient scans, large aggregations, and hot keys. I would check whether there are many writes, background maintenance tasks, or long-running transactions consuming CPU. If needed, I would optimize the queries, add indexes, reduce write amplification, and scale the database or move some workload to read replicas.

### 9. How do you detect and eliminate N+1 query issues?

I would detect N+1 queries by measuring the number of queries issued per request and by observing repeated fetches for related entities. In ORMs, I would inspect query logs or traces to see one parent query followed by many child queries. I would eliminate them by using eager loading, joins, batching, or aggregation, depending on the data model.

### 10. Which database optimization techniques have improved performance in your projects?

The most impactful techniques are adding the right indexes, projecting only the necessary fields, using pagination, reducing large result sets, and enabling proper connection pooling. I have also improved performance by caching frequent reads, using materialized views for expensive aggregations, partitioning large datasets, and batching writes where possible.

## ⚡ Caching

### 11. Users receive outdated data after updates while Redis is enabled. What might be causing it?

The most common cause is cache invalidation mismatch. The application may be updating the database but failing to invalidate or update the corresponding Redis entry, or the cache may have an old TTL that is serving stale data. Another possibility is write-through/read-through inconsistencies or a race condition during concurrent updates.

### 12. How would you design an effective cache invalidation strategy?

I would use a combination of TTLs, write-through or write-behind invalidation, and event-driven invalidation whenever possible. The most reliable strategy is to invalidate or update the cache when the source data changes. For more complex systems, I would use versioned keys and publish-subscribe events so that all services invalidate stale entries consistently.

### 13. When is caching not the right solution?

Caching is not ideal for highly dynamic or real-time data, very small datasets, or workloads with high write rates and low read rates. It can also be a poor fit when the value of cached data is hard to invalidate correctly or when the data is user-specific and changes frequently.

## 🔗 Microservices

### 14. Service A depends on Service B, but Service B is unavailable. How do you prevent cascading failures?

I would add timeouts, circuit breakers, retries with backoff, and bulkheading so that one failing dependency cannot overwhelm the caller. I would also use rate limiting and degrade the user experience gracefully by serving cached or partial data when the dependency is unavailable.

### 15. What is the Circuit Breaker pattern, and why is it useful?

The Circuit Breaker pattern prevents repeated calls to a failing dependency. When the failure threshold is exceeded, the breaker opens and short-circuits further requests for a time window. This helps protect the system from repeated failures, reduces latency spikes, and gives the failing service time to recover.

### 16. How do you improve resilience between microservices?

I would use clear service contracts, retries with jitter, idempotent operations, health checks, distributed tracing, and asynchronous communication where possible. I would also isolate dependencies with timeouts, circuit breakers, and fallback behavior so that failures are contained.

### 17. How do you handle retries, timeouts, and fallback mechanisms?

Retries should be used carefully, preferably for idempotent operations and with exponential backoff plus jitter to avoid retry storms. Timeouts should be short and explicit so slow dependencies do not tie up threads or connections. Fallbacks can return cached data, default values, a degraded response, or a queued operation for later processing.

## 📩 Queues & Asynchronous Processing

### 18. Why should emails and notifications be processed asynchronously?

They should be processed asynchronously because they are not part of the critical request path. Doing them in the background keeps the API responsive, reduces user-facing latency, and allows the system to handle spikes more gracefully. It also makes retries and failure recovery easier.

### 19. A message queue backlog keeps growing. How would you investigate it?

I would inspect consumer lag, processing time, error rates, dead-letter queues, and the throughput of producers and consumers. I would also check whether a consumer is crashing, whether a message is repeatedly failing, or whether the queue is being flooded by a traffic burst. Scaling consumers and fixing the root cause of slow processing are usually the next steps.

### 20. What is a Dead Letter Queue (DLQ), and when would you use one?

A Dead Letter Queue stores messages that fail processing after repeated attempts. I would use it for poison messages, malformed payloads, or messages that repeatedly cause exceptions so they do not block the main queue indefinitely.

### 21. How do you ensure messages aren't processed multiple times?

I cannot guarantee exactly-once delivery in a distributed system, but I can reduce duplicates by making handlers idempotent and by using idempotency keys or deduplication stores. The usual strategy is at-least-once delivery with deduplication logic on the consumer side.

## 🧠 Memory & Debugging

### 22. Memory usage keeps increasing until the application crashes. How would you debug it?

I would take heap snapshots and compare them over time to find which objects are growing unexpectedly. I would inspect object retention, references, caches, event listeners, and unbounded queues. I would also look for closures or long-lived references that keep data alive longer than intended.

### 23. What approaches help identify memory leaks in production?

Heap dump analysis, allocation profiling, and memory trend monitoring are the most useful techniques. I would also correlate memory growth with deployment versions, request volume, and specific features to identify when and why the leak occurs.

### 24. Which tools have you used for heap dumps, profiling, and performance analysis?

In Node.js projects, I have used the built-in inspector, Chrome DevTools, heap snapshot tools, and profiling libraries such as Clinic.js. In production, I have also used APM tools such as New Relic, Datadog, and AppDynamics for tracing, metrics, and performance analysis.

## 🔒 Security

### 25. What steps would you take to secure a production Node.js API?

I would enforce HTTPS, validate and sanitize all input, use strong authentication and authorization, and store secrets in a secure manager rather than in code. I would also use rate limiting, CORS policies, security headers, dependency updates, logging, and least-privilege database access. For extra protection, I would add WAF rules and monitor suspicious traffic.

### 26. How would you defend login endpoints against brute-force attacks?

I would implement rate limiting by IP and account, add exponential backoff, use CAPTCHA after repeated failures, and support MFA. I would also ensure passwords are hashed with strong algorithms like bcrypt or Argon2, and I would avoid leaking whether a username or email exists in the response.

### 27. How do you mitigate SQL Injection and NoSQL Injection vulnerabilities?

I would always use parameterized queries or query builders rather than string concatenation. In NoSQL databases, I would validate input, use allowlists, avoid directly interpolating user input into query objects, and rely on the ODM or driver’s safe query APIs.
