# Fix: tdd-make-regression-false-positive (issue #731)

- **Fixed**: 2026-09-02 (this session)
- **Branch**: `fix/731-tdd-make-regression-false-positive` (base: master `b832c1f0`)
- **Cycle**: red → green → verify (TDD, spec-kit TDD extension)

## Production change (1 file)

`lib/src/plugins/tdd/commands/make_command.dart` — suite-guard regression
check (step 9) only:

1. The verdict is now computed by
   `_regressionsAttributableToThisMake()` over `diff.newFailures`
   (the raw name-diff from `SuiteGuard.diff`, unchanged):
   - a new failing identifier inside the **current behavior's own test
     file** is a regression (boundary-aware file match,
     `_testFileOf` / `_sameTestFile` helpers handle progress-line,
     `loading …` load-failure, and bare-path identifier shapes);
   - a new failing identifier in a file with **zero baseline failures**
     is a regression (a previously-green file — genuine collateral
     regression; acceptance test A8 stays green);
   - a new failing identifier in a file **already red at baseline** is a
     pre-existing red behavior — tolerated (issue #731), printed with an
     explicit reason line naming the tolerated identifiers.
2. The regression report, summary outcome, and the green-evidence
   `suiteNewFailures` field all use the scoped verdict.
3. Library doc comment updated to the scoped contract.

`services/suite_guard.dart` and all other files: untouched.

## Tests (test/plugins/tdd/make_command_test.dart, US3 group, 2 new)

1. `bug 731: pre-existing red behaviors with unstable failing-test ids never
   flip an already-green target to regression — the skip transition reports
   skipped` — a deferred sibling whose failing test name embeds a timestamp
   (unstable identifier across the baseline/guard runs) plus an already-green
   target with certified-red evidence: make must exit 0 with
   `outcome=skipped`, never `regression`, and append green evidence.
2. `bug 731: a regression in a file that was ALREADY red at baseline is
   tolerated on the generation path too — make goes green when only
   pre-existing red behaviors fail` — same unstable sibling with a genuinely
   red target that the fake pipeline turns green: make must exit 0 with
   `outcome=green`, never `regression`.

Both failed against the pre-fix code (RED, captured verbatim in
`../assessment.md`) and pass against the fix (GREEN).

## Verification summary (real runs, this session)

- `dart test --preset=all -t slow test/plugins/tdd/make_command_test.dart
  test/plugins/tdd/services/suite_guard_test.dart` → make file `+26 −2` (the
  2 failures pre-date this branch; pristine tree `+24 −2`, same two tests),
  suite guard file `+9` all passed.
- `tools/run_tests_chunked.sh` (fast tier) → `OK: all chunks passed.`
- `dart analyze` → No issues found. `dart format` → stable on both files.
- Details and audit verdict: `./tdd/verification.md`.
