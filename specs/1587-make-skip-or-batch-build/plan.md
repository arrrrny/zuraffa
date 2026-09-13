**Template Version**: `zuraffa-1.0`

# Plan: 1587-make-skip-or-batch-build

## Technical Context

- Language/Dart SDK: ^3.11.0 (repo), running on Dart 3.13.3 stable.
- CLI surfaces involved:
  - `lib/src/plugins/tdd/commands/make_command.dart` — the TDD make
    cycle: certified-red precondition (L~405), drift check / target-test
    re-run before generation (L~1085, `_runTargetTest` → real `dart
    test` subprocess), plan via `GenerationPlanner` (L~1377), pipeline
    execution `PipelineRunner.runPlan` (L~1527), post-generation target
    test (L~1810), suite guard (L~1908), green evidence append (L~2015).
  - `lib/src/plugins/tdd/services/pipeline_runner.dart` — executes the
    plan's steps in order via `Process.run` (`runTimed`), capturing
    `GenerationStep`s; stops on first failure.
  - `lib/src/plugins/tdd/services/generation_planner.dart` — every
    expressible plan terminates in a `build` step (`args: ['build']`),
    appended in ~9 branches; one execution-time gate covers all of them
    (the planner stays pure — it never reads files).
  - `lib/src/commands/build_command.dart` — the `zfa build` child: DDA
    route stage (`_contentFilter = RegExp(r'@(Route|ZfaRoute)\b')` is
    the repo's own content-filter precedent), build_runner, analyze
    gate. NOT modified (hard constraint).
  - `lib/src/plugins/tdd/services/cycle_evidence.dart` —
    `ParsedCycleEntry` parse of `- subject-hash:` (sha256 hex, 64 chars)
    — the field the dedup reads.
- Test seams (existing, reused): `test/plugins/tdd/helpers/tdd_fixture.dart`
  — `writeFakeZfaBin` (argv-logged fake zfa with side effects/exit
  dispatch), `seedCertifiedRed`, `CliRunner.runCapturing`. The fake-zfa
  argv log makes build-step spawning OBSERVABLE; `runCapturing` output
  makes the skip/dedup notes observable.

## Design

### 1. Build-relevance gate (new service)

`lib/src/plugins/tdd/services/build_relevance.dart`:

- `BuildRelevance.buildConfigFiles` — the config set whose change always
  requires a build.
- `BuildRelevance.builderFacingAnnotation` — one RegExp covering the
  annotations `zfa build`'s stages consume (`@Zorphy(@Mixin)?`,
  `@JsonSerializable`, `@HiveType`, `@HiveField`, `@Route`,
  `@ZfaRoute`). Raw-content match: a comment false-positive only makes
  the build RUN (safe direction).
- `BuildRelevance.fingerprint(projectRoot)` — walks `lib/`, `test/`,
  `bin/`, `tool/` plus the config files; returns
  `Map<String,String>` (POSIX-relative path → sha256 hex). Deleted
  files are absent from the later map → deletion detection.
- `BuildRelevance.canSkipTerminalBuild({before, after, contentOf})` —
  pure decision: skip iff no deletions, no config change, and every
  created/modified file is a `.dart` file whose CURRENT content carries
  no builder-facing annotation.

### 2. Pipeline scheduling seam

`PipelineRunner.runPlan` gains `bool skipUnchangedBuild = false`
(FR-008: default OFF). When set, the runner fingerprints the project
before step 0; before executing a step whose args are exactly
`['build']` it re-fingerprints and consults the gate:

- skip → capture a synthetic `GenerationStep` (exit 0, skip note in
  output, `buildSkipped: true` marker — new optional field, default
  false) and continue; the decision is made ONCE per plan.
- run → proceed byte-identically to today (all #737/#942/#1407 guards
  downstream see a real executed step).

`GenerationStep.buildSkipped` renders in `CycleLogEntry.toMarkdown` as
an additive `note:` line in the generation block (schema stays v1 — the
`- evidence:`/`- subject-hash:` optional-line precedent).

### 3. Drift-check dedup (make precondition)

`make_command.dart` step 4 keeps its place and shape; the live
`_runTargetTest` call is guarded by a new `_driftRunDedupCertificate`
helper:

- Reads `CycleEvidence.lastEntryFor(behaviorId, kind: 'red')` and the
  behavior's last entry of ANY kind; dedup eligible iff the last entry
  IS that red entry, it has a 64-hex `subject-hash`, `exit == 1`, and
  the current subject's sha256 (existing `_subjectHashAt`) equals it.
- Eligible → fabricate the precondition `RunRecord` from the
  certification (command/exit/output recorded by verify-red; exit 1 ⇒
  not already-green ⇒ generation proceeds) and print the dedup note.
  `driftRun.timedOut` is false, `startedProcess` true — the #742/#1402
  misfire checks pass through unchanged (verify-red already certified a
  real assertion red).
- Not eligible → live drift re-run exactly as before (hashless legacy
  entries, drifted subject, green/refactor after red — FR-005 fail
  open).

The post-generation green-evidence run stays live (FR-006).

## Alternatives rejected

- Batch build per run (criterion 2): needs run-driver state and a
  scheduling owner; the state machine must stay untouched, and the
  residual risk (a skipped final build never running) is worse. The
  skip gate gets the same economics for the reported case.
- `--build-filter` scoping (criterion 3): changes the build command
  surface (hard constraint forbids).
- Dedup keyed on subject hash alone without the "last entry is red"
  guard: would override the #694 skip transition / #1036 drift refusal
  shapes. Guarded (FR-005).
- Recording a `test-hash` in red entries to prove test-bytes freshness:
  expands the evidence schema and verify-red surface; rejected. The
  dedup only skips a RED-side precondition re-run — every failure mode
  surfaces one step later at the live post-generation run with the same
  verdict, and green evidence is always live.

## Verification

- Red tests first (see `tdd/test-list.md`), driven through the public
  CLI surface (`zfa tdd make` + fake zfa argv log) plus pure unit tests
  for the gate decision.
- `dart analyze` diffed against the saved 112-info baseline: zero new.
- `dart format` clean on touched files.
