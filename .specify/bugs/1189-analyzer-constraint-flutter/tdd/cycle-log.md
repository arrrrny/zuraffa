# TDD cycle log — Issue #1189 (red → green → refactor → verify)

Toolchain used for every entry below: Flutter 3.47.2 (stable) / Dart
3.13.2, Linux x86_64. All exit codes are real, captured at run time.

## Phase 0 — baseline (pre-fix tree, `git stash` reproduction of HEAD)

- `dart pub get` (root, recurses into example/): **FAIL, exit 1.** Solver
  verdict: `zuraffa from path is incompatible with flutter_test from
  sdk`. Full dump preserved at
  `.specify/bugs/1189-analyzer-constraint-flutter/red-evidence-flutter-pubget.md`.
- `dart analyze lib test` (after `dart pub get --no-example`): exit 0,
  **103 infos** (baseline for T6).

## Phase 1 — RED (bug reproduced before any fix)

- T1 pre-fix: `flutter pub get` in `example/` → **exit 1**
  ("Failed to update packages."). Evidence:
  `red-evidence-flutter-pubget.md`.
- T4 pre-fix: `tools/flutter_smoke_gate.sh` on the stashed (pre-fix)
  tree → **exit 1**, stage 1 message
  `FAIL: example/ failed to resolve — Flutter consumers are broken
  (#1189 regression).` Evidence:
  `gate-red-evidence.md`.

## Phase 2 — GREEN (minimal fix applied)

Fix diff: `test: any` → dev_dependencies; analyzer `^14.3.0` →
`">=14.0.0 <15.0.0"`; analysis_options.yaml info parity; example/
obsolete meta override dropped; gate + CI job added.

- T1: `flutter pub get` in `example/` → **exit 0** ("Got dependencies!").
- T1b: `dart pub get` at root (recursing into example/) → **exit 0**
  ("Got dependencies in `./example`.").
- T2: gate stage 2 → **exit 0**, zero overrides
  (`zuraffa 6.1.0 from path` in the resolved graph).
- T3: gate stage 3 → **exit 0**, `flutter test`: `00:00 +1: All tests
  passed!` — the public surface (including analyzer-importing exports)
  compiles and runs under the consumer graph.
- T5: with a TEMPORARY local `dependency_overrides: analyzer: 14.0.0`
  (never committed), `dart pub get` + `dart analyze lib test` → **exit
  0**. The widened lower bound is honest.

## Phase 3 — refactor

None required. The fix touches only pubspec metadata, one lint ignore,
the example app's obsolete override, and CI wiring. No shipped Dart code
changed, so there is nothing to refactor without expanding scope.

## Phase 4 — regression backstop

- T6: `dart analyze lib test` on the fixed tree → **exit 0, 103 issues**
  — identical count to the pre-fix baseline (the naive fix had produced
  218; the analysis_options.yaml ignore restores parity).
- T7: `tools/run_tests_chunked.sh` (fast suite, 90 chunks, kernel caches
  bounded per chunk) → see `tdd/verification.md` for the final verdict
  and pass/fail counts.

## Housekeeping

All temp artifacts of the experiments (the synthesized smoke app, the
temporary analyzer override edit, the stash ping-pong) were reverted or
auto-cleaned; `git status` at commit time contains only intended files.
