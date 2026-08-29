---
feature: 042-bone-working-slice
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 6
planned_at: 042-start
updated_at: 042-start
suite_baseline: green (57 tests, test/plugins/skeleton/)
---

# Test List: Bone Working Slice

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md`. Each stays red until the feature works end to end through
the real entry point — `zfa bone generate` via `CommandRunner`, artifacts on disk.

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| A1  | Entities have real fields, fromJson, toJson, copyWith, validate; no empty `class X {}` | US1.AC1, FR-001 | example | PASS | `test/plugins/skeleton/scenarios/sc_005_working_slice_test.dart::entity real shape` |
| A2  | Abstract repository + data implementation + datasource interface exist per entity | US1.AC2, FR-002 | example | PASS | `sc_005::repo layers exist` |
| A3  | Get/Create/Update/Delete use cases injected with repository via DI | US1.AC3, FR-003 | example | PASS | `sc_005::crud usecases` |
| A4  | Field-less spec entities still emit fromJson/toJson/validate (no empty stubs) | US1.AC4, FR-001 | example | PASS | `sc_005::fieldless entity` |
| A5  | `--di mock` wires mock default; `bone.yaml` records `di: mock` | US2.AC1, FR-006/007/009 | example | PASS | `sc_005::di mock wiring` |
| A6  | `--di firebase` wires firebase default with credential plumbing | US2.AC2, FR-004/009 | example | PASS | `sc_005::di firebase wiring` |
| A7  | `--di auto` detects firebase from project pubspec/zfa.yaml | US2.AC3, FR-009 | example | PASS | `test/plugins/skeleton/di_choice_resolver_test.dart::detects firebase` |
| A8  | `--di auto` without config falls back to mock and records source | US2.AC4, FR-009 | example | PASS | `di_choice_resolver_test.dart::fallback mock` |
| A9  | Invalid `--di redis` prints usage error, exit non-zero, nothing generated | US2.AC5, FR-009 | example | PASS | `sc_005::invalid di rejected` |
| A10 | `--flutter` emits minimal pubspec.yaml + runnable lib/main.dart | US3.AC1, FR-008 | example | PASS | `sc_005::flutter entry` |
| A11 | `--flutter` emits presentation page invoking a use case via DI | US3.AC2, FR-005 | example | PASS | `sc_005::presentation page` |
| A12 | No `--flutter` → no pubspec, no main.dart, no widget page | US3.AC3, FR-008 | example | PASS | `sc_005::library mode omits flutter files` |
| A13 | `--flutter` emits widget test for the page | US3.AC4, FR-012 | example | PASS | `sc_005::widget test` |
| A14 | `--include-deps` inlines shared entity with the dependency's declared fields | US4.AC1, FR-010 | example | PASS | `sc_005::include deps inlines` |
| A15 | Transitive chain A→B→C inlines closure | US4.AC2, FR-010 | example | PASS | `sc_005::transitive closure` |
| A16 | Unrelated feature D's entities absent | US4.AC3, FR-010 | example | PASS | `sc_005::unrelated absent` |
| A17 | Default generation declares deps in bone.yaml only (no inlined files) | US4.AC4, FR-010 | example | PASS | `sc_005::declare only` |
| A18 | Dependency cycle refused; no partial output | US4.AC5, FR-010 | example | PASS | `sc_005::cycle refused` |
| A19 | `--export` produces `<feature>-<di>.tar.gz` unpacking to the bone tree | US5.AC1, FR-011 | example | PASS | `sc_005::export artifact` |
| A20 | Two features exported into same dir without conflicts | US5.AC2, SC-006 | example | PASS | `sc_005::parallel no conflict` |
| A21 | Failed generation leaves no artifact and no partial bone | US5.AC3, FR-011 | example | PASS | `sc_005::failure clean` |
| A22 | Generated tests pass with `dart run` — no pub get, no network | US6.AC1, SC-003, FR-012 | example | PASS | `sc_005::generated tests run` |
| A23 | Exported artifact < 50KB | US6.AC2, SC-005 | example | PASS | `sc_005::artifact size` |
| A24 | Firebase datasource without credentials fails with clear StateError | US6.AC3, FR-004 | example | PASS | `sc_005::missing credentials error` |
| A25 | Pure-Dart core analyzes with zero errors in a scratch package | SC-002, FR-001..006 | example | PASS | `sc_005::analyze zero errors` |
| A26 | `bone validate` passes on flutter bone incl. `package:flutter_test` import | FR-013 | example | PASS | `sc_005::validate flutter bone` |
| A27 | No README placeholders, no empty classes, no TODO-only test stubs | FR-015 | example | PASS | `sc_005::no placeholders` |
| A28 | Regenerating a feature replaces its bone atomically | FR-014 | example | PASS | `sc_005::atomic regen` |

## Inner loop: unit behaviors

### `lib/src/plugins/skeleton/generators/spec_reader.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U1  | Parses `- fieldName: Type` lines into entity fields | FR-001 | example | PENDING | `spec_reader_test.dart::parses fields` |
| U2  | `?` suffix marks field nullable | FR-001 | example | PENDING | `spec_reader_test.dart::nullable marker` |
| U3  | Unknown type → error naming entity, field, allowed types | FR-001, Edge | example | PENDING | `spec_reader_test.dart::unknown type refused` |
| U4  | Specs without field lines keep entity-name-only extraction (backward compat) | FR-001 | example | PENDING | `spec_reader_test.dart::fieldless compat` |
| U5  | Fields bind to the entity above them, not across headings | FR-001 | example | PENDING | `spec_reader_test.dart::field binding` |

