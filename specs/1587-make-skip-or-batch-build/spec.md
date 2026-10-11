**Template Version**: `zuraffa-1.0`

# Spec: 1587-make-skip-or-batch-build

## Overview

Every behavior's `zfa tdd make` runs the plan's terminal `zfa build` —
build_runner plus a whole-project `dart analyze` — even when the
behavior's generation wrote files no builder consumes (or wrote nothing
at all). On a 10-behavior pure-Dart calculator feature the make step
measured 56–274s per behavior while `find .dart_tool/build/generated
-name '*.g.dart' | wc -l` returned 0: the builders had nothing to emit,
and the step was pure per-behavior overhead (issue #1587). Make also
re-runs the target test as its precondition (drift check) even when a
verify-red certification recorded the exact same subject shape seconds
earlier — the same test runs up to three times per behavior. This spec
makes the build step SCHEDULED: it is skipped when the make's generation
wrote no build-relevant inputs, and the make precondition is satisfied
from the existing certification when the subject hash matches, so the
common no-drift cycle pays neither the whole-project build nor the
redundant precondition re-run.

Scope guard (hard constraints from the issue): the fix touches ONLY the
build-step scheduling and the test-run dedup. The `zfa build` command
itself, the analyze gate, and the run-loop state machine (`MakeOutcome`
set and its grading) are untouched. When the generation DOES write
build-relevant inputs, the build runs exactly as before.

## Acceptance Scenarios

1. **Given** a certified-red behavior whose make plan's generation steps
   write nothing a builder consumes (a plain-Dart subject under `lib/`
   with no builder-facing annotation — the reported calculator case —
   or nothing at all), **When** `zfa tdd make <id>` executes the plan,
   **Then** the terminal `build` step is SKIPPED — no `zfa build`
   subprocess is spawned (absent from the zfa argv log), a synthetic
   audit step with exit 0 and the skip note is recorded in the green
   evidence's generation block, the make prints the skip line naming
   issue #1587, and the make completes with its normal outcome (exit 0,
   green evidence appended when the target test passes).
   **Type**: acceptance
2. **Given** a certified-red behavior whose make plan's generation steps
   DO write something a builder consumes (a builder-facing annotated
   dart file — `@Zorphy`, `@JsonSerializable`, `@HiveType`, `@Route` —
   or a non-dart file), change a build config file, or delete a
   build-relevant file, **When** `zfa tdd make <id>` executes the plan,
   **Then** the terminal `build` step RUNS exactly as before — the skip
   gate never fires and the #737/#942/#1407 failed-build guards keep
   their existing contracts.
   **Type**: acceptance
3. **Given** a behavior whose cycle log's LAST entry is a certified red
   carrying a subject hash, and the CURRENT subject file hash equals the
   certified hash (no drift since verify-red), **When** `zfa tdd make
   <id>` reaches its precondition, **Then** the drift-check target-test
   re-run is SATISFIED FROM THE CERTIFICATION — no `dart test`
   subprocess runs for the precondition, the make prints the dedup note
   naming issue #1587, and generation proceeds directly (the certified
   red's recorded verdict stands as the precondition evidence).
   **Type**: acceptance
4. **Given** a behavior whose certified red entry is hashless (legacy
   log) or whose current subject hash DIFFERS from the certified hash
   (subject drifted or was hand-implemented), **When** `zfa tdd make
   <id>` reaches its precondition, **Then** the drift-check target-test
   re-run executes exactly as before — hashless/drifted shapes fail open
   to the live re-run (safe fallback, never a silent pass).
   **Type**: acceptance
