---
feature: 020-skeleton-plugin-bones
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 11
planned_at: 30be42a1
updated_at: 30be42a1
suite_baseline: unknown
---

# Test List: Skeleton Plugin — Bare-Bones Feature Scaffold

Baseline note: the feature-scoped suite (`dart test test/plugins/skeleton/`) does
not exist yet (load error at planning time — expected for a new plugin). The repo
fast suite was not run as a baseline because the profile marks it slow; the loop
must establish green on the scoped suite from the first cycle onward.

Acceptance scenarios in `spec.md` carry no ids; they are traced here as
`US<story>.<scenario>` (e.g. `US2.2` = User Story 2, acceptance scenario 2).

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md`. Each drives the real entry point: the
`zfa bone` CLI invoked in-process, asserting on the generated filesystem state.

| id  | behavior                                                                                                          | traces               | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------------------------- | -------------------- | ------- | ------- | ---- |
| A1  | Generating a bone for a spec with ≥1 entity creates manifest, entity stubs, layer placeholders, dependency file   | US1.1, FR-001, FR-002 | example | DONE    | scenarios/sc_001_bone_generation_test.dart::generating a bone creates manifest, entity stubs, layer placeholders |
| A2  | Every import in a generated bone resolves inside the bone or to a declared dependency                              | US1.2, FR-005        | example | DONE    | scenarios/sc_001_bone_generation_test.dart::every import in the bone resolves inside the bone or to a dependency |
| A3  | A bone depending on another bone records the dependency in its manifest and includes or links the dependent stub   | US1.3, FR-003        | example | DONE    | scenarios/sc_002_dependency_graph_test.dart::A3: three-feature chain — C depends on B depends on A; manifest reflects the chain |
| A4  | Generating bones for features A and B where B references A's entity puts A with the shared entity in B's manifest  | US2.1, FR-003        | example | DONE    | scenarios/sc_002_dependency_graph_test.dart::A4: B references A's entity → B's manifest lists A with shared entity |
| A5  | A circular dependency across bones fails generation with an error naming the bones in the cycle                    | US2.2, FR-004        | example | DONE    | scenarios/sc_002_dependency_graph_test.dart::A5: circular dependency fails generation naming cycle members, no output |
| A6  | A bone with no cross-references is generated with an empty dependency list                                         | US2.3                | example | DONE    | scenarios/sc_002_dependency_graph_test.dart::A6: no cross-references → dependencies: [] |
| A7  | A bone generated from a specify-produced spec reflects the spec's declared entities                                | US3.1, FR-007        | example | DONE    | scenarios/sc_003_workflow_integration_test.dart::A7: bone generated from a spec reflects the spec declared entities |
| A8  | The bone's test stubs load and run under `dart test` as valid scaffolds                                            | US3.2                | example | DONE    | scenarios/sc_003_workflow_integration_test.dart::A8: the bone test stubs parse as valid Dart test scaffolds |
| A9  | Xray overlay markers in the source spec are preserved in the bone manifest                                         | US3.3                | example | DONE    | scenarios/sc_003_workflow_integration_test.dart::A9: xray overlay markers in the source spec are preserved in the bone manifest |
| A10 | Exporting a bone produces a single `.tar.gz` containing the full bone structure                                    | US4.1, FR-006        | example | DONE    | scenarios/sc_004_export_test.dart::A10: exporting a bone produces a tar.gz containing every bone file |
| A11 | The exported artifact extracted into a clean directory validates standalone                                        | US4.2, FR-005        | example | DONE    | scenarios/sc_004_export_test.dart::A11: exported artifact extracted into a clean directory validates standalone |

## Inner loop: unit behaviors

Grouped by the component from `plan.md` that owns them.

### `lib/src/plugins/skeleton/models/dependency_graph.dart`

| id  | behavior                                                              | traces        | kind    | state   | test |
| --- | --------------------------------------------------------------------- | ------------- | ------- | ------- | ---- |
| U1  | Topological sort places every dependency before its dependent         | FR-003        | example | DONE    | dependency_graph_test.dart::topological sort places every dependency before its dependent |
| U2  | Sorting a graph with no edges returns all nodes                       | US2.3         | example | DONE    | dependency_graph_test.dart::sorting a graph with no edges returns all nodes |
| U3  | A cycle throws `CycleException` naming the bones in the cycle         | FR-004, US2.2 | example | DONE    | dependency_graph_test.dart::a cycle throws CycleException naming the bones in the cycle |
| U4  | A self-dependency is reported as a cycle naming that bone             | FR-004        | example | DONE    | dependency_graph_test.dart::a self-dependency is reported as a cycle naming that bone |

### `lib/src/plugins/skeleton/generators/spec_reader.dart`

| id  | behavior                                                                     | traces         | kind    | state   | test |
| --- | ---------------------------------------------------------------------------- | -------------- | ------- | ------- | ---- |
| U5  | Extracts entity names from the `## Key Entities` bold entries                | FR-007, US1.1  | example | DONE    | spec_reader_test.dart::extracts entity names from the ## Key Entities bold entries |
| U6  | A spec with no entity declarations yields an empty entity list               | edge case 3    | example | DONE    | spec_reader_test.dart::a spec with no entity declarations yields an empty entity list |
| U7  | `spec_version` is the SHA-256 of the spec bytes and changes with the content | FR-008         | example | DONE    | spec_reader_test.dart::spec_version is SHA-256 of spec bytes and changes with content |
| U8  | The feature slug is derived from the spec's directory name                   | FR-001         | example | DONE    | spec_reader_test.dart::feature slug is derived from the spec directory name |
| U34 | Extracts entities from a `### Key Entities` (h3) section nested under `## Requirements` | FR-007, US1.1  | example | DONE    | spec_reader_test.dart::extracts entities from a ### Key Entities section nested under ## Requirements |
| U35 | A multi-word bold entity name (`**Dependency Graph**`) is captured and normalized to PascalCase | FR-007, US1.1  | example | DONE    | spec_reader_test.dart::a multi-word bold entity name is captured and normalized to PascalCase |

