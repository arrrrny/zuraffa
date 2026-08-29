---
feature: 043-slice-plugin
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 27
planned_at: ee0aa612
updated_at: be1edd22
suite_baseline: red
---

# Test List: Slice Plugin — Context-Isolated Codebase Extraction

**Trace id conventions**: `USn-Sm` = User Story n, acceptance scenario m in
`spec.md` (scenarios carry no ids of their own; this convention is defined
here). `FR-0xx` ids are literal from `spec.md`. `INV-1` is a recorded invariant
(see below).

**Recorded decision (2026-08-29, user)**: merge handles agent-created and
agent-deleted sandbox files, not just modified ones. This extends FR-008 beyond
its literal wording ("copying only modified files"); `spec.md` is unchanged by
this command — run `/speckit.clarify` to bake the extension into the spec.
U67/U68 trace to FR-008 under this decision.

**Recorded invariant**: INV-1 — every `zfa slice` subcommand validates its
arguments and fails with usage text, never a stack trace. Rationale: the CLI is
the feature's only real entry point; every acceptance scenario invokes it.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. Each stays red until the feature
works end to end through its real entry point (the `zfa slice` CLI against the
fixture project). The profile names no distinct acceptance runner; per the
profile's own test-layout convention these live as scenario tests under
`test/plugins/slice/scenarios/` (or the integration test files named in
tasks.md where a scenario spans one command), driven by `dart test`.

