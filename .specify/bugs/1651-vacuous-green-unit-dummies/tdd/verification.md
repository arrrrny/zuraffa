# TDD Verification: 1651-vacuous-green-unit-dummies (#1651)

- **Feature**: `.specify/bugs/1651-vacuous-green-unit-dummies`
- **Date**: 2026-09-15
- **Mode**: LLM-guided fallback audit (`ZFA_MISSING` — no `.zfa.json`; the
  zuraffa repo cannot drive `zfa tdd verify` on its own development; the
  `dart-core-lane-timeout-overflow` precedent)
- **Verdict**: **PASS**

## Audit dimensions

### 1. Test-first evidence

- RED ran BEFORE the fix touched any lib file (same session, sequential
  commands): `test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart`
  → `+5 -4` with the four failures being exactly the new contract
  (detector classification U1a-c, writer marker emission U3); the e2e
  repro failed at `Which: does not contain 'zfa:tdd: vacuous-guard'` on
  gen's real output. Evidence: `../red-evidence.md`, `cycle-log.md`
  (red cycle).
- GREEN applied the minimal fix; the same suites pass (`+9`, `+1`).
  Evidence: `cycle-log.md` (green cycle).

### 2. Red-phase honesty

The red failures are the bug's mechanism, not contrived assertions: the
e2e red captured the REAL `zfa tdd gen` output —
`subject.subject_u1(0, 0)` + `expect(result, isA<int>())`, marker-less —
which is the issue's verbatim complaint.

### 3. Test smells — none found

- No sleeps/timeouts/order dependence; fixtures are temp-dir scoped with
  `addTearDown`/`tearDown` disposal.
- Failure reasons name the contract (the #1259/#1651 reason-string
  discipline).
- Tier discipline: detector/writer pins fast; the process-spawning repro
  is `@Tags(['e2e'])` (honest under direct invocation, excluded from CI's
  fast lane — the #1510 convention).

### 4. Mutation results (targeted, changed seams)

| Mutant | Change | Result |
| ------ | ------ | ------ |
| M1 | `contentIsVacuousGreen` drops the `_typeOnlyScalarExpect` strip | **killed** — U1a/U1b/U1c fail (`+6 -3`) |
| M2 | scalar branch emits `$vacuousGuardComment` instead of `$typeOnlyVacuousGuardComment` (compiles; marker survives) | **killed** — U3 fails the `issue #1651` wording pin (`+8 -1`) |
| restore | both reverts | `+9: All tests passed!`, `dart analyze` clean |

Additional structural kills (by existing suites): the legacy-pin flips
themselves are mutant killers — 1310 U6 kills "make certifies a dummy
green" (now expects `outcome=vacuous-green`); 1259 U5 / 1538 B1 / 1512
guardrail kill "scalar emission without the marker" at the content level.

### 5. Acceptance-criteria coverage

- AC-1 (red on pre-fix tree): covered — `red-evidence.md`.
- AC-2 (green tree, legacy pins updated, family stable): covered —
  fast batch `+46`, slow/e2e batch `+33` (1259, 1538, 1310, 1411),
  untagged driver batch + the 1651 e2e — all passed.

## Gaps

- The full mutation harness (the engine's per-behavior mutant loop) was
  not run — `ZFA_MISSING`; two hand-driven targeted mutants were, both
  killed. Acceptable for the fallback audit on a two-function diff.
- The whole-repo fast suite was not run (surgical contract: only the
  affected families). CI's fast lane is the net for unrelated surprises.

## Verdict

**PASS** — test-first proven (red→green with evidence), no smells,
targeted mutants killed, acceptance criteria covered.