### `lib/src/plugins/skeleton/builders/manifest_builder.dart`

| id  | behavior                                                                              | traces         | kind    | state   | test |
| --- | ------------------------------------------------------------------------------------- | -------------- | ------- | ------- | ---- |
| U9  | Renders schema-valid YAML with version, feature, spec_version, entities, layers       | FR-002         | example | DONE    | manifest_builder_test.dart::renders schema-valid YAML with version, feature, spec_version, entities, layers |
| U10 | Renders `dependencies: []` when the bone has no dependencies                          | US2.3          | example | DONE    | manifest_builder_test.dart::renders dependencies: [] when the bone has no dependencies |
| U11 | Renders a dependency entry with bone slug and shared entity names                     | FR-003, US2.1  | example | DONE    | manifest_builder_test.dart::renders a dependency entry with bone slug and shared entity names |
| U12 | The rendered `spec_version` matches `sha256:` + 64 lowercase hex chars                | FR-008         | example | DONE    | manifest_builder_test.dart::the rendered spec_version matches sha256: + 64 lowercase hex chars |

### `lib/src/plugins/skeleton/builders/entity_stub_builder.dart`

| id  | behavior                                                        | traces | kind    | state   | test |
| --- | --------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U13 | Emits syntactically valid Dart source for an entity declaration | FR-001 | example | DONE    | entity_stub_builder_test.dart::emits syntactically valid Dart source for an entity declaration |
| U14 | The stub path is `lib/entities/<snake_case>.dart`               | FR-002 | example | DONE    | entity_stub_builder_test.dart::the stub path is lib/entities/<snake_case>.dart |

### `lib/src/plugins/skeleton/builders/bone_scaffold_builder.dart`

| id  | behavior                                                                   | traces | kind    | state   | test |
| --- | -------------------------------------------------------------------------- | ------ | ------- | ------- | ---- |
| U15 | Emits `domain/`, `data/`, `presentation/` placeholder files                | FR-002 | example | DONE    | bone_scaffold_builder_test.dart::emits domain/, data/, presentation/ placeholder files |
| U16 | The barrel entry point exports every entity stub                           | US1.2  | example | DONE    | bone_scaffold_builder_test.dart::the barrel entry point exports every entity stub |
| U17 | Emits one `test`-package scaffold per entity importing the bone barrel     | US3.2  | example | DONE    | bone_scaffold_builder_test.dart::emits one test-package scaffold per entity importing the bone barrel |

### `lib/src/plugins/skeleton/generators/bone_generator.dart`

| id  | behavior                                                                                     | traces            | kind    | state   | test |
| --- | -------------------------------------------------------------------------------------------- | ----------------- | ------- | ------- | ---- |
| U18 | Emits the full bone file set for a spec declaring ≥1 entity                                  | FR-001, US1.1     | example | DONE    | bone_generator_test.dart::emits the full bone file set for a spec declaring ≥1 entity |
| U19 | Refuses with a missing-field error when the spec declares no entities                        | edge case 3       | example | DONE    | bone_generator_test.dart::refuses with a missing-field error when the spec declares no entities |
| U20 | Refuses with a missing-dependency error for an entity no known feature defines               | edge case 1       | example | DONE    | bone_generator_test.dart::refuses with a missing-dependency error for an unknown entity |
| U21 | Rejects a stub import that is neither bone-local, `dart:*`, nor a declared dependency        | FR-005, US1.2     | example | DONE    | bone_generator_test.dart::rejects a stub import that is neither bone-local, dart:*, nor a declared dependency; bone_command_test.dart::validate rejects/accepts package: import not matching/matching a declared dependency |
| U22 | A failed generation leaves no partial bone directory behind                                  | FR-004, invariant | example | DONE    | bone_generator_test.dart::a failed generation leaves no partial bone directory behind |

