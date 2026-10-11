# TDD Verification — Spec 1322 phase-0 ensure zorphy builder dependency

## Test-first evidence (RED recorded before implementation)

All new behaviors (tdd/test-list.md) were written BEFORE any lib/ change.
Red runs were executed after `rm -rf .dart_tool/test/ && rm -f
$TMPDIR/dart_test.kernel.*` kernel-cache cleanup, single-file runs only
(never the full suite — cloud-agent disk protocol).

### RED observation 1 — assertion red (the misdiagnosis, pinned by the harness)

```
dart test --preset=all test/plugins/tdd/run_command_test.dart --plain-name "1322"
00:00 +0 -1: Some tests failed.
Expected: contains '[run] phase-0 build -> failed (missing builder dependency)'
  Actual: 'zfa tdd run: feature 090-run-driver — 3 behavior(s)\n'
            '[run] phase-0 entity User -> created\n'
            '[run] phase-0 build -> failed\n'
            '   zfa build --no-analyze: [WARNING] Ignoring options for unknown builder "zorphy:zorphy" found in build.yaml.\n'
            'zfa tdd run: phase-0 build failed (exit 1) — the run stops before any behavior is driven (bug #829).\n'
            'run: feature=090-run-driver result=runner-error pending=3 red=0 green=0 done=0 stopped_at=phase-0:build\n'
```

The red output pins the issue verbatim: the driver PRINTS the
build_runner unknown-builder warning and still labels the stop
`result=runner-error` with the generic message — the exact #1322
misdiagnosis (one missing dev dependency dead-ending the feature under a
label that never names it).

### RED observation 2 — compile reds (the APIs do not exist yet)

| Suite | RED observation |
|---|---|
| test/commands/builder_dependency_preflight_test.dart | `Error: Error when reading 'lib/src/core/dependencies/builder_dependency_preflight.dart': No such file or directory`; `Undefined name 'BuilderDependencyPreflight'` |
| test/commands/build_command_unit_test.dart | `Error: No named parameter with the name 'buildOutput'` (lines 397/441 — the safety-net distinction has no seam yet) |
| test/commands/entity_builder_preflight_test.dart | `Error: No named parameter with the name 'pubRunner'` (the preflight is not injectable yet) |
| test/plugins/tdd/make_build_step_classifier_test.dart | `Error: Member not found: 'MakeCommand.missingBuildersForBuildStep'`; `Error: Member not found: 'missingBuilderDependency'` (the outcome does not exist yet) |

## Green evidence (after implementation)

Fix: NEW `lib/src/core/dependencies/builder_dependency_preflight.dart`
(the shared classifier + injectable `pub add --dev` preflight + message
contract) wired into four call sites — `entity_command.dart` (AC-1
preflight before the entity write), `build_command.dart` (AC-2
safety-net distinction, `buildOutput` pass-through from the already-
captured `_BuildOutput`), `run_driver_core.dart` (AC-3 phase-0 label via
the evidence-requiring `missingBuildersForFailedBuild`),
`generation_plan.dart` + `make_command.dart` (AC-3 make outcome). The
core engine cycle, the build_runner invocation, zorphy codegen, and the
verify gate are untouched (scope fence).

Mid-green discovery: the static classifier alone mis-attributed the
U-991b class (a generic build failure over a missing-package state —
`TddFixture.create` runs `pub get`, so the fixture's package_config
exists without zorphy). Fixed by requiring FAILURE-LINKED evidence in
the captured output (the build_runner signal, or the #276 safety-net
marker) for every exit != 0 classification; the static check alone
remains authoritative only for the exited-0-but-wrote-0-outputs safety
net, and the typo class (signal but package resolvable) still falls
through to the glob remedy. Regression pins added at both tiers
(service `missingBuildersForFailedBuild` group + U-991b staying green
unmodified).

### Per-suite GREEN results (kernel cache cleaned before each run)

