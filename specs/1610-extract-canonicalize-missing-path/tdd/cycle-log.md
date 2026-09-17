# Cycle Log: Extract canonicalizeMissingPath — documented precondition + direct walk-up test (chore #1610)

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

Environment: Dart 3.13.4 stable, Linux x64 (uid 1001), kernel cache cleared
before each targeted run (`rm -rf .dart_tool/test/`,
`rm -f $TMPDIR/dart_test.kernel.*`).

## Baseline

- suite: `dart test test/plugins/tdd/commands/view_command_test.dart
  test/plugins/tdd/wire_command_test.dart
  test/plugins/tdd/commands/func_command_test.dart` (default preset) →
  **10 passed** — the +10 is func_command_test.dart ONLY: view and wire
  carry `@Tags(['slow'])` and the default preset excludes the slow tag, so
  those two files ran ZERO tests (a load-time "Does not exist" misread was
  ruled out: the wire file lives at `test/plugins/tdd/wire_command_test.dart`,
  NOT under `commands/` — path corrected and re-run)
- suite (corrected tiers): `dart test --preset=all
  test/plugins/tdd/commands/view_command_test.dart` → **15 passed, 0 failed**;
  `dart test --preset=all test/plugins/tdd/wire_command_test.dart` →
  **16 passed, 0 failed**; `dart test
  test/plugins/tdd/commands/func_command_test.dart` → **10 passed, 0 failed**
- commit: `f220b6a3`
- recorded: cycle 0, before any change — suite_baseline: green
- note: the slow-tier requirement for the pin suites is recorded in
  tdd/test-list.md "Verification commands" so verify runs the pins under
  `--preset=all`

## Cycle: T001 — direct walk-up pins (characterization baseline)

- behavior: U1, U2, U3, U4 (tdd/test-list.md inner loop; tasks.md T001)
- kind: green-by-design baseline, recorded honestly as characterization —
  the shared helper ALREADY exists on this branch's base (master `994daeb1`
  landed the mechanical extraction during PR #1611 review); the pins are new
  tests OF existing behavior, so their strength is proven by deliberate
  mutants (below), not by a pre-implementation red
- test: test/plugins/tdd/services/path_canonicalizer_test.dart (NEW)
- command: `dart test test/plugins/tdd/services/path_canonicalizer_test.dart`
- exit: 0
- at: 2026-09-16
- output:
```
00:00 +4: All tests passed!
```
- fixture note (recorded because it shaped the pins): the FIRST baseline run
  failed U3 — `Link.create()` was awaited-by-accident-of-timing (async) and
  `link_parent` did not exist yet when the helper walked, so the result came
  back `<root>/link_parent/subject.dart` (walk-up ran, link missing). The
  fixture was made deterministic with `createSync` (both the setUp alias and
  U3's parent link); the helper was untouched. This is a test-fixture bug,
  not a helper bug — recorded for the honest-red discipline.

## Cycle: T001m — deliberate-mutant sampling (SC-3 red evidence)

No mutation tool is wired for helper-level services in this repo (same
precedent as PR #1606's verification: "Mutation sampling (no mutation tool
wired)"). Each mutant was applied to
`lib/src/plugins/tdd/services/path_canonicalizer.dart`, the suite run, then
RESTORED byte-identical via `git checkout --` before the next mutant;
mutant states were never committed. Suite command for every row:
`dart test test/plugins/tdd/services/path_canonicalizer_test.dart`.

### M1 — drop `.reversed` (`...tail.reversed` → `...tail`)

- killed by: U1 AND U2 (prediction: U2 — met, plus U1)
- exit: 1
- decisive failure lines:
```
U1 Expected: '/tmp/tdd_canon_root_RJOVPM/missing/subject.dart'
U1 Actual:   '/tmp/tdd_canon_root_RJOVPM/subject.dart/missing'
U2 Expected: '/tmp/tdd_canon_root_MABOLF/missing_a/missing_b/subject.dart'
U2 Actual:   '/tmp/tdd_canon_root_MABOLF/subject.dart/missing_b/missing_a'
```
- restore → `00:00 +4: All tests passed!` (GREEN)

### M2 — skip the walk-up (return `path` on first FileSystemException)

- first application: killed by U1 ONLY — U2 SURVIVED on this host: with a
  non-symlinked `/tmp`, raw input `<root>/missing_a/missing_b/subject.dart`
  string-equals the resolved-root expectation, so U2's exact match could not
  see the mutant. Remediation: U2's missing chain now travels the ALIAS form
  (`<alias>/missing_a/missing_b/subject.dart`) — a strict strengthening that
  keeps U2's tail-order purpose and gives it an independent kill of M2 on
  any host. (The first-run observation is recorded verbatim rather than
  silently rewritten: the strengthened suite is what ships.)
- killed by (strengthened suite): U1 AND U2 (prediction met)
- exit: 1
- decisive failure line (first application):
```
U1 Expected: '/tmp/tdd_canon_root_SLYTZX/missing/subject.dart'
U1 Actual:   '/tmp/tdd_canon_root_SLYTZX_alias/missing/subject.dart'
```
- strengthened-suite result: `00:00 +2 -2: Some tests failed.` (U1, U2 red)
- restore → `00:00 +4: All tests passed!` (GREEN)

### M3 — drop the basename re-append (`p.joinAll([resolved])`)

- killed by: U1, U2, U3, AND U4 (prediction: U1/U2/U3 — met; U4 additional)
- exit: 1
- decisive evidence: every pin's exact-match expectation lost the
  re-appended segment(s) (e.g. U3 actual `<resolvedRoot>/real_parent` vs
  expected `<resolvedRoot>/real_parent/subject.dart`)
```
00:00 +0 -4: Some tests failed.
```
- restore → `00:00 +4: All tests passed!` (GREEN)

### Mutation hygiene

- after M3's restore: `git diff` on `lib/` → EMPTY (no mutant residue);
  suite green on the pristine helper.

## Cycle: T002 — green gate (targeted suites, zero executable diffs)

- behaviors: U6 (gate aggregation), A3–A6 acceptance surface
- command: see the recorded invocations below (slow-tagged command suites
  run under `--preset=all` per the Baseline note; func runs default-tier)
- at: 2026-09-16
- result: RECORDED IN `tdd/verification.md` (final runs over the finished
  tree: new suite + view + wire + func + analyze + format)