| id  | behavior                                                                                                                              | traces                    | kind    | state   | test |
| --- | ------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- | ------- | ------- | ---- |
| A1  | `slice cut` on a profile-like page produces a sandbox with view/controller/presenter/state/usecases/entities/mock DI/entry point and no unrelated files | US1-S1, FR-001, FR-003, FR-004 | example | DONE   | `test/plugins/slice/slice_cut_integration_test.dart` |
| A2  | A cut including widgets used by other features includes them and classifies them `shared` in slice.yaml                                | US1-S2, FR-010            | example | DONE   | `test/plugins/slice/slice_cut_integration_test.dart` |
| A3  | A presenter resolving usecases via `getIt<T>()` gets those usecase types and their DI registration files included                      | US1-S3, FR-001            | example | DONE   | `test/plugins/slice/slice_cut_integration_test.dart` |
| A4  | A barrel (`index.dart`) import pulls in only the re-exported symbols the slice actually references                                     | US1-S4, FR-005            | example | DONE   | `test/plugins/slice/slice_cut_integration_test.dart` |
| A5  | Merge copies back only the agent-modified file to its original path and touches nothing else                                           | US2-S1, FR-008            | example | DONE   | `test/plugins/slice/slice_merge_integration_test.dart` |
| A6  | Merge of a modified `shared` file warns and requires confirmation before overwriting                                                   | US2-S2, FR-008, FR-010    | example | DONE   | `test/plugins/slice/slice_merge_integration_test.dart` |
| A7  | A file changed in both sandbox and main project since the cut is reported as a conflict, never silently overwritten                    | US2-S3, FR-008            | example | DONE   | `test/plugins/slice/slice_merge_integration_test.dart` |
| A8  | Merge with no modifications reports "no changes to merge" and deletes the slice directory                                              | US2-S4, FR-008            | example | DONE   | `test/plugins/slice/slice_merge_integration_test.dart` |
| A9  | `slice list` shows all active slices with name, entry points, creation date, and file count                                            | US3-S1, FR-012            | example | DONE   | `test/plugins/slice/slice_list_inspect_test.dart` |
| A10 | `slice inspect` shows every file with ownership classification and modified-since-cut status                                           | US3-S2, FR-012, FR-010    | example | DONE    | `test/plugins/slice/slice_list_inspect_test.dart::A10 (T096): inspect shows every file with ownership and modification status` |
| A11 | A two-entry cut contains both pages' dependency trees with shared dependencies included exactly once                                   | US4-S1, FR-011            | example | DONE    | `test/plugins/slice/slice_multi_entry_test.dart::A11 (T097): both pages with shared dependencies exactly once` |
| A12 | A usecase shared by both entries appears once in the manifest with one DI registration                                                 | US4-S2, FR-011            | example | DONE    | `test/plugins/slice/slice_multi_entry_test.dart::A12 (T098): the shared usecase and its DI registration appear once in the manifest` |
| A13 | `--depth view` includes view/controller/state and no presenter, usecases, or entities                                                  | US5-S1, FR-002            | example | DONE    | `test/plugins/slice/slice_depth_test.dart::A13 (T099): depth view — view/controller/state, no deeper layers` |
| A14 | `--depth feature` (default) adds presenter/usecases/domain interfaces/entities but no data implementations                             | US5-S2, FR-002            | example | DONE    | `test/plugins/slice/slice_depth_test.dart::A14 (T100): depth feature (default) — domain in, data out` |
| A15 | `--depth full` additionally includes repository implementations, datasources, and providers                                            | US5-S3, FR-002            | example | DONE    | `test/plugins/slice/slice_depth_test.dart::A15 (T101): depth full — data implementations included, no mocks` |
| A16 | `slice verify` on a complete slice reports all imports resolved and the slice ready                                                    | US6-S1, FR-013            | example | DONE    | `test/plugins/slice/slice_verify_integration_test.dart::A16 (T102): a complete slice verifies clean` |
| A17 | `slice verify` on a slice missing a file reports exactly which files have unresolved imports and which import paths are broken         | US6-S2, FR-013            | example | DONE    | `test/plugins/slice/slice_verify_integration_test.dart::A17 (T103): a deleted sandbox file is reported with its broken imports` |
| A18 | `slice verify --analyze` runs `dart analyze` on the sandbox and reports compilation errors                                             | US6-S3, FR-014            | example | DONE    | `test/plugins/slice/slice_verify_integration_test.dart::A18 (T104): --analyze runs dart analyze and reports errors` |
| A19 | `slice cut --verify` auto-verifies after extraction and fails the extraction when the slice is incomplete                              | US6-S4, FR-015            | example | DONE    | `test/plugins/slice/slice_verify_integration_test.dart::A19 (T105): cut --verify fails the cut when the slice is broken` |
| A20 | `slice run` launches `flutter run -t .zuraffa/slices/<name>/main_slice.dart` from the project root                                     | US7-S1, FR-016            | example | DONE   | `test/plugins/slice/runner/slice_runner_test.dart` |
| A21 | `slice run` on an unverified slice verifies first and aborts without launching when verification fails                                 | US7-S2, FR-016, FR-013    | example | DONE   | `test/plugins/slice/runner/slice_runner_test.dart` |
| A22 | Extra flags (e.g. `--device chrome`) pass through to the underlying `flutter run`                                                      | US7-S3, FR-016            | example | DONE   | `test/plugins/slice/runner/slice_runner_test.dart` |
| A23 | `slice export --format tar.gz` produces an archive with all sandbox files and a self-contained filtered pubspec.yaml                   | US8-S1, FR-017, FR-020    | example | DONE   | `test/plugins/slice/slice_export_integration_test.dart` |
| A24 | `slice export --format github --repo <name>` creates/pushes a GitHub repo with SLICE.md as README and a working pubspec.yaml           | US8-S2, FR-018, FR-020    | example | DONE   | `test/plugins/slice/slice_export_integration_test.dart` |
| A25 | `slice export --format github` without `--repo` auto-generates a repo name from project and slice name                                 | US8-S3, FR-018            | example | DONE   | `test/plugins/slice/slice_export_integration_test.dart` |
| A26 | Export of an unverified slice runs verification first and aborts when it fails                                                         | US8-S4, FR-020            | example | DONE   | `test/plugins/slice/slice_export_integration_test.dart` |
| A27 | `slice import --from github` pulls the exported repo's contents back into the local sandbox, ready for `slice merge`                   | US8-S5, FR-019            | example | DONE   | `test/plugins/slice/slice_export_integration_test.dart` |

## Inner loop: unit behaviors

Grouped by the component from `plan.md` that owns them. Each line names one
observable result. No property-based or approval tooling exists in the stack
profile, so round-trip invariants are `example` tests sampled at the
boundaries, not proven properties.

### `lib/src/plugins/slice/models/slice_manifest.dart` + `lib/src/plugins/slice/generators/manifest_writer.dart`

