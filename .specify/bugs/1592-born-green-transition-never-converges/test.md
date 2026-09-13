# Bug Verification: born-green transition never converges — fixed via the born-green-certified refactor re-entry

- **Slug**: 1592-born-green-transition-never-converges
- **Tested**: 2026-09-13
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md

## Summary

The bug reproduced verbatim pre-fix (the #1411 arm re-prescribing the
already-run `--born-green`, forever) and does not reproduce post-fix: the
real-CLI end-to-end A/B on a real temp project shows the run driving the
born-green-certified blocked contract through the REAL refactor child to
`result=complete`, with the next run re-entering at refactor only. All
pinned born-green contracts (#1542, #1411, #1373, #1324, #1544) stay green.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | real-CLI `dart bin/zfa.dart tdd run 1592-e2e --project <fixture> --zfa-bin bin/zfa.dart` on the blocked + born-green fixture | pass | `result=complete pending=0 red=0 green=1 done=0`, exit 0; no verify-red, no make, no prescription |
| Reproduction (pre-fix control) | same fixture, same command, driver file from the pre-fix commit | pass (reproduces) | `verify-red -> unexpected-green` → `make -> not-certified-red` → `#1411` prescription of the already-run `--born-green`; `result=stopped ... stopped_at=contract:A1:hand` — the loop, verbatim |
| New / updated tests | `dart test --preset=all test/plugins/tdd/commands/bug_1592_born_green_blocked_convergence_test.dart` | pass | 5/5 (U-1592-1..5) |
| Pinned born-green family | same command with `bug_1542_*`, `bug_1373_*`, `bug_1411_*` | pass | 24/24 — incl. U-1542-1's pinned marker-less window |
| Regression suite (fast guards) | `dart test` over `bug_1324_*`, `bug_1544_*`, `two_cycle_*`, `unified_journal_*` | pass | the #1324/#1544 semantics unchanged |
| Regression suite (chunked blast radius) | per-folder chunks of `test/plugins/tdd/**` + `test/commands` (kernel cache cleared per chunk) | pass | 1180 pass / 0 fail |
| No-new-failures proof | `make_command_test.dart` failure lists diffed pre-fix vs post-fix | pass | byte-identical 4 environment-dependent failures |
| Lint / type-check | `dart analyze` (changed files + tdd subtree); `dart format --output=none --set-exit-if-changed lib/ test/` | pass | no findings; 0 format changes |

## Output Excerpts

POST-FIX real CLI (the decisive line):

```
[run] contract:A1 refactor -> clean
run: feature=1592-e2e result=complete pending=0 red=0 green=1 done=0
```

PRE-FIX real CLI (the loop this fix kills):

```
[run] contract:A1 make -> not-certified-red
   Certify the born-green hand transition: `zfa tdd make contract:A1 --born-green` — then re-run `zfa tdd run 1592-e2e`.
run: feature=1592-e2e result=stopped pending=0 red=0 green=0 done=0 blocked=1 stopped_at=contract:A1:hand
```

## Residual Risks

- The formal `zfa tdd verify` mutation gate was not run (it targets
  generated subject features; the CLI repo uses the fallback audit path —
  see ./tdd/verification.md §Mode).
- `make_command_test.dart`'s four real-pipeline suites fail in a cold,
  Flutter-less environment identically before and after this fix
  (environment-dependent, unrelated; failure lists diffed byte-identical).
- The `test/plugins/tdd/scenarios` chunk carries only `slow`-tagged suites
  and contributes zero fast-tier tests (unchanged by this fix).

## Recommendation

Close the bug — verified end-to-end (real CLI, real step children), with
the pinned born-green contracts and the chunked blast-radius suite green.
The PR (`Closes #1592`) carries the reconciled fix, the merged suite, and
the fresh verification artifacts.
