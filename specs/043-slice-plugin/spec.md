# Feature Specification: Slice Plugin — Context-Isolated Codebase Extraction

**Feature Branch**: `043-slice-plugin`

**Created**: 2026-08-29

**Status**: Draft

**Input**: User description: "Build a Zuraffa plugin that extracts runnable, self-contained subsets ('slices') of a large app codebase so that AI agents (or human developers) can work on isolated features without needing the full project context. The plugin traces the dependency graph from an entry point (page, route, entity, or arbitrary file), respects architecture boundaries, generates a runnable sandbox with mock DI wiring, and merges changes back into the main project. This solves the AI agent context-window problem: instead of giving a cloud agent a 130-entity monolith, you give it a 12-file mini-app that compiles and runs."

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Cut a Feature Slice for AI Agent Delegation (Priority: P1)

A developer wants to delegate the redesign of a preferences page to a cloud AI agent. Instead of giving the agent the entire 130-entity app, the developer runs a single command specifying the preferences page as the entry point. The system traces the dependency graph — view, controller, presenter, usecases, entities — and produces a self-contained, runnable mini-app in a sandbox directory. The developer then points the cloud agent at only this sandbox. The agent has everything it needs: the relevant source files, mock dependency injection, a runnable entry point, and an instruction file describing what it can and cannot modify.

**Why this priority**: This is the core value proposition. Without the ability to extract a working slice from an entry point, nothing else matters.

**Independent Test**: Can be fully tested by pointing the command at a known page directory in a Zuraffa-structured project and verifying the output compiles, runs, and contains exactly the expected file set.

**Acceptance Scenarios**:

1. **Given** a Zuraffa-structured project with a `ProfileView` page that depends on `CustomerRepository`, `WatchCustomerUseCase`, and `LogoutUseCase`, **When** the user runs `zfa slice cut profile_feature --entry profile`, **Then** the system produces a sandbox directory containing the view, controller, presenter, state, usecases, entity files, mock DI registrations, and a runnable entry point — and no files from unrelated features.
2. **Given** a page that imports shared widgets used by other features, **When** the slice is cut, **Then** the shared widgets are included in the sandbox and classified as "shared" (not "owned") in the manifest.
3. **Given** a presenter that resolves usecases via a service locator pattern (`getIt<T>()`) rather than constructor injection, **When** the slice is cut, **Then** the system detects these service-locator lookups and includes the corresponding usecase types and their DI registration files.
4. **Given** a project using barrel files (`index.dart`) that re-export dozens of unrelated registrations, **When** the slice encounters a barrel import during traversal, **Then** only the symbols actually needed by the slice are included — the entire barrel contents are not pulled in.

---

### User Story 2 - Merge Agent Changes Back Into the Main Project (Priority: P1)

After the AI agent finishes working on the sliced preferences page, the developer merges the agent's modifications back into the main project. The system compares file hashes recorded at cut time against both the current sandbox files and the current main project files, producing clean diffs of only what the agent changed. If the main project changed files that the agent also modified, the developer is warned.

**Why this priority**: Extraction without merge-back is useless. The round-trip (cut → work → merge) is the unit of work.

**Independent Test**: Can be tested by cutting a slice, modifying a file in the sandbox, then running merge and verifying the main project reflects exactly the modification.

**Acceptance Scenarios**:

1. **Given** a slice where the agent modified `preferences_view.dart`, **When** the developer runs `zfa slice merge profile_feature`, **Then** only the modified file is copied back to the main project at its original path, and no other files are touched.
2. **Given** a slice where the agent modified a "shared" file (e.g., a widget used by other features), **When** merge is run, **Then** the system warns the developer that a shared file was modified and asks for confirmation before overwriting.
3. **Given** a slice where the main project's version of a file changed after the slice was cut (concurrent modification), **When** merge is run, **Then** the system detects the conflict (hash mismatch) and reports it to the developer instead of silently overwriting.
4. **Given** a slice where no files were modified, **When** merge is run, **Then** the system reports "no changes to merge" and deletes the slice directory.

