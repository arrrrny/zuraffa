# TDD Verification — feature `bug-tdd-run-baseline-timeout`

Generated fresh by `zfa tdd verify --feature bug-tdd-run-baseline-timeout`.

## Gate

- gate: `fail_survived`

## Mutation buckets (FR-014)

- killed: 26
- survived: 14
- timed_out: 0

## Behavior scope (FR-018)

- `A1` — traces: `AC-1`
- `A2` — traces: `AC-2`
- `U1` — traces: `FR-001`
- `A3` — traces: `AC-1`

## Restoration (FR-021)

- restoration_verified: true
- restoration_scope_count: 4
- restoration_scope (subjects only, never tests):
  - `/home/z/my-project/zuraffa/lib/tdd/bug-tdd-run-baseline-timeout/a2_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/bug-tdd-run-baseline-timeout/a3_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/bug-tdd-run-baseline-timeout/u1_subject.dart`
  - `/home/z/my-project/zuraffa/./lib/tdd/bug-tdd-run-baseline-timeout/a1_subject.dart`

## Repro diagnostics (FR-020, non-sensitive)

- runner_command: `dart run mutation_test`
- exit_code: 255
- elapsed_seconds: 49
- report_path: `/home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md`
- preflight_scope_ran (bug #924, per-behavior):
  - `/home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a2_test.dart`
  - `/home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a3_test.dart`
  - `/home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/u1_test.dart`
  - `test/tdd/bug-tdd-run-baseline-timeout/a1_test.dart`

## Mutation run

- mutation_was_run: true
- mutation_score: 0.6500

## Survived mutants (bug #837)

- `lib/tdd/bug-tdd-run-baseline-timeout/a2_subject.dart:35`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/bug-tdd-run-baseline-timeout/a2_subject.dart:35`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/bug-tdd-run-baseline-timeout/a2_subject.dart:36`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/bug-tdd-run-baseline-timeout/a2_subject.dart:36`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/bug-tdd-run-baseline-timeout/a2_subject.dart:49`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/bug-tdd-run-baseline-timeout/a2_subject.dart:49`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/bug-tdd-run-baseline-timeout/u1_subject.dart:32`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/bug-tdd-run-baseline-timeout/u1_subject.dart:41`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/bug-tdd-run-baseline-timeout/u1_subject.dart:46`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/bug-tdd-run-baseline-timeout/u1_subject.dart:47`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/bug-tdd-run-baseline-timeout/u1_subject.dart:57`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/bug-tdd-run-baseline-timeout/u1_subject.dart:57`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/bug-tdd-run-baseline-timeout/a1_subject.dart:53`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)
- `lib/tdd/bug-tdd-run-baseline-timeout/a1_subject.dart:53`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/./.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)

## Evidence binding (bug #837)

- spec_hash: f891e088eb713218ddfe208a5c39fb19ec433729d85261dc24a60a175c76703a
- subject_hash: `/home/z/my-project/zuraffa/./lib/tdd/bug-tdd-run-baseline-timeout/a1_subject.dart` d833feb13f1b4a84f8cca73de9a9aaf153e9258083220452cab05dc1224f9f6a
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/bug-tdd-run-baseline-timeout/a2_subject.dart` 244c0533a645f3e46bc02f67919cd38bba6608d97532af5b2e964e1d04ac57d4
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/bug-tdd-run-baseline-timeout/a3_subject.dart` cc17513d6cb88c8fe253f7cafc9f5e0d890a0af1744180e342e5ac989554f732
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/bug-tdd-run-baseline-timeout/u1_subject.dart` 5ffdc37ef046e7c0509cc8f12da63dd93f36e2ef14639baafe0ce2f28942b90a
