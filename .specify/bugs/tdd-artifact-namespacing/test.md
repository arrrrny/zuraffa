# Bug Test Report: per-feature TDD artifact namespacing (#827)

- **Slug**: tdd-artifact-namespacing
- **Tested**: 2026-09-02
- **Fix**: ./fix.md (PR #869 + review fix in `9211128b`)
- **Result**: verified

## Reproduction re-run (the #827 scenario)

The issue's repro (feature 2's gen dying with an ownership conflict after
feature 1) is pinned end-to-end by the PR's first acceptance test —
"feature-1 then feature-2 with the same behavior id: both gens succeed and
artifacts live under per-feature directories" — which drives the real
`zfa tdd gen` CLI for both features in one project and asserts both pairs
land under their namespaces with feature 1 byte-identical. Confirmed
green on the current PR branch head (`9211128b`) in this session's runs.

## Commands run (this session, final branch state)

| Command | Result |
|---------|--------|
| `dart test --preset=all test/plugins/tdd/commands/gen_namespacing_827_test.dart` | 11 passed, 0 failed |
| `dart test --preset=all test/plugins/tdd/commands/gen_command_test.dart test/plugins/tdd/commands/plan_gen_contract_test.dart` | 24 passed, 0 failed |
| `dart analyze lib/src/plugins/tdd/commands/migrate_paths_command.dart test/plugins/tdd/commands/gen_namespacing_827_test.dart` | no issues |

Regression check for the review fix: the new migration test was observed
RED on the PR branch before the fix (moved file still contained
`'../../lib/tdd/a1_subject.dart'`), GREEN after — red-first evidence in
this session's run log, green evidence in the table above.

## TDD audit note

The branch carries `verification.md` (tdd.verify verdict: PASS_WITH_GAPS,
4/4 deliberate mutants killed) authored by the parallel session BEFORE the
review fix landed; its one recorded gap (a since-strengthened vacuous
assertion) was already addressed in `3cb47d66`. The review-fix test added
afterwards is red-first evidenced here. A full cold-context re-verify
against the post-review-fix state was not re-run this session — the delta
is one test plus two private helpers in `migrate_paths_command.dart`,
covered by the red/green runs above.

## Pre-existing / environmental

- Concurrent-session interference: two heavy slow-tier batches run in
  parallel produced fixture-subprocess timeouts; re-run solo they pass.
  The PR's own matrix (make ×2, run ×1, corpus-status flake ×1 documented
  as pre-existing on clean HEAD) matches this observation.
- The four slow-tier failures seen at this session's planning baseline
  (`subprocess_timeout` ×1, `verify_red_subdirectory` ×3) pass in
  isolation post-change; they are load/order flakes, not regressions.
