# TDD Verification — feature `1195-differential-harness-mock-vs-real`

Written from the ACTUAL runs performed on this branch (every command below
was executed; outputs are quoted from the transcripts, not asserted).
Toolchain: Dart 3.13.3 (stable) on linux_x64 (`dart --version`). Flutter is
not installed in this environment — the pure-Dart CLI lanes and the fast
suite run without it; Flutter-dependent tiers are out of scope here.

## Gate

- gate: `passed`
- analyze: `dart analyze` (whole repo) → **0 errors, 0 warnings**, 135
  info-level lints (all pre-existing in untouched files — the
  `lib/tdd/0966-*` subject naming and `world_utils.dart` type-literal
  idioms classes; the spec's own files analyze clean:
  `dart analyze lib/src/plugins/tdd test/plugins/tdd` → `No issues
  found!`)
- fast suite (chunked): the ranged driver of `tools/run_tests_chunked.sh`
  (`tools/run_chunks_range.sh 1-15 … 76-90`, six foreground ranges)
  → **90/90 chunks, 0 failed — 84 chunks with fast-tier tests all
  reported `All tests passed!`, 6 reported the runner's SKIP (no
  fast-tier tests), 3,553 tests passed, 0 failed**
- targeted neighbors: `dart test test/plugins/tdd/commands/
  realize_mock_command_test.dart corpus_differential_command_test.dart
  test/plugins/route/spec_971_t004_route_verify_test.dart` → **32/32
  passed** (the realize-adjacent surfaces that consume the
  `realize-diff.v1` fixture shape and the `RealizeSuiteRunner` seam)
