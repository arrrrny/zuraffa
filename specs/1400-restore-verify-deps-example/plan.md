# Plan — Spec 1400 restore verify deps in example

**Branch**: `feat/1400-restore-verify-deps-example` | **Date**: 2026-09-11 | **Spec**: [spec.md](./spec.md)

## Technical context

- Surface: `example/pubspec.yaml` ONLY (data; hard constraint — no
  engine, verify-command, mutation-tool, or source changes).
- Toolchain of record: Flutter 3.47.3 / Dart 3.13.3 (stable channel;
  matches the task's Dart 3.13+ / Flutter 3.47+ floor).
- Feature under certification: `004-login-ui` (project `example`,
  runner `flutter`).
- Evidence of record: the committed
  `example/specs/004-login-ui/tdd/verification.md` (evidence commit
  fb44db98, issue #1376's regenerate): `mutation_was_run: true`,
  killed=48, survived=8, mutation_score=0.8571, elapsed 436s,
  scope = 6 subjects / 6 tests.

## Approach

Certification, not code: the dependency restoration this issue demands
already landed on master (#1369 restored the TDD baseline; #1370
superseded its plain-`test` clause). The plan re-proves, with real runs
against the restored tree, each claim the issue needs to be true before
`Closes #1400` is honest:

1. **Resolution**: `flutter pub get` in `example/` (zero overrides).
2. **Baseline contract**: the existing structural pin
   (`test/package_sdk/bug_1369_example_tdd_baseline_test.dart`)
   asserts B1 (writer-canonical pair present at canonical constraints)
   and B2 (no plain `test`).
3. **Evidence reproduction**: re-run the evidence's scoped mutation
   audit (same shape `zfa tdd verify` builds via
   `buildScopedMutationConfig`, restricted to the committed evidence's
   registered 6 subjects / 6 tests) with `dart run mutation_test` and
   compare against the committed numbers. The audit surface is
   byte-identical between fb44db98 and HEAD, so the comparison is
   bit-exact.
4. **Data pin**: append the #1400 certification to the baseline's
   issue-reference comment chain (comment-only pubspec edit).

## Why plain `test` stays out — empirical proof (2026-09-11)

Re-proving locked decision 2 on Flutter 3.47.3 / Dart 3.13.3: with
`test: ^1.0.0` inserted into `example/pubspec.yaml` dev_dependencies,
`flutter pub get` fails with (abridged solver transcript):

```
Because every version of zuraffa from path depends on analyzer ^14.0.0
and test >=1.27.0 <1.29.0 depends on test_api 0.7.8, if zuraffa from
path and test >=1.27.0 <1.31.2 then test_api 0.7.8 or 0.7.11.
...
And because example depends on zuraffa from path which depends on
graphql ^5.2.3, flutter_test from sdk is incompatible with
test >=0.12.0-beta.3.
So, because example depends on both flutter_test from sdk and
test ^1.0.0, version solving failed.
```

The pubspec was then restored and `flutter pub get` re-run clean. This
is the #1189/#1370 conflict class, live on the current toolchain.

## Test strategy

- Hermetic: the structural pin (package_sdk suite) — no network, no
  Flutter SDK needed.
- Evidential: the scoped mutation audit run (`mutation_test` v1.8.0,
  resolved FROM the restored dev_dependencies — the very fact the issue
  says was broken). Per-mutant command: `flutter test <6 evidence-scope
  test files>`; kernel-cache hygiene per the audit protocol
  (`rm -rf .dart_tool/test/` + `$TMPDIR/dart_test.kernel.*` before and
  after).
- Excluded, with reason: the full-lane `zfa tdd verify` gate — red at
  HEAD via `u1_test.dart`'s honest-red stub (#1377, unrelated
  pre-existing failure; fixing it requires implementing `subject_u1`,
  a source-code change this issue forbids).

## Risks

- Mutation-run nondeterminism: none expected — subjects and tests are
  byte-identical to the evidence commit; only wall-clock differs.
- Version-solver drift: covered by SC-001 + CI's flutter-smoke-gate.
