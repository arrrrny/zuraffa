# Test List: dart-core-lane-timeout-overflow (#1632)

**Feature**: `.specify/bugs/dart-core-lane-timeout-overflow` (bug TDD mode)
**Source**: `spec.md` — plan derived via `zfa tdd plan` (4 acceptance + 4 unit
+ 2 contract behaviors, all routed; the zfa-emitted revision of this file with
its routing provenance is preserved in git history of this session). Loop
executed via the **LLM-guided fallback path** — the skills' engine detection
contract (`ZFA_MISSING`, no `.zfa.json` in this repo) and the driver's own
honest stop at `A1:make` (vacuous-green: the acceptance scenarios of a
CI-budget bug carry no renderable contract assertion) both route this bug
class to the hand-driven loop, matching the `tdd-doctor-feature-positional`
(#1585) precedent on this repo.
**Suite**: `test/tier_integrity_test.dart` — the fast-lane pins ride the
existing tier gate (B5/B6 added; B1–B4 stay green).

## Unit behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1 | every fast-lane-eligible suite matching a heavyweight criterion (spawns external processes, or an analyzer/compile self-hosting gate) carries `e2e` or `slow` | FR-001 | unit | DONE | test/tier_integrity_test.dart (B5) |
| U2 | every regression-tier file is kept off the CI fast lane by `slow` or `e2e` (tier-only tags leak into every default `dart test`) | FR-002 | unit | DONE | test/tier_integrity_test.dart (B6) |
| U3 | the census pin is fast and pure (reads sources and tags, runs no suites) and enumerates offenders in its failure reason | FR-003 | unit | DONE | test/tier_integrity_test.dart (B5 failure reason) |
| U4 | the dart_core test step runs the residual lane with `--concurrency=4` and a truthful budget comment; the B3/B4 pins are unaffected | FR-004 | unit | DONE | .github/workflows/ci.yaml (dart_core step) |

## Acceptance behaviors

| id | behavior | criterion | state |
| -- | -------- | --------- | ----- |
| A1 | pre-fix tree: the census FAILS, enumerating the untagged heavyweight offenders (./red-evidence.md) | AC-1 | DONE |
| A2 | tagged tree: the census passes with an empty offender list; `dart analyze lib test` reports 0 errors / 0 warnings from the annotation edits | AC-2 | DONE |
| A3 | the residual fast lane completes under 8 minutes on CI hardware — CI attribution: 1759s measured serial lane on run 34951330675 minus the tagged heavy suites leaves a 736s serial residual; at the restored `-j4` runner-default parallelism that projects to ~4–5 min. Confirmed by this PR's own dart_core CI run | AC-3 | DONE |
| A4 | `test/tier_integrity_test.dart` 7/7 green — the #1382/#1510 pins (B1–B4) unaffected by the retagging | AC-4 | DONE |

## Coverage

- U1 traces to FR-001 (A1/A2): the census is the assertion surface; the
  heavyweight population it pins is the 2026-09-15 CI attribution (run
  34951330675) plus the structural spawn/compile criteria (durable against
  future drift).
- U2 traces to FR-002 (A2): 17+ regression-tier files carried tier-only tags
  at HEAD; every regression-tagged file now carries `slow` (the corpus
  convention) or keeps its deliberate #1510 `['regression', 'e2e']` form.
- U4 traces to FR-004 (A3/A4): the scoped `--concurrency=4` restores the
  runner-default parallelism for the pure-Dart unit lane only; the heavy
  temp-project lanes keep the global `concurrency: 1` guard.
