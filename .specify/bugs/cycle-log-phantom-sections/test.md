# Bug Verification: cycle-log.md section parsing breaks on test output containing '## '

- **Slug**: cycle-log-phantom-sections
- **Tested**: 2026-09-12
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md — not produced; `zfa tdd verify` returned NOT_ASSESSED (see Residual Risks)

## Summary

The bug no longer reproduces. The new acceptance test, run against a throwaway
worktree checked out at `origin/master`, fails with
`Bad state: A5: hash-chain link lost: null` — the phantom section stranding the
real entry's `- hash:` field, exactly the reported symptom — and passes on the fix
branch. The modified theater test likewise fails on `master` (`has length of <5>`:
the phantom fifth cycle) and passes here. The 327-file reader-site regression
suite shows no new failures.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (pre-fix, splitter) | `dart test test/tdd/cycle-log-phantom-sections/a5_test.dart` in a worktree at `origin/master` | fail (expected) | `Bad state: A5: hash-chain link lost: null` — the reported symptom |
| Reproduction (pre-fix, reader) | `dart test test/plugins/tdd/theater/theater_data_test.dart` in the same worktree | fail (expected) | `has length of <5>` — the phantom fifth section |
| New / updated tests (post-fix) | `dart test test/tdd/cycle-log-phantom-sections test/plugins/tdd/theater/theater_data_test.dart` | pass | 10/10: A1–A5 plus theater U1–U5 |
| Regression suite (reader sites) | `dart test test/plugins/tdd` | pass, 2 known pre-existing failures | `+2123 ~1 -2`; both failures are the pre-fix baseline pair |
| Adoption audit | `grep -rn "split('\n## ')" lib/src` plus the A4 subject | pass | 0 naive splits remain in `lib/src`; all 9 reader sites call `splitCycleLogSections` |
| Feature resolution | `zfa tdd doctor cycle-log-phantom-sections` (bare slug and explicit path) | pass | resolves `.specify/bugs/cycle-log-phantom-sections` (issue #1471 fix) |
| TDD-mode audit | `zfa tdd verify --feature cycle-log-phantom-sections --timeout 45` | not-run | NOT_ASSESSED, exit 3 — proof preflight digest drift, see below |
| Full-suite engine run | `zfa tdd run cycle-log-phantom-sections` | not-run | not viable on this machine, see Residual Risks |

## Output Excerpts

Pre-fix (master worktree, new A5 test — the reproduction):

```
00:00 +0 -1: A5 (AC-5) A5 — it yields exactly one entry with the correct behavior id, kind, [E]
  Bad state: A5: hash-chain link lost: null
  package:zuraffa/tdd/cycle-log-phantom-sections/a5_subject.dart 56:5  subject_a5
00:00 +0 -1: Some tests failed.
```

Pre-fix (master worktree, new theater test):

```
     Which: has length of <5>
  test/plugins/tdd/theater/theater_data_test.dart 389:7  main.<fn>.<fn>
```

Post-fix (this branch):

```
00:01 +10: All tests passed!
```

Post-fix regression suite:

```
08:13 +2123 ~1 -2: Some tests failed.
Failing tests:
  test/plugins/tdd/commands/bug_1388_gen_traces_fingerprint_test.dart: B1: traces drift forces regeneration carrying the new routing
  test/plugins/tdd/commands/view_command_test.dart: U-V3: a missing subject file is a hard runner-error
```

Both failing tests appear in the pre-fix suite baseline (`tdd/run-baseline.json`),
which tolerated 4 pre-existing failures; neither exercises cycle-log parsing and
neither is touched by this change.

## Residual Risks

- **`zfa tdd verify` cannot pass on this branch.** It stops at its proof preflight
  with exit 3:
  ```
  zfa tdd verify: NOT_ASSESSED — the feature's artifacts failed the proof preflight (digest drift before the audit).
     [modified] lib/tdd/cycle-log-phantom-sections/a1_subject.dart
     digest mismatch: receipt says 488b208dac1f, disk has 4b8e4cd3a971 (action: create); reproduce with: zfa tdd gen
  ```
  The `zfa tdd gen` receipt records the generated *stub*; implementing the
  subject by hand (the designed hand-delta seam the subject headers describe)
  changes the bytes. There is no re-seal command (`zfa proof` offers only
  `chain` / `check` / `prune`), and the prescribed remedy — re-running the
  generating verbs — would revert the subjects to stubs and destroy the fix.
  So the TDD-mode audit verdict is honestly unavailable, not passed.
- **The full suite was not run locally.** `zfa tdd run`'s baseline and refactor
  re-proof both invoke a whole-tree `dart test`, which on this machine is a cold
  ~42 GB, 20+ minute kernel compile; each `#1333` retry calls
  `clearDartTestKernelCache` and forces another cold compile, so the retry loop
  can consume well over 100 GB. The run was aborted deliberately rather than
  risk filling the disk. CI, and a machine with more headroom, cover this.
- The engine's recorded A1–A5 `green` states are **not** the evidence for this
  fix; the red-on-master/green-here proofs above are. See `tdd/cycle-log.md`.
- Writer-side hardening (fence-length adaptation, or indenting captured output)
  remains out of scope, as recorded in the assessment.

## Recommendation

Close the bug once the PR merges. The symptom is gone end-to-end, both changed
tests are proven regression tests (red on master, green on the fix), and no new
failures appear in the reader-site regression suite. The two items under Residual
Risks are environment/tooling limitations, not doubts about the fix itself.