| id  | behavior                                                                                       | traces | kind    | state   | test |
| --- | ---------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U1  | A manifest with files, boundaries, hashes, and depth round-trips through write→read unchanged  | FR-004 | example | DONE   | `test/plugins/slice/models/slice_manifest_test.dart` |
| U2  | A manifest with empty files/boundaries and null `exportedTo` round-trips unchanged             | FR-004 | example | DONE   | `test/plugins/slice/models/slice_manifest_test.dart` |
| U3  | Reading a missing or corrupt `slice.yaml` fails with an error naming the slice directory       | FR-012 | example | DONE   | `test/plugins/slice/models/slice_manifest_test.dart` |

### `lib/src/plugins/slice/engine/package_resolver.dart`

| id  | behavior                                                                                                    | traces         | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------------------- | -------------- | ------- | ------- | ---- |
| U4  | Resolves `package:<self>/src/x.dart` to `<root>/lib/src/x.dart` via `.dart_tool/package_config.json`        | FR-009         | example | DONE   | `test/plugins/slice/engine/package_resolver_test.dart` |
| U5  | Resolves a relative import (`../foo/bar.dart`) against the importing file's directory                       | FR-009         | example | DONE   | `test/plugins/slice/engine/package_resolver_test.dart` |
| U6  | Classifies `dart:*` and third-party `package:*` imports as framework/external without filesystem resolution | FR-009, FR-010 | example | DONE   | `test/plugins/slice/engine/package_resolver_test.dart` |
| U7  | A missing `package_config.json` fails with an error telling the user to run `dart pub get`                  | FR-009         | example | DONE   | `test/plugins/slice/engine/package_resolver_test.dart` |
| U8  | A `package:` URI absent from the package config is treated as external and never traversed                  | FR-009         | example | DONE   | `test/plugins/slice/engine/package_resolver_test.dart` |

### `lib/src/plugins/slice/engine/service_locator_analyzer.dart`

| id  | behavior                                                                                                    | traces | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U9  | Extracts every `getIt<T>()` type argument from a presenter constructor body                                 | FR-001 | example | DONE   | `test/plugins/slice/engine/service_locator_analyzer_test.dart` |
| U10 | Extracts `T` nested inside `registerUseCase(getIt<T>())`                                                    | FR-001 | example | DONE    | `test/plugins/slice/engine/service_locator_analyzer_test.dart::U10: extracts T nested inside registerUseCase(getIt<T>())` |
| U11 | Ignores generic method calls that are not `getIt` lookups                                                   | FR-001 | example | DONE    | `test/plugins/slice/engine/service_locator_analyzer_test.dart::U11: ignores generic method calls that are not getIt lookups` |
| U12 | Maps each extracted type to its DI registration file under `lib/src/di/` via the snake_case naming convention | FR-001 | example | DONE    | `test/plugins/slice/engine/service_locator_analyzer_test.dart::U12: maps a type to lib/src/di/**/<snake>_di.dart` |

### `lib/src/plugins/slice/engine/barrel_resolver.dart`

| id  | behavior                                                                                                       | traces | kind    | state   | test |
| --- | -------------------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U13 | A barrel import with a `show` clause includes only the files exporting the shown symbols                       | FR-005 | example | DONE    | `test/plugins/slice/engine/barrel_resolver_test.dart::U13: a show clause includes only the files exporting shown symbols` |
| U14 | A barrel import without `show` includes only the files exporting types the importer actually references        | FR-005 | example | DONE    | `test/plugins/slice/engine/barrel_resolver_test.dart::U14: without show, only referenced exported types come in` |
| U15 | A DI barrel re-exporting 100+ registrations yields only the registration files the slice's `getIt` types need  | FR-005 | example | DONE    | `test/plugins/slice/engine/barrel_resolver_test.dart::U15: a DI barrel with 100+ registrations yields only needed files` |
| U16 | A non-barrel file passes through unmodified                                                                    | FR-005 | example | DONE    | `test/plugins/slice/engine/barrel_resolver_test.dart::U16: a non-barrel file passes through unmodified` |

### `lib/src/plugins/slice/engine/companion_detector.dart`

