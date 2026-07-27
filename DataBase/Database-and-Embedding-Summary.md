# Database Types, Embeddings, and Vector Databases

There are several common types of databases, depending on how they store and query data.

## Main Types of Databases

### 1. Relational Databases
Store data in tables with rows and columns.

Examples:
- PostgreSQL
- MySQL
- SQL Server

Good for:
- structured business data
- joins
- transactions
- reporting

### 2. Document Databases
Store data as JSON-like documents.

Examples:
- MongoDB
- Couchbase

Good for:
- flexible schemas
- application data that changes shape often

### 3. Key-Value Databases
Store data as key-value pairs.

Examples:
- Redis
- DynamoDB

Good for:
- caching
- sessions
- very fast simple lookups

### 4. Graph Databases
Store data as nodes and relationships.

Examples:
- Neo4j
- ArangoDB

Good for:
- connected data
- recommendations
- legal or document relationships
- fraud and network analysis

### 5. Vector Databases
Store embeddings and support similarity-based search.

Examples:
- Chroma
- Pinecone
- Weaviate
- Milvus

Good for:
- semantic search
- RAG
- similarity matching

### 6. Time-Series Databases
Optimized for storing and querying data over time.

Examples:
- InfluxDB
- TimescaleDB

Good for:
- metrics
- monitoring
- sensor data

## In This App

- MongoDB = document database
- Neo4j = graph database, and also used here as a vector database
- Chroma = vector database

One database can sometimes play more than one role. In this app, Neo4j is mainly graph-based, but it is also being used for vector search.

---

## What does “embedded” mean?

“Embedded” means converting text into a list of numbers that captures its meaning.

For example, a sentence like:

> “What are the rules for banking contracts?”

can be transformed into something like:

```text
[0.12, -0.44, 0.91, ...]
```

This numeric representation is called an embedding.

### Why we use embeddings

- Similar meanings produce vectors that are close to each other.
- This allows searching by meaning instead of only by exact words.
- A query like “bank loans” can match text about “credit agreements” even if the wording is different.

### In this app

- Neo4j embeddings are used for the legal corpus.
- Chroma embeddings are used for uploaded PDFs and crawled pages.

So when people say “embed the documents,” they usually mean:

1. Split text into chunks.
2. Convert each chunk into a numeric vector.
3. Store those vectors in a vector database.
4. Retrieve the closest chunks later when a user asks a question.

---

## What is a vector database?

A vector database is a database that stores embeddings, meaning numeric vectors that represent text, images, or other data, and allows searching for the closest meaning.

### Normal database

- Stores rows and columns
- Good for exact lookup like “find user with id = 5”

### Vector database

- Stores vectors like `[0.12, -0.44, 0.91, ...]`
- Good for “find documents most similar in meaning to this question”

### Example

If a user asks:

> “rules for ending a work contract”

then:

1. The question is converted into a vector.
2. The database compares it with stored document vectors.
3. It returns the chunks whose vectors are closest.

So instead of exact keyword matching, it uses similarity search.

### Why it matters

- Finds relevant text even when wording is different.
- Powers RAG and semantic search.
- Helps the LLM answer using retrieved context.

### Short definition

A vector database is a database optimized for storing embeddings and retrieving the most semantically similar items.
