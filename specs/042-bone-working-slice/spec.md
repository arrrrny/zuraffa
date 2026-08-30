# Feature Specification: Bone Working Slice — minimal runnable Flutter app per feature with swappable DI

**Feature Branch**: `042-bone-working-slice`
**Created**: 2026-08-29
**Status**: Draft
**Input**: GitHub issue #592 — "Bone Working Slice: minimal runnable Flutter app per feature with swappable DI"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Cloud agent receives a working slice, not empty stubs (Priority: P1)

As a cloud agent tasked with adding a feature (e.g. a profile page) to a zuraffa app, when the repo
owner runs the bone generator and sends me the artifact, I want the bone to contain a working,
compilable, runnable app module scoped to exactly that feature, so that I can start implementing
immediately instead of reverse-engineering the architecture from `class User {}` stubs and empty
README placeholders.

**Why this priority**: This is the core complaint of issue #592 — the current skeleton plugin emits
empty class stubs, which are "barely more useful than the spec itself". Every other story depends
on this one.

**Independent Test**: Generate a bone from a spec that declares entities with fields; assert the
output contains real entities (fields, `fromJson`, validation), an abstract repository, CRUD use
cases, mock and firebase data sources, a data repository implementation, a DI container, and real
tests — and no empty `class X {}` stubs or layer README placeholders.

**Acceptance Scenarios**:

1. **Given** a spec declaring `## Key Entities` with `- **User**` plus indented field lines
   (`id: String`, `displayName: String`, `email?: String`), **When** `zfa bone generate <feature>`
   runs, **Then** `entities/user.dart` contains final fields, a const constructor, `fromJson`,
   `toJson`, `copyWith`, and a `validate` function that rejects blank required fields.
2. **Given** the same spec, **When** generation completes, **Then** `domain/repositories/user_repository.dart`
   is an abstract class with CRUD method signatures, `data/repositories/data_user_repository.dart`
   implements it against an abstract data source, and `data/datasources/user_mock.dart` +
   `data/datasources/user_firebase.dart` both exist.
3. **Given** the same spec, **When** generation completes, **Then** `domain/usecases/` contains real
   CRUD use case classes (get/create/update/delete) that receive the repository via constructor
   injection from the DI container.
4. **Given** a spec whose entities declare no fields, **When** a bone is generated, **Then** the
   entity is still emitted with `fromJson`/`toJson`/`validate` (vacuously valid) rather than an
   empty class stub.

### User Story 2 — Swappable DI via --di mock|firebase|auto (Priority: P1)

As a repo owner, when I generate a bone, I want to choose the data backend wiring with
`--di mock`, `--di firebase`, or `--di auto`, so that prototype bones run without any external
services while production bones arrive wired for real Firebase.

**Why this priority**: The issue's key design decision #1 — the swappable DI flag — is what makes
one bone useful for prototyping and another production-ready without code changes.

**Independent Test**: Generate the same feature with `--di mock` and `--di firebase`; both bones
contain identical abstract layers, but `di/injection.dart` defaults to different concrete data
sources, and `bone.yaml` records the resolved DI choice.

**Acceptance Scenarios**:

1. **Given** `--di mock`, **When** the bone is generated, **Then** `di/injection.dart` wires mock
   data sources as the default backend while keeping firebase data sources present and selectable
   at runtime, and `bone.yaml` contains `di: mock`.
2. **Given** `--di firebase`, **When** the bone is generated, **Then** `di/injection.dart` defaults
   to firebase data sources that accept real Firebase credentials (project id + API key), and
   `bone.yaml` contains `di: firebase`.
3. **Given** `--di auto` in a project whose `pubspec.yaml`/`zfa.yaml` references firebase,
   **When** the bone is generated, **Then** the resolved choice is `firebase` and `bone.yaml`
   records where the detection came from.
4. **Given** `--di auto` with no detectable DI config, **When** the bone is generated, **Then**
   the choice falls back to `mock` and the fallback is recorded in `bone.yaml`.
5. **Given** an invalid value like `--di redis`, **When** the command runs, **Then** it prints a
   usage error and generates nothing.

### User Story 3 — Runnable Flutter app with --flutter (Priority: P1)

