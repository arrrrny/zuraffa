# TDD Verification — feature `004-login-ui`

Generated fresh by `zfa tdd verify --feature 004-login-ui`.

## Gate

- gate: `fail_survived`

## Mutation buckets (FR-014)

- killed: 8
- survived: 1
- timed_out: 0

## Behavior scope (FR-018)

- `A1` — traces: `AC-1`
- `A2` — traces: `AC-2`
- `A3` — traces: `AC-3`
- `A4` — traces: `AC-4`
- `A5` — traces: `AC-5`
- `A6` — traces: `AC-6`
- `U1` — traces: `FR-001, LoginValidation.validate`
- `U2` — traces: `FR-002, LoginValidation.validate`
- `U3` — traces: `FR-003, LoginValidation.validate`
- `U4` — traces: `FR-004, AuthGateway.signIn`
- `U5` — traces: `FR-005, AuthGateway.signIn`
- `U6` — traces: `FR-006, LoginValidation.validate`
- `contract:A1` — traces: `LoginValidation.validate`

## Behavior kinds (issue #1376)

- presence: 0
- absence: 0
- route-outcome: 0
- enabled-state: 0
- sequence: 0

- `A1` — not traced: no scenario-assertions header in test/tdd/004-login-ui/a1_test.dart
- `A2` — not traced: no scenario-assertions header in test/tdd/004-login-ui/a2_test.dart
- `A3` — not traced: no scenario-assertions header in test/tdd/004-login-ui/a3_test.dart
- `A4` — not traced: no scenario-assertions header in test/tdd/004-login-ui/a4_test.dart
- `A5` — not traced: no scenario-assertions header in test/tdd/004-login-ui/a5_test.dart
- `A6` — not traced: no scenario-assertions header in test/tdd/004-login-ui/a6_test.dart
- `U1` — not traced: no scenario-assertions header in test/tdd/004-login-ui/u1_test.dart
- `U2` — not traced: no scenario-assertions header in test/tdd/004-login-ui/u2_test.dart
- `U3` — not traced: no scenario-assertions header in test/tdd/004-login-ui/u3_test.dart
- `U4` — not traced: no scenario-assertions header in test/tdd/004-login-ui/u4_test.dart
- `U5` — not traced: no scenario-assertions header in test/tdd/004-login-ui/u5_test.dart
- `U6` — not traced: no scenario-assertions header in test/tdd/004-login-ui/u6_test.dart
- `contract:A1` — not traced: no scenario-assertions header in test/tdd/004-login-ui/contract_a1_test.dart

## Restoration (FR-021)

- restoration_verified: true
- restoration_scope_count: 13
- restoration_scope (subjects only, never tests):
  - `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/a1_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/a2_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/a3_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/a4_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/a5_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/a6_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/contract_a1_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/u1_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/u2_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/u3_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/u4_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/u5_subject.dart`
  - `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/u6_subject.dart`

## Repro diagnostics (FR-020, non-sensitive)

- runner_command: `dart run mutation_test`
- exit_code: 0
- elapsed_seconds: 21
- report_path: `/home/z/my-project/zuraffa/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md`
- preflight_scope_ran (bug #924, per-behavior):
  - `test/tdd/004-login-ui/a1_test.dart`
  - `test/tdd/004-login-ui/a2_test.dart`
  - `test/tdd/004-login-ui/a3_test.dart`
  - `test/tdd/004-login-ui/a4_test.dart`
  - `test/tdd/004-login-ui/a5_test.dart`
  - `test/tdd/004-login-ui/a6_test.dart`
  - `test/tdd/004-login-ui/contract_a1_test.dart`
  - `test/tdd/004-login-ui/u1_test.dart`
  - `test/tdd/004-login-ui/u2_test.dart`
  - `test/tdd/004-login-ui/u3_test.dart`
  - `test/tdd/004-login-ui/u4_test.dart`
  - `test/tdd/004-login-ui/u5_test.dart`
  - `test/tdd/004-login-ui/u6_test.dart`

## Mutation run

- mutation_was_run: true
- mutation_score: 0.8889

## Survived mutants (bug #837)

- `lib/tdd/004-login-ui/a1_subject.dart:26`
  --> fix: add or strengthen a scope test that fails on this mutant (report: /home/z/my-project/zuraffa/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md)

## Evidence binding (bug #837)

- spec_hash: 61000641611653aa5ada387a594754b6eef40a5b7478178fd07f1c95e5d2cbf8
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/a1_subject.dart` 8672a8a08cfdd22be615ce32589b954e2d3583154e26cbb5eba5ad78a7bffac9
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/a2_subject.dart` 6bb1bd860a56a16830b051f86da59295c0c18e15fbf2d461a29912ac1852f22b
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/a3_subject.dart` 397ab019adf2346986c1609b26d03475d61e59e9f58ebe02430c19a038bfb132
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/a4_subject.dart` 1935d16b6be9ddd30d559d900d5db71addaeafa36b0b390d1451517f23e70bac
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/a5_subject.dart` b5b75e93541e492384667e9b5804aebb7f2b88e2dd5e03fabdc1ad6e3c356ffe
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/a6_subject.dart` 6b311eaff4290d32856fb41ea22026d767cb8e7caf886a6506751f679cbe2e3f
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/contract_a1_subject.dart` ac26a205d5e95437d227b60a944bade6a4ce76f0fd91f488c5b872b0c28fa577
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/u1_subject.dart` 9395a0ff6b3b1b5cd0b3da43a258d6dbdc608a31719bcb1c6e87b7be960b3969
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/u2_subject.dart` 6d0ab84fe8788e3f3211221405a8641a0e07aa1829a9bdd514be4d5eaf0941da
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/u3_subject.dart` c9e56ef85b96224ab53c4d7f9c5fc3b3b8bb2489bd4da0a920d45b53df11c942
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/u4_subject.dart` 7292ef9cd120fda8262775ebcff8c8cf7489283a909fafdd4babd6bc25ad0e35
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/u5_subject.dart` f23219f63ba4a5dce8992406a81a80a061f9282219fa079b8ec95ca1474db7de
- subject_hash: `/home/z/my-project/zuraffa/lib/tdd/004-login-ui/u6_subject.dart` 3111018c87fa8ab4f2f0569177cedeee5b3d7f3c006b74067f5b056ef6211dc6