| id  | behavior                                                                                  | traces | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U17 | An existing `.g.dart` companion is included alongside its source file                     | FR-006 | example | DONE    | `test/plugins/slice/engine/companion_detector_test.dart::U17: an existing .g.dart companion is detected` |
| U18 | A missing `.g.dart` companion records a warning and still includes the source file        | FR-006 | example | DONE    | `test/plugins/slice/engine/companion_detector_test.dart::U18: a missing .g.dart companion records a warning` |
| U19 | An existing `.freezed.dart` companion is included                                         | FR-006 | example | DONE    | `test/plugins/slice/engine/companion_detector_test.dart::U19: an existing .freezed.dart companion is detected` |

### `lib/src/plugins/slice/engine/import_graph_walker.dart`

| id  | behavior                                                                                                          | traces         | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------------------------- | -------------- | ------- | ------- | ---- |
| U20 | The transitive closure from one entry includes exactly the reachable local files, each exactly once               | FR-001         | example | DONE    | `test/plugins/slice/engine/import_graph_walker_test.dart::U20: closure from one entry is exactly the reachable local files` |
| U21 | An import cycle terminates with all files in the cycle included once                                              | FR-001         | example | DONE    | `test/plugins/slice/engine/import_graph_walker_test.dart::U21: an import cycle terminates and includes every cycle file once` |
| U22 | A missing entry file fails with the attempted path and the available alternatives                                 | FR-001         | example | DONE    | `test/plugins/slice/engine/import_graph_walker_test.dart::U22: a missing entry reports the attempted path and alternatives` |
| U23 | At `view` depth the slice includes view/controller/state and excludes presenter, usecases, and domain             | FR-002         | example | DONE    | `test/plugins/slice/engine/import_graph_walker_test.dart::U23: view depth excludes presenter, usecases, and domain` |
| U24 | At `feature` depth the slice includes domain interfaces/entities and excludes data-layer implementations          | FR-002         | example | DONE    | `test/plugins/slice/engine/import_graph_walker_test.dart::U24: feature depth includes domain and excludes data` |
| U25 | At `full` depth the slice additionally includes repository implementations, datasources, and providers            | FR-002         | example | DONE    | `test/plugins/slice/engine/import_graph_walker_test.dart::U25: full depth includes data implementations` |
| U26 | Multiple entries produce the union of their closures with shared files deduplicated                               | FR-011         | example | DONE    | `test/plugins/slice/engine/import_graph_walker_test.dart::U26: two entries union their closures with dedup` |

### `lib/src/plugins/slice/engine/ownership_classifier.dart`

| id  | behavior                                                                                            | traces | kind    | state   | test |
| --- | --------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U27 | A file under the entry's `presentation/pages/<feature>/` directory classifies as `owned`            | FR-010 | example | DONE    | `test/plugins/slice/engine/ownership_classifier_test.dart::U27: files under an entry page directory are owned` |
| U28 | Entities, domain interfaces, shared widgets, and `core/`/`config/` files classify as `shared`       | FR-010 | example | DONE    | `test/plugins/slice/engine/ownership_classifier_test.dart::U28: entities, domain interfaces, shared widgets, core, config are shared` |

### `lib/src/plugins/slice/generators/mock_stub_generator.dart`

| id  | behavior                                                                                                   | traces | kind    | state   | test |
| --- | ---------------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U29 | An abstract boundary interface gets a generated mock implementing all its members with stub returns        | FR-003 | example | DONE    | `test/plugins/slice/generators/mock_stub_generator_test.dart::U29: an abstract interface gets a mock implementing every member` |
| U30 | A boundary with `mockStrategy: existing` reuses the project's own mock instead of generating one           | FR-003 | example | DONE    | `test/plugins/slice/generators/mock_stub_generator_test.dart::U30: mockStrategy existing reuses the project mock (generates nothing)` |
| U31 | Mock generation is depth-aware: at `view` depth the presenter is mocked; at `full` depth no mocks are made | FR-002 | example | DONE    | `test/plugins/slice/generators/mock_stub_generator_test.dart::U31: at full depth no mocks are made` |

### `lib/src/plugins/slice/generators/sandbox_bootstrapper.dart`

