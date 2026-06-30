# Docker

**Status:** To study

---

## What is Docker?

Think of Docker as a **digital shipping container system for software**.

Before physical shipping containers, loading cargo onto ships was chaotic — oil barrels, banana crates, and flour sacks mixed together. A leak ruined everything. Docker solves the same problem for software: it packages an app and everything it needs into an **isolated container** that runs the same on your laptop, a test server, or the cloud.

---

## The Core Problem Docker Solves

Every developer has said: *"Well, it worked on my machine!"*

Different OS versions, libraries, and configs cause apps to fail in production. Docker eliminates this — the app travels in its own predictable container and behaves the same everywhere.

---

## Key Docker Concepts

| Term | Analogy | What it is |
| :--- | :--- | :--- |
| **Dockerfile** | The recipe | Text file of commands: OS, software to install, files to copy, commands to run |
| **Image** | Cake mix | Read-only template built from the Dockerfile — code, libraries, dependencies. Cannot run directly; it's the blueprint |
| **Container** | The cake | Live, running instance of an image. Start, stop, move, or delete in seconds. Multiple containers can run from one image |
| **Docker Hub** | Grocery store | Online registry of shared images — pull pre-made WordPress, MySQL, Python environments instead of building from scratch |

Also useful:

- **Volume** — persistent storage outside the container filesystem
- **Network** — how containers talk to each other and the host

---

## Docker vs Virtual Machines (VMs)

Both isolate applications, but very differently.

**Virtual Machines** — full copy of an OS + app + binaries per VM. Heavy, slow to start (minutes), resource-heavy (gigabytes of RAM).

**Docker Containers** — share the host OS kernel. Only package app logic and dependencies. Lightweight (megabytes), boot in milliseconds.

| Feature | Virtual Machines | Docker Containers |
| :--- | :--- | :--- |
| **Size** | Gigabytes (GB) | Megabytes (MB) |
| **Startup time** | Minutes | Milliseconds |
| **Resource usage** | High (fixed RAM/CPU) | Low (uses only what it needs) |
| **Efficiency** | Heavyweight | Extremely lightweight |

---

## Why Docker is Popular

- **Consistency** — "It works on my machine" is a thing of the past
- **Isolation** — conflicting software versions on the same machine don't interfere
- **Microservices** — split a monolith into small pieces (login, cart, database — each in its own container)
- **Scalability** — spin up many identical containers in seconds under traffic spikes

---

## Commands to Know

- `docker build`, `docker run`, `docker ps`, `docker logs`, `docker exec`
- `docker compose up` / `down` for multi-container apps

---

## Notes

<!-- Add Dockerfile examples, links, and project notes here -->