- format: `dart format .` → first pass formatted the spec's 4 files
  (the harness test's map literals); second run → `Formatted 2373
  files (0 changed)`

## Red → green evidence (the loop, honestly)

### RED (reproduced on the pre-change tree)

```
$ dart test test/plugins/tdd/services/differential_harness_test.dart \
             test/plugins/tdd/commands/realize_diff_only_test.dart
  Failed to load "…differential_harness_test.dart":
  …: Error when reading
  'lib/src/plugins/tdd/services/differential_harness.dart': No such
  file or directory
  …: 'RealizeFixtureDriver' isn't a type.
  …: 'DifferentialHarness' isn't a type.
  …: Undefined name 'DifferentialVerdict' / 'DiffDimension'
                       → load failure (the machinery does not exist)

$ dart run bin/zfa.dart tdd realize User --diff-only
  ❌ Could not find an option named "--diff-only".
  Usage: zfa tdd realize <entity|behavior> --adapter <real> [options]
                       → exit 64 (no standalone differential mode)
```

The old `DifferentialGate` (spec 913) driven over a fixture pair whose
real side diverges in the contract dimensions (state drift + one-sided
error):

```
verdict: drift
findings (the old string-blob lens):
  - [missing-field] get-by-id-u1: field "error" only on the real side
  - [field] signup-u2: field "id" drifts — mock "u2" vs real "u9"
  - [field] signup-u2: field "state" drifts — mock "ACTIVE" vs real "PENDING"
report schema: realize-diff.v1
journal block: false
rows (structured named rows): false
```

No dimension classification (entity value drift counted against the
budget), string-blob findings, no journal block, no fixture digest, no
named rows — and the differential could only run inside the full swap
flow. "Contract suite green on the real adapter" was trust, not proof.

### GREEN (the same commands on this branch)

1. **SC-1 + SC-3 (harness + determinism) — unit tier, 10/10:**

   ```
   $ dart test test/plugins/tdd/services/differential_harness_test.dart
     B-001 … not a divergence (parity is shape, not bytes)
     B-002 … NAMED row (fixture, field, dimension, clause, input, …)
     B-003 … state-transition drift is a row in the state dimension
     B-004 … error-kind mismatch and one-sided error presence
     B-005 … default threshold 0.0 is strict; inclusive boundary
     B-006 … deterministic receipt — same bytes; digest changes
     B-007 … journal-consumable (#1113) — schema, gate_state, refs
     B-008 … skipped, never a vacuous pass
     B-009 … runner-error — the gate fails closed
     B-010 … `clauses` / `contract` maps override
     → All tests passed!
   ```

2. **SC-2 + SC-5 (command tier) — the real CLI, end-to-end
   (`zfa tdd realize User --diff-only` against a temp project with a
   committed signup fixture and the project-owned
   `tool/realize_driver.dart`):**

   Passing replay:

   ```
   $ dart run bin/zfa.dart tdd realize User --diff-only --feature 1195-demo
     zfa tdd realize --diff-only: entity User replayed against the real binding
        era: MOCKED
        differential replay pass: 0 row(s) / 3 compared field(s) <= threshold 0.0
        receipt: specs/1195-demo/tdd/differential-receipt.json
                 (mode diff-only, digest sha256:94c968afe577...)
     realize: entity=User adapter=- feature=1195-demo contract=-
              differential=pass drift=0.0 threshold=0.0 handDeltas=0
              era=MOCKED result=diff-clean            → exit 0
   ```

   Replay determinism (run again, sha256 the receipt):

   ```
   REPLAY BYTES IDENTICAL: 173ee1c87cd83f33421a5a3084e04ab188ed589…
   ```

   Divergent real adapter (PENDING where the mock certified ACTIVE):

   ```
     differential replay DIVERGENCE: 1 named row(s) — the mock and the
     real adapter disagree on contract behavior…
     divergence: signup-u2/state (state transition) — field "state"
                 state transition drifts — mock "ACTIVE" vs real "PENDING"
       clause: SC-2: signup lands the user in ACTIVE
       input: {"op":"signup","email":"x@y.z"}
       mock:  {"id":"u2","email":"x@y.z","state":"ACTIVE"}
       real:  {"id":"u9","email":"x@y.z","state":"PENDING"}
     realize: … differential=divergence … result=diff-divergence  → exit 1
   ```

   Note the honest lens: the entity payload drift (`id` `u2` vs `u9`)
   produced NO row (same shape — value drift on entity data is not
   contract); the state outcome did, with the fixture's declared clause.

   The receipt on disk (journal-consumable, #1113):

   ```
   { "schema": "realize-diff-receipt.v1",
     "feature": "1195-demo", "entity": "User", "adapter": "-",
     "mode": "diff-only", "verdict": "divergence",
     "threshold": 0.0, "divergence": 0.333333,
     "fixtures": { "count": 1,
       "digest": "sha256:94c968afe577…f03faf16" },
     "replayed": 1, "compared": 3,
     "rows": [ { "fixture": "signup-u2", "field": "state",
       "dimension": "stateTransition",
       "clause": "SC-2: signup lands the user in ACTIVE",
       "input": {"op":"signup","email":"x@y.z"},
       "mockOutput": {"id":"u2","email":"x@y.z","state":"ACTIVE"},
       "realOutput": {"id":"u9","email":"x@y.z","state":"PENDING"},
       "detail": "…" } ],
     "journal": { "gate_state": "red",
       "violations": ["signup-u2/state"],
       "refs": { "fixtures": "specs/1195-demo/tdd/fixtures",
                 "receipt": "specs/1195-demo/tdd/differential-receipt.json" } } }
   ```

3. **SC-2 (embedded promotion gate) — in-process acceptance tests:**

   ```
   $ dart test test/plugins/tdd/commands/realize_diff_only_test.dart \
               test/plugins/tdd/commands/realize_command_test.dart
     B-011 --diff-only runs ONLY the differential (suite poisoned)
     B-012 divergence exits 1, named row, tree untouched
     B-013 embedded realize: within-threshold rows pass but are named
     A1..A5 (updated): full swap, rollback, hand-deltas, thresholds
     → All tests passed! (21 with the harness file)
   ```

## What was PROVED vs not

- PROVED (SC-1..SC-5, all criteria from the issue): same-fixture replay
  through mock + real; contract-relevant diffing (entity shapes / state
  transitions / error kinds) with named rows carrying input, mock
  output, real output, and contract clause; divergence blocks the
  MOCKED→REAL promotion (embedded: rollback + exit 1); determinism
  (byte-identical replay, digest-bound); receipt in the feature's tdd/
  directory, journal-consumable; `--diff-only` standalone replay that
  never touches the tree.
- NOT exercised here: the production `tool/realize_driver.dart` of a
  real consumer project (the protocol is documented; the CLI proof used
  a driver written to the documented protocol), and the journal (#1113)
  itself — it has not landed yet; the receipt's `journal` block is
  shaped for its `gate_state`/`violations`/`refs` fields so the lift is
  mechanical when it does.