5. **Given** a behavior whose cycle log has a green (or refactor) entry
   AFTER its last red entry (the behavior was already made), **When**
   `zfa tdd make <id>` reaches its precondition, **Then** the drift
   check runs live — the dedup never overrides the already-green skip
   transition (issue #694) or the subject-drift refusal (issue #1036),
   whose contracts are unchanged.
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The make plan's terminal `build` step MUST be skipped when
  the generation steps wrote no build-relevant inputs since the pipeline
  started. The gate evaluates the changed-file set (content fingerprint
  captured before the first pipeline step, re-read before the build
  step): skip is allowed ONLY when (a) no build-relevant file was
  deleted, (b) no build config file changed (`pubspec.yaml`,
  `pubspec.lock`, `build.yaml`, `analysis_options.yaml`,
  `dart_test.yaml`, `.zfa.json`, `.dart_tool/package_config.json`), and
  (c) every created/modified build-relevant file is a `.dart` file whose
  content carries no builder-facing annotation (`@Zorphy`, `@ZorphyMixin`,
  `@JsonSerializable`, `@HiveType`, `@HiveField`, `@Route`,
  `@ZfaRoute` — the content-filter pattern the DDA route stage itself
  uses). Build-relevant paths: `lib/`, `test/`, `bin/`, `tool/` plus the
  config files above.
- **FR-002**: A skipped build step MUST be recorded honestly in the
  audit: the pipeline result carries a synthetic step with the build
  command, exit 0, the skip reason in its output, and a skip marker;
  the green evidence's generation block renders the step with the skip
  note. The make's stdout prints the skip decision naming issue #1587.
- **FR-003**: When the build step runs (any FR-001 condition fails), the
  pipeline, the #737 per-behavior tolerance, the #942 analyzer-error
  gate, and the #1407 warnings-only refusal behave EXACTLY as before —
  the gate is a scheduling decision, never a verdict change.
- **FR-004**: The make precondition drift check MUST be satisfied from
  the certified red evidence when: the behavior's LAST cycle-log entry
  is a red entry, that entry carries a subject hash, the recorded exit
  is 1 (a certified red), and the CURRENT subject file's sha256 equals
  the recorded hash. The dedup prints the decision line and uses the
  certification's recorded command/exit as the precondition evidence.
- **FR-005**: The dedup MUST fail open to the live drift re-run when any
  FR-004 condition is unmet (hashless legacy entries, drifted subject,
  or a green/refactor entry after the last red). The #694 skip
  transition, the #1036 subject-drift refusal, the #1323 hand-delta
  re-certification, and the #1162 re-drive adoption all keep their
  existing shapes.
- **FR-006**: The post-generation green-evidence target test MUST stay a
  live run (issue #1587: "only (3) must be live") — the dedup never
  fabricates green evidence.
- **FR-007**: The gate and the dedup MUST be observable: the skip and
  dedup paths print machine-findable notes naming issue #1587, and the
  fake-zfa argv-log tests assert the presence/absence of the `build`
  spawn.
- **FR-008**: The pipeline runner's new scheduling flag MUST default to
  OFF for existing callers — no caller's behavior changes unless the
  make command opts in.

## Success Criteria (measurable)

- **SC-001**: On a fixture make whose generation writes only a plain
  (un-annotated) Dart subject, the fake-zfa argv log records ZERO
  `build` invocations (was: 1) and the make still exits 0 with green
  evidence when the target test passes.
- **SC-002**: On a fixture make whose generation writes an annotated
  (`@Zorphy`) dart file under `lib/`, the fake-zfa argv log records the
  `build` invocation (unchanged from pre-fix).
- **SC-003**: On a fixture make whose generation changes a build config
  file (or deletes a build-relevant file), the `build` invocation is
  recorded (config churn and deletions never skip).
- **SC-004**: On a fixture make whose certified red entry carries the
  matching subject hash, the precondition runs ZERO target-test
  subprocesses and the run completes green.
- **SC-005**: On a fixture make with a hashless certified red, the
  precondition still runs the target test exactly once (unchanged).
- **SC-006**: `dart analyze` reports zero new findings against the
  112-info pre-fix baseline.

## Non-Goals

- Batch build once per run (criterion 2) and `--build-filter` scoping
  (criterion 3) — larger surface (run driver + build command flags);
  recorded as future work. The skip gate removes the per-behavior cost
  for the reported no-output case without touching those surfaces.
- No change to `zfa build`, build_runner invocation, the analyze gate,
  `MakeOutcome`, or the run driver.
- No change to the verify-red evidence schema (the dedup reads the
  EXISTING `subject-hash` field).
