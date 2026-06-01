## [5.0.0] - 2026-06-01

### Change
- Release 5.0.0

## [5.0.0] - 2026-06-01

### Change
- Release 5.0.0

## [5.0.0] - 2026-06-01

### Change
- Release 5.0.0

## [5.0.0] - 2026-06-01

### 🎉 Zuraffa v5 - Canonical Pipeline Release

Zuraffa v5 establishes a unified, AI-first generation contract that replaces the legacy one-shot generator with a three-step canonical workflow.

### Breaking Changes

#### Removed Legacy Generator

- **Removed**: `zfa generate` command and all legacy one-shot generation patterns
- **Removed**: Custom domain/output directory overrides (`--domain-root`, `--entity-output`, `--output`)
- **Removed**: Legacy flag combinations and implicit generation modes
- **Migration**: Use the v5 canonical workflow: `entity create → make → build`

#### Fixed Architecture Contract

- **Fixed domain root**: `lib/src/domain` (no longer configurable)
- **Fixed entity location**: `lib/src/domain/entities/{entity_snake}/{entity_snake}.dart`
- **Fixed output root**: `lib/src` for all generated architecture

### New Canonical Workflow

The v5 contract enforces a three-step pipeline for all generation:

```bash
# Step 1: Create entity
zfa entity create -n Product --field id:String --field name:String --field price:double

# Step 2: Generate architecture
zfa make Product --preset=crud --methods=get,getList,create,update,delete --with=vpc --state --di --test

# Step 3: Run code generation
zfa build
```

### What `zfa make` Generates

- Repository interfaces and implementations
- DataSource interfaces and implementations
- UseCases for business logic
- Presenters/Controllers/State (with `--with=vpc --state`)
- DI registration (with `--di`)
- Tests (with `--test`)
- Cache support (with `--cache`)
- Mock datasources (with `--mock`)
- Route generation (with `--route`)
- GraphQL support (with `--gql`)

### Configuration Changes

#### New `.zfa.json` Structure

Migrated from flat configuration to nested v5 shape:

```json
{
  "plugins": {
    "defaults": {
      "di": true,
      "test": true,
      "method_append": true,
      "route": false,
      "mock": false,
      "gql": false,
      "cache": false
    },
    "disabled": []
  },
  "planning": {
    "presets": {},
    "aliases": {}
  },
  "ui": {
    "adaptiveLayouts": true,
    "platformShells": true,
    "layoutTargets": ["mobile", "tablet", "desktop"],
    "adaptivePreset": "adaptive-feature"
  },
  "entity": {
    "entityFirst": true,
    "jsonByDefault": true,
    "compareByDefault": true,
    "filterByDefault": true
  },
  "buildByDefault": false,
  "formatByDefault": false
}
```

### Project Memory: `.zfa/` Directory

Introduced `.zfa/` as the canonical project memory surface for AI agents and developers:

```
.zfa/
├── plans/          # Generation plans from `zfa make --plan`
├── runs/           # Execution logs and results
├── blueprints/     # Architectural blueprints and patterns
├── decisions/      # Architectural decision records (ADRs)
├── manifests/      # Feature manifests
└── context.json    # Project context and state
```

See `doc/ZFA_MEMORY_GUIDE.md` for complete usage documentation.

### MCP Server Updates

- **Updated**: MCP now advertises `zuraffa_make` instead of `zuraffa_generate`
- **Updated**: MCP tool execution invokes `zfa make` with the v5 contract
- **Updated**: Tool schema includes `preset` parameter for generation patterns
- **Updated**: Documentation reflects the canonical v5 pipeline

### Documentation Updates

#### New Documentation

- `doc/V5_ACTION_PLAN.md` - Concrete v5 execution plan
- `doc/ROADMAP.md` - v5-specific roadmap
- `doc/ZFA_MEMORY_GUIDE.md` - Complete `.zfa/` usage guide
- `doc/ZIK_ZAK_V5_MIGRATION_PLAN.md` - Downstream migration guide

#### Updated Documentation

- `README.md` - v5 workflow and examples
- `website/docs/intro.md` - v5 getting started
- `website/docs/features/mcp-server.md` - v5 MCP integration
- `doc/MCP_SERVER.md` - v5 MCP documentation
- `AGENTS.md` - v5 AI agent guidelines

#### Removed Documentation

- `doc/cli_command_list.md` - Obsolete command reference
- `doc/combinations.md` - Legacy flag combinations

### Example Project Updates

- Updated `example/.zfa.json` to v5 shape
- Updated all example code to use v5 workflow
- Cleaned legacy command references from comments
- Updated test fixtures to v5 patterns

### Testing & Validation

#### New Tests

- `test/regression/v5_pipeline_contract_test.dart` - Enforces v5 contract across all surfaces
- Enhanced `test/regression/docs_command_consistency_test.dart` - Validates documentation consistency

#### Test Coverage

- ✅ Default `.zfa` context uses `entity create → make → build`
- ✅ Core docs teach the full canonical pipeline
- ✅ MCP advertises `zuraffa_make` and invokes `make`
- ✅ `example/.zfa.json` uses v5 config shape
- ✅ No active/public surfaces contain legacy commands

### Migration Guide

#### For Existing Projects

**Step 1: Update `.zfa.json`**

```bash
# Backup your current config
cp .zfa.json .zfa.json.backup

# Update to v5 shape (see doc/ZFA_MEMORY_GUIDE.md for examples)
```

**Step 2: Update project guidance**

- Replace `zfa generate` with `zfa make` in docs
- Remove custom `--domain-root` or `--output` flags
- Update to fixed domain structure: `lib/src/domain/entities/{entity}/{entity}.dart`

**Step 3: Seed `.zfa/` directory**

