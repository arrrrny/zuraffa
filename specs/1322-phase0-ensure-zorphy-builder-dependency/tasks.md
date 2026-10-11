# Tasks 1322 — phase-0 builder-dependency preflight + missing-dependency diagnosis (MVP-first, dependency-ordered)

Every behavior task below is driven by a failing test FIRST
(tdd/test-list.md). Non-behavioral tasks are handled by
speckit.implement after the green loop.

## Phase 0 — RED (test-first evidence)

- [x] T0.1 Add `test/commands/builder_dependency_preflight_test.dart`:
      parser tests (canonical build.yaml content → zorphy, json_serializable,
      source_gen packages; pipe form; empty content), resolvability tests
      (package_config fixture → names; absent file → unverifiable), the
      classifier tests (missing zorphy detected; resolvable → empty;
      absent package_config → empty; output-signal corroboration; typo-in-
      resolvable-package NOT diagnosed; generic non-zorphy builder
      named), the auto-add tests (injected success spawn
      `dart pub add --dev zorphy`; injected failure → failed + blocking
      prescription; dry-run no-spawn; no-op no-spawn; flutter pubspec →
      `flutter pub add --dev`). [SC-1, SC-2, SC-3, SC-9]
- [x] T0.2 Extend `test/commands/build_command_unit_test.dart`: safety-net
      distinction — fixture with build.yaml + package_config WITHOUT
      zorphy → message names zorphy + `dart pub add --dev zorphy` + the
      build_runner signal, NOT the glob remedy; resolvable/absent-config
      fixtures → current glob remedy preserved. [SC-4, SC-5]
- [x] T0.3 Add `test/commands/entity_builder_preflight_test.dart`:
      in-process `EntityCommand.execute(create …, exitOnCompletion: false)`
      with an injected failing pub runner in a resolved project missing
      zorphy → throws (non-zero), entity file NOT written, blocking
      prescription names zorphy; with zorphy resolvable → entity created,
      pubspec byte-identical. [SC-6]
- [x] T0.4 Extend `test/plugins/tdd/run_command_test.dart` (bug-829
      group): scripted fake-zfa build failure carrying the unknown-builder
      signal + fixture package_config without zorphy → run stops with
      `result=missing-builder-dependency`, `stopped_at=phase-0:build`,
      message names zorphy + the fix. [SC-7]
- [x] T0.5 Add `test/plugins/tdd/make_build_step_classifier_test.dart`:
      the build-step failure classifier — failed `build` step with the
      signal (or the #276 safety-net marker) →
      `MakeOutcome.missingBuilderDependency`; non-build step / unlinked
      generic failure / everything-resolvable → null (existing grading).
      [SC-8]
- [x] T0.6 Run the new/extended suites, record RED evidence into
      `tdd/verification.md` (kernel-cache cleanup before/after;
      single-file runs only).

## Phase 1 — GREEN (the fix)

- [x] T1.1 NEW `lib/src/core/dependencies/builder_dependency_preflight.dart`:
      `RegisteredBuilder`, `BuilderPreflightResult`,
      `BuilderDependencyPreflight` (parser, resolvability, output-signal
      extraction, the shared classifier, the message lines, the
      injectable auto-add). [SC-1, SC-2, SC-3, SC-9]
- [x] T1.2 `entity_command.dart`: optional `pubRunner` constructor seam;
      preflight call in `_handleCreate` before any write; blocking bail
      on failed add; dry-run would-add. [SC-6]
- [x] T1.3 `build_command.dart`: `verifyOutputsOrFail` optional
      `buildOutput` param + classifier-first message branch; both `run()`
      call sites pass the captured output. [SC-4, SC-5]
- [x] T1.4 `run_driver_core.dart`: classify the phase-0 build failure
      through the evidence-requiring failed-build classifier →
      `missing-builder-dependency` stop naming the package + fix; every
      other path (incl. the U-991b generic-failure class) unchanged. [SC-7]
- [x] T1.5 `generation_plan.dart`: additive
      `MakeOutcome.missingBuilderDependency('missing-builder-dependency')`;
      `make_command.dart`: `missingBuildersForBuildStep` classifier seam
      + grade a classified failed build step with the new outcome (naming
      lines + subject-restore contract preserved, exit 1). [SC-8]
- [x] T1.6 Re-run the new/extended suites + the pinned existing suites
      (build_command_unit_test, build_yaml_guard_test, entity suites,
      run_command_test bug-829 group); all green; record GREEN evidence.

## Phase 2 — implement (non-behavioral)

- [x] T2.1 `speckit.analyze` cross-artifact drift pass: spec ↔ plan ↔
      tasks ↔ test-list consistency; fix drift, no scope growth.
- [x] T2.2 `dart analyze` on changed files; `dart format .`; zero
      remaining diffs. [SC-10]
- [x] T2.3 Disk housekeeping: remove kernel caches (`.dart_tool/test/`,
      `$TMPDIR/dart_test.kernel.*`), sandbox fixtures; confirm
      `df -h .` healthy.
- [x] T2.4 Commit spec artifacts + fix + tests together
      (`fix(1322):` Conventional Commits), push, open PR closing #1322
      with the clean phase-0 build-success demo.

## Dependency order

T0.1 → T0.2 → T0.3 → T0.4 → T0.5 → T0.6 (RED) → T1.1 → T1.2 → T1.3 →
T1.4 → T1.5 → T1.6 (GREEN) → T2.1 → T2.2 → T2.3 → T2.4. No
parallelizable tracks (one shared classifier every call site consumes).
