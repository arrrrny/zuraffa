# TDD Test List — Spec 1322 phase-0 ensure zorphy builder dependency

One behavior per line, traced to the success criteria (SC-n) in
spec.md. Every behavior is written as a failing test FIRST (RED), then
made to pass (GREEN). Red for this feature is an assertion red: the
preflight/classifier APIs do not exist yet (compile red for the new
service tests) and the safety net / drivers print the generic messages
(assertion red for the existing-harness tests).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Builder-key parsing: canonical build.yaml content → packages {zorphy, json_serializable, source_gen}; `<pkg>|<builder>` form parses; empty content → empty set | SC-9 | test/commands/builder_dependency_preflight_test.dart |
| B2 | Resolvability: a package_config.json fixture → its package names; an ABSENT package_config.json → unverifiable (null) | SC-5 | test/commands/builder_dependency_preflight_test.dart |
| B3 | Classifier: resolved fixture (package_config without zorphy) + effective set containing zorphy:zorphy → missing [zorphy]; with zorphy resolvable → empty; package_config ABSENT → empty (never a false diagnosis) | SC-1, SC-5 | test/commands/builder_dependency_preflight_test.dart |
| B4 | Classifier corroboration: build_runner `Ignoring options for unknown builder "zorphy:zorphy"` in the output + zorphy absent from package_config → diagnosed; the same warning while zorphy IS resolvable (typo/stale class) → NOT diagnosed | SC-4 | test/commands/builder_dependency_preflight_test.dart |
| B5 | Generic: a fixture registering `some_other_pkg:its_builder` with that package absent → diagnosis names `some_other_pkg` + prescribes `dart pub add --dev some_other_pkg` | SC-9 | test/commands/builder_dependency_preflight_test.dart |
| B6 | Auto-add: injected success → exactly `dart pub add --dev zorphy` in the project root, added=[zorphy]; injected failure → failed=[zorphy] + blocking lines containing the exact command; dry-run → no spawn, would-add reported, pubspec byte-identical; all-resolvable → no spawn (no-op); flutter pubspec → `flutter pub add --dev zorphy` | SC-1, SC-2, SC-3 | test/commands/builder_dependency_preflight_test.dart |
| B7 | Safety net distinction: verifyOutputsOrFail with @Zorphy sources + 0 outputs + diagnosed missing zorphy → false; message names zorphy, contains `dart pub add --dev zorphy` + the build_runner signal, NOT the glob remedy | SC-4 | test/commands/build_command_unit_test.dart |
| B8 | Safety net back-compat: same fixture with zorphy resolvable (or package_config absent) → the CURRENT glob-remedy message (generate_for / lib/src/**), no `pub add` — existing #276 tests stay green unmodified | SC-5 | test/commands/build_command_unit_test.dart |
| B9 | Entity preflight blocking: in-process `zfa entity create` (injected failing runner) in a resolved project missing zorphy → non-zero (bail), entity file NOT written, blocking lines name zorphy + the exact command | SC-6 | test/commands/entity_builder_preflight_test.dart |
| B10 | Entity preflight no-op: zorphy resolvable → entity created normally, pubspec byte-identical, no spawn | SC-3, SC-6 | test/commands/entity_builder_preflight_test.dart |
| B11 | Phase-0 labeling: scripted phase-0 build failure carrying the signal → run stops `result=missing-builder-dependency` (not runner-error), `stopped_at=phase-0:build`, message names zorphy + `dart pub add --dev zorphy`; a GENERIC failure over the same missing-package state keeps `result=runner-error` (the U-991b contract, unmodified) | SC-7 | test/plugins/tdd/run_command_test.dart |
| B12 | Make labeling: the build-step failure classifier grades a failed `build` step carrying the signal (or the #276 safety-net marker) as `MakeOutcome.missingBuilderDependency`; a non-build step, an unlinked generic failure, or an unclassified build failure → null — the existing grading stands | SC-8 | test/plugins/tdd/make_build_step_classifier_test.dart |

## Red protocol

Run per file, never the full suite (disk ceiling):

```
rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*
dart test test/commands/builder_dependency_preflight_test.dart
dart test test/commands/build_command_unit_test.dart
dart test test/commands/entity_builder_preflight_test.dart
dart test test/plugins/tdd/make_build_step_classifier_test.dart
dart test --preset=all test/plugins/tdd/run_command_test.dart --plain-name 1322
```

Expected RED: B1–B6 compile-red (the preflight service does not exist);
B7/B9/B11/B12 assertion-red (generic messages/labels today); B8/B10
back-compat pins may pass immediately (they pin unchanged behavior).

## Green protocol

Same single-file commands after the fix lands in
`lib/src/core/dependencies/builder_dependency_preflight.dart` + the four
call sites. Then targeted `dart analyze` on changed files,
`dart format .`, kernel-cache cleanup.