---

### User Story 3 - Inspect and List Active Slices (Priority: P2)

A developer managing multiple delegated tasks wants to see which slices are currently active, what files each contains, and which files have been modified since extraction.

**Why this priority**: Operational visibility is essential for managing parallel agent workflows, but the system delivers value without it (manual directory inspection works as a fallback).

**Independent Test**: Can be tested by creating two slices, then running list/inspect commands and verifying the output matches the actual sandbox contents.

**Acceptance Scenarios**:

1. **Given** two active slices (`profile_feature` and `barcode_scanner`), **When** the developer runs `zfa slice list`, **Then** the system displays both slice names, their entry points, creation dates, and file counts.
2. **Given** an active slice where the agent modified 2 files, **When** the developer runs `zfa slice inspect profile_feature`, **Then** the system shows all files in the slice, their ownership classification (owned/shared/framework), and which files have been modified since extraction.

---

### User Story 4 - Multi-Entry Slice for Cross-Screen Features (Priority: P2)

A developer wants to work on a flow that spans multiple screens — for example, the profile page and the preferences page that it navigates to. The developer specifies multiple entry points, and the system unions their dependency graphs into a single slice.

**Why this priority**: Many real features span multiple screens. Without multi-entry support, the developer must create separate slices and manually coordinate, which defeats the purpose.

**Independent Test**: Can be tested by specifying two related pages as entries and verifying the resulting slice contains both dependency trees, deduplicated.

**Acceptance Scenarios**:

1. **Given** a profile page that navigates to a preferences page, **When** the developer runs `zfa slice cut profile_flow --entry profile --entry preferences`, **Then** the sandbox contains both pages and their combined dependency trees with shared dependencies (e.g., `CustomerRepository`) included only once.
2. **Given** two entry points that share a common usecase (`WatchCustomerUseCase`), **When** the slice is cut, **Then** the usecase and its DI registration appear once in the manifest, not duplicated.

---

### User Story 5 - Configurable Extraction Depth (Priority: P3)

A developer wants to control how deep the slice goes. For pure UI styling work, only the view and its immediate state are needed. For full feature work, the domain layer with mock data is needed. For integration work, even the data layer implementations should be included.

**Why this priority**: Different types of work need different amounts of context. Over-including wastes agent context window; under-including prevents the work from compiling.

**Independent Test**: Can be tested by cutting the same entry point at different depths and verifying each depth level includes the expected file set and excludes deeper layers.

**Acceptance Scenarios**:

1. **Given** a barcode listing feature, **When** the developer runs `zfa slice cut barcode_ui --entry barcode_listing --depth view`, **Then** the sandbox contains only the view, controller, and state files — no presenter, no usecases, no entities.
2. **Given** the same feature, **When** cut at `--depth feature` (default), **Then** the sandbox contains view, controller, presenter, state, usecases, domain interfaces, and entities — but not data layer implementations.
3. **Given** the same feature, **When** cut at `--depth full`, **Then** the sandbox also includes the data repository implementation, datasource files, and provider files.

---

### User Story 6 - Verify Slice Integrity After Extraction (Priority: P1)

After cutting a slice, the developer (or an automated CI step) wants to verify that the slice is complete and will compile before handing it to an agent. The system runs a static analysis pass that checks every import in every sliced file resolves to either another file in the slice, an external package, or the SDK. It also optionally attempts a compilation check (`dart analyze` or `flutter analyze`) on the sandbox to catch missing symbols, unresolved types, or incomplete mock stubs.

**Why this priority**: A broken slice is worse than no slice — the agent wastes its entire context window debugging import errors instead of doing the actual work. Verification is the quality gate that makes the whole system trustworthy.

**Independent Test**: Can be tested by cutting a slice, then running verify and confirming it reports success. Can also be tested by deliberately removing a file from the slice and confirming verify catches the dangling import.

