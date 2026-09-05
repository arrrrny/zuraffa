# Test List: 968-simulation-worlds

## External dependencies

| dependency | type | contract | mock priority |
| ---------- | ---- | -------- | ------------- |
| FirebaseAuth | service | signIn(email, password) -> User, signOut() -> void | P1 |
| RestSync | service | push(batch) -> SyncResult, pull(cursor) -> Page | P1 |

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | `zfa simulate init <scenario> --feature <f>` reads the declared dependency table (#960 output) and writes a committed, diffable world manifest (`tdd/worlds/<scenario>.world.json`) declaring both touchpoints with parsed contract methods, the time model (seed), latency bands, and the default failure-storm schedule. | US1 | DONE |
| A2 | init certifies the world: every declared method invoked through the world runtime, `world-cert.json` records per-method `satisfied: true` + the world hash; cycle-log evidence appended (schema-1 chain). | US1 | DONE |
| A3 | init refuses honestly on a feature with no readable dependency table (non-zero, fix hint `zfa tdd plan`). | US1 | DONE |
| A4 | `zfa simulate run <scenario>` executes the scenario deterministically under virtual time (same seed → same run digest), fires the declared failure storms exactly, never sleeps wall time for latency, and writes a proof-carrying run receipt naming the world hash. | US2 | DONE |
| A5 | Mutating the world after a green run invalidates the receipt: re-run reports the hash drift, exits 1, and no stale green survives on disk. | US2 | DONE |
| A6 | `--replay` re-executes with the recorded seed and proves the run digest matches (#806 composes). | US2 | DONE |
| A7 | The differential gate runs the same behaviors against the mock world AND the direct real-adapter harness; outcome parity required, drift is a named red verdict with a per-behavior report. | US2 | DONE |
| A8 | The demo temporal feature (RetrySyncEngine) survives the network-flap storm within its retry budget with exponential backoff on the virtual clock (wall time ~0, virtual time = latencies + backoffs). | US3 | DONE |
| A9 | Auth-expiry mid-flow surfaces honestly (no blind retry); partial writes are repaired; a storm exceeding the budget is an honest RED. | US3 | DONE |
| A10 | `zfa simulate verify-world <scenario>` is the CI gate: manifest/cert/run-receipt hashes agree → exit 0; any drift → exit 1 naming the delta. `zfa simulate certify <scenario>` re-proves live. | US4 | DONE |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | WorldManifest parses + round-trips; contract strings parse into method pins; canonical hashing is deterministic (sorted keys) and byte-sensitive; validation errors carry `--> fix:` hints. | A1 | DONE |
| U2 | VirtualClock is seed-deterministic; advance/elapsed accounting; never touches wall time. | A4 | DONE |
| U3 | LatencyModel samples deterministic banded latencies (fast/slow/timeout) per touchpoint from the seed; classification matches the declared bands. | A4 | DONE |
| U4 | FailureSchedule fires storms at declared call indices/virtual times: network-flap (HTTP 503), auth-expiry (auth code mid-flow), partial-write (half-written marker); out-of-window calls pass. | A4/A9 | DONE |
| U5 | WorldRuntime invokes touchpoints with latency (virtual clock advance) + failure injection + corpus fixture serving; known-family touchpoints dispatch through the certified #832 adapters; play ledger records per-invocation evidence. | A4 | DONE |
| U6 | RetrySyncEngine: exponential backoff waits advance the virtual clock; retry budget respected; failure ledger complete; auth-class failures short-circuit; partial-write repair re-pushes. | A8/A9 | DONE |
| U7 | WorldCertifier proves declared contracts by invocation (never self-graded); per-method receipts; unsatisfied method → certification red with the method named. | A2 | DONE |
| U8 | WorldDifferentialGate: same behaviors through world binding vs real (direct) binding; per-behavior outcome comparison; drift named; report written to `tdd/world-differential-report.json`. | A7 | DONE |
| U9 | Run receipts: proof.v1-parseable with world hash + run digest + seed + verdict extras; deterministic replay equality; invalidation on world mutation. | A4/A5/A6 | DONE |
