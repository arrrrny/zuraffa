# TDD Test List — Spec 1400

One behavior per line, traced to the acceptance criteria in
[../spec.md](../spec.md).

## Behaviors

| # | Behavior | Trace | Test vehicle |
|---|--------|--------|--------------|
| B1 | The example baseline declares the writer-canonical TDD pair (`mutation_test: ^1.8.0`, `coverage: ^1.15.1`) | FR-1 / AS-1 | `test/package_sdk/bug_1369_example_tdd_baseline_test.dart` (existing structural pin, unchanged) |
| B2 | The example baseline declares NO plain `test` (unresolvable in this Flutter graph) | FR-2 / AS-1 | same structural pin (`isNot(contains('test'))`) |
| B3 | The committed verification.md mutation evidence reproduces at HEAD on the restored tree (mutation_was_run=true, killed=48, survived=8, score=0.8571) | FR-3 / AS-3 / SC-002 | scoped mutation audit run — `dart run mutation_test .dart_tool/zfa/tdd-verify-mutation-repro.xml` in `example/` (report: `.dart_tool/zfa/tdd-verify-report-repro/`) |
| B4 | Adding plain `test: ^1.0.0` back makes the Flutter consumer graph unresolvable (the certified red justifying FR-2) | FR-2 (counter-evidence) | empirical solver run, transcript recorded in [../plan.md](../plan.md) |

## Red protocol (recorded reds)

1. **The issue's red (filing state, 2026-09-09 07:33Z)**:
   `zfa tdd verify --feature 004-login-ui --project example --runner flutter`
   → `Could not find package 'mutation_test'`, `gate: not_assessed`,
   `mutation_was_run: false` (quoted in issue #1400).
2. **The residual red at HEAD (unrelated pre-existing, flagged)**: the
   full-lane verify stops at `gate: preflight_red` via
   `test/tdd/004-login-ui/u1_test.dart`
   (`UnimplementedError: subject_u1 not implemented`, #1377's deliberate
   honest-red stub) — `mutation_was_run: false` at the gate, though the
   evidence-scope preflight (W1 + A3–A7) is green (+8) and the
   dependency half is repaired. Owned by the U1 lane; out of scope here.
3. **The counter-evidence red (B4)**: `test: ^1.0.0` restored →
   `flutter pub get` → version solving failed (#1189/#1370 conflict
   class, live on Flutter 3.47.3 / Dart 3.13.3).

The dependency-restoration half of the red in (1) pre-landed on master
(#1369 + #1370) before this branch was cut, so no new red→green CODE
cycle exists inside this issue's fix-only-pubspec constraint; the green
below CERTIFIES the repaired state with real runs.