| id  | behavior                                                                                                              | traces | kind    | state   | test |
| --- | --------------------------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U32 | Generated `main_slice.dart` imports the root view, calls `setupSliceDependencies()`, and runs the app                 | FR-003 | example | DONE    | `test/plugins/slice/generators/sandbox_bootstrapper_test.dart::U32: single entry imports the root view, sets up DI, runs the app` |
| U33 | Generated `slice_di.dart` registers exactly the slice's needed bindings and boundary mocks — nothing else             | FR-003 | example | DONE    | `test/plugins/slice/generators/sandbox_bootstrapper_test.dart::U33: registers real bindings and boundary mocks, nothing else` |
| U34 | A multi-entry slice generates an entry point exposing every entry root                                                | FR-011 | example | DONE    | `test/plugins/slice/generators/sandbox_bootstrapper_test.dart::U34: a multi-entry slice exposes every entry root` |

### `lib/src/plugins/slice/generators/agent_readme_generator.dart`

| id  | behavior                                                                                                    | traces         | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------------------- | -------------- | ------- | ------- | ---- |
| U35 | `SLICE.md` marks owned files as modifiable and shared files as modify-with-caution                          | FR-007, FR-010 | example | DONE    | `test/plugins/slice/generators/agent_readme_generator_test.dart::U35: owned files are modifiable, shared files are caution` |
| U36 | `SLICE.md` contains the run command with the correct `-t` path and the boundary interface list              | FR-007         | example | DONE    | `test/plugins/slice/generators/agent_readme_generator_test.dart::U36: contains the run command with the correct -t path` |

### `lib/src/plugins/slice/merger/conflict_detector.dart`

| id  | behavior                                                                                          | traces | kind    | state   | test |
| --- | ------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U37 | `sandbox_hash == cut_hash` yields skip (file not copied)                                          | FR-008 | example | DONE    | `test/plugins/slice/merger/conflict_detector_test.dart::U37: unchanged sandbox file yields skip` |
| U38 | `sandbox_hash != cut_hash` and `main_hash == cut_hash` yields safe_copy                           | FR-008 | example | DONE    | `test/plugins/slice/merger/conflict_detector_test.dart::U38: agent-modified only yields safeCopy` |
| U39 | `sandbox_hash != cut_hash` and `main_hash != cut_hash` yields conflict                            | FR-008 | example | DONE    | `test/plugins/slice/merger/conflict_detector_test.dart::U39: both sides modified yields conflict` |
| U40 | A manifest branch differing from the current branch yields a recorded warning                     | FR-008 | example | DONE    | `test/plugins/slice/merger/conflict_detector_test.dart::U40: a branch mismatch yields a recorded warning` |

### `lib/src/plugins/slice/merger/slice_merger.dart`

| id  | behavior                                                                                                                          | traces | kind    | state   | test |
| --- | --------------------------------------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U41 | Merge copies back only files classified safe_copy                                                                                 | FR-008 | example | DONE    | `test/plugins/slice/merger/slice_merger_test.dart::U41: merge copies back only safe-copy files` |
| U42 | A modified `shared` file requires confirmation before it is overwritten                                                           | FR-008, FR-010 | example | DONE    | `test/plugins/slice/merger/slice_merger_test.dart::U42: a modified shared file requires confirmation` |
| U43 | A conflicted file is not copied, is reported, and the sandbox is preserved                                                        | FR-008 | example | DONE    | `test/plugins/slice/merger/slice_merger_test.dart::U43: a conflicted file is not copied and the sandbox survives` |
| U44 | A merge with zero modifications reports "no changes" and deletes the slice directory                                              | FR-008 | example | DONE    | `test/plugins/slice/merger/slice_merger_test.dart::U44: zero modifications reports no changes and deletes the slice` |
| U67 | A file the agent created inside the sandbox is copied to its mirrored project path and listed in the merge report                 | FR-008 (extended per 2026-08-29 decision) | example | DONE    | `test/plugins/slice/merger/slice_merger_test.dart::U67: an agent-created file is copied back and reported` |
| U68 | A file the agent deleted from the sandbox is deleted in the project; a deleted `shared` file requires confirmation                | FR-008 (extended per 2026-08-29 decision) | example | DONE    | `test/plugins/slice/merger/slice_merger_test.dart::U68: an agent-deleted file is removed; shared needs confirmation` |

