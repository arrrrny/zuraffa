# Tasks: test-package-missing-after-setup (bug #716)

TDD-mode fix; the loop ran inside-out. See `tdd/test-list.md` and
`tdd/cycle-log.md`. All bug behaviors are DONE; the tasks below are
remediation items from `tdd/verification.md` (verdict PASS_WITH_GAPS, no
HIGH findings — the bug itself is not blocked by them).

## Phase 1: TDD remediation

- [ ] 1.1 Triage the pre-existing, environment-sensitive chunk failures in
      `test/plugins/tdd/commands` (func_command_test U-F2) and
      `test/plugins/tdd/services` (refactor_passes_test U2 + bug #689 PATH
      test) reported by verification finding 3: identical failure counts at
      base `029f6785`, pass in isolation. Isolate the shared cwd/PATH state
      and re-run `tools/run_tests_chunked.sh` to prove all 66 chunks green.
- [ ] 1.2 (optional, verification finding 2) Promote the e2e acceptance
      evidence to a committed integration test that runs `zfa setup` +
      `zfa tdd gen` against a temp project when a Flutter SDK is present,
      gated behind the `flutter` tag, so A1 no longer depends on a scratch
      project. Prove with:
      `dart test --preset flutter test/commands/setup_command_test.dart`.
