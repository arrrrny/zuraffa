# TDD Verification — Spec 1334 zfa proof chain end-to-end validation

**Command**: `/speckit.tdd.verify`
**Test list**: [tdd/test-list.md](test-list.md)
**Cycle log**: [tdd/cycle-log.md](cycle-log.md)
**Date**: 2026-09-09

## Summary

| Metric | Value |
| --- | --- |
| Behaviors declared | 12 (B1-B12) |
| Behaviors green | 12/12 |
| Unit tests (checker core) | 28 passed / 0 failed |
| CLI contract tests (subprocess) | 8 passed / 0 failed |
| Regression tests (#807 proof surface) | 19 passed / 0 failed |
| Total | **55 passed / 0 failed** |
| Mutants applied / killed | 3 / 3 (kill rate 100%) |
| `dart analyze` (changed files) | 0 issues |
| `dart format` (changed files) | 0 remaining diffs |

## Test-first evidence

Every behavior was written as a failing test BEFORE the implementation
(full transcript in [cycle-log.md](cycle-log.md)):

- **B1-B11 RED**: `dart test test/core/proof_chain_checker_test.dart`
  failed to load — `lib/src/core/proof/proof_chain_checker.dart: No such
  file or directory` (exit 255).
- **B4 RED**: `dart run bin/zuraffa.dart proof chain` printed
  `Could not find a subcommand named "chain" for "zfa proof"` (exit 2 —
  the subcommand was not registered).
- **B12 was green at every phase by design** — it is the regression
  guard proving the #807 surface stayed untouched.

## Green evidence (the exact commands, this session)

```
$ dart test test/core/proof_chain_checker_test.dart
00:00 +28: All tests passed!

$ dart test test/commands/proof_chain_command_test.dart
00:39 +8: All tests passed!

$ dart test test/commands/proof_command_test.dart \
      test/core/proof_checker_test.dart \
      test/core/proof/proof_check_valid_test.dart
00:02 +19: All tests passed!
```

## Mutation evidence (the tests are not vacuous)

Each mutant was applied surgically to the implementation, the targeted
test was run, the kill was observed, and the mutant was reverted
(the final tree is the clean implementation — verified by re-running
the full suite green afterwards):

| Mutant | Change | Killed by | Result |
| --- | --- | --- | --- |
| M1 | Digest mismatch never flagged (`if (false && actual != entry.sha256)`) | B3 "edited artifact -> receipt_digest drift" | **killed** (+0 -1) |
| M2 | Exit code pinned to 0 (`int get exitCode => 0`) | B1/B3 exit-code assertions | **killed** (+0 -1) |
| M3 | Failed route verify never flagged (`if (false && !verdict.ok)`) | B8 "failed verify verdict -> route_verify drift" | **killed** (+0 -1) |

Kill rate: **3/3 = 100%** — every mutant is caught by the suite, so the
assertions bind real behavior (digest comparison, exit-code derivation,
verdict classification), not incidental output.

## CLI exit-code protocol demo (live subprocess runs)

| Scenario | Command | Exit |
| --- | --- | --- |
| Clean project, existing command | `zfa proof check` | **0** |
| Clean project, new command | `zfa proof chain` | **0** ("0 drift, 0 gap — OK") |
| Drifted receipt (hand-edited artifact) | `zfa proof chain` | **1** (expected/actual sha256 + fix line) |
| `.zfa/receipts` occupied by a file | `zfa proof chain` | **2** (infra error + `--> fix:` line) |
| JSON verdict, existing surface | `zfa proof check --format=json` | 0, `jsonDecode`-valid (`proof.v1`) |
| JSON verdict, new surface | `zfa proof chain --json` | 0, `jsonDecode`-valid (`proof-chain.v1`) |

Note on the literal `zfa proof check --json` form: `--json` is not a
flag of the #807 `proof check` command (its JSON surface is
`--format=json`), and the issue's hard constraint forbids changing that
command — the new `--json` flag belongs to the new `proof chain`
subcommand. Both JSON surfaces were validated above.

## Honest verdict on THIS repository's tree

`dart run bin/zuraffa.dart proof chain` (full repo) exits **1** with
131 drift / 1611 gap / 11 info:

- The 131 `test_integrity` drifts are PRE-EXISTING state — committed
  `artifacts.json` records carrying machine-specific absolute paths
  (`/workspace/zuraffa/.worktrees/...`) and comma-joined legacy
  multi-path records that resolve on no other clone. The auditor
  reports them faithfully; nothing in this PR introduced them, and the
  19 pre-existing proof tests confirm the #807 surface is unchanged.
- The 1611 `behavior_coverage` gaps are the repo's real open chain
  links (specs whose cycle-logs carry no machine green entries) —
  reported, never failed, per the issue's severity contract.

## Verification commands (reproduce everything)

```
dart analyze lib/src/core/proof/proof_chain_checker.dart \
             lib/src/commands/proof_command.dart \
             test/core/proof_chain_checker_test.dart \
             test/commands/proof_chain_command_test.dart
dart test test/core/proof_chain_checker_test.dart
dart test test/commands/proof_chain_command_test.dart
dart test test/commands/proof_command_test.dart \
      test/core/proof_checker_test.dart \
      test/core/proof/proof_check_valid_test.dart
dart run bin/zuraffa.dart proof chain          # repo tree: exit 1 (honest)
dart run bin/zuraffa.dart proof chain --json   # one proof-chain.v1 object
dart format --output=none --set-exit-if-changed <the four files above>
```
