## Full solution summary: performant, cacheable paginated unit listing

**The problem**: ~90 pages, 30 units each, each unit has details + image. Need speed and scalability.

### 1. Query optimization

- Index all filter/sort columns (city, price, bedrooms, status)
- Replace `OFFSET`-based pagination with **keyset/cursor pagination** (`WHERE id > last_id LIMIT 30`) — offset gets slower the deeper you paginate; keyset stays fast on page 90 just like page 1
- Select only listing fields (id, thumbnail, price, size, bedrooms, status) — never `SELECT *`; fetch full detail only on the unit detail page
- Consider denormalizing/materializing the listing view if data is normally spread across joined tables

### 2. Caching layers

- **CDN/edge cache**: cache full page responses keyed by `page + filters + sort`. Since there are only ~90 pages, the whole listing is cacheable
- **Redis/app cache**: same keying strategy for raw data — useful if rendered HTML differs per user even though underlying data doesn't
- **Database**: only hit on a cold cache; benefits from the indexing/keyset work above
- **Cache the total count** separately — don't recompute `COUNT(*)` on every request

### 3. Page 1 gets special treatment

- Highest-traffic page, typically identical for all users → best caching ROI
- Longer TTL, or **write-through** (refresh cache immediately on any unit create/update/delete) since it's hit constantly
- Cache a handful of common filter/sort variants of page 1 explicitly (default, popular filters); everything else falls back to standard per-page caching

### 4. Image handling (separate, decoupled path)

- Serve via a dedicated **image CDN**, not the app server
- Pre-generate **thumbnails** sized for the grid — never serve full-res images in a listing
- Lazy-load (`loading="lazy"`) so only visible images load
- Use modern formats (WebP/AVIF) with responsive `srcset`

### 5. Invalidation strategy

- Two options, pick based on freshness needs:
  - **Short TTL** — simple, small staleness window, no invalidation logic
  - **Targeted invalidation on write** — more precise, more complex (only wipe the cache key for the affected page)

### Net result

Most requests are served from CDN or Redis without ever touching the database. The DB only handles cold-cache misses and deep, rarely-visited pages — and even those are fast thanks to indexing and keyset pagination.
