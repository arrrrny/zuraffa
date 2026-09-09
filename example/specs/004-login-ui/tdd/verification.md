# TDD Verification — feature `004-login-ui`

Generated fresh by `zfa tdd verify --feature 004-login-ui`.

## Gate

- gate: `fail_survived`

## Mutation buckets (FR-014)

- killed: 48
- survived: 8
- timed_out: 0

## Behavior scope (FR-018)

- `W1` — traces: `FR-001`
- `A3` — traces: `AC-3`
- `A4` — traces: `AC-4`
- `A5` — traces: `AC-5`
- `A6` — traces: `AC-6`
- `A7` — traces: `AC-7`

## Behavior kinds (issue #1376)

- presence: 2
- absence: 1
- route-outcome: 2
- enabled-state: 1
- sequence: 1

- `W1` — not traced: no scenario-assertions header in test/presentation/pages/login/login_view_test.dart
- `A3` — presence
- `A4` — route-outcome
- `A5` — absence
- `A6` — enabled-state
- `A7` — presence, route-outcome, sequence

## Restoration (FR-021)

- restoration_verified: true
- restoration_scope_count: 6
- restoration_scope (subjects only, never tests):
  - `/home/z/my-project/zuraffa/example/lib/tdd/004-login-ui/a3_subject.dart`
  - `/home/z/my-project/zuraffa/example/lib/tdd/004-login-ui/a4_subject.dart`
  - `/home/z/my-project/zuraffa/example/lib/tdd/004-login-ui/a6_subject.dart`
  - `/home/z/my-project/zuraffa/example/lib/tdd/004-login-ui/a7_subject.dart`
  - `/home/z/my-project/zuraffa/example/lib/src/presentation/pages/login/login_view.dart`
  - `/home/z/my-project/zuraffa/example/lib/tdd/004-login-ui/a5_subject.dart`

## Repro diagnostics (FR-020, non-sensitive)

- runner_command: `dart run mutation_test`
- exit_code: 0
- elapsed_seconds: 436
- report_path: `/home/z/my-project/zuraffa/example/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md`
- preflight_scope_ran (bug #924, per-behavior):
  - `/home/z/my-project/zuraffa/example/test/tdd/004-login-ui/a3_test.dart`
  - `/home/z/my-project/zuraffa/example/test/tdd/004-login-ui/a4_test.dart`
  - `/home/z/my-project/zuraffa/example/test/tdd/004-login-ui/a6_test.dart`
  - `/home/z/my-project/zuraffa/example/test/tdd/004-login-ui/a7_test.dart`
  - `test/presentation/pages/login/login_view_test.dart`
  - `test/tdd/004-login-ui/a5_test.dart`

## Mutation run

- mutation_was_run: true
- mutation_score: 0.8571

## Survived mutants (bug #837)

- `lib/tdd/004-login-ui/a4_subject.dart:49`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/example/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/004-login-ui/a7_subject.dart:59`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/example/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/src/presentation/pages/login/login_view.dart:25`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/example/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/src/presentation/pages/login/login_view.dart:36`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/example/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/src/presentation/pages/login/login_view.dart:75`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/example/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/src/presentation/pages/login/login_view.dart:232`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/example/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/src/presentation/pages/login/login_view.dart:298`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/example/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/src/presentation/pages/login/login_view.dart:298`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/example/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)

## Evidence binding (bug #837)

- spec_hash: 6b85c7e6f952479b86bc8b879e74ff3a2c96c5625cdc7f1bdce8cc9d31bfd957
- subject_hash: `/home/z/my-project/zuraffa/example/lib/src/presentation/pages/login/login_view.dart` c18ab31c029e09036edd487317a79f5631365b3b15b5692e28668f034b23c28c
- subject_hash: `/home/z/my-project/zuraffa/example/lib/tdd/004-login-ui/a3_subject.dart` 0bf3fc39fdefbe8cffe10fd3fadeddc19390af5780211eeae1e567a47508de4d
- subject_hash: `/home/z/my-project/zuraffa/example/lib/tdd/004-login-ui/a4_subject.dart` 823b158b5bffbd49cfd79ab4e30bb2f6b6bac743179decaba92d06b5c2a2639f
- subject_hash: `/home/z/my-project/zuraffa/example/lib/tdd/004-login-ui/a5_subject.dart` f3026f8ee4ab3feff3991619acb26dc46d40cdff33ed2596ca3929971f57f45f
- subject_hash: `/home/z/my-project/zuraffa/example/lib/tdd/004-login-ui/a6_subject.dart` 77520b2244471e120a6e3ed55cf21d9ff77ef05ab4fe04a53e3cc0ec52110d2c
- subject_hash: `/home/z/my-project/zuraffa/example/lib/tdd/004-login-ui/a7_subject.dart` a2d1a99d73db32e15abb7f7876616e37a3796cd8dc698f4df4cbbda2eb9abdeb