### `lib/src/plugins/slice/verifier/import_verifier.dart`

| id  | behavior                                                                                                             | traces | kind    | state   | test |
| --- | -------------------------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U45 | A slice whose imports all resolve yields a pass report                                                               | FR-013 | example | DONE    | `test/plugins/slice/verifier/import_verifier_test.dart::U45: a slice whose imports all resolve passes` |
| U46 | A dangling import yields a failure naming the file, the line, and the broken import path                             | FR-013 | example | DONE    | `test/plugins/slice/verifier/import_verifier_test.dart::U46: a dangling relative import names file, line, and path` |
| U47 | `dart:` SDK imports always resolve; a `package:` import absent from pubspec.yaml fails verification                  | FR-013 | example | DONE    | `test/plugins/slice/verifier/import_verifier_test.dart::U47: dart: imports resolve; unknown packages fail` |

### `lib/src/plugins/slice/verifier/analyze_runner.dart`

| id  | behavior                                                                                          | traces | kind    | state   | test |
| --- | ------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U48 | An analyzer-clean sandbox yields a pass result                                                    | FR-014 | example | DONE    | `test/plugins/slice/verifier/analyze_runner_test.dart::U48: an analyzer-clean sandbox passes` |
| U49 | Analyzer errors are captured and returned as a structured failure listing the errors              | FR-014 | example | DONE    | `test/plugins/slice/verifier/analyze_runner_test.dart::U49: analyzer errors are captured as a structured failure` |
| U50 | A missing dart/flutter toolchain yields a clear environment error, not a crash                    | FR-014 | example | DONE    | `test/plugins/slice/verifier/analyze_runner_test.dart::U50: a missing toolchain yields a clear environment error` |

### `lib/src/plugins/slice/runner/slice_runner.dart`

| id  | behavior                                                                                                                        | traces          | kind    | state   | test |
| --- | ------------------------------------------------------------------------------------------------------------------------------- | --------------- | ------- | ------- | ---- |
| U51 | Builds `flutter run -t <project>/.zuraffa/slices/<name>/main_slice.dart` with the working directory at the project root         | FR-016          | example | DONE   | `test/plugins/slice/runner/slice_runner_test.dart` |
| U52 | Extra CLI flags are forwarded to `flutter run` verbatim                                                                          | FR-016          | example | DONE   | `test/plugins/slice/runner/slice_runner_test.dart` |
| U53 | A failed fast verification aborts the launch before `flutter run` executes                                                       | FR-016, FR-013  | example | DONE   | `test/plugins/slice/runner/slice_runner_test.dart` |

### `lib/src/plugins/slice/exporter/pubspec_filter.dart`

| id  | behavior                                                                                                   | traces | kind    | state   | test |
| --- | ---------------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U54 | The filtered pubspec keeps only dependencies actually imported by the sliced files                         | FR-017 | example | DONE   | `test/plugins/slice/exporter/pubspec_filter_test.dart` |
| U55 | `flutter` and `flutter_test` SDK entries are always kept                                                   | FR-017 | example | DONE   | `test/plugins/slice/exporter/pubspec_filter_test.dart` |
| U56 | Git, path, and hosted sources of kept dependencies are preserved                                           | FR-017 | example | DONE   | `test/plugins/slice/exporter/pubspec_filter_test.dart` |

### `lib/src/plugins/slice/exporter/tarball_exporter.dart`

| id  | behavior                                                                                                                    | traces | kind    | state   | test |
| --- | --------------------------------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U57 | The archive contains the mirrored sandbox tree, the filtered `pubspec.yaml`, `main_slice.dart`, and `SLICE.md`              | FR-017 | example | DONE   | `test/plugins/slice/exporter/tarball_exporter_test.dart` |

### `lib/src/plugins/slice/capabilities/export_slice_capability.dart`

| id  | behavior                                                                              | traces | kind    | state   | test |
| --- | ------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U58 | Export of a slice that fails verification aborts before any archive or repo is made   | FR-020 | example | DONE   | `test/plugins/slice/capabilities/export_slice_capability_test.dart` |

