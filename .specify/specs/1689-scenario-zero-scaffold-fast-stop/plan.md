**Template Version**: `zuraffa-1.0`

# Plan: 1689-scenario-zero-scaffold-fast-stop

## Technical Context

- Language/Dart SDK: ^3.11.0 (repo), running on Dart 3.13.4 stable.
- CLI surfaces involved:
  - `lib/src/plugins/tdd/commands/make_command.dart` — the TDD make
    cycle: unit-row kind probe `_rowKindQuiet` (L~2645), the 3c
    vacuous-green preflight (#1259/#1488, L~1176–1274), the drift check
    (L~1306–1374, real `dart test` subprocess; the #694 skip transition
    returns before planning), plan via `GenerationPlanner` (L~1690),
    the #1330 no-op fallback closing at L~1835, the #1036 subject
    snapshot (L~1843), `PipelineRunner.runPlan` (L~1858 — the func
    spawn + build), the post-generation target test (L~2162) and the
    `generation-error` stop (L~2234–2245), the 9b placeholder refusal
    (#1651, L~2452–2533), `_printSummary` (L~4082) and its verdict
    switch (L~4126, default → fail). The #1565 predict-and-skip
    precedent `_subjectWouldMakeFuncRefuse` (L~2669) is the shape the
    new pre-flight mirrors.
  - `lib/src/plugins/tdd/commands/func_command.dart` — `_renderScaffolded`
    (L~594) and `_declaredStubBody` (L~629–641): the #1517 zero-scaffold
    vocabulary the forecast must mirror (`String` → the function's own
    name, `int` → `0`, `double` → `0.0`, `bool` → `true`; everything
    else — including `void`, `num`, nullable tokens, entities — keeps
    the still-red `UnimplementedError` branch). `functionName` comes
    from `SubjectProvenance.funcRewritableStubPattern` group 2 (L~326) —
    the same pattern make consults. NOT modified (hard constraint).
  - `lib/src/plugins/tdd/services/subject_provenance.dart` —
    `funcRewritableStubPattern` (the arrow-throw stub shape: return
    type / name / params groups) and `kGenProvenanceMarker` (proves gen
    wrote the file — the gate's provenance safety).
  - `lib/src/plugins/tdd/models/generation_plan.dart` — `MakeOutcome`
    (L~19–232): the new `wouldNeverPass('would-never-pass')` entry;
    every existing switch on the enum has a default arm.
  - `lib/src/plugins/tdd/services/behavior_test_writer.dart` —
    `_declaredAssertion` (L~475–498): the #1679 shape the gate detects
    (`expect(result, equals(<literal>))` when a scenario resolved; the
    `isA<T>()` + marker fallback when not).
- Test seams (existing, reused): `test/plugins/tdd/helpers/tdd_fixture.dart`
  — `writeFakeZfaBin` (argv-logged fake zfa with side-effect dispatch;
  the #1587 SC pattern makes func spawning OBSERVABLE),
  `registerBehavior`, `seedRedEvidence`, `subjectPathOf`,
  `readFakeZfaLog`, `CliRunner.runCapturing`. The e2e probe extends the
  `bug_1651_vacuous_green_e2e_test.dart` fixture shape (real `dart pub
  get` + real `dart test` subprocesses; tagged `e2e` so the fast lane
  excludes it).

## Design

### 1. The forecast service (new, single-sourced)

`lib/src/plugins/tdd/services/scaffold_attempt_forecast.dart`:

- `funcScaffoldDummyLiteral(returnType, functionName)` — the #1517
  forward map as a source literal, mirroring `_declaredStubBody`
  verbatim; null for every non-literal scaffold (safe direction).
- `ScaffoldAttemptForecast` — `returnType`, `functionName`,
  `dummyLiteral` (source form), `expectedLiteral` (the first
  provably-unsatisfiable assertion literal, source form).
- `forecastMakeAttempt({subjectSource, testSource})` — the ONE gate
  predicate:
  1. `funcRewritableStubPattern.firstMatch(subjectSource)` — func's own
     rewrite shape; miss → null (foreign/hand shape: attempt as today).
  2. `kGenProvenanceMarker` present — gen wrote the stub (a
     hand-authored file never scaffolds the predicted dummy).
  3. Parametrized stub (group 3 non-empty) — the #1679 scenario class
     is parametrized by construction; the legacy no-arg description-
     derived body (`deriveSubjectSignature`) is a different scaffold
     the gate must not speak for.
  4. `funcScaffoldDummyLiteral(group1, group2)` — null → silent.
  5. Test side: scan `equals(<literal>)` value assertions; fire on the
     FIRST literal provably different from the dummy (value-aware
     comparator per FR-004; unparseable → skip that assertion).
- `wouldNeverPassRemedy({behaviorId, subjectPath, testPath})` — the
  single-sourced `--> fix:` line (the #1651 `scalarDummyGreenRemedy`
  precedent): hand-implement the subject, then re-run make; the re-run's
  drift check certifies the implemented subject.

### 2. The outcome entry

`generation_plan.dart`: `MakeOutcome.wouldNeverPass('would-never-pass')`
with the class doc (guaranteed-failing attempt skipped BEFORE the
pipeline; same honest hand-step remedy, minus the 30–40s; self-removes
per FR-006). `_printSummary`'s switch default (`VerdictOutcome.fail`)
grades it with zero changes; the run driver's generic make-failure arm
owns the loop semantics (unchanged, per spec FR-002/Non-Goals).

### 3. The make gate (6b)

`make_command.dart`, after the plan finalizes (the #1330 fallback
closes) and BEFORE the #1036 subject snapshot / `SourceWriteProbe` /
`runPlan` — nothing has been mutated there, so no restore machinery is
needed:

- Scope: `vacuousRowKind == BehaviorKind.unit` (the 3c precedent's row
  probe, already computed), `!effectivePlan.funcStepSkipped`, and the
  plan actually schedules a `tdd func` step.
- Probe: `_wouldNeverPassForecast({cwd, record})` — best-effort read of
  the subject + test (fail-open on missing/unreadable, the
  `_subjectWouldMakeFuncRefuse` convention) feeding
  `forecastMakeAttempt`.
- Fire: print the diagnosis (issue #1689, the dummy, the declared
  return, the offending literal) + the single-sourced remedy with the
  recorded project-relative paths (the 9b call-site convention),
  `_printSummary(outcome: MakeOutcome.wouldNeverPass)`, exit 1, return.
  No green evidence, subject untouched (byte-identical — the #1036
  contract holds trivially: nothing has run).

### 4. Why this position

After the drift check (the #694 skip transition must keep its chance to
certify a hand-implemented subject — a gate BEFORE the drift check
would refuse makes that should have been skips) and after planning (the
gate needs the plan's func fact, and the #1565 skip must win first) and
before the pipeline (the whole point: the func write, the build
scheduling, and the doomed post-generation target test never happen).

## Test seams

- Unit (fast, no subprocess):
  `test/plugins/tdd/services/scaffold_attempt_forecast_test.dart` — the
  predicate truth table per spec FR-001/FR-004: fires for int/double/
  bool/String × a differing literal; silent for zero-matching literals
  (`equals(0)`, `equals(0.0)` vs int, `equals(true)` vs bool, the
  function's own name vs String), for `void`/`num`/`int?` returns, for
  the legacy no-arg stub, for marker-less (hand-authored) subjects, for
  non-stub bodies, for guard-only/type-only tests, and for unparseable
  matcher args (fail-open).
- E2E (the probe, real `dart test` subprocesses, fake-zfa argv log):
  `test/plugins/tdd/commands/bug_1689_scenario_zero_scaffold_fast_stop_e2e_test.dart`
  — B-1689-U1 (the bug: stub + `equals(5)` → `would-never-pass`, ZERO
  spawns, wall-time printed), B-1689-U2 (guard-only → `vacuous-green`
  unchanged), B-1689-U3 (type-only + dummy → 9b `vacuous-green`
  unchanged), B-1689-U4 (zero-matching `equals(0)` → gate silent, func
  spawns), B-1689-U5 (real implementation + `equals(5)` → `skipped`
  unchanged).