**Acceptance Scenarios**:

1. **Given** a correctly extracted slice where all imports resolve, **When** the developer runs `zfa slice verify profile_feature`, **Then** the system reports all imports resolved and the slice is ready for use.
2. **Given** a slice where a shared widget file was accidentally excluded (e.g., manually deleted from the sandbox), **When** verify is run, **Then** the system reports exactly which files have unresolved imports and which import paths are broken.
3. **Given** a slice with the `--analyze` flag, **When** verify is run, **Then** the system runs `dart analyze` on the sandbox directory and reports any compilation errors.
4. **Given** a slice that passes verification, **When** the developer runs `zfa slice cut` with `--verify` flag, **Then** verification runs automatically at the end of extraction and the command fails if the slice is incomplete.

---

### User Story 7 - Run the Slice as a Standalone App (Priority: P2)

A developer wants to quickly launch the sliced mini-app to visually verify it works before handing it to an agent, or after an agent finishes to review the changes. Instead of remembering the non-obvious entry point path, the developer runs a single command that launches the slice.

**Why this priority**: The entry point path (`.zuraffa/slices/<name>/main_slice.dart`) is deeply nested and easy to mistype. A run command removes friction and makes the slice feel like a first-class artifact. However, advanced users can always run it manually, so this is convenience rather than capability.

**Independent Test**: Can be tested by cutting a slice, running it, and verifying the app launches on the target device/emulator.

**Acceptance Scenarios**:

1. **Given** a verified slice, **When** the developer runs `zfa slice run profile_feature`, **Then** the system launches `flutter run -t .zuraffa/slices/profile_feature/main_slice.dart` in the current project directory.
2. **Given** a slice that has not been verified, **When** run is invoked, **Then** the system runs verify first and aborts with an error message if verification fails.
3. **Given** a slice, **When** the developer runs `zfa slice run profile_feature --device chrome`, **Then** additional flags are passed through to the underlying `flutter run` command.

---

### User Story 8 - Export a Slice for Cloud Agent Handoff (Priority: P2)

A developer wants to hand a slice to a cloud AI agent that cannot access the local filesystem. The developer exports the slice as either a `.tar.gz` archive they can upload, or as a new GitHub repository the cloud agent can clone. The export includes the sandbox files, the generated entry point, the agent instruction file, and a standalone `pubspec.yaml` so the exported artifact is fully self-contained.

**Why this priority**: Cloud agents (Copilot, Codex, Devin, Kimi, etc.) are the primary consumers of slices. Without export, the developer must manually zip and upload the sandbox — error-prone and tedious. However, local agents (Zed, Cursor) can work directly on the sandbox directory, so export is not required for all workflows.

**Independent Test**: Can be tested by cutting a slice, exporting it as a tarball, extracting to a clean directory, and verifying `flutter analyze` passes. For GitHub export, verify a new repo is created with the expected file structure.

**Acceptance Scenarios**:

1. **Given** a verified slice, **When** the developer runs `zfa slice export profile_feature --format tar.gz`, **Then** the system produces a `.tar.gz` archive at `.zuraffa/slices/profile_feature/profile_feature.tar.gz` containing all sandbox files with a self-contained `pubspec.yaml`.
2. **Given** a verified slice, **When** the developer runs `zfa slice export profile_feature --format github --repo my-org/profile-slice`, **Then** the system creates a new GitHub repository (or pushes to an existing one) with the sandbox contents, including `SLICE.md` as the repo README and a working `pubspec.yaml`.
3. **Given** a verified slice, **When** the developer runs `zfa slice export profile_feature --format github` without specifying a repo name, **Then** the system auto-generates a repo name based on the project and slice name (e.g., `zik-zak-slice-profile-feature`) and creates it under the authenticated user's account.
4. **Given** a slice that has not been verified, **When** export is run, **Then** the system runs verify first and aborts if the slice is incomplete.
5. **Given** an exported GitHub repo where the agent has pushed commits, **When** the developer runs `zfa slice import profile_feature --from github --repo my-org/profile-slice`, **Then** the system pulls the repo contents back into the local sandbox directory, ready for `zfa slice merge`.