### `lib/src/plugins/slice/exporter/github_exporter.dart`

| id  | behavior                                                                                                  | traces | kind    | state   | test |
| --- | --------------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U59 | Creates a private repo, pushes the sandbox as the initial commit, and uses `SLICE.md` as the README       | FR-018 | example | DONE   | `test/plugins/slice/exporter/tarball_exporter_test.dart` |
| U60 | A given `--repo` value is honored; without one a name is generated from the project and slice names       | FR-018 | example | DONE   | `test/plugins/slice/exporter/tarball_exporter_test.dart` |
| U61 | The repo URL is recorded in the manifest's `exportedTo` field                                             | FR-018 | example | DONE   | `test/plugins/slice/exporter/tarball_exporter_test.dart` |
| U62 | An unauthenticated `gh` CLI fails with a clear auth error naming the fix                                  | FR-018 | example | DONE   | `test/plugins/slice/exporter/tarball_exporter_test.dart` |

### `lib/src/plugins/slice/exporter/slice_importer.dart`

| id  | behavior                                                                                     | traces | kind    | state   | test |
| --- | -------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U63 | Import pulls the exported repo's contents over the local sandbox, overwriting sandbox files  | FR-019 | example | DONE   | `test/plugins/slice/exporter/slice_importer_test.dart` |
| U64 | Import on a slice with no `exportedTo` fails with an error telling the user to export first  | FR-019 | example | DONE   | `test/plugins/slice/exporter/slice_importer_test.dart` |

### `lib/src/plugins/slice/slice_command.dart`

| id  | behavior                                                                                     | traces | kind    | state   | test |
| --- | -------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U65 | An unknown subcommand fails with a usage error listing the valid subcommands                 | INV-1  | example | DONE    | `test/plugins/slice/slice_command_test.dart::U65: an unknown subcommand fails with a usage error listing the valid subcommands` |
| U66 | `cut` without `--entry` fails with a usage error                                             | INV-1  | example | DONE    | `test/plugins/slice/slice_command_test.dart::U66: cut without --entry fails with a usage error` |

## Invariants and edge cases still to place

- Two active slices with overlapping files: the second merge must surface the
  hash mismatches created by the first merge (spec edge case). Will land in the
  end-to-end lifecycle test (`test/plugins/slice/slice_e2e_test.dart`, T075).
- Manifest round-trip is an invariant (write→read is identity) sampled as U1/U2
  examples — the profile has no property-based library, so it is sampled, not
  proven.

## Out of scope

- Navigation edge analysis (auto-detecting `context.go()`/`push()` targets):
  v2 per spec Assumptions; v1 requires explicit multi-entry flags.
- `slice sync` (rebasing main-project changes into an active slice): v2 per
  spec Assumptions.
- Multi-package/monorepo slicing: v1 is single-package only (spec Assumptions).
- GitHub authentication management: delegated to the `gh` CLI (spec
  Assumptions); only the unauthenticated error path is tested (U62).
- Rewriting imports inside sliced files: rejected by research R-003; slices
  mirror original paths so imports never change.
- Real `flutter run` launches and real GitHub pushes in tests: the repo's test
  environment is pure Dart with no Flutter SDK or network. A20–A22 and
  A24–A27/A59–A64 assert command construction and flow through an injected
  process/`gh` seam, per the fixture-based approach in tasks.md.

## Verification commands

Copied from `.specify/memory/tdd-profile.md` at planning time; the profile's
scoped paths name the benchmark plugin (it predates this feature — consider
`/speckit.tdd.setup refresh`), so feature-scoped lines are adapted and marked:

- Single test: `dart test test/<path>.dart -P "<name>"`
- Full suite (feature scope, adapted): `dart test test/plugins/slice/`
- Full suite (repo): `dart test` — slow (~15 min); do not run per cycle, run
  the scoped subset and the full suite before commits
- Static analysis (feature scope, adapted): `dart analyze lib/src/plugins/slice/ test/plugins/slice/`
- Coverage: `dart test --coverage=<dir>` then `dart run coverage:format_coverage` (opt-in, not a gate)
- Mutation: none wired in CI — deliberate-mutant sampling per the profile