As a cloud agent, when I receive a bone generated with `--flutter`, I want a `pubspec.yaml` and a
runnable `lib/main.dart` entry point plus a real presentation page, so that I can extract the
artifact and `flutter run` it immediately.

**Why this priority**: Success criterion #1 of the issue ("A cloud agent can extract a bone and
`flutter run` it immediately") depends on the `--flutter` flag.

**Independent Test**: Generate with `--flutter`; assert `pubspec.yaml` (minimal deps),
`lib/main.dart` (runnable entry that builds the DI container and launches the app), and
`presentation/<feature>_page.dart` (real UI backed by the primary entity's use cases) exist; the
pure-Dart core of the bone analyzes clean.

**Acceptance Scenarios**:

1. **Given** `--flutter`, **When** the bone is generated, **Then** it contains `pubspec.yaml` with
   minimal dependencies and `lib/main.dart` that constructs the DI container and runs the app.
2. **Given** `--flutter`, **When** the bone is generated, **Then** `presentation/<feature>_page.dart`
   is a real UI page that renders the primary entity's fields and invokes at least one use case
   through the DI container.
3. **Given** generation without `--flutter`, **When** the bone is generated, **Then** no
   `pubspec.yaml`, `main.dart`, or widget page is emitted (library slice; presentation widgets
   would not compile without the Flutter SDK dependency).
4. **Given** `--flutter`, **When** the bone is generated, **Then** `test/<feature>_page_test.dart`
   is a real widget test for the page.

### User Story 4 — Minimal transitive dependency inclusion (Priority: P2)

As a repo owner, when my feature depends on entities owned by other features, I want the dependency
graph to drive what is included — only the minimal transitive set of shared entities, never
unrelated features — so the bone stays small and safe to delegate.

**Why this priority**: The issue's key design decision #2; important but exercised only when
cross-feature dependencies exist.

**Independent Test**: With specs A→B→C (A's spec mentions B's entity, B's mentions C's), generate
A's bone with `--include-deps` and assert B's and C's shared entity files are inlined while an
unrelated feature D's entities are absent; without the flag they are only declared in `bone.yaml`.

**Acceptance Scenarios**:

1. **Given** feature A's spec references entity `User` owned by feature B, **When** `zfa bone
   generate a --include-deps` runs, **Then** `entities/user.dart` from B's spec (with B's declared
   fields) is inlined into A's bone.
2. **Given** a transitive chain A→B→C, **When** A is generated with `--include-deps`, **Then** the
   closure is inlined recursively (B's and C's shared entities).
3. **Given** feature D shares no entities with A, **When** A is generated with `--include-deps`,
   **Then** none of D's entities appear in A's bone.
4. **Given** default generation (no `--include-deps`), **When** A depends on B, **Then** B is
   recorded in `bone.yaml` `dependencies:` but B's files are not inlined.
5. **Given** a dependency cycle, **When** generation runs, **Then** generation is refused with the
   existing cycle error and no partial output is left behind.

### User Story 5 — Parallel delegation with one-shot export (Priority: P2)

As a repo owner, when I want multiple cloud agents working different features in parallel, I want
`zfa bone generate <feature> --flutter --export` to produce a self-contained `<feature>-<di>.tar.gz`
artifact, so each agent can extract, build, and run independently and I pick the best
implementation per feature.

**Why this priority**: The issue's key design decision #3; it composes the earlier stories into the
delegation workflow.

**Independent Test**: Generate two different features with `--export` into the same bones
directory; both tar.gz artifacts exist, both unpack to valid bones, and generation of the second
does not disturb the first.

**Acceptance Scenarios**:

1. **Given** `--export`, **When** generation succeeds, **Then** `<output>/<feature>-<di>.tar.gz`
   exists and unpacks to the same file tree as the generated bone directory.
2. **Given** two different features generated with `--export` into the same bones dir, **When**
   both complete, **Then** both artifacts exist and each unpacks without conflicts.
3. **Given** generation fails (e.g. spec declares no entities), **When** `--export` was requested,
   **Then** no artifact and no partial bone directory are left behind.

### User Story 6 — Mock bones work with no external services; artifacts stay tiny (Priority: P1)

As a cloud agent without credentials or network access to backend services, when I extract a mock
bone, I want its self-contained tests to pass using only the Dart toolchain, and the artifact I
received to be well under the full app's size, so I can verify my starting point instantly.

**Why this priority**: Success criteria #3 ("Mock bones work without any external services") and
#5 ("< 50KB compressed") are directly checkable guarantees for every delegated agent.

**Independent Test**: Generate a mock bone; run each generated `test/*.dart` with `dart run` (no
pub get, no network) — all pass; export it and assert the tar.gz is smaller than 50KB.

**Acceptance Scenarios**:

1. **Given** a mock bone, **When** its generated tests are executed with `dart run
   test/<entity>_test.dart` and `dart run test/di_test.dart`, **Then** each exits 0 with zero
   external services and no package dependencies beyond `dart:*`.
2. **Given** any generated bone, **When** exported, **Then** the tar.gz artifact is < 50KB.
3. **Given** a firebase-wired bone, **When** no credentials are supplied at runtime, **Then** the
   firebase data source reports a clear missing-credentials error rather than silently faking
   success.

---

### Edge Cases

- What happens when a spec declares an entity field with an unsupported type (e.g.
  `avatar: UIImage`)? The generator MUST refuse with a `BoneGenerationError` naming the entity,
  field, and allowed types — never emit code that cannot compile.
- What happens when two features declare the same entity name and `--include-deps` pulls both?
  The existing duplicate-entity `DependencyResolutionError` MUST be preserved (refuse, clean up).
- What happens when `--di auto` finds no app config? It MUST fall back to `mock` and record
  `di_source: auto-fallback` in `bone.yaml` — not fail the generation.
- What happens when the feature slug starts with digits (e.g. `042-bone-working-slice`)? Dart
  identifiers derived from it MUST strip the leading number prefix so generated class names and
  pubspec names stay valid.
- What happens when `zfa bone validate` runs on a `--flutter` bone whose tests import
  `package:flutter_test/...`? The validator MUST accept packages declared in the bone's own
  `pubspec.yaml` (flutter, flutter_test) as resolvable, while still rejecting undeclared packages.
- What happens when regeneration targets an existing bone directory? The generator MUST replace
  the previous bone atomically (old tree removed, no stale files merged in).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Entity generation MUST emit real entities: final typed fields parsed from indented
  field lines under each `## Key Entities` bold entry (`- name: Type`, `?` suffix for nullable),
  a const constructor, `fromJson` factory, `toJson`, `copyWith`, and `validate` that flags blank
  or missing required fields. Supported types: `String`, `int`, `double`, `num`, `bool`,
  `List<String>`, `Map<String, dynamic>`, `DateTime`. Unknown types MUST fail generation.
- **FR-002**: For each entity the bone MUST contain an abstract repository interface
  (`domain/repositories/<entity>_repository.dart`) with CRUD method signatures and a data-layer
  implementation (`data/repositories/data_<entity>_repository.dart`) coded against an abstract
  data source interface (`data/datasources/<entity>_datasource.dart`).
- **FR-003**: For each entity the bone MUST contain real CRUD use cases
  (`domain/usecases/{get,create,update,delete}_<entity>_usecase.dart`) whose classes receive the
  repository via constructor injection and expose a `call` method — the same shape `zfa make`
  produces.
- **FR-004**: For each entity the bone MUST contain a mock data source
  (`data/datasources/<entity>_mock.dart`, in-memory, seeded with sample values, zero external
  services) and a firebase data source (`data/datasources/<entity>_firebase.dart`, Firestore REST
  over `dart:io` `HttpClient`, accepting project id + API key credentials).
- **FR-005**: `presentation/<feature>_page.dart` MUST be generated in `--flutter` mode as a real
  UI page over the primary entity (first `## Key Entities` entry) invoking at least one use case
  through the DI container.
- **FR-006**: `di/injection.dart` MUST contain a self-contained DI container (no external
  packages — `dart:*` and bone-relative imports only) that registers all repositories wired to
  mock or firebase data sources, defaults to the generated `--di` choice, and allows runtime
  backend selection.
- **FR-007**: `bone.yaml` MUST record the resolved DI choice (`di: mock|firebase`) and its source
  (`di_source: flag|auto-detected|auto-fallback`), plus `flutter: true` and `entrypoint:
  lib/main.dart` when generated with `--flutter`. Existing manifest keys MUST keep their meaning.
- **FR-008**: `--flutter` MUST add `pubspec.yaml` (minimal: environment + flutter SDK deps only)
  and a runnable `lib/main.dart` that builds the DI container and launches the presentation page.
  Without the flag neither file (nor any widget page) is emitted.
- **FR-009**: `zfa bone generate` MUST accept `--di mock|firebase|auto` (default `auto`).
  `auto` detects firebase usage from `pubspec.yaml`/`zfa.yaml` in the working project and falls
  back to `mock` when no config is found. Invalid values print a usage error and exit non-zero
  without generating.
- **FR-010**: `--include-deps` MUST inline the minimal transitive set of shared entities from
  dependency features (recursively, cycle-refusing, duplicate-refusing). Default generation
  declares dependencies in `bone.yaml` without inlining their files.
- **FR-011**: `--export` MUST additionally produce `<output>/<feature>-<di>.tar.gz` (reusing the
  existing tar.gz exporter) after successful generation; on failure no artifact remains.
- **FR-012**: The bone MUST contain real tests: `test/<entity>_test.dart` per entity (fromJson
  round-trip, validation, copyWith) and `test/di_test.dart` (mock backend wired end-to-end through
  the DI container) — self-contained plain Dart (`dart:*` only) so they run with `dart run`
  without `pub get`; `--flutter` mode additionally emits `test/<feature>_page_test.dart` as a
  widget test.
- **FR-013**: `zfa bone validate` MUST still pass on generated bones: relative imports resolve
  in-bone, and `package:` imports are legal when the package is either a declared dependency bone
  slug or a dependency of the bone's own `pubspec.yaml`.
- **FR-014**: Multiple bones MUST be generatable for different features into the same bones
  directory without conflicts; regenerating a feature replaces its bone directory atomically.
- **FR-015**: Empty layer README placeholders (`domain/README.md` etc.), empty entity classes, and
  TODO-only test stubs MUST NOT be emitted anymore — every emitted file has real content.

### Key Entities

- **BoneWorkingSlice** — the generated artifact: entities, domain, data, presentation (flutter
  mode), DI, manifest, pubspec (flutter mode), tests.
- **EntityField** — name, type, nullability parsed from the spec; drives entity codegen.
- **DiChoice** — mock | firebase | auto with resolved value + source; drives DI wiring and manifest.
- **BoneManifest** — extended with `di`, `di_source`, `flutter`, `entrypoint` keys.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A generated `--flutter --di mock` bone contains a runnable Flutter app module
  (`pubspec.yaml`, `lib/main.dart`, presentation page, DI, entities, domain, data, tests) scoped
  to exactly one feature.
- **SC-002**: The bone's pure-Dart core (entities, domain, data, DI, tests) analyzes with zero
  errors under `dart analyze` in a scratch package.
- **SC-003**: Mock bones run their generated tests successfully using only the Dart toolchain —
  no external services, no `pub get`, no network.
- **SC-004**: Firebase bones ship real Firestore REST data sources that accept project id + API
  key credentials and fail with a clear error when credentials are missing.
- **SC-005**: Exported bone artifacts are < 50KB compressed.
- **SC-006**: Multiple bones for different features generate into the same directory without
  conflicts.

## Assumptions

- The existing skeleton plugin (`zfa bone generate/export/validate`, `SpecReader`,
  `DependencyResolver`, `BoneExporter`) is the base being upgraded; its CLI surface, manifest
  compatibility, staleness checking, and dependency-graph semantics are preserved.
- "Firebase data source" is implemented against the Firestore REST API over `dart:io HttpClient`
  so bones stay self-contained (no firebase_* packages) and compile with pure Dart.
- The cloud agent runs the Flutter toolchain for `--flutter` bones; zuraffa's own test suite
  verifies the pure-Dart core by executing it with the Dart SDK (Flutter SDK is not a test
  dependency of this repository).
- `--di auto` detection scope is the working project's `pubspec.yaml` / `zfa.yaml`; anything
  unrecognized means `mock`.