---

### Edge Cases

- What happens when an entry point file does not exist? The system reports a clear error with the attempted path and available alternatives.
- What happens when the dependency graph contains a circular import? The system detects the cycle during traversal, includes all files in the cycle, and continues without infinite recursion.
- What happens when a generated companion file (`.g.dart`) is missing? The system warns that the companion is expected but missing, and includes the source file anyway.
- What happens when the developer tries to merge a slice that was cut from a different branch? The system detects the branch mismatch and warns the developer.
- What happens when two active slices have overlapping files? Each slice operates independently; merge processes one at a time. The second merge may detect hash mismatches from the first merge.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: The system MUST trace the complete dependency graph from one or more entry point files, following both import statements and service-locator type resolutions (`getIt<T>()` calls in presenter constructors).
- **FR-002**: The system MUST detect and respect architecture layer boundaries, stopping traversal at configurable depth levels (view, presentation, feature, full).
- **FR-003**: The system MUST generate a runnable entry point file (`main_slice.dart`) that bootstraps only the dependencies needed for the sliced feature, including mock implementations for boundary interfaces.
- **FR-004**: The system MUST generate a slice manifest (`slice.yaml`) recording all included files, their hashes at extraction time, ownership classification (owned/shared/framework), and boundary interfaces.
- **FR-005**: The system MUST handle barrel files (`index.dart`) selectively — including only the re-exported symbols that are actually referenced by the slice, not the entire barrel contents.
- **FR-006**: The system MUST automatically include generated companion files (`.g.dart`, `.freezed.dart`) when their source files are included in the slice.
- **FR-007**: The system MUST generate an agent instruction file (`SLICE.md`) that describes the slice contents, modifiable files, run commands, and boundary interfaces.
- **FR-008**: The system MUST merge sandbox changes back into the main project by comparing file hashes, copying only modified files, and warning on shared-file modifications or concurrent main-project changes.
- **FR-009**: The system MUST resolve `package:` self-imports (e.g., `package:zik_zak/src/...`) to filesystem paths using the project's package configuration.
- **FR-010**: The system MUST classify every file in the slice as "owned" (unique to this feature, safe to modify), "shared" (used by other features, modify with caution), or "framework" (external dependency, read-only).
- **FR-011**: The system MUST support multiple entry points per slice, unioning their dependency graphs and deduplicating shared files.
- **FR-012**: The system MUST provide list and inspect commands for operational visibility into active slices.
- **FR-013**: The system MUST verify slice integrity by checking that every import in every sliced file resolves to either another file in the slice, an external package declared in pubspec.yaml, or the Dart/Flutter SDK.
- **FR-014**: The system MUST support an optional compilation check (`dart analyze` / `flutter analyze`) on the sandbox as part of verification.
- **FR-015**: The system MUST support automatic verification at the end of `slice cut` via a `--verify` flag, failing the extraction if the slice is incomplete.
- **FR-016**: The system MUST provide a run command that launches the slice as a standalone app via `flutter run` with the generated entry point, passing through additional device/platform flags.
- **FR-017**: The system MUST export a slice as a `.tar.gz` archive containing all sandbox files with a self-contained `pubspec.yaml` that declares only the dependencies used by the slice.
- **FR-018**: The system MUST export a slice to a new or existing GitHub repository, using `SLICE.md` as the repo README, including all sandbox files, and providing a working `pubspec.yaml`.
- **FR-019**: The system MUST support importing agent changes back from an exported GitHub repository into the local sandbox for merge-back via `zfa slice import`.
- **FR-020**: The system MUST run verification before any export and abort if the slice is incomplete.