### `lib/src/plugins/skeleton/models/bone.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U6  | DiChoice resolves auto→mock fallback with recorded source | FR-009 | example | PENDING | `bone_models_test.dart::di choice fallback` |
| U7  | EntityField exposes nullable flag + supported type set | FR-001 | example | PENDING | `bone_models_test.dart::entity field model` |
| U8  | Leading digit prefixes stripped from slug-derived identifiers | Edge | example | PENDING | `bone_models_test.dart::identifier stripping` |

### `lib/src/plugins/skeleton/builders/entity_stub_builder.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U9  | Emits final fields + const constructor | FR-001 | example | PENDING | `entity_stub_builder_test.dart::fields ctor` |
| U10 | fromJson coerces String/int/double/bool/List/Map/DateTime | FR-001 | example | PENDING | `entity_stub_builder_test.dart::fromJson coercion` |
| U11 | toJson inverts fromJson (round-trippable) | FR-001 | example | PENDING | `entity_stub_builder_test.dart::toJson round trip` |
| U12 | copyWith overrides only provided fields | FR-001 | example | PENDING | `entity_stub_builder_test.dart::copyWith` |
| U13 | validate flags blank/missing required fields | FR-001 | example | PENDING | `entity_stub_builder_test.dart::validate required` |
| U14 | Nullable fields skipped by validate | FR-001 | example | PENDING | `entity_stub_builder_test.dart::validate nullable` |
| U15 | Field-less entity emits valid empty-args shape | US1.AC4 | example | PENDING | `entity_stub_builder_test.dart::fieldless emission` |

### `lib/src/plugins/skeleton/builders/slice/repository_builder.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U16 | Abstract repository declares getById/getAll/save/delete | FR-002 | example | PENDING | `repository_builder_test.dart::interface` |
| U17 | Abstract datasource interface mirrors repository shape | FR-002 | example | PENDING | `repository_builder_test.dart::datasource iface` |
| U18 | Data implementation delegates to injected datasource | FR-002 | example | PENDING | `repository_builder_test.dart::data impl delegates` |

### `lib/src/plugins/skeleton/builders/slice/usecase_builder.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U19 | Four use cases per entity; repo via ctor; call delegates | FR-003 | example | PENDING | `usecase_builder_test.dart::crud usecases` |

### `lib/src/plugins/skeleton/builders/slice/datasource_builder.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U20 | Mock datasource: in-memory seeded store + CRUD ops | FR-004 | example | PENDING | `datasource_builder_test.dart::mock store` |
| U21 | Mock datasource imports dart:* only (zero external services) | FR-004, US6 | example | PENDING | `datasource_builder_test.dart::mock hermetic` |
| U22 | Firebase datasource requires credentials (StateError) | FR-004, Edge | example | PENDING | `datasource_builder_test.dart::firebase credentials` |
| U23 | Firebase REST URLs built from projectId + collection | FR-004 | example | PENDING | `datasource_builder_test.dart::firebase urls` |
| U24 | Firestore value mapping for entity fields | FR-004 | example | PENDING | `datasource_builder_test.dart::firestore mapping` |

