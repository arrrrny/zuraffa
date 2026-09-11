# Test List — bug #1507: TMPDIR kernel cache leak (cleanup is a no-op)

- **Slug**: 1507-tmpdir-kernel-cache-leak
- **Feature dir**: `.specify/bugs/1507-tmpdir-kernel-cache-leak` (pinned per bug
  extension TDD mode)
- **Source test file**: `test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart`
- **Behavior under test**: `clearDartTestKernelCache` (shared by
  `refactor_command.dart` and `run_command.dart`)

## Behaviors

| ID | Behavior | Kind | State |
| --- | --- | --- | --- |
| B1 | The sweep matches BOTH files and directories named `dart_test.kernel.*` and deletes directories recursively (the leaked shape is a per-invocation directory full of dill files) | unit | PROVEN |
| B2 | The sweep runs at the START of every TDD cycle in the refactor command — proven on a healthy green cycle where the retry machinery never fires (counter == 2: preflight + re-proof) | unit | PROVEN |
| B3 | The sweep runs at the START of every TDD cycle in the run command (`run_command.dart` had no kernel handling at all) | unit | PROVEN |
| B4 | The sweep logs what it reclaimed: `cleared N stale kernel dir(s), freed X MB` | unit | PROVEN |
| B5 | Entries created or updated after `commandStartedAt` survive (concurrent-runner guard preserved — the existing #1333 contract) | unit | PROVEN |
| B6 | A kernel directory referenced by a LIVE process argv (the dart test runner's own frontend-server child holds `--output-dill=<tmp>/dart_test.kernel.<rand>/output.dill` for the whole invocation) survives the sweep, and is reclaimed by the next cycle once the holder exits | unit | PROVEN |
| B7 | The project-local cache `<project>/.dart_tool/test/` is cleared by the same start-of-cycle sweep | unit | PROVEN |

## Acceptance criteria (from the bug report)

1. `$TMPDIR/dart_test.kernel.*` cleaned after every cycle (not just
   infra-retry) — B2, B3.
2. Cleanup matches directories (not just files) and deletes recursively — B1.
3. A long-running TDD loop has bounded, roughly flat temp-disk usage — B1+B2+B3
   together (one sweep per cycle start; leaks from prior cycles are reclaimed
   before new ones accumulate).
4. Must log what was reclaimed (`cleared N stale kernel dir(s), freed X MB`) —
   B4.
5. Must not break concurrent runners — the existing `commandStartedAt` guard is
   preserved (B5) and extended with a liveness guard (B6).
6. Fix confined to the kernel cache cleanup in `refactor_command.dart` and
   `run_command.dart`; no test-runner semantics, state machine, or loop-logic
   changes.
