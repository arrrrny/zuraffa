---
feature: zfa-tdd-init-missing-flutter-app-deps (bug #1349)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: working-tree of d23bde35 (branch fix/1349-init-missing-zuraffa-flutter-getit-deps)
toolchain: Dart 3.13.3 stable (no Flutter SDK in this sandbox)
behaviors: 7
proven: 7
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 7
criteria_covered: 7
suite: bug_1349 suite 7 passed, 0 failed (red-first: 2 passed / 5 failed pre-fix); init-flow regression 35 passed, 0 failed; dart analyze clean on changed files; dart format 0 changed repo-wide
---

# TDD Verification: zfa tdd init self-heals the Flutter app-module deps (issue #1349)

**Verdict: PASS_WITH_GAPS.** All seven behaviors from `assessment.md` are
`PROVEN` with red-first evidence against the real `zfa tdd init` code
path. The gap is environmental, not evidential: this sandbox has no
Flutter SDK, so the literal issue repro (`flutter create` project →
`flutter test` compile pass) was not executed here; the day-zero compile
contract is verified hermetically at the CLI level instead. No stale or
copied evidence — every run below is from this session.

## Proven behaviors (this session's runs)

| id | behavior | class | evidence |
| -- | -------- | ----- | -------- |
| B-U1 | init adds `zuraffa_flutter: ^6.0.0` + `get_it: ^9.2.1` under `dependencies:` (before `dev_dependencies:`) | PROVEN | green run: `00:00 +7: All tests passed!`; init stdout: `✓ pubspec.yaml dependencies (app module: added: zuraffa_flutter: ^6.0.0, get_it: ^9.2.1)` |
| B-A1 | day-zero surface self-consistent (app.dart exists, imports the barrel, pubspec declares what it imports) | PROVEN | green run asserts the app-module file, its barrel import, and both pubspec entries |
| B-U2 | self-heal idempotent (no duplication on re-run) | PROVEN | green run: `zuraffa_flutter`/`get_it` each exactly once after a second init |
| B-U3 | hand-edited pubspec with complete deps preserved byte-for-byte | PROVEN | green run (fixture seeds both deps + full dev_dependencies; file unchanged) |
| B-U4 | pure-Dart pubspec untouched by the Flutter app deps | PROVEN | green pre-fix AND post-fix (scope invariant) |
| B-U5 | empty inline `dependencies: {}` expanded, no duplicate section | PROVEN | green run |
| B-U6 | malformed `dependencies:` value is a loud writer failure, not a crash | PROVEN | pre-fix exit 0 (red) → post-fix exit != 0 with `writer(s) failed` + `pubspec_app_dependencies_patcher` tag |

## Red-first evidence

Pre-fix run (HEAD d23bde35, before any production change):
`00:00 +2 -5: Some tests failed.` — the 5 failures are exactly the bug
contract (deps never added; malformed pubspec silently accepted); the 2
passes are the preserved invariants. Full transcript pinned in
`tdd/red-evidence.md`.

## Regression scope (changed-file protocol)

Cloud changed-file protocol applied: only the init-flow surface was
re-run, not the full suite (full suite = ~6.5 GB kernel cache, out of
budget here):

- `test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart` → 7/7
- `test/cli/writers/tdd/bug_1260_skin_dependency_patcher_test.dart`
  (skin opt-in interplay with the same `dependencies:` block) — in the
  35-test green run
- `test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart`
  (the sibling self-heal pass) — in the 35-test green run
- `test/plugins/tdd/tdd_command_smoke_test.dart`,
  `test/plugins/tdd/bug_969_json_verdict_envelope_test.dart` (tdd init
  flow + verdict envelope) — in the 35-test green run
- `dart analyze lib/src/plugins/tdd/commands/init_command.dart
  test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart` →
  No issues found!
- `dart format` changed files → clean; repo-wide dry-run:
  `Formatted 2443 files (0 changed)` (exit 0)
- No unrelated pre-existing failures observed in the executed suites.

## Gaps (honest)

1. **No real Flutter-project smoke run.** The sandbox lacks the Flutter
   SDK (`example/` resolve fails: "flutter_test from sdk which doesn't
   exist"). The issue's literal repro was therefore verified by
   structural equivalence (hermetic CliRunner fixtures exercise the real
   init code path against real temp project roots and pin the exact
   pubspec entries the compiler needs), not by a real
   `flutter create && flutter test` cycle. Risk is low: the fix only
   inserts two pubspec entries whose constraints match
   `DependencyWirer.standardSet` / the repo's own resolution, and the
   insertion mechanism is the same textual patcher pattern shipped for
   #1260. Follow-up on a Flutter-equipped machine: run the issue repro
   end-to-end.
2. **Full suite not run** — per the cloud changed-file protocol above;
   CI is expected to cover the remainder.
3. **Audit written by the same session** that wrote the fix and tests
   (single-agent run); the rubric's independent-audit preference is not
   satisfiable in this environment.

## Verdict inputs

- criteria_total 7 / criteria_covered 7
- test_after 0 (every assertion authored red-first, before the fix)
- high_smells 0 (no time-dependence, no order-coupling, fixtures hermetic)
- mutation sampling: not run (no `mutation_test` cycle executed in this
  session; the suite's assertions pin exact constraint strings and
  section placement, which the red run shows are load-bearing)
