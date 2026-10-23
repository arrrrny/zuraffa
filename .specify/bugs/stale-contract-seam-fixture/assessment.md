# Bug Assessment: the bug_1589 contract-seam fixture seeds a non-wireable placeholder

- **Slug**: stale-contract-seam-fixture
- **Created**: 2026-10-22
- **Source**: https://github.com/arrrrny/zuraffa/issues/2004
- **Verdict**: valid
- **Severity**: low

## Report (summarized)

> **Update (fixes round)**: `master` advanced while this PR's fixes were
> being written and landed a COMPETING fix for the same fixture staleness —
> the single-line wireable body seeded into the generated contract TEST, the
> shape the #2006 review rejected (the contract seam lives in the SUBJECT
> file and carries the CONTRACT lane's shape). The artifact-pair seeding
> this assessment recommends is what the PR carries; the merge resolves the
> conflict in favour of it and keeps master's `takeExitCode` flake guard.

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

- `test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart`
  — the fixture's seam-seeding helper (`seedSeamFile` at the time of this
  assessment; `seedContractArtifacts` after the fix), which writes the seam
  file.
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
`CONTRACT SEAM (issue #1007)` provenance marker. The fixture's seam-seeding
helper still seeds `// kind: contract\nvoid main() {}\n` — no arrow-throw at
all — so under #1752's rule that seam is not wireable, the hint degrades, and
the suite's three wire-command assertions fail. Confidence: high.

## Proposed Remediation

**Preferred**: seed the behavior's generated contract artifacts the way
`zfa tdd gen` writes them (issue #1007) — the contract SEAM at
`lib/tdd/<feature>/<snake>_subject.dart` and the contract TEST scaffold at
`test/tdd/<feature>/<snake>_test.dart`, both rendered by the production
writers (`ContractSubjectWriter` / `ContractTestWriter`).

The ARTIFACT, not the regex it happens to satisfy, is what the fixture must
model:

- **The seam lives in the SUBJECT file** — the file `zfa tdd wire` rewrites
  (`record.subjectPath`) and the file `HandSurface.seamPathFor` resolves
  first (issue #1625). A seam body in the generated contract TEST is not
  something the wire command can rewrite.
- **The seam carries the CONTRACT lane's shape** — the WRAPPED arrow-throw
  with the `CONTRACT SEAM (issue #1007)` provenance marker
  (`ContractSubjectWriter._render`), the arm `seamIsWireable` reads as
  wireable (issue #1752). The unit lane's single-line arrow-throw is the
  OTHER arm, so seeding it leaves the contract lane uncovered.
- **The seam declares its OWN contract** — the signature is derived from
  the behavior's declared contract, so `contract:A2` declares `login`, not
  `validateEmail`.
- **The generated test keeps a loadable `main()`** — a `*_test.dart` that
  cannot load is exactly the unattested failure the `--parked-seam` refactor
  gate must not tolerate.

This is a fixture-only change: no production code moves, and it gives
#1752's contract-lane wireable path its first coverage.

**Alternatives**:
- Relax `seamIsWireable` to accept any seam — rejected: it would let the hint
  prescribe a command `zfa tdd wire` itself refuses (the dead end #1752
  removed).
- Change the assertions to accept the degraded hint — rejected: the suite's
  stated intent is that the park note names the wire command.

**Files likely to change**:
- `test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart`
- `test/plugins/tdd/helpers/tdd_fixture.dart` — the registry record must
  name the seeded seam (an optional `subjectPath`).
- `.specify/bugs/stale-contract-seam-fixture/assessment.md` — this file.

**Tests to add or update**:
- the existing three failing assertions ARE the regression test; they fail
  before the fix and pass after it.
- one new pin: the seeded seam carries the contract lane's shape (the
  marker + the wrapped arrow-throw) in the subject file, and each seam
  declares its own contract.

## Risks & Considerations

- The seam body is read by `seamIsWireable` and by the mtime-based
  world-change probe in these tests, so a shape change cannot alter the
  verdict semantics. The seam now lives under `lib/`, which the #1544 watch
  set scans — the still-blocked cases must backdate it, or they read as
  "the world changed" and the skip never fires.
- The suite stays in the `slow` tier, so the fast lane still does not
  execute it — a separate concern from this issue.

## Open Questions

- None.