| Suite | Result |
|---|---|
| test/commands/builder_dependency_preflight_test.dart | 20 passed, 0 failed |
| test/plugins/tdd/make_build_step_classifier_test.dart | 6 passed, 0 failed |
| test/commands/entity_builder_preflight_test.dart | 2 passed, 0 failed |
| test/commands/build_command_unit_test.dart (44 pre-existing + 2 new + countEntities/hasGeneratedOutputs groups) | 48 passed, 0 failed |
| test/plugins/tdd/run_command_test.dart (full file, incl. the 1322 test + U-991b/U-829c..f pinned) | 50 passed, 0 failed |
| test/plugins/tdd/two_cycle_run_commands_test.dart (run-engine/run-skin share the driver core) | 21 passed, 0 failed |
| test/commands/build_yaml_guard_test.dart + bug_1303_build_retry_skip_test.dart | 13 passed, 0 failed |
| test/commands/entity_convergent_test.dart + entity_create_primitive_types_test.dart + entity_cli_exit_code_test.dart + entity_help_test.dart | 16 passed, 0 failed |
| test/commands/entity_receipt_test.dart + make_pubspec_auto_add_test.dart (#1265 precedent, EntityCommand ctor back-compat) | 5 passed, 0 failed |

Known-unrelated pre-existing failures (verified on the CLEAN tree by
`git stash` → identical +33 −5 profile → `git stash pop`):

- `test/plugins/tdd/make_command_test.dart`: 5 failures (bug 657 manual-
  implementation hint, U-829g/U-829h entity-pipeline plan shape, SC-004
  composition, A15 #737 skip transition) — present on master `0a9f448`
  without any #1322 change; untouched by this fix (no make grading
  branch they exercise changed for unlinked failures).

## Acceptance-criteria coverage

| SC | Proof |
|---|---|
| SC-1 preflight spawns `dart pub add --dev zorphy` | 'runs `dart pub add --dev zorphy` in the project root' — injected runner records exactly one `dart pub add --dev zorphy [<root>]` invocation, added=[zorphy] |
| SC-2 blocking refusal | 'blocks when the add fails: failed names the package' — failed=[zorphy], commandLine=`dart pub add --dev zorphy`, prescription lines contain the exact command |
| SC-3 no-op + dry-run | 'no-op when every builder package is resolvable (no spawn)' (invocations empty); 'dry-run reports the would-add without spawning or writing' (invocations empty, pubspec byte-identical) |
| SC-4 safety net names the package | build_command_unit_test '#1322: 0 outputs + builder package missing…' — message contains zorphy, `dart pub add --dev zorphy`, the signal, `package_config.json`; does NOT contain `generate_for` / `zfa setup` |
| SC-5 glob remedy preserved | build_command_unit_test '#1322 back-compat' + ALL pre-existing #276 tests unmodified (48/48) — resolvable/absent-config states print the current glob message |
| SC-6 CLI-tier blocking + no-op | entity_builder_preflight_test: failing injected add → entity dir absent + prescription; zorphy resolvable → entity created, pubspec byte-identical, no spawn |
| SC-7 phase-0 label | run_command_test 1322 test: `result=missing-builder-dependency`, `stopped_at=phase-0:build`, message names zorphy + fix, `isNot(contains('result=runner-error'))`; U-991b (generic failure) stays green with `result=runner-error` |
| SC-8 make outcome | make_build_step_classifier_test: signal → missingBuildersForBuildStep non-null (zorphy named); generic/unlinked failures and non-build steps → null; `MakeOutcome.missingBuilderDependency.label == 'missing-builder-dependency'` |
| SC-9 generic, not hardcoded | preflight service tests: `some_other_pkg:its_builder` fixture → diagnosis names `some_other_pkg` + `dart pub add --dev some_other_pkg`, `isNot(contains('zorphy'))`; pipe form parsed |
| SC-10 analyze/format | `dart analyze` on all six changed lib files → `No issues found!`; `dart format .` → zero remaining diffs (see below) |

## Test-strength / mutation evidence

The full mutation engine (`zfa tdd verify`'s MutationAuditor) was NOT
run: the cloud-agent protocol forbids the full suite (≈6.5 GB kernel
cache overflow) and the auditor mutates scope subjects beyond this
fix's files. Honest compensating evidence:

- The classifier is pinned from BOTH sides (positive diagnosis AND the
  negative classes: unverifiable state, typo-in-resolvable-package,
  unlinked generic failure, non-build step, empty output) — a mutant
  that drops any guard condition flips at least one negative-class
  assertion.
- The back-compat pins are the strongest mutation check for the
  message/label seams: 48 build_command_unit_test assertions pin the
  glob remedy byte-for-byte for every non-#1322 state, and U-991b pins
  the generic `runner-error` label over a missing-package state — a
  mutant that classifies unlinked failures (the mid-green defect this
  spec actually hit) is killed by U-991b.
- The entity preflight is pinned at the CLI tier through the REAL
  in-process command (`EntityCommand.execute`), including the
  side-effect contract (entity file absent on blocking; pubspec
  byte-identical on no-op).
