# Test — 1630 (differential compile seam)

## Red (before the fix, master @ 8480a53e)

```bash
dart test test/plugins/tdd/commands/corpus_differential_command_test.dart
# 13 tests: 6 passed, 7 failed — every zfa step died with
#   ZfaCompilationException: dart compile exe failed for
#   "/tmp/diff_cmd_*/scratch-root/wt-from/bin/zfa.dart" (exit 254)
#   stderr: bin/zfa.dart: Error: No 'main' method found.
```

CI evidence (PR #1629's `dart_core` job, run 34943793655): the same three
`corpus_differential_command_test.dart` cases are the first ❌ groups after
the suite reaches `test/plugins/tdd/commands/`.

## Green (after the fix)

| command | result |
|---|---|
| `dart test test/plugins/tdd/commands/corpus_differential_command_test.dart test/plugins/tdd/services/differential_ref_runner_test.dart` | **30 passed** (13 + 17) |
| `dart analyze` on both touched files | no issues |
| `dart format --set-exit-if-changed` on both touched files | clean |

## Full-suite sweep (why no other fallout is expected)

`dart test test --exclude-tags "flutter || e2e"` (the CI `dart_core` command)
run locally on the fix branch: **7428 passed, 2 skipped, 3 failed**, and none
of the three is a new no-JIT casualty:

1. `corpus_differential_command_test.dart` — loading failure caused by the
   sweep compiling the file while it was being edited (the incremental
   kernel-cache artifact; the targeted re-run above is the authoritative
   result: 13/13 green).
2. `bug_1388_gen_traces_fingerprint_test.dart` B1 — pre-existing: also red in
   the #1628 merge run (run 34936969400, before #1629).
3. `pubignore_export_guard_test.dart` — pre-existing: also red in the #1628
   merge run.
