# Verification Audit: 1521-1484-breaks-1481-fallback-tests (bug #1521)

Audit target: `.specify/bugs/1521-1484-breaks-1481-fallback-tests/`.
Full evidence (front-matter verdict, per-behavior table, gaps) lives in
`tdd/verification.md` — produced from this session's REAL runs; no
copied or back-dated evidence.

## Summary

- Verdict: **PASS_WITH_GAPS** (3/3 behaviors PROVEN; environmental
  gap + one pre-existing neighbor failure documented)
- Red-first: 5 passed / 3 failed pre-fix → 8/8 post-fix
- Regression (chunked suite, CI parity `--exclude-tags flutter`): all
  top-level chunks green; 6 dirs N/A under CI tag selectors; ONE
  pre-existing failure (`bug_1432_platform_lane_rows_test.dart`,
  +1 -3) proven unrelated by stash run on pristine HEAD
- `dart analyze` (changed file): `No issues found!`
- `dart format`: changed file clean; repo-wide dry-run 2730 files,
  0 changed
- Gaps: no Flutter SDK in sandbox → Flutter-tagged slices excluded
  with CI's own selector; `slow`-tagged nested suites out of gate
  scope; single-session audit.

## Success criteria: PROVED vs NOT PROVED

PROVED (this session):

- the three feature-1484 stranded tests pass with expectations that
  pin the manual-routing contract (per-FR warning, destination,
  both remedies, no unit route line, no dead-end tally)
- red-first discipline: `+5 -3` on pristine HEAD before any edit;
  `+8` after — production code untouched (`git diff` scope verified)
- the retired fatal class is asserted ABSENT (`isNot` guards on the
  route line and the fallback prefix), so a future revert of feature
  1484 trips these tests loudly instead of silently
- the #1481 one-invocation-truth invariants still hold (A1 heals to
  `[declared: type marker` in the same run; spec.md carries the
  written marker)

NOT PROVED (out of scope / environmental):

- Flutter-SDK runs (no SDK in sandbox; CI parity selector used)
- healing `bug_1432` (pre-existing red on the feature branch, separate
  concern from #1521; evidence recorded for the #1504 authors)

## Commit hygiene

- One PR per bug; branch
  `fix/1521-1484-breaks-1481-fallback-tests` cut from
  `feat/1484-fr-manual-exemption` (the branch where the regression
  lives); PR targets that branch so the diff is exactly the bug fix;
  `Closes #1521`.
- Deliverables in-repo: this bug directory (`assessment.md`,
  `issue.md`, `fix.md`, `test.md`, `tdd/test-list.md`,
  `tdd/red-evidence.md`, `tdd/cycle-log.md`,
  `tdd/verification.md`) + the one-file test fix.
