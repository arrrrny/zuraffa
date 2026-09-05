# Tasks: 0974-di-a-plus-upgrade

- [x] T001. RED: write `test/plugins/di/dead_command_gone_test.dart` (file gone
      + zero references). Run it RED. GREEN: `git rm
      lib/src/commands/di_command.dart`. Re-run green. Commit.
- [x] T002. RED: write `test/plugins/di/di_verify_test.dart` (positive:
      clean registrations verify; negative: dangling `getIt<Missing>()` fails
      naming the class + expected file). GREEN: implement
      `DiVerifyCapability` + register in `DiPlugin.capabilities`. Commit.
- [x] T003. RED: write `test/plugins/di/di_receipts_test.dart` (standalone
      create writes `.zfa/receipts/*-di-<target>.json`; `ProofChecker` green).
      GREEN: `DiReceiptWriter` wired into `CreateDiCapability` +
      `RegisterCapability`. Commit.
- [x] T004. RED: write `test/plugins/di/di_verdicts_test.dart` (forced
      generation failure ⇒ `success: false`; skips ⇒ structured
      `{target, reason}` warnings). GREEN: real verdicts in both capabilities +
      `ExecutionResult.warnings`. Commit.
- [x] T005. Fix docs: openwiki DI section + `ModularDiCommand` help +
      `.specify/extensions/zuraffa/commands/utilities/di.md`. Commit.
- [x] T006. REFACTOR + VERIFY: `dart format`, `dart analyze` (zero new vs
      baseline), `tools/run_tests_chunked.sh` green, `dart format .` zero diff.
- [x] T007. `/speckit.tdd.verify` — generate
      `tdd/verification.md` from the REAL runs of this session. Commit. Push
      + PR.
