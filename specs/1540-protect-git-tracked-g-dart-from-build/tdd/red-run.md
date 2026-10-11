# Red Run Evidence — spec 1540

Date: 2026-09-13 · Dart SDK 3.13.3 · branch `feat/1540-protect-git-tracked-g.dart-from-build`

State under test: guard stub (`TrackedGeneratedOutputGuard` no-ops) +
`BuildCommand.recoverTrackedGeneratedOutputs` stub (`=> true`) + tests from
`tdd/test-list.md` (A1–A8, U1–U9). All failures below are BEHAVIOR-level
(no compile errors) — the red discipline from the test list holds.

## Fast tier

```
dart test test/core/generation/ test/commands/build_command_tracked_outputs_test.dart
00:01 +15 -13: Some tests failed.

Failing tests:
  U8: recovery restores the deletion and prints the FR-3 message
  U9/A2: recovery REFUSES (returns false, prints the git checkout remedy)
  A5a: tracked missing part → remedy names git checkout + doc
  A8: docs page exists and documents both builder exclusions
  ... and 9 more (U1, U2, U5, U6, U7, trackedFilesSync, ...)
```

(A3/A4/U3/U4 pass under the stub by construction — they assert the ABSENCE
of action, which a no-op satisfies; the protection behaviors are the red set.)

## Slow tier (CLI surface, TddFixture)

```
dart test --preset=all test/plugins/tdd/bug_1540_refactor_tracked_restore_test.dart
00:17 +0 -2: Some tests failed.
  A6: build pass deletes a tracked placeholder → restored byte-identical ...  [E]
  A7: build pass deletes a tracked placeholder and the restore is
      impossible → refusal, remedy named, exit non-zero                        [E]
```

A7's transcript IS the issue-#1540 dead-end, reproduced:

```
   pass: build
     exit: 0            ← fake zfa "build" deleted the tracked placeholder
   changed: (none)      ← and nothing in the loop noticed or restored it
zfa tdd refactor: re-proof: full ...
   re-proof exit: 0
refactor: feature=090-tdd-fixture outcome=refactored applied=1
```

…with the placeholder still missing from the tree and exit code 0: exactly
the "deletes-and-fails / silently continues" surface the spec forbids.
