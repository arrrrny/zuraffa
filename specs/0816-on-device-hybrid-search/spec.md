# On-device hybrid search (spec 816)

Generated search layer: FTS5 keywords + quantized int8 vector index + RRF fusion, unified query API, sync-aware re-index.

## v0 first slice
- FTS5 index generation + basic query API
- Vector column type + cosine search over quantized int8 embeddings
- Hybrid rank fusion (RRF) + golden tests on fixture corpus

## Done when
- Notes example: searching "trip planning ideas" finds untitled Kyoto note, offline
- Index rebuilds after sync merge without duplicates/orphan rows

Status: scaffold only (CLI group `zfa search`). Full generation pending.
