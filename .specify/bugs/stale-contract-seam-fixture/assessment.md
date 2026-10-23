# Bug Assessment: the bug_1589 contract-seam fixture seeds a non-wireable placeholder

- **Slug**: stale-contract-seam-fixture
- **Created**: 2026-10-22
- **Source**: https://github.com/arrrrny/zuraffa/issues/2004
- **Verdict**: valid
- **Severity**: low

## Report (summarized)

`test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart` is red
on `master`: 3 of its tests fail. The suite is tagged `@Tags(['slow'])`, and
`dart_test.yaml` excludes `slow` from the default run, so CI's fast lane never
executed it — the same rot class as issue #2000.

The failing assertions all expect the hand-surface hint to name the wire
command `zfa tdd wire contract:A1 --entity User`; the actual output degrades
to "the seam shape is not one `zfa tdd wire` can rewrite; implement it
directly".

## Symptom

The blocked-contract stop names the seam file but never names the wire
command, because the seam the FIXTURE seeds is not a shape `zfa tdd wire` can
rewrite. Expected: the hint names `zfa tdd wire contract:A1 --entity User`
for a seam that `zfa tdd wire` can actually rewrite.

## Reproduction

1. `dart pub get --no-example`
2. `dart test --preset=all test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart`
3. Observe `+8 -3: Some tests failed.` with
   `Expected: contains 'zfa tdd wire contract:A1 --entity User'`.

The `--preset=all` flag is required: the file is `@Tags(['slow'])` and the
default run excludes `slow`.

## Suspected Code Paths

- `test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart:654`
  — `seedSeamFile`, the fixture helper that writes the seam file.
- `lib/src/plugins/tdd/services/hand_surface.dart:97` —
  `HandSurface.seamIsWireable`, the #1752 gate the hint consults.
- `lib/src/plugins/tdd/services/hand_surface.dart:285` — `hintLine`, which
  degrades to the hand-implement instruction when the seam is not wireable.

## Root Cause Hypothesis

Not a production regression — the production hint is deliberate and still
satisfies issue #1589's intent. The SUITE's fixture is stale.

Commit `20a4611f` ("fix: implement #1752 — wire accepts contract-seam shape;
hint gates on seam shape") made the hand-surface hint gate on the SEAM'S
SHAPE: `seamIsWireable` accepts only a single-line
`=> throw UnimplementedError(...)` seam, or a wrapped one carrying the
`CONTRACT SEAM (issue #1007)` provenance marker. `seedSeamFile` still seeds
`// kind: contract\nvoid main() {}\n` — no arrow-throw at all — so under
#1752's rule that seam is not wireable, the hint degrades, and the suite's
three wire-command assertions fail. Confidence: high.

## Proposed Remediation

**Preferred**: seed the seam with a realistic, wireable contract-seam body in
`seedSeamFile` so the fixture again matches the shape `seamIsWireable`
recognizes — e.g. a single-line
`bool validateEmail(String email) => throw UnimplementedError('not implemented');`
body, keeping the `// kind: contract` provenance marker. This is a
fixture-only change: no production code moves, and it gives #1752's wireable
path its first coverage.

**Alternatives**:
- Relax `seamIsWireable` to accept any seam — rejected: it would let the hint
  prescribe a command `zfa tdd wire` itself refuses (the dead end #1752
  removed).
- Change the assertions to accept the degraded hint — rejected: the suite's
  stated intent is that the park note names the wire command.

**Files likely to change**:
- `test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart`

**Tests to add or update**:
- none new — the existing three failing assertions ARE the regression test;
  they fail before the fix and pass after it.

## Risks & Considerations

- The seam body is only ever read by `seamIsWireable` and the mtime-based
  world-change probe in these tests, so a shape change cannot alter the
  verdict semantics.
- The suite stays in the `slow` tier, so the fast lane still does not
  execute it — a separate concern from this issue.

## Open Questions

- None.