```bash
mkdir -p .zfa/{plans,runs,blueprints,decisions,manifests}
# Create initial context.json (see doc/ZFA_MEMORY_GUIDE.md)
```

**Step 4: Regenerate features incrementally**

```bash
# Start with a small pilot feature
zfa make YourEntity --preset=crud --methods=get,getList --with=vpc --state --di --test
zfa build
```

#### For New Projects

Start with the v5 workflow from day one:

```bash
# 1. Create entity
zfa entity create -n User --field id:String --field email:String --field name:String

# 2. Generate architecture
zfa make User --preset=crud --methods=get,getList,create,update,delete --with=vpc --state --di --test

# 3. Build
zfa build
```

### Presets and Patterns

#### Available Presets

- `crud` - Complete CRUD stack (repository, datasource, usecases)
- `feature` - Full feature with presentation layer
- `adaptive-feature` - Feature with adaptive layouts for multiple platforms

#### Common Patterns

**Basic CRUD:**

```bash
zfa make Product --preset=crud --methods=get,getList,create,update,delete
```

**Full stack with presentation:**

```bash
zfa make Product --preset=crud --with=vpc --state --di --test --methods=get,getList,create,update,delete
```

**Custom use case:**

```bash
zfa make SearchProducts usecase --domain=search --params=SearchQuery --returns=List<Product>
```

**With caching:**

```bash
zfa make Product --preset=crud --cache --methods=get,getList
```

**With mocks:**

```bash
zfa make Product --preset=crud --mock --use-mock --methods=get,getList
```

### Adaptive Layouts

v5 introduces adaptive layout support for multi-platform applications:

```bash
zfa make Product --preset=adaptive-feature --with=vpc --state --methods=get,getList
```

Generates layouts for:

- Mobile
- Tablet
- Desktop
- Platform-specific shells (e.g., macOS)

### AI Agent Integration

v5 is designed for AI-first workflows:

- **MCP Server**: Native integration with Claude and other AI assistants
- **Project Memory**: `.zfa/` provides context for multi-session agent work
- **Canonical Contract**: Single workflow reduces agent confusion
- **Documentation**: All docs teach the same v5 pattern

### Downstream Validation

The v5 pipeline has been validated with:

- Complete example project regeneration
- ZikZak app migration (Phase 1 complete)
- v4 vs v5 comparison testing
- Comprehensive regression test suite

### Known Limitations

#### Manual Integration for `.zfa/`

Currently, `.zfa/` artifacts are manually managed. Future versions will:

- Auto-write plans when using `--plan`
- Auto-write run logs after execution
- Auto-update `context.json` after generation

#### GraphQL Support

GraphQL plugin is currently disabled by default. Full GraphQL support is planned for v5.1.x.

### Upgrade Path

**From v4.x to v5.0.0:**

1. Update `pubspec.yaml`: `zuraffa: ^5.0.0`
2. Run `flutter pub get`
3. Update `.zfa.json` to v5 shape
4. Update project docs to remove legacy commands
5. Seed `.zfa/` directory structure
6. Regenerate features incrementally with `zfa make`

**Estimated migration time:**

- Small projects (1-5 features): 1-2 hours
- Medium projects (5-15 features): 4-8 hours
- Large projects (15+ features): Plan incremental migration over multiple sessions

### Future Roadmap

#### v5.1.x (SHOULD)

- `zfa migrate` - Automated migration from v4 to v5
- `zfa doctor` - Project health diagnostics
- `zfa diff` - Preview regeneration changes
- GraphQL decision and integration
- Adaptive layout refinements
- Unified root resolution

#### v5.2.x (NICE TO HAVE)

- Enhanced docs and recipes
- Faster incremental regeneration
- Better progress reporting
- Routing helpers
- Realtime scaffolds

### Contributors

Special thanks to all contributors who helped shape v5.

### Resources

- **Documentation**: https://zuraffa.com
- **Repository**: https://github.com/arrrrny/zuraffa
- **Issues**: https://github.com/arrrrny/zuraffa/issues
- **Migration Guide**: `doc/ZIK_ZAK_V5_MIGRATION_PLAN.md`
- **Memory Guide**: `doc/ZFA_MEMORY_GUIDE.md`
- **Action Plan**: `doc/V5_ACTION_PLAN.md`

---

## [4.1.2] - 2026-05-03

### Change

- Release 4.1.2

## [4.1.1] - 2026-05-02

### Fixed

- **OpenTelemetry Context Management**: Fixed "unexpected (mismatched) token given to detach" errors in concurrent scrape operations.
  - `trace()` and `traceSync()` now wrap their entire body in `runZoned()` to fork isolated zones with independent context stacks.
  - Parent context is explicitly captured and passed to `startSpan()` to maintain correct span lineage across asynchronous boundaries.

### Change

- Release 4.1.1

## [4.1.0] - 2026-04-30

### Added

- **Analyzer 13 Support**: Full compatibility with `analyzer` package version 13.0.0.
- **Robust AST Migration**: Implemented reflection-based helper methods in `InjectBuilder` and `MethodExtractor` to support both legacy and new `analyzer` AST structures (`RegularFormalParameter`, `NamedArgument`, `Label.name`, etc.).
- **Improved DI Generation**: Enhanced constructor merging and registration logic to handle breaking changes in formal parameter representation.

### Changed

- Upgraded `dart_style` to `^3.1.9` for improved code formatting and compatibility with new Dart features.
- Pin `analyzer` to `13.0.0` in dependency overrides to ensure stable code generation.
- Upgraded `zorphy_annotation` to `^1.7.0` and `zorphy` to `^1.6.9`.

## [4.0.10] - 2026-04-26

### Change

- Release 4.0.10

## [4.0.9] - 2026-04-26

### Change

- Release 4.0.9

## [4.0.8] - 2026-04-26