### `lib/src/plugins/skeleton/generators/dependency_resolver.dart`

| id  | behavior                                                                                  | traces         | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------- | -------------- | ------- | ------- | ---- |
| U23 | A cross-feature entity reference produces a dependency edge naming the shared entity      | FR-003, US2.1  | example | DONE    | dependency_resolver_test.dart::U23: cross-feature entity reference produces a dependency edge naming the shared entity |
| U24 | Conflicting definitions of the same entity name across features are refused               | edge case 2    | example | DONE    | dependency_resolver_test.dart::U24: conflicting definitions of the same entity name across features are refused |
| U25 | A cycle across bones is reported naming the member bones                                  | FR-004, US2.2  | example | DONE    | dependency_resolver_test.dart::U25: cycle across bones is reported naming the member bones |

### `lib/src/plugins/skeleton/bone_command.dart`

| id  | behavior                                                                                  | traces            | kind     | state   | test |
| --- | ----------------------------------------------------------------------------------------- | ----------------- | -------- | ------- | ---- |
| U26 | `zfa bone generate <slug>` generates the bone for the named feature                       | FR-001, US1.1     | example  | DONE    | bone_command_test.dart::zfa bone generate <slug> generates the bone for the named feature |
| U27 | `zfa bone generate` with no slug resolves the active feature from `.specify/feature.json` | FR-007, US3.1     | example  | DONE    | scenarios/sc_003_workflow_integration_test.dart::A7: bone generated from a spec reflects the spec declared entities |
| U28 | `zfa bone export` writes a `.tar.gz` containing every file in the bone directory          | FR-006, US4.1     | example  | DONE    | bone_command_test.dart::U28: zfa bone export writes a tar.gz containing every bone file |
| U29 | `zfa bone export` fails non-zero when the bone has not been generated                     | cli contract      | example  | DONE    | bone_command_test.dart::U29: zfa bone export fails non-zero when the bone has not been generated |
| U30 | `zfa bone validate` passes a clean bone and fails after the source spec changes           | FR-008, US4.2     | example  | DONE    | bone_command_test.dart::U30: zfa bone validate passes a clean bone and fails after spec changes |
| U31 | Command failures exit non-zero with a stderr message and no partial output                | cli contract      | example  | DONE    | bone_command_test.dart::U31: generate failure exits non-zero with no partial output, U29: export failure, U30: validate staleness |
| U32 | `zfa bone --help` lists the `generate`, `export`, and `validate` subcommands              | cli contract      | contract | DONE    | bone_command_test.dart::zfa bone --help lists generate, export, and validate subcommands |
| U33 | Xray overlay markers in the spec are copied verbatim into the manifest `xray:` key        | US3.3             | example  | DONE    | spec_reader_test.dart::U33: xray overlay markers are extracted from HTML comment annotations, manifest_builder_test.dart::U33: xray overlay markers are rendered under an xray: key, bone_generator_test.dart::U33: xray markers from the spec are passed through to the manifest |
| U36 | The CLI process exit code is non-zero when a bone subcommand reports an error             | cli contract, U31 | example  | DONE    | bone_command_test.dart::U36: CLI process exits non-zero when a bone subcommand reports an error |
| U37 | `zfa bone validate` rejects a bone containing a broken relative import, naming the file    | FR-005, US4.2     | example  | DONE    | bone_command_test.dart::U37: validate rejects a bone containing a broken relative import |
| U38 | A generated bone's manifest `spec_version` matches `sha256:` + 64 hex end to end           | FR-008            | example  | DONE    | bone_generator_test.dart::U38: generated manifest spec_version matches sha256: + 64 hex end to end |

## Invariants and edge cases still to place

None — all spec edge cases are placed (U19, U20, U22, U24; staleness at U7/U30).

## Out of scope

- Automatic cycle breaking: spec assumptions defer it; detection (U3/U4/U25) only.
- Network-based bone transfer: spec assumptions exclude it for v1; export is a local artifact only.
- Prose-based entity inference: spec assumptions forbid it; only structured declarations are parsed.
- SC-001/SC-003 timing goals (< 10s generation, < 5s cycle detection): no performance harness exists in the profile; verified informally via quickstart, not as tests.
- Xray overlay *generation*: the plugin only preserves existing markers (A9/U33); producing overlays belongs to the xray feature.

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time:

- Single test: `dart test test/<path>.dart -P "<name>"`
- Full suite (feature scope): `dart test test/plugins/skeleton/`
- Static analysis (feature scope): `dart analyze lib/src/plugins/skeleton/ test/plugins/skeleton/`
- Coverage (opt-in): `dart test --coverage=<dir>` then `dart run coverage:format_coverage`
- Mutation: none wired in CI; deliberate-mutant sampling at audit time