### Key Entities

- **Slice**: A named, self-contained extraction of a codebase subset. Contains entry points, included files, boundary interfaces, depth configuration, and file hashes. Persisted as a manifest on disk.
- **SliceFile**: A file included in a slice with ownership classification (owned/shared/framework), hash at extraction time, and current modification status.
- **Boundary**: An abstract interface at the edge of the slice's dependency graph where traversal stopped. Each boundary has a type name and an auto-generated or user-provided mock implementation.
- **SliceManifest**: The persistent record of a slice's configuration and contents. Stored as `slice.yaml` in the slice directory.
- **FileGraph**: The project-wide dependency graph with nodes (files) and edges (imports, DI bindings, navigation routes). Built on demand from the project's source files.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: A developer can extract a runnable slice from any page in a Zuraffa-structured project within 30 seconds for projects with up to 300 source files.
- **SC-002**: The extracted slice compiles and runs as a standalone mini-app without manual intervention in 100% of cases where the entry point and its dependencies follow Zuraffa architecture conventions.
- **SC-003**: The slice contains no more than 20% overhead files beyond the strict dependency graph (i.e., at least 80% of included files are directly reachable from the entry points).
- **SC-004**: Merge-back correctly applies agent modifications to the main project without data loss in 100% of non-conflicting cases.
- **SC-005**: An AI agent working on a slice produces changes that apply cleanly to the main project at least 90% of the time (i.e., fewer than 10% of merges require manual conflict resolution).
- **SC-006**: The slice size (file count) is at most 15% of the total project file count for a typical single-feature extraction, ensuring meaningful context reduction for AI agents.
- **SC-007**: Slice verification completes in under 10 seconds for slices with up to 50 files, and catches 100% of missing-file import errors.
- **SC-008**: A verified slice launches successfully via `zfa slice run` on the first attempt in 95% of cases where the developer's Flutter environment is correctly configured.
- **SC-009**: A `.tar.gz` export can be extracted to a clean machine with only Flutter SDK installed and passes `flutter analyze` without errors.
- **SC-010**: A GitHub-exported slice can be cloned by a cloud agent and the agent can run `flutter analyze` successfully without any additional setup beyond `flutter pub get`.

## Assumptions

- The target project follows Zuraffa clean architecture conventions (domain/data/presentation layers with standard naming).
- Dependency injection uses the GetIt service locator pattern with per-binding DI files, as generated by Zuraffa's DI plugin.
- The project is a single-package Dart/Flutter application (monorepo/multi-package support is out of scope for v1).
- Generated companion files (`.g.dart`) exist alongside their source files and follow standard naming conventions.
- The developer has a working Flutter/Dart environment capable of running the main project (the slice inherits this capability).
- The slice plugin can leverage Zuraffa's existing AST infrastructure (`FileParser`, `AstHelper`, `DependencyGraph`, `DiscoveryEngine`) without modification.
- Navigation edge analysis (detecting `context.go()` / `context.push()` calls) is a v2 enhancement — v1 requires explicit multi-entry specification by the developer.
- The `slice sync` command (syncing main project changes into an active slice) is a v2 enhancement — v1 supports only cut and merge.
- GitHub export requires an authenticated GitHub CLI (`gh`) or a configured GitHub token. The plugin does not manage GitHub authentication itself.
- The exported `pubspec.yaml` is generated from the main project's `pubspec.yaml` by filtering to only the dependencies actually imported by the sliced files. This may require manual adjustment for transitive dependencies in edge cases.
- `slice import` pulls the full repo contents, overwriting the local sandbox. It does not perform a merge — that happens in the subsequent `slice merge` step.
- Verification's `--analyze` mode requires a valid Flutter/Dart environment and may take 30-60 seconds for large slices. The fast mode (import resolution check only) is the default.
- The `run` command delegates to `flutter run` and inherits its device/platform requirements. It is a thin wrapper, not a Flutter runtime.
