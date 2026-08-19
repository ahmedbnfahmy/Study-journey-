# Backend Interview Answers

## 1) Describe a backend system you personally owned end to end in production

I personally owned an order and payments orchestration service for a marketplace platform. I was the main backend engineer responsible for the system from design through production support. My role included defining the API contract, designing the database schema, implementing the core business logic, setting up monitoring, and managing deployments.

What I built was a service that handled order creation, payment authorization, inventory reservation, and downstream notifications. I also built the operational tooling needed to support it in production, including alerting, logs, dashboards, and rollback procedures. When the system broke, I was accountable for diagnosing the issue quickly, communicating the impact to stakeholders, and coordinating a safe mitigation plan.

In one incident, we saw a spike in payment failures after a deployment. I investigated the logs, traced the error path, and identified that a new validation rule was too strict for a specific payment provider. I rolled back the change, restored service stability, and then added stronger regression tests so the issue would not recur. That experience reinforced the importance of observability, staged rollout, and clear ownership in production systems.

## 2) Give a specific example of a Node.js performance or memory issue you diagnosed in production

One production issue I diagnosed was a Node.js service that gradually increased memory usage until the process was restarted by the container runtime. The symptom was steady growth in RSS memory after each processing batch, which eventually caused latency spikes and occasional crashes.

I started by capturing heap snapshots and comparing them over time. I also used Node’s built-in profiler and a memory flame graph to understand where allocations were accumulating. The root cause turned out to be a queue consumer that kept references to processed messages in an in-memory cache without ever clearing them. In addition, a retry path was creating new objects for each failure and retaining them in a long-lived structure.

The fix was to limit the cache size, clear references once work was complete, and change the retry flow to avoid retaining stale objects. I also added better logging around memory pressure and set alerts to trigger before the service reached the restart threshold. That reduced memory growth significantly and improved stability under load.

## 3) How do you guarantee that a financial operation is never double-applied when a client retries a request?

To guarantee that a financial operation is never applied twice, I use an idempotency-first approach at both the API and database layers.

At the API layer, the client sends an idempotency key with every mutating request, such as a wallet debit or purchase. The server stores the key along with the request fingerprint, status, and response body. If the same key is received again, the service returns the original response instead of executing the operation a second time. This protects the system even when the client retries due to timeout or network failure.

At the database layer, the operation is wrapped in a transaction and uses a unique constraint on the idempotency key or operation identifier. The debit itself is executed as an atomic update, such as reducing the balance only if sufficient funds exist. If the same operation is retried, the database will detect the duplicate key and return the previously stored result rather than applying a second debit. In addition, I prefer using a ledger table so every financial action is recorded as an immutable event, which makes auditing and reconciliation much easier.
