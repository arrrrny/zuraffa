# TDD Verification — Spec 1411 — Verdict: PASS (2026-09-11)

- Test-first: red commit (`a9bc479d` — spec artifacts + the test matrix,
  red evidence recorded in tdd/test-list.md) precedes the fix commit.
- Suite: bug file `+10 All tests passed!` (B1–B7 make block, D1–D3
  driver block). Red evidence: `+1 −9` pre-fix (D3 green from the
  start — the compatibility pin).
- Analyze: `dart analyze` over the changed files — No issues found.
- Format: `dart format` over the changed files — exit 0, zero remaining
  formatting diffs. (A repo-wide `dart format .` also reformatted two
  UNRELATED files with pre-existing drift —
  `example/test/tdd/004-login-ui/u1_test.dart`,
  `tool/generate_openwiki_cli_docs.dart`; reverted to keep the PR
  surgical.)
- Mutation sampling (executed):
  - M1 — make's attestation gate disabled (`false &&`) → B4 RED
    (killed).
  - M2 — the driver arm's catch-22 signature gate dropped
    (`sawUnexpectedGreen &&` removed) → D3 RED (killed).
  - 0 survivors.
- Regression pins (scoped, cloud agent):
  - #1373 hand-off driver + #1308 remedy driver + #1308 remedy:
    `+11 All tests passed!`
  - two-cycle driver + sc_002 + sc_004: `+30 All tests passed!`
  - run command + path format + unified journal + explain:
    `+79 All tests passed!`
  - UNRELATED pre-existing failures (flagged, NOT introduced here —
    reproduced identically with the fix stashed on the pristine base):
    5 tests in `make_command_test.dart` (bug 657 unexpressible hint,
    spec 052 SC-004 / A15 composition fallback, U-829g/U-829h entity
    pipeline) + the same shape in `make_command_1036_test.dart` /
    `sc_006` chunk: `+41 −5`. These exercise real `build_runner`
    composition subprocesses and fail on this environment regardless
    of the #1411 change.
- Constraint audit: gen pipeline untouched; verify-red logic untouched;
  cycle-log format untouched (the born-green entry renders through the
  existing `CycleLogEntry` fields — the `- evidence:` note precedent of
  issue #1162, the empty `generation:` block and zero suite numbers of
  the #694/#741 skip pattern); the core engine cycle unchanged (the
  transition is explicit-flag-gated, refuses safe-failure on every
  non-attested shape, and is inert whenever certified red exists).
- Envelope/journal surface: the `:hand` stop lands the #1411 hand-step
  violation in the lane journal via the content-keyed dispatch
  (`hand-step=U1:hand … --born-green`), asserted in D1.
- AC coverage: AC1 → B1 (+B3/B4/B5/B7 safe-failure pins), AC2 → D1/D2,
  AC3 → B6 + D3.