### `lib/src/plugins/skeleton/builders/slice/injection_builder.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U25 | Container default backend follows DiChoice | FR-006 | example | PENDING | `injection_builder_test.dart::default backend` |
| U26 | Runtime backend override selects other datasource | FR-006 | example | PENDING | `injection_builder_test.dart::runtime override` |
| U27 | All entities registered with getters | FR-006 | example | PENDING | `injection_builder_test.dart::registers all` |

### `lib/src/plugins/skeleton/builders/slice/app_entry_builder.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U28 | pubspec minimal: environment + flutter SDK deps only | FR-008 | example | PENDING | `app_entry_builder_test.dart::pubspec minimal` |
| U29 | main.dart builds container and runs app | FR-008 | example | PENDING | `app_entry_builder_test.dart::main entry` |

### `lib/src/plugins/skeleton/builders/slice/presentation_builder.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U30 | Page renders primary entity fields + uses a use case via DI | FR-005 | example | PENDING | `presentation_builder_test.dart::page wiring` |
| U31 | Widget test imports flutter_test and pumps the page | FR-012 | example | PENDING | `presentation_builder_test.dart::widget test` |

### `lib/src/plugins/skeleton/builders/manifest_builder.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U32 | Renders di + di_source keys | FR-007 | example | PENDING | `manifest_builder_test.dart::di keys` |
| U33 | Flutter mode renders flutter + entrypoint keys; library mode omits | FR-007 | example | PENDING | `manifest_builder_test.dart::flutter keys` |

### `lib/src/plugins/skeleton/generators/di_choice_resolver.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U34 | firebase reference in pubspec.yaml → auto-detected firebase | FR-009 | example | PENDING | `di_choice_resolver_test.dart::pubspec detection` |
| U35 | firebase reference in zfa.yaml → auto-detected firebase | FR-009 | example | PENDING | `di_choice_resolver_test.dart::zfa detection` |
| U36 | No config → mock with auto-fallback source | FR-009 | example | PENDING | `di_choice_resolver_test.dart::fallback` |

### `lib/src/plugins/skeleton/bone_command.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U37 | `--di` invalid value → usage error + non-zero exit, no output dir | FR-009 | example | PENDING | `bone_command_test.dart::invalid di` |
| U38 | `--export` names artifact `<feature>-<di>.tar.gz` | FR-011 | example | PENDING | `bone_command_test.dart::export naming` |
| U39 | `--flutter`/`--include-deps`/`--di` plumbed to generator | FR-008/009/010 | example | PENDING | `bone_command_test.dart::flags plumbed` |
| U40 | Usage text documents new flags | FR-009..011 | example | PENDING | `bone_command_test.dart::usage documents flags` |

### `lib/src/plugins/skeleton/bone_command.dart` (validate)

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U41 | Packages in bone's own pubspec accepted as imports | FR-013 | example | PENDING | `bone_command_test.dart::validate pubspec deps` |
| U42 | Undeclared packages still rejected | FR-013 | example | PENDING | `bone_command_test.dart::validate rejects undeclared` |

### `lib/src/plugins/skeleton/generators/bone_generator.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U43 | Regeneration replaces bone dir (no stale files) | FR-014 | example | PENDING | `bone_generator_test.dart::atomic replace` |
| U44 | `--include-deps` computes recursive shared-entity closure | FR-010 | example | PENDING | `bone_generator_test.dart::dep closure` |
| U45 | Inlined dep entity uses dependency spec's fields | FR-010 | example | PENDING | `bone_generator_test.dart::dep fields honored` |

## Out of scope

- Live Firestore network round-trips (no credentials in CI; SC-004 proven structurally + via
  missing-credentials behavior).
- `flutter analyze` / `flutter test` execution inside zuraffa's CI (no Flutter SDK; widget files
  verified by content).
- Multi-bone `package:` cross-import composition workspaces (validate tolerance kept, no
  workspace generator).
- Watch/stream use cases, pagination, offline sync.

## Verification commands

```bash
dart test test/plugins/skeleton/
dart analyze
```
