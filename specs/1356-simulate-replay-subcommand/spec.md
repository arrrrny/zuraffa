**Template Version**: `zuraffa-1.0`

# Spec: 1356-simulate-replay-subcommand

GitHub issue: arrrrny/zuraffa#1356 (labels: verify-misfire, spec-drift)
Epic: #1136 Phase A step 4 — "zfa simulate replay <run-id> — Does replay
re-execute deterministic?"

## Summary

The epic documents a `zfa simulate replay` surface; the implemented
subcommands are `init|run|certify|verify-world` only, so the invocation
falls through to the usage screen (exit 2). Determinism IS provable today
via `zfa simulate run --replay` (recorded-seed re-execution, digest
comparison) — but that is not the documented surface. Fix: add the
`replay` subcommand as the documented deterministic-proof entry:
re-execute the recorded run receipt for a scenario and compare world hash
+ run digest.

## Problem

The replay proof exists in pieces (receipt store, recorded seed, digest
comparison inside `run --replay`) but no `replay` subcommand exposes it.
An epic verify agent invoking the documented command gets the usage
screen instead of a proof.

## Locked decisions

1. `zfa simulate replay <scenario> [--feature <f>] [--project <root>]` —
   scenario-keyed (the receipts are scenario-keyed; the epic's
   "<run-id>" maps to the recorded receipt for the scenario).
2. Semantics: load the manifest; load the recorded run receipt for the
   scenario; refuse honestly (exit 1) when the receipt is absent or RED
   or names a different world hash; otherwise re-execute with the
   RECORDED seed and compare the fresh digest to the recorded one.
   Deterministic → exit 0 (`deterministic=true`); mismatch → exit 1
   (`DIGEST MISMATCH`). The recorded receipt is NEVER overwritten by a
   replay (a replay is a proof, not a new run).
3. The replay subcommand joins the #1354 resolution (explicit --feature >
   pinned feature > honest usage error), registers parser-only like the
   other subcommands (bug #856 — the legacy flag surface must keep
   working), writes hash-chained cycle-log evidence (kind world-replay),
   and updates the invocation string + library docs.
4. The differential gate does NOT run in replay (that is `run`'s job);
   replay is the pure deterministic re-execution proof.

## Functional requirements

- **FR-1 (happy path)**: after `init` + `run`, `zfa simulate replay
  <scenario>` exits 0, prints `simulate-replay: scenario=<s> ...
  deterministic=true` with play count and digests, and appends
  world-replay cycle-log evidence.
- **FR-2 (honest refusals)**: no recorded receipt → exit 1 naming the
  missing receipt and the run-first fix; a RED recorded run → exit 1
  (nothing green to replay); a mutated world (hash drift vs the
  receipt) → exit 1 naming both hashes.
- **FR-3 (digest mismatch)**: a recorded digest that does not match the
  fresh digest → exit 1 with `DIGEST MISMATCH` and both digests.
- **FR-4 (integration)**: replay honors the #1354 feature resolution
  (bare positional + pin works), registers without breaking the legacy
  flag surface, and is documented in `--help`/invocation.

## Acceptance scenarios (measurable)

1. **Given** init + run completed for the pinned feature, **when**
   `zfa simulate replay test_world` runs bare, **then** exit 0 with
   `simulate-replay: scenario=test_world` and `deterministic=true`.
2. **Given** only init completed (no run), **when** replay runs, **then**
   exit 1, the message names the missing recorded receipt and the
   run-first fix.
3. **Given** init + run then a mutated world manifest, **when** replay
   runs, **then** exit 1 naming `mutated since the recorded run` with
   both world hashes.
4. **Given** a tampered recorded digest, **when** replay runs, **then**
   exit 1 with `DIGEST MISMATCH` and both digests.
5. **Given** `zfa simulate --help`, **when** inspected, **then** `replay`
   is listed, and the legacy `--scaffold/--feature` flag surface still
   works (bug #856 guard holds).

## Success criteria

- **SC-001**: The epic's step-4 invocation produces a real deterministic
  proof instead of the usage screen.
- **SC-002**: The simulate suites stay green (legacy surface + subcommands).

## Assumptions

- Scenario-keyed receipts satisfy the epic's run-id intent (the recorded
  receipt IS the run identity in the implemented design).
