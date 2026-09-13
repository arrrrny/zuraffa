## Summary

Fixes #1585. The `bug_828` suite's `doctor()` helper invoked
`zfa tdd doctor --feature <name>` — a flag the command has not accepted since
the `b6afda42` (#840) rework moved the feature positional (`DoctorCommand`
declares only `--json` / `--repair` / `--project` and reads the feature from
`argResults.rest`). All four usage-error tests now reach the drift logic.

Fixing the helper exposed **two defects the usage error had masked** — the
suite is a slow-tier tripwire (`@Tags(['slow'])`), which is why the drift went
unnoticed:

1. **The doctor's evidence hash-chain walk was missing.** `zfa tdd doctor`
   reported `stores agree — no drift detected` for a cycle-log whose certified
   facts had been edited. The walk existed at `1183009e` (`_verifyChain`) and
   was dropped by the #840 rework while `cycle_log.dart` still documents it as
   the doctor's job ("The doctor recomputes this from the parsed entry and
   reports any mismatch as drift with a fix line"). Restored as gate 3c
   (`_hashChainDrifts`), ported from the pre-rework implementation: every
   `- prev-hash:` must chain, every `- hash:` must equal the recomputed
   `CycleLog.payloadFromFields` digest; legacy hash-less entries stay valid.
2. **The zero-drift pin asserted a retired output format.** The
   `doctor: feature=<f> drifts=<n>` summary line was replaced by the verdict
   envelope (bug #840 / issue #969); the pin now reads `verdict: healthy` +
   empty `drifts` from the final machine line, the idiom every sibling doctor
   suite uses.

A new pin (`U1585-6`) covers the restored walk's **linkage** arm: the mutation
audit showed a content-only walk survived, so the severed-`prev-hash:` case is
pinned separately.

## Changes

| File | Change |
|------|--------|
| `test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart` | helper passes the feature positionally; the consistent-store pin reads the verdict envelope; new linkage pin |
| `lib/src/plugins/tdd/commands/doctor_command.dart` | restored the #828 evidence hash-chain walk (gate 3c + `_hashChainDrifts` + header contract entry) |
| `.specify/bugs/tdd-doctor-feature-positional/` | spec, test list, cycle log, verification report, fix/test records |

## Verification

- `dart test --preset=all test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`
  → pre-fix `+9 -4` (the issue's usage error); helper-only `+11 -2` (the two
  masked defects); final **`+14: All tests passed!`**
- Mutation sampling: **M1** (walk disabled) killed by both hash pins; **M2**
  (linkage arm dropped) killed by the new linkage pin. Both reverted, tree
  re-run green.
- `dart analyze` on both changed files → `No issues found!`; `dart format` → `0 changed`.
- Sibling doctor sweep (14 suites): the 11 failures it reports are **identical
  on pristine `origin/master` (175f990d)** in a clean worktree (`+28 -11` both
  ways) — pre-existing `gen`/`reset`/`run`/`migrate-paths` reds, none in the
  changed surface.

Assessment: `.specify/bugs/tdd-doctor-feature-positional/assessment.md`
Verification: `.specify/bugs/tdd-doctor-feature-positional/tdd/verification.md`

Closes #1585.
