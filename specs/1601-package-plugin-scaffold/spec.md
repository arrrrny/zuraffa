# Feature Specification: Federated Plugin Scaffold (`zfa package plugin`)

**Feature Branch**: `1601-package-plugin-scaffold`

**Created**: 2026-09-13

**Status**: Draft

**Origin**: GitHub issue [#678](https://github.com/arrrrny/zuraffa/issues/678) (sub-issue of epic #214: migrate all ZikZak pub.dev packages to be built on zuraffa)

**Input**: User description: "create a new repo for this [zuraffa_ffi], follow the zuraffa_auth, zuraffa_permission and other packages, make sure we have an easy way — I guess some zfa command already does it — to create a whole zuraffa plugin publishable to pub.dev with ios, macos, android subpackages."

## User Scenarios & Testing *(mandatory)*

<!--
  The "users" here are Zuraffa package authors (first among them the
  maintainer scaffolding zuraffa_ffi for issue #678) who need a repeatable,
  one-command way to produce the same federated-plugin monorepo shape the
  zuraffa_auth and zuraffa_permissions repos use today — today that shape
  exists only as hand-built repos.
-->

### User Story 1 - One command scaffolds a complete federated plugin monorepo (Priority: P1)

A Zuraffa package author runs a single `zfa` command and obtains a complete
plugin monorepo in the federated shape the ecosystem already uses
(zuraffa_auth, zuraffa_permissions): an app-facing package, a shared
platform-core package, and one platform-adapter package per selected
platform (Android, iOS, macOS) — every package with its dependency
configuration, analysis configuration, README, and a passing test harness.
No hand-assembly of directory structures, no copy-pasting from an existing
repo.

**Why this priority**: The scaffold is the entry point. Without it, every
new plugin (zuraffa_ffi today, others tomorrow) is hand-assembled and the
family of packages drifts apart.

**Independent Test**: A developer runs the plugin scaffold command for a
new name and obtains a monorepo where every generated package passes static
analysis and its test suite with zero manual edits.

**Acceptance Scenarios**:

1. **Given** an empty working directory, **When** the developer runs the
   plugin scaffold command for a new name, **Then** a monorepo directory is
   created containing exactly five packages: the app-facing package, the
   platform-core package, and the Android, iOS, and macOS adapters — each
   in its own directory with a valid dependency manifest, analysis
   configuration, README, library barrel, and test harness.
   **Type**: acceptance
2. **Given** the newly scaffolded monorepo, **When** the developer runs
   static analysis on each generated package, **Then** every package
   reports zero errors.
3. **Given** the newly scaffolded monorepo, **When** the developer runs
   the test suite of each generated package, **Then** every package's
   tests pass.
4. **Given** the newly scaffolded monorepo, **When** the developer inspects
   the app-facing package's dependency manifest, **Then** it depends on the
   Zuraffa framework, and the adapter packages depend on the app-facing
   package and the platform-core package, with in-family constraints
   aligned to the scaffold's initial version.
5. **Given** the platform-core package, **When** the developer inspects
   its dependency manifest, **Then** it does not depend on any platform
   adapter (adapters depend on the core, never the reverse).

---

### User Story 2 - Generated packages are pub.dev-publishable out of the box (Priority: P1)

A package author wants to publish every generated package to pub.dev
without fixing metadata or unwinding local-development dependency
overrides by hand. Each package carries complete publish metadata
(description, repository, issue tracker, homepage, topics) and the
monorepo ships the publish tooling that prepares packages for publishing.

**Why this priority**: "Publish to pub.dev" is an explicit goal of the
request. A scaffold that cannot pass a publish dry-run forces manual
metadata surgery on every package — the exact toil the command exists to
remove.

**Independent Test**: For every package in a freshly scaffolded monorepo,
a publish dry-run succeeds.

**Acceptance Scenarios**:

1. **Given** the newly scaffolded monorepo, **When** the developer runs a
   publish dry-run for each generated package, **Then** every dry-run
   succeeds (the package is publishable as-is).
2. **Given** a freshly scaffolded monorepo, **When** the developer inspects
   any adapter or core package's dependency manifest, **Then** the
   local-development path overrides are declared in a section that the
   publish tooling strips before publishing, never as hosted constraints.
3. **Given** the scaffolded monorepo, **When** the developer runs the
   bundled publish-preparation tooling for a version, **Then** every
   package's version is aligned and in-family hosted constraints are
   rewritten to that version.
4. **Given** the scaffolded monorepo, **When** the developer inspects the
   root, **Then** there is a README describing the family and a publishing
   guide explaining the release flow.

---

### User Story 3 - Platform selection with correct dependency wiring (Priority: P2)

A package author may not target all three desktop/mobile platforms. The
scaffold command accepts a platform selection, and the generated family
contains an adapter package only for each selected platform — with the
dependency graph correctly wired either way (adapters depend on the
app-facing package and the core; the app-facing package and the core never
depend on adapters).

**Why this priority**: Subset scaffolds are common (a macOS-only helper,
an Android+iOS pair) but secondary to the full default scaffold.

**Independent Test**: Scaffolding with a subset selection yields exactly
the app-facing package, the core, and one adapter per selected platform —
and nothing else — with the same clean analysis/test/publish results as
the full scaffold.

**Acceptance Scenarios**:

1. **Given** an empty working directory, **When** the developer scaffolds
   a plugin selecting only Android and iOS, **Then** the monorepo contains
   exactly the app-facing package, the platform core, and the Android and
   iOS adapters — no macOS adapter.
2. **Given** a subset-scaffolded monorepo, **When** the developer runs
   static analysis, tests, and publish dry-runs for every package, **Then**
   all succeed with zero manual edits.
3. **Given** any scaffolded monorepo, **When** the developer inspects the
   dependency graph, **Then** each adapter depends on the app-facing
   package and the platform core, and the app-facing package depends on
   the framework but on no adapter.

---

### User Story 4 - The first consumer is the zuraffa_ffi plugin repo (Priority: P2)

The maintainer addressing issue #678 uses the new command to create the
`zuraffa_ffi` plugin monorepo — the repo currently does not exist (404) —
and publishes it to GitHub as the starting point for the FFI migration.
The generated repo follows the same shape as the zuraffa_auth repo, so
future family members stay consistent.

**Why this priority**: Issue #678 is the concrete deliverable that
motivates this feature; it must be satisfiable with the command itself —
not by hand — proving the command end-to-end.

**Independent Test**: The command is run for the name `zuraffa_ffi`; the
resulting monorepo passes analysis, tests, and publish dry-runs; it is
initialized as a git repository and pushed to GitHub.

**Acceptance Scenarios**:

1. **Given** the new command, **When** the maintainer scaffolds the plugin
   named `zuraffa_ffi`, **Then** the resulting monorepo has the same
   five-package federated shape as the zuraffa_auth repo (app-facing,
   platform core, Android/iOS/macOS adapters).
2. **Given** the scaffolded zuraffa_ffi monorepo, **When** the maintainer
   runs analysis, tests, and publish dry-runs for every package, **Then**
   all succeed with zero manual edits.
3. **Given** the verified zuraffa_ffi monorepo, **When** the maintainer
   initializes git and pushes to the `arrrrny/zuraffa_ffi` GitHub
   repository, **Then** the repository resolves (no longer 404).

---

### User Story 5 - Safe, inspectable operation (Priority: P3)

A package author gets clear, operator-fixable errors for invalid input
(bad name, existing target directory, unknown platform) and can preview
the full scaffold with a dry-run that writes nothing.

**Why this priority**: Safety rails prevent destructive surprises, but
they polish an already-working flow.

**Independent Test**: Invalid invocations fail with actionable messages
and no partial output; a dry-run prints the plan and creates no
directories.

**Acceptance Scenarios**:

1. **Given** a target directory that already exists, **When** the
   developer runs the scaffold, **Then** the command fails with a clear
   error and nothing is written or overwritten.
2. **Given** an invalid package name (not lower snake_case), **When** the
   developer runs the scaffold, **Then** the command fails with a message
   naming the validity rule.
3. **Given** a dry-run invocation, **When** the developer runs the
   scaffold, **Then** every file that would be created is reported and no
   directory is created on disk.
4. **Given** an unknown platform in the selection, **When** the developer
   runs the scaffold, **Then** the command fails naming the supported
   platforms.

---

### Edge Cases

- What happens when the package name contains hyphens or uppercase
  letters? (Name normalization vs. rejection.)
- What happens when the scaffold runs inside an existing package or app
  rather than an empty parent? (Nested output directory.)
- How does the scaffold behave when a selected platform yields an adapter
  name that collides with an existing pub.dev package? (Out of scope —
  collision is a publishing-time concern.)
- What happens when the framework dependency should resolve locally
  during development (path override) but hosted on publish?
- What happens when the developer scaffolds with zero platforms selected?
  (Reject — the family must contain at least one adapter.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a `zfa package plugin <name>`
  command that scaffolds a complete federated plugin monorepo named
  `<name>` containing the app-facing package, the shared platform-core
  package, and one platform adapter per selected platform (Android, iOS,
  macOS — all selected by default).
            traces: PluginScaffold
- **FR-002**: Every package generated by the scaffold MUST pass static
  analysis and its test suite with zero manual edits after creation.
- **FR-003**: Every package generated by the scaffold MUST pass a publish
  dry-run as-is: complete publish metadata (description, homepage,
  repository, issue tracker, topics) and no local-development overrides
  leaking into hosted constraints.
- **FR-004**: The scaffold MUST wire the family dependency graph
  correctly: each adapter depends on the app-facing package and the
  platform-core package (in-family constraints at the scaffold version);
  the app-facing package depends on the Zuraffa framework and the platform
  core depends only on the app-facing package — no package depends on an
  adapter.
            traces: PluginFamily
- **FR-005**: The scaffold MUST support platform selection, generating
  adapter packages only for the selected platforms, and MUST reject an
  empty selection and unknown platform names.
- **FR-006**: The scaffold MUST emit local-development path overrides for
  in-family resolution in a dedicated manifest section that the bundled
  publish tooling strips, so publishing never ships path dependencies.
- **FR-007**: The monorepo MUST ship publish tooling that, for a given
  version, aligns every package's version, rewrites in-family hosted
  constraints to that version, and strips the local-development
  overrides — mirroring the zuraffa_auth publish pipeline.
- **FR-008**: The scaffold MUST emit a per-package test harness that
  exercises the generated public surface (the tests fail if the family
  wiring is broken, not merely if files exist).
- **FR-009**: The scaffold MUST support a dry-run mode that reports every
  file it would create without writing to disk.
- **FR-010**: The scaffold MUST reject an existing target directory and
  invalid package names with clear, operator-fixable errors, leaving the
  filesystem untouched.
- **FR-011**: The monorepo MUST include, at its root: a README describing
  the package family, a publishing guide, a LICENSE, and git
  ignore/configuration suitable for the generated layout.
- **FR-012**: The scaffold MUST accept a description and a repository
  identity (GitHub owner/name) and stamp them consistently into every
  generated package's metadata.
- **FR-013**: The scaffold MUST accept a local framework path override so
  generated packages can resolve an unreleased Zuraffa checkout during
  development.

### Layer Contracts

**Function**:
- `PluginScaffold`: `scaffold(PluginScaffoldRequest) -> PluginScaffoldResult`
- `PluginFamilyNames`: `derive(String baseName) -> PluginFamilyNames`

### Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| PluginScaffoldRequest | `name: String`, `description: String?`, `platforms: List<Platform>`, `outputParent: String`, `repository: String?`, `zuraffaPath: String?`, `dryRun: bool` | Everything the scaffold needs to produce one plugin family |
| PluginScaffoldResult | `monorepoPath: String`, `packages: List<GeneratedPackage>` | What one scaffold run produced |
| PluginFamily | `baseName: String`, `appPackage: GeneratedPackage`, `corePackage: GeneratedPackage`, `adapters: List<GeneratedPackage>` | The federated family shape: app-facing + core + adapters |
| GeneratedPackage | `name: String`, `role: Role (app/core/adapter)`, `path: String`, `dependencies: List<String>` | One publishable package in the family |
| PluginFamilyNames | `app: String`, `core: String`, `adapter(Platform) -> String` | Derived package names: `<name>`, `<name>_platform`, `<name>_<platform>` |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `zfa package plugin <name>` produces a monorepo in which
  every package passes static analysis and its test suite in under 5
  minutes on a fresh checkout, with zero manual edits.
  - **Verification**: An end-to-end test scaffolds a family, runs
    analysis and tests for every package, and asserts zero failures.
- **SC-002**: Every generated package passes a publish dry-run as-is.
  - **Verification**: A test runs the publish dry-run for every package
    in a freshly scaffolded family and asserts success.
- **SC-003**: The generated family shape is identical in structure to the
  zuraffa_auth reference: five packages with the same roles, name
  derivation, and dependency direction.
  - **Verification**: A structural comparison between a scaffolded family
    and the zuraffa_auth repo layout: same package roles, same
    dependency edges, same publish tooling surface.
- **SC-004**: Issue #678's deliverable exists: the `zuraffa_ffi` GitHub
  repository is scaffolded via the new command, all package checks pass,
  and the repository is pushed and resolvable.
  - **Verification**: After scaffolding and pushing, the GitHub repo
    resolves and the local monorepo passes every package's analysis,
    tests, and publish dry-run.

## Assumptions

- **Pure-Dart federated packages, following zuraffa_auth.** The family
  pattern is the pure-Dart one used by zuraffa_auth: platform adapters
  wrap injected platform channels (typed envelopes) rather than shipping
  native Swift/Kotlin sources. Actual native implementations are out of
  scope; the scaffold provides the shape the FFI migration builds on.
- **Platform set is Android, iOS, macOS** — the three the request names
  and the zuraffa_auth family covers. Windows/Linux/web adapters are out
  of scope.
- **Initial version 1.0.0** for every generated package; in-family hosted
  constraints `^1.0.0`. Framework dependency resolves the current
  published v6 constraint unless a path override is requested.
- **Repository identity defaults** to the maintainer's GitHub owner
  (`arrrrny`) and homepage `https://zuraffa.com`, matching the existing
  family repos; both are overridable per invocation.
- **The first consumer (zuraffa_ffi) is a delivery of this feature**:
  issue #678 asks for the repo to be created; the command is proven by
  producing it. FFI-specific domain code is follow-up migration work, out
  of scope here.
- **Publishing to pub.dev itself is manual** (operator credentials); the
  scaffold guarantees dry-run-clean packages and ships the same publish
  tooling zuraffa_auth uses.
