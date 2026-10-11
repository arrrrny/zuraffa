# TDD Verification: dart format Robustness in a Fresh Clone [SPEC 1506]

**Feature ID:** 1506-format-fresh-clone-robustness
**Issue:** #1506
**Verified:** 2026-09-13, Dart SDK 3.13.2 (the SDK CI's format job pins)

## 1. Test-first evidence

Cycle log: [cycle-log.md](cycle-log.md).

- RED recorded BEFORE implementation existed: both new test files failed
  at load (`FormatRunner` missing, `EntityCommand` lacked the
  `formatRunner` seam) — no behavior could pass pre-implementation.
- GREEN recorded after the minimal implementation: `00:00 +8: All tests
  passed!` for `test/commands/format_runner_1506_test.dart` +
  `test/commands/entity_format_scope_1506_test.dart` (U1–U8).
- No test was weakened during the green phase; two strictly-additive
  fixes are documented in the cycle log (runner result semantics caught
  by U3; test fakes made production-faithful re: pub-get side effects).

## 2. Acceptance-criteria coverage (spec.md Success Criteria)

| # | Criterion | Evidence |
|---|-----------|----------|
| 1 | Fresh-clone CLI format path cannot emit repeated resolution warnings — `dart format` never spawned without resolution | U3 (pub get enforced before format), U4 (unresolvable → formatter NEVER spawned, single warning); integration U8 (order through `EntityCommand`) |
| 2 | After `dart pub get --no-example`, `dart format lib test` is a no-op | Reproduced: fresh clone → `Formatted 2591 files (868 changed)`; after pub get → `Formatted 2591 files (0 changed)`. Post-fix repo: `dart format .` → `Formatted 2763 files (0 changed)` |
| 3 | CLI format invocation scoped to `lib/src/domain/entities`, never `.` / bare `lib` / `test`; tree-wide scope raises `ArgumentError` before spawning | U2 (guard: `.`, `./`, `..`, the absolute package root and its parent), U5/U6 (scoped args, trimmed/normalized, forbidden elements absent), U7 (entity integration: exactly one invocation, args `['format', 'lib/src/domain/entities']`) |
| 4 | Pub-get enforcement in every documented workflow | AGENTS.md hard rule amended (#1506 rationale); `.github/agents/surgical-pr-fix.agent.md` step 6 amended; CI format job verified already compliant (`.github/workflows/ci.yaml`: `dart pub get --no-example` with the resolution-rationale comment, then `dart format --set-exit-if-changed lib test`) — verified-no-change |
| 5 | `dart analyze lib test` zero new issues | Post-change: 112 issues, 0 errors, 0 warnings — identical to the pre-change baseline (112 pre-existing infos) |

## 3. Test-smell rubric

- **Assertion-less tests:** none — every test asserts observable
  behavior (invocation order, argument contents, result flags, warning
  text).
- **Tautological/mirrored assertions:** none — expectations pin exact
  command strings (`dart pub get --no-example`, `dart format
  lib/src/domain/entities`), not re-derivations of the implementation.
- **Test interdependence:** none — each test builds its own temp
  fixture; `Directory.current` is switched per test and restored
  (the #1322 fixture convention).
- **Non-hermetic tests:** none — the process runner is injected; no
  test spawns a real formatter or a real pub (verified: all 8 tests run
  in ~0.00–0.06s of setup-independent time).
- **Behavior-pinning brittleness:** the exact `--no-example` flag and
  the entity-tree scope are asserted deliberately — they ARE the
  regression contract for #1506, not incidental coupling.

## 4. Mutation check (test strength)

Candidate mutants and whether the suite kills them (manual analysis
against the recorded assertions; the fast-lane runtime of the two files
is <1s, so re-running after any mutant is cheap):

| Mutant | Killed by |
|--------|-----------|
| Remove the pub-get enforcement (format immediately) | U3, U8 (order assertions) |
| Spawn format despite failed pub get | U4 (formatter-never-spawned) |
| Skip the resolution check when config exists | U5 (no pub get on the fast path) |
| Accept `.` scope silently | U2 (ArgumentError + no process) |
| Compare only the literal `.` (let `..`/absolute root through) | U2 (`..`, the package root, and its parent all rejected) |
| Reformat args (drop/duplicate/pad scope paths) | U6, U7 (exact invocation args) |
| Drop the formatter output (leave `result.output` unset) | U5 (captured summary carried in the result) |
| Report `pubGetRan: false` after enforcement | U3 (result flag) — this exact mutant was caught during the green phase |
| Emit per-file warnings instead of one | U4 (single-warning contract) |

## 5. Constraint compliance

- Hard constraint "fix ONLY format invocation patterns + pub-get
  enforcement": the diff touches `FormatRunner` (new), `EntityCommand`
  format wiring, two docs, and two new test files. The make command, the
  TDD state machine, and the pass registry (`refactor_passes.dart`,
  receipt-pinned `dart format lib/`) are untouched — see spec.md
  Problem section and plan.md D5 for the exclusion rationale.
- Regression: `dart test test/commands/` — 378 tests, all passed
  (includes the pre-existing #1322 preflight fixture exercising the
  same `EntityCommand` constructor seam).
- `dart format .` idempotence after the change: 0 files changed.
