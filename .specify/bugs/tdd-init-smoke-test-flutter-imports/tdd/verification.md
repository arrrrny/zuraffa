---
feature: tdd-init-smoke-test-flutter-imports
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: ea399d96 (branch fix/664-tdd-init-smoke-test-flutter-imports, pre-commit)
behaviors: 3
proven: 2
likely: 0
test_after: 1
no_test: 0
high_smells: 0
criteria_total: 2
criteria_covered: 2
mutation_score: n/a # no mutation tool in profile; deliberate mutant 1/1 caught
mutants_survived: 0
suite: writer unit suite 7/7 (+3 new), app_module_writer 6/6, tdd_command_smoke + tdd commands 69/69 all green; end-to-end pure-Dart fixture `dart test` 1/1 green post-fix and 0/1 RED pre-fix; flutter fixture content check unchanged (flutter_test + app.dart still emitted); dart analyze on changed files 0 issues
---

# TDD Verification: `zfa tdd init` smoke test respects project flavor — pure Dart no longer gets Flutter imports (#664)

**Verdict: PASS_WITH_GAPS.** The flavor gate is real and end-to-end: the same
pure-Dart fixture that failed `dart test` pre-fix ("Couldn't resolve the
package 'flutter_test'") passes post-fix ("All tests passed!"), the Flutter
path renders byte-identical Flutter content (existing tests unchanged and
green), and a deliberate gate-drop mutant was caught by exactly the new
assertions. Gaps: two of the three behaviors are only PROVEN at the
unit/render level while the end-to-end regression guard for the Flutter path
is TEST_AFTER (the repo's flutter-tagged day-zero suite needs a Flutter SDK
this environment does not have, so the Flutter fixture was verified at
content level, not by `flutter test` execution), and the audit is
same-session, not a fresh-context subagent pass.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — `zfa tdd init` on a pure Dart package produces a smoke test that only imports `package:test`, and `dart test` is green on day zero | PROVEN | RED observed pre-fix on the fixture `/home/z/my-project/tmp-fixtures/fresh_dart_pkg` (pubspec: `sdk: ^3.11.0`, no flutter key): generated `test/bootstrap_smoke_test.dart` line 2 = `import 'package:flutter_test/flutter_test.dart';` and `dart test` failed with `Couldn't resolve the package 'flutter_test' in 'package:flutter_test/flutter_test.dart'.` + `00:00 +0 -1: Some tests failed.` Post-fix, same fixture re-run: smoke test line 2 = `import 'package:test/test.dart';`, `dart test` → `00:00 +1: All tests passed!`. Unit pin: `smoke_test_writer_test.dart` group "issue #664 — pure Dart flavor" (render + write + idempotence) |
| B2 — a Flutter project still receives the Flutter smoke test (`package:flutter_test` + `<AppName>Container` app-module assertion) — no regression | TEST_AFTER | guard behavior, no red-first run (the fix must not change the Flutter path). Content check on fixture `/home/z/my-project/tmp-fixtures/fresh_flutter_pkg` (pubspec declares `flutter: sdk`): `zfa tdd init` still emits `import 'package:flutter_test/flutter_test.dart';` + `import 'package:fresh_flutter_pkg/app.dart';` + `lib/app.dart (created)`. Existing 4 writer tests (default `isFlutter: true`) pass unmodified — they pin the Flutter render contract including `MyappContainer`/`ZikZakTddContainer` (issue #626). The Flutter-execution regression guard `test/integration/day_zero_smoke_gate_test.dart` is flutter-tagged and requires a Flutter SDK; not executable here, content-level check substituted |
| B3 — the pure-Dart path preserves the skip-if-exists sentinel (existing user content never clobbered) | PROVEN | new unit test `write() stays idempotent for the pure Dart flavor`: second `write()` returns null and the hand-written `// Custom user test` body survives; the sentinel was already green pre-fix (an existing file was never overwritten — the bug was the generated content, not the sentinel), so this behavior is proven at unit level with the mutant confirming the assertions can fail |

No pre-existing test was weakened: the 4 original cases in
`smoke_test_writer_test.dart` run byte-for-byte unchanged (their assertions
pin the Flutter path, which is intentionally untouched);
`tdd_command_smoke_test.dart`'s `zfa tdd init on an empty directory is
idempotent` runs unchanged and green (the pure-Dart fixture now receives the
Dart smoke test — the file-exists assertion still holds). No assertion was
loosened, no test skipped or renamed out of a filter's reach, no threshold
lowered.

## Deliberate mutants (no mutation tool in the profile; sampling on the changed gate)

| # | Mutant (one small change, restored exactly after) | Result |
| --- | --- | --- |
| 1 | Gate dropped: `render()` reduced to `_renderFlutter(appName)` (flavor ignored, historical unconditional behavior) | CAUGHT — 2 failures for the RIGHT reason: `Expected: contains 'import 'package:test/test.dart';'` / `Actual: 'import 'package:flutter_test/flutter_test.dart';'` on both pure-Dart render and write tests (+5 -2: Some tests failed). Restored exactly (`isFlutter ? _renderFlutter(appName) : _renderPureDart()`); re-run: +20 All tests passed! |

Restored exactly after the mutant; writer suite + app_module_writer +
tdd_command_smoke re-run green after restoration (+20, 0 failures). Sampling
covers the changed branch's only decision point (the render gate); the
skip-if-exists sentinel and the Flutter render body were not mutated — they
are explicitly out of scope for this fix.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | Environment (not this change): no Flutter SDK in this environment, so the Flutter regression guard was verified at content level (generated bytes) rather than by executing `flutter test` on a Flutter fixture. The repo's own flutter-tagged day-zero suite covers execution and remains green on CI where the SDK exists | fixture content check (B2); `test/integration/day_zero_smoke_gate_test.dart` tagged flutter, skipped by fast tier per dart_test.yaml |
| 2 | LOW | `setup_command.dart:467` still constructs `const SmokeTestWriter()` with the default `isFlutter: true`. Intentional: `zfa setup` generates Flutter scaffolds (its `PubspecDevDependenciesPatcher` is hardcoded `isFlutter: true` two lines below), so the default preserves its contract. If `zfa setup` ever targets pure Dart, it must pass the flag explicitly | `lib/src/commands/setup_command.dart:467-480` |
| 3 | LOW | Same-session audit (Hard Rule 2): tests and fix were written in this session, so the smell pass is not independent. Mitigation: the new tests follow the file's established style (tmp fixture, `setUp`/`tearDown`, `p.join` paths) and the mutant pass was executed blind against the assertions before any result was recorded | session transcript; mutant log ordering |

## Traceability

| Issue criterion (expected behavior) | Behavior(s) | Test(s) |
| --- | --- | --- |
| "For pure Dart projects, SmokeTestWriter should … generate a Dart-compatible smoke test that uses package:test" (issue #664 Expected Behavior, option 2) | B1 | `test/cli/writers/tdd/smoke_test_writer_test.dart` group "issue #664 — pure Dart flavor" (3 cases); end-to-end fixture `dart test` green |
| "…zfa tdd init on a Flutter project → smoke test still uses package:flutter_test (no regression)" (assessment §Tests to add or update) | B2 | original 4 writer tests unchanged + flutter fixture content check; day_zero_smoke_gate_test.dart (flutter-tagged, CI-only execution) |
| "Skipping the file entirely must not break downstream tooling" (assessment §Risks — satisfied by choosing option 2, write a Dart test, keeping the file present) | B3 | idempotence unit test + `tdd_command_smoke_test.dart` init-idempotent case (file exists on second run) |

Both issue criteria are covered; no test traces to nothing (every new test
maps to a criterion above).

## What was not audited

- `flutter test` execution on a real Flutter fixture (no Flutter SDK in this
  environment) — the Flutter path is verified at the render/content level
  only, plus the unmodified existing unit pins.
- Mutation testing via `mutation_test` (no mutation tool configured in this
  environment's profile run) — deliberate mutant sampling substituted,
  scope limited to the changed render gate.
- The rest of the fast suite beyond the writer/CLI/TDD command chunks listed
  in `suite:` was not re-run per-bug; the shared chunked run is recorded once
  for the combo (see final verification summary).
