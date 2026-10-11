# TDD Verification Report: Simulation Worlds — `zfa simulate --scenario`

**Feature**: 968-simulation-worlds
**Verified**: 2026-09-05
**Branch**: `spec/968-simulation-worlds` (from master `512a8189`)
**Mode**: outer+inner (test-list.md: 10 acceptance + 9 unit behaviors)
**SDK**: Dart 3.13.3 (stable), linux-x64 — pure Dart, no Flutter SDK

---

## Verdict: **PASS**

All 19 behaviors (A1–A10 acceptance, U1–U9 unit) are green, each backed by
an executed test in `test/simulation/worlds/` and committed world evidence
under `specs/968-simulation-worlds/tdd/worlds/`. The one failing suite in
the full fast run (`test/plugins/cache`, 2 tests) is pre-existing on
origin/master — proven by a clean-worktree baseline run (below), unrelated
to this spec.

---

## Executed verification commands (real outputs)

| # | Command | Result |
|---|---------|--------|
| 1 | `dart analyze lib test` (CI gate: `--no-fatal-warnings`) | exit 0 — no errors, no warnings in branch files (11 warnings found and fixed during verification; remaining infos match repo baseline) |
| 2 | `dart format --output=none --set-exit-if-changed lib test bin` | `Formatted 2085 files (0 changed)` — zero format diff |
| 3 | `dart test test/simulation/worlds/` | `+103: All tests passed!` |
| 4 | `dart test test/simulation/` (includes legacy `--scaffold`/`--scenario`/`--verify-guard` surface) | `+192: All tests passed!` |
| 5 | `tools/run_tests_chunked.sh` (fast suite, 83 chunks) | 77 chunks ran tests — all green, 3,276 tests; 4 chunks no fast-tier tests; `test/plugins/cache` **+44 −2 — both failures pre-existing on master** (see baseline below) |
| 6 | `zfa simulate verify-world checkout-flow --feature 968-simulation-worlds` | exit 0 — `world-hash=33a393b3b92b certified=4 methods run-receipt=green verdict=GREEN` |
| 7 | `zfa simulate run checkout-flow --feature 968-simulation-worlds --replay` | exit 0 — `replay: deterministic (digest match) (1dc0b12bd015 vs 1dc0b12bd015)` |

### Pre-existing failure baseline (not this branch)

`test/plugins/cache/cache_adapter_receipt_test.dart` fails 2 tests
("a cache-adapter receipt lands in .zfa/receipts/ with the full payload",
"the receipt binds the entity source as its spec" — a receipt `kind`
naming drift from spec #975). Verified pre-existing: a clean
`git worktree` of origin/master `512a8189` under the same SDK fails the
same 2 tests (`+44 −2`). `cache_compile_test.dart` flaked once in its
`(setUpAll)` under chunked-batch load and passes standalone
(`+1: All tests passed!`). Nothing in this spec touches cache code.

---

## Behavior coverage map

### Acceptance (outer loop)

| id | Behavior | Witness |
|----|----------|---------|
| A1 | init scaffolds the world from the declared dependency table | `simulate_worlds_command_test.dart` — "A1" group: manifest written, both touchpoints, parsed methods, time/latency/failure models, corpus |
| A2 | init certifies the world + cycle-log evidence | `simulate_worlds_command_test.dart` — cert `world_hash` recomputed from committed bytes; 4/4 methods `satisfied: true`; schema-1 hash chain |
| A3 | init refuses without a dependency table | `simulate_worlds_command_test.dart` — "A3": non-zero + `zfa tdd plan` fix hint |
| A4 | run executes deterministically under virtual time, writes receipt | `simulate_worlds_command_test.dart` — "A4": GREEN, world-hash, virtual-ms > 0, wall ~0; determinism: two runs same digest |
| A5 | mutated world invalidates the green receipt | `simulate_worlds_command_test.dart` — "A5": re-run refuses, no stale green; re-certify greens against the new hash |
| A6 | `--replay` proves digest equality | `simulate_worlds_command_test.dart` — "A6" + executed replay above (digest match) |
| A7 | differential gate: mock world vs real adapter harness | `world_differential_gate_test.dart` + committed `tdd/world-differential-report.json` (5 behaviors: 4 parity + 1 storm-proof, drift 0) |
| A8 | RetrySyncEngine survives the network-flap storm (virtual backoff) | `retry_sync_engine_test.dart` — flap storm green within budget, virtual clock advances, wall ~0 |
| A9 | auth expiry short-circuits; partial write repaired; budget exhaustion RED | `retry_sync_engine_test.dart` — attempts=1 on auth, re-push repair, honest red + ledger |
| A10 | verify-world CI gate (hash triple) | `simulate_worlds_command_test.dart` — "A10": green triple → 0; drift → 1 naming the delta; unknown scenario → fix hint |

### Unit (inner loop)

| id | Behavior | Witness |
|----|----------|---------|
| U1 | manifest parse/round-trip, canonical hash, fix hints | `world_manifest_test.dart` |
| U2 | virtual clock determinism, no wall time | `virtual_clock_test.dart` |
| U3 | latency bands sampled deterministically | `latency_model_test.dart` |
| U4 | failure storms fire at declared indices/times | `failure_schedule_test.dart` |
| U5 | runtime: latency + injection + corpus + play ledger | `world_runtime_test.dart` |
| U6 | retry engine: backoff, budget, ledger, short-circuit, repair | `retry_sync_engine_test.dart` |
| U7 | certifier proves contracts by invocation | `world_certification_test.dart` |
| U8 | differential gate parity/drift/report | `world_differential_gate_test.dart` |
| U9 | receipts: proof.v1 + world hash, replay equality, invalidation | `world_run_receipt_test.dart` |

---

## Committed world evidence

- `tdd/worlds/checkout-flow.world.json` — the scenario manifest (touchpoints FirebaseAuth + RestSync, time model seed 968, latency bands, network-flap / auth-expiry / partial-write storm schedule, corpus, 5-behavior program)
- `tdd/worlds/checkout-flow.cert.json` — live certification receipt (4/4 declared methods, world hash `33a393b3…`)
- `tdd/world-differential-report.json` — world vs real-adapter differential: verdict `pass`, drift 0, the auth-expiry storm rehearsed as an honest world-lane red
- `tdd/cycle-log.md` — schema-1 hash-chained evidence: world-cert (init), re-certification, world-runs (GREEN, 8 plays, 667 virtual ms), final `--replay` verification

## Honest-deficit disclosure

- The 2 `test/plugins/cache` failures are master's, not this branch's (baseline-proven); they are NOT fixed here (one-PR scope).
- `test/plugins/tdd/services`-adjacent chunks were green in the chunked run; no other suite regressed.
