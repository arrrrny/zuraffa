This page documents the strategic evolution of Zuraffa across three major versions, providing advanced developers with the architectural rationale, migration patterns, and tooling required to navigate these transitions. Each version represents a fundamental shift in the framework's contract, and understanding these shifts is critical for maintaining downstream projects.

## Version Evolution Overview

The progression from v4 to v6 represents a maturation from a flexible but ambiguous generation system to a strict, AI-first architectural contract:

| Version | Release Date | Core Philosophy | Key Breaking Change |
|---------|--------------|-----------------|---------------------|
| v4 | Pre-2026-06 | One-shot generator with multiple command paths | Removal of `zfa generate` |
| v5 | 2026-06-01 | Canonical three-step pipeline (`entity create → make → build`) | Fixed domain root, `.zfa/` memory model |
| v6 | 2026-08-21 | Pure-Dart core + `zuraffa_flutter` split, dual-layer state | Fragmented Signal Slices, package SDK |

Sources: [CHANGELOG.md](CHANGELOG.md#L494-L540) [docs/v4_vs_v5_comparison.md](docs/v4_vs_v5_comparison.md#L1-L20) [docs/v6_state_migration_guide.md](docs/v6_state_migration_guide.md#L1-L30)

## v4 → v5 Migration: The Canonical Pipeline Shift

### The v4 Problem

In v4, developers faced **multiple competing generation paths** (`zfa generate`, `zfa feature`, direct plugin commands) that created orchestration drift and agent hesitation. The framework allowed custom domain/output directory overrides, leading to inconsistent project structures across teams.

### The v5 Solution

v5 established a **single canonical workflow** with strict constraints:

```bash
# Step 1: Create entity (fixed location: lib/src/domain/entities/{entity}/{entity}.dart)
zfa entity create -n Product --field id:String --field name:String --field price:double

# Step 2: Generate architecture (presets + plugins)
zfa make Product --preset=crud --methods=get,getList,create,update,delete --with=vpc --state --di --test

# Step 3: Run code generation
zfa build
```

**Key architectural changes**:

- **Fixed domain root**: `lib/src/domain` (no longer configurable)
- **Fixed entity location**: `lib/src/domain/entities/{entity_snake}/{entity_snake}.dart`
- **Fixed output root**: `lib/src` for all generated architecture
- **Plugin orchestration**: Deterministic plugin selection via presets, `.zfa.json` defaults, or explicit flags
- **Project memory**: `.zfa/` directory persisting plans, runs, blueprints, and decisions

Sources: [CHANGELOG.md](CHANGELOG.md#L494-L540) [specs/007-zuraffa-v5-foundation/spec.md](specs/007-zuraffa-v5-foundation/spec.md#L1-L40)

### Migration Steps v4 → v5

1. **Update `.zfa.json`** from flat legacy shape to nested v5 structure
2. **Replace `zfa generate`** with `zfa make` in all docs, scripts, and comments
3. **Remove custom flags**: `--domain-root`, `--entity-output`, `--output`
4. **Seed `.zfa/` directory**: `mkdir -p .zfa/{plans,runs,blueprints,decisions,manifests}`
5. **Regenerate features incrementally** using the canonical workflow

Sources: [CHANGELOG.md](CHANGELOG.md#L567-L590) [doc/ZIK_ZAK_V5_MIGRATION_PLAN.md](doc/ZIK_ZAK_V5_MIGRATION_PLAN.md#L1-L40)

## v5 → v6 Migration: Dual-Layer State & Package SDK

### The v5 Problem

v5's monolithic `.state.dart` pattern held **all state** for a presenter in a single generated file. Any manual UI state edits were wiped on every `zfa build` cycle, forcing developers to use `@preserve` blocks and workarounds.

### The v6 Solution

v6 introduces a strict **dual-layer boundary**:

| Layer | Class | Ownership | Regenerated? |
|-------|-------|-----------|--------------|
| **DomainState** | `{Name}DomainState` | Auto-generated | ✅ Every `zfa build` |
| **ViewState** | `{Name}ViewState` | Developer-edited | ❌ Scaffolded once, preserved |
| **Presenter** | `{Name}Presenter extends DualLayerPresenter` | Developer-edited | ❌ Scaffolded once, preserved |

Each UseCase gets its own `SignalSlice<T>` inside `DomainState`, enabling **O(1) granular rebuilds**.

Sources: [docs/v6_state_migration_guide.md](docs/v6_state_migration_guide.md#L1-L50)

### v6 Architectural Innovations

#### 1. Fragmented Signal Slices

Fine-grained reactive wrappers around individual UseCase results:

```dart
final productSlice = SignalSlice<Product>(
  useCase: getProductUseCase,
  params: GetProductParams(id: '123'),
);
productSlice.listen((product, error) { /* O(1) rebuild */ });
```

#### 2. FragmentBuilder & SignalBuilder

- **`FragmentBuilder<S>`** — subscribes to a single `SignalSlice<S>` and rebuilds only when that slice changes
- **`SignalBuilder<T>`** — subscribes to pure UI `Signal<T>` from `ViewState`

#### 3. ControlledWidget

The v6 base widget with typed controller access and `onInit` / `onDispose` lifecycle hooks.

#### 4. Package SDK

v6 delivers `zfa package create` plus generators, DDA auto-DI, and module & agent codegen operating in a package context — enabling reusable, Zuraffa-native packages that contribute entities, datasources, usecases, modules, and agent tools to consuming apps.

Sources: [docs/v6_state_migration_guide.md](docs/v6_state_migration_guide.md#L51-L100) [specs/025-v6-package-sdk/spec.md](specs/025-v6-package-sdk/spec.md#L1-L50)

### Migration Steps v5 → v6

#### State Migration

```bash
# Preview changes
zfa migrate state --dry-run

# Apply
zfa migrate state
```

The migrator:
- Detects `*Presenter` classes with `UseCase` fields
- Generates `late final` slice bindings (`bind<T>(...)`) for each UseCase
- Derives semantic slice keys from field names
- Creates `.bak` backup when writing over the source file

#### Manual State Split

Move transient UI state from v5 generated state files to `ViewState`:

**Before (v5)**:
```dart
// product_state.dart — wiped on every build
class ProductState {
  bool isDropdownOpen = false;  // ❌ lost on regeneration
  int activeTab = 0;            // ❌ lost on regeneration
}
```

**After (v6)**:
```dart
// product_view_state.dart — preserved across builds
class ProductViewState extends ViewState {
  ProductViewState() {
    registerSignal(isDropdownOpen);
    registerSignal(activeTab);
  }
  final isDropdownOpen = Signal<bool>(false);
  final activeTab = Signal<int>(0);
}
```

Sources: [docs/v6_state_migration_guide.md](docs/v6_state_migration_guide.md#L101-L200) [lib/src/migration/fixers/state_fixer.dart](lib/src/migration/fixers/state_fixer.dart#L1-L50)

## Migration Tooling & Automation

### Built-in Migration Commands

The framework provides automated migration tooling via `zfa migrate`:

| Command | Target | Status |
|---------|--------|--------|
| `zfa migrate state` | v5 mixed state → v6 DomainState + ViewState | ✅ Automated |
| `zfa migrate gql` | v5 GraphQL const strings → v6 `.graphql` files | ✅ Automated |
| `zfa migrate di` | Manual get_it → @Datasource/@Repository annotations | ⚠️ Detection-only |

### Migration Detection System

The detector system scans for v5 patterns and reports findings:

- **`StateDetector`**: Identifies mixed state classes needing DomainState/ViewState split
- **`ManualDiDetector`**: Flags manual `getIt.registerXXX` calls that should use annotations
- **`GqlConstStringDetector`**: Finds inline GraphQL query strings that should be extracted

Each detector produces machine-readable `MigrationFinding` objects with:
- Human-readable message
- File path and line number
- Machine-readable rule ID
- Severity level (info, warning, error)
- Suggested fix description

Sources: [lib/src/migration/migration.dart](lib/src/migration/migration.dart#L1-L21) [lib/src/migration/migration_models.dart](lib/src/migration/migration_models.dart#L1-L50) [lib/src/commands/migrate_command.dart](lib/src/commands/migrate_command.dart#L1-L50)

### The `zuraffa-migrate` Speckit Extension

For large-scale brownfield migrations, the `zuraffa-migrate` extension automates the entire playbook:

| Command | Phase | What it does |
|---------|-------|--------------|
| `speckit.zuraffa-migrate.analyze` | §1–2 | Runs censuses, decides shape, writes migration contract |
| `speckit.zuraffa-migrate.plan` | §3–4 | Scaffolds, maps every symbol, emits spec.md + test-list.md |
| `speckit.zuraffa-migrate.port` | §5–6 | Drives test-first port loop (red→green per behavior) and facade |
| `speckit.zuraffa-migrate.verify` | §7 | Walks parity gates and writes verdict with remediation tasks |

Sources: [docs/package_migration_guide.md](docs/package_migration_guide.md#L256-L275)

## Entity Identity Migration (v5 → v6)

A critical v6 change is the **loud no-id error** — entities without an id field, `*Id` field, or `autoId: true` now fail loudly instead of silently picking the first field.

### Three Identity Kinds

1. **Entity with real id** (default) — declares literal `id` or `*Id` field
2. **Entity with auto-generated uuid** (`@Zorphy(autoId: true)`) — aggregate roots and event records
3. **Value object** (`@ZValueObject`) — immutable composition types with no identity of their own

### Migration Recipe

```bash
# 1. Re-model a value object (no id, no persistence surface):
zfa entity create -n ParserConfig --kind=value_object \
  --field separator:String --field trimWhitespace:bool

# 2. Re-model an autoId entity (aggregate/event root):
zfa entity create -n ChatMessage --auto-id \
  --field role:ChatMessageRole --field content:String --field timestamp:DateTime

# 3. Then rebuild + re-make:
zfa build
zfa make ChatMessage --preset=crud --with=vpc,state,di,test,mock
```

Sources: [docs/issue-320-zikzak-entity-identity-migration.md](docs/issue-320-zikzak-entity-identity-migration.md#L1-L60)

## Package Migration Playbook

For converting existing Dart/Flutter packages to Zuraffa-native packages:

### Phase 0 — Inventory

Write `specs/001-zuraffa-migration/migration-contract.md` capturing:
1. Public API census (parity contract)
2. Behavior census (existing tests)
3. Native/platform census
4. Dependency census
5. Consumers

### Phase 1 — Scaffold

```bash
# Pure package
zfa package create <name> --description "<original description>, zuraffa-native"

# Federated plugin
zfa package create-plugin <name> --description "..." --repo <owner>/<name> --platforms android,ios,macos
```

### Phase 2 — Map Old API to Zuraffa Shapes

| Old Shape | Zuraffa Shape | Notes |
|-----------|---------------|-------|
| High-level service class | **Port** + **Service** + UseCases per operation | Consumers can use the facade or the usecases |
| One method per operation | One **UseCase** per operation | `execute(params, cancelToken)`; call syntax returns a `Result` |
| Request/response structs | **Entities** (domain) | Zorphy `@Zorphy` entities when they benefit from codegen |
| Callbacks / Streams | **StreamUseCase** | Cancellation comes free via `CancelToken` |
| `init()` / `dispose()` | **Module lifecycle** | `onInit` / `onDispose` on the `PackageModule` |
| Error enums / exceptions | **`AppFailure` hierarchy** | Throw `AppFailure` subclasses for expected errors |

Sources: [docs/package_migration_guide.md](docs/package_migration_guide.md#L100-L160)

## Verification & Parity Gates

The migration is complete when **all** of the following hold:

| Gate | Check |
|---|---|
| API parity | Every Phase-0 symbol exported, or listed as intentionally broken |
| Behavior parity | Full ported suite green; test count ≥ baseline; no test deleted without a contract note |
| Layer discipline | `grep`-able: `lib/src/domain` imports no `dart:io`/`dart:ffi`/channel code |
| DI completeness | Every public usecase/repository resolves from a fresh container after `registerPackage` |
| Statics | `dart analyze` clean; `zfa build` (if codegen present) clean |
| Module lifecycle | bootstrap/ready/shutdown test passes; no work outside lifecycle hooks |
| Publish | `dart pub publish --dry-run` (per package) clean |
| Journal | `specs/<NNN>-zuraffa-rewrite/tdd/cycle-log.md` shows red→green evidence per behavior |

Sources: [docs/package_migration_guide.md](docs/package_migration_guide.md#L232-L245)

## Version Skew Contract

The framework enforces a **version skew contract** to prevent silent failures when the CLI binary and driving tool differ:

- When the build pass's resolved zfa binary provably reports a version other than the driving CLI's, it is bypassed for the driving CLI's own entrypoint
- An equal, unprovable, or unresolvable version keeps the previous resolution
- The replacement itself must prove the driving version too

This ensures that `zfa tdd` loops always drive against the exact binary version that produced the receipts, preventing false positives from version drift.

Sources: [CHANGELOG.md](CHANGELOG.md#L84-L87) [.specify/bugs/version-skew-contract](.specify/bugs/version-skew-contract)

## Recommended Reading Progression

For advanced developers navigating the migration landscape:

1. **Start with the v5 foundation** — [Canonical v5 Workflow](5-canonical-v5-workflow-entity-make-build) to understand the current generation contract
2. **Understand v4 → v5** — [docs/v4_vs_v5_comparison.md](docs/v4_vs_v5_comparison.md) for concrete file-by-file comparison
3. **Plan v5 → v6 state migration** — [V6 State Migration Guide](docs/v6_state_migration_guide.md) for the dual-layer architecture
4. **For package authors** — [Package Migration Guide](docs/package_migration_guide.md) for the complete brownfield playbook
5. **For AI agents** — [Agent & Skill Ecosystem](10-agent-and-skill-ecosystem-speckit-and-kimi-skills) to understand how migration tooling integrates with agent workflows

## Key Takeaways

1. **v4 → v5** was about **constraining flexibility** to reduce agent ambiguity — one canonical path, fixed locations, deterministic plugin selection
2. **v5 → v6** is about **fragmenting state** for performance and **package-izing the SDK** for reusability — granular rebuilds, DI annotations, package registrars
3. **Migration tooling** is first-class — `zfa migrate` detectors and fixers automate the mechanical parts; the strategic decisions (entity identity classification, API mapping) remain human-led
4. **Backward compatibility** is maintained through facades and opt-in flags — existing v5 code continues to work in v6 without changes
5. **Verification is contract-driven** — every migration ships with a parity contract and TDD journal proving red→green evidence per behavior