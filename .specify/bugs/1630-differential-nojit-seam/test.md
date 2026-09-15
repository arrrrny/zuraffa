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
| `dart test test/plugins/tdd/commands/corpus_differential_command_test.dart test/plugins/tdd/services/differential_ref_runner_test.dart` | **31 passed** (14 + 17) |
| `dart analyze` on both touched files | no issues |
| `dart format --set-exit-if-changed` on both touched files | clean |

## Full-suite sweep (why no other fallout is expected)

The whole-suite command is not a clean instrument on this host, so this
appendix leans on the direct evidence instead of its aggregate count.

**Casualties that reproduce.**
`bug_1388_gen_traces_fingerprint_test.dart` B1 and
`pubignore_export_guard_test.dart` are real test failures, pre-existing: both
were also red in the #1628 merge run (run 34936969400, before #1629).

**The sweep's third entry is dropped.** It was a *loading* failure of
`corpus_differential_command_test.dart` — not a test failure — and it does not
reproduce: run directly on the fix commit the file is **13/13 green** (14/14
once the seam-contract test below is added). Its
shape is environmental here, not a signal about this change: a re-run of
`dart test test --exclude-tags "flutter || e2e"` cascaded to **830 "Failed to
load" suites** (empty reason, 23 GB disk free) the moment the sweep reached
`test/plugins/mock` — the mass kernel/RAM exhaustion `dart_test.yaml`
documents as "hundreds of silent 'Failed to load' errors for unrelated
suites". Nothing in this PR touches `test/plugins/mock`.

**The clean re-run is not available.** `dart_core` on this PR's head commit
was **cancelled at its 30-minute job budget** (run 34955462286) — the same
capacity wall #1629 hit, and the reason the PR body raises the job's budget.

So the sweep's aggregate count is not evidence either way; the two named reds
above are the only reproducible casualties.
