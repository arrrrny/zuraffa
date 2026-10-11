## Summary

Fixes #1467. Every cycle-log reader sectioned `tdd/cycle-log.md` with a naive
`raw.split('\n## ')`. Because the writer embeds captured test stdout verbatim
inside a fenced code block in each `## Cycle:` section, a captured line starting
with `## ` started a **phantom section**: the real entry's trailing fields
(`- kind:`, `- schema:`, `- prev-hash:`, `- hash:`) were stranded in the fake
chunk, so evidence was lost or misattributed and the doctor's hash-chain
verification failed.

This replaces all 9 naive split sites with a shared, fence-aware splitter.

## Changes

| File | Change |
|------|--------|
| `lib/src/plugins/tdd/services/cycle_log_sections.dart` | **New.** `splitCycleLogSections()` — tracks CommonMark backtick fences line-by-line (including info-string fences) and only treats `## ` at column 0 outside a fence as a section header. On fence-free input its output is identical to the legacy `split('\n## ')`, so there is no format change and no migration. |
| `lib/src/plugins/tdd/services/cycle_evidence.dart` | 2 sites adopt the splitter |
| `lib/src/plugins/tdd/commands/make_command.dart` | 2 sites |
| `lib/src/plugins/tdd/commands/compose_command.dart` | 2 sites |
| `lib/src/plugins/tdd/commands/verify_red_command.dart` | 1 site |
| `lib/src/plugins/tdd/services/era_tagged_log.dart` | 1 site |
| `lib/src/plugins/tdd/services/theater_data.dart` | 1 site |
| `lib/src/plugins/tdd/services/replay_history.dart` | 1 site |
| `test/tdd/cycle-log-phantom-sections/a{1..5}_test.dart` | **New.** Acceptance tests A1–A5 for the fixed behaviour |
| `lib/tdd/cycle-log-phantom-sections/a{1..5}_subject.dart` | **New.** Hand-implemented subjects (the designed hand-delta seam) |
| `test/plugins/tdd/theater/theater_data_test.dart` | U3 edge fixture migrated to the fence-aware contract: an unterminated fence now absorbs the rest of the log, so `## Cycle: A3 (green)` is captured data rather than a phantom cycle |

No naive `raw.split('\n## ')` call remains in `lib/src`.

## Verification

Both changed tests are proven regression tests — each fails on `origin/master`
and passes with the fix:

| Test | Against `origin/master` | With the fix |
|------|------------------------|--------------|
| `test/tdd/cycle-log-phantom-sections/a5_test.dart` | `Bad state: A5: hash-chain link lost: null` | pass |
| `test/plugins/tdd/theater/theater_data_test.dart` | `Which: has length of <5>` (phantom 5th cycle) | pass |

```
dart test test/tdd/cycle-log-phantom-sections test/plugins/tdd/theater/theater_data_test.dart
→ 00:01 +10: All tests passed!

dart test test/plugins/tdd                                     # 327 reader-site test files
→ 08:13 +2123 ~1 -2
  test/plugins/tdd/commands/bug_1388_gen_traces_fingerprint_test.dart: B1: ...
  test/plugins/tdd/commands/view_command_test.dart: U-V3: ...
```

Both failures are the known pre-existing baseline pair recorded in
`tdd/run-baseline.json` (which tolerated 4 pre-existing failures); neither
exercises cycle-log parsing and neither is touched by this change.

## Notes for reviewers

- **The TDD-mode audit could not run.** `zfa tdd verify` returns `NOT_ASSESSED`
  (exit 3) at its proof preflight: the `zfa tdd gen` receipt records the
  generated *stub* digest, and implementing the subject by hand — the designed
  hand-delta seam — changes the bytes. There is no re-seal command, and the
  prescribed remedy (re-run the generating verbs) would revert the subjects to
  stubs. The verdict is honestly unavailable.
- **The full suite was not run locally.** `zfa tdd run`'s baseline and refactor
  re-proof each invoke a whole-tree `dart test`, a cold ~42 GB / 20+ minute
  kernel compile on this machine; the `#1333` retry clears the kernel cache and
  forces another cold compile, so the loop can consume >100 GB. Aborted
  deliberately rather than fill the disk.
- **Writer-side hardening is out of scope** as recorded in the assessment:
  adapting the fence length, or indenting captured output, is a format change.

Assessment: `.specify/bugs/cycle-log-phantom-sections/assessment.md`
Verification: `.specify/bugs/cycle-log-phantom-sections/test.md`

Closes #1467.
