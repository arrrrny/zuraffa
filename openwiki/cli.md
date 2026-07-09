# CLI Reference

Zuraffa provides three CLI executables: `zuraffa` (full), `zfa` (shorthand), and `zuraffa_mcp_server` (MCP integration).

## Canonical Workflow

```
zfa entity create  →  zfa make  →  zfa build
```

This three-step flow is the recommended way to generate code in v5.

## Command Model

Commands are organized into **core commands** (registered directly) and **plugin commands** (registered dynamically from plugin capabilities).

```
zfa <command> [subcommand] [name] [options]
```

### Core Commands

| Command | File | Description |
|---|---|---|
| `entity` | `entity_command.dart` | Manage Zorphy entities (create, enum, add-field, list, from-json) |
| `make` | `make_command.dart` | **Primary generation orchestrator** — runs multiple plugins for a named entity |
| `build` | `build_command.dart` | Wraps `build_runner build` with file counting |
| `config` | `config_command.dart` | Manage `.zfa.json` (init, show, set) |
| `init` / `initialize` | `initialize_command.dart` | Bootstrap a project with sample entity and folders |
| `doctor` | `doctor_command.dart` | Inspect tooling and environment health |
| `manifest` | `manifest_command.dart` | List all MCP capabilities in JSON/MCP format |
| `apply` | `apply_command.dart` | Execute a previously generated plan (from PlanStore) |
| `schema` | `schema_command.dart` | Output JSON Schema for config files |
| `validate` | `validate_command.dart` | Validate a JSON configuration file |
| `create` | `create_command.dart` | Create page / architecture folders |
| `plugin` | `plugin_command.dart` | List, enable, or disable plugins |

### Plugin Commands (wrap individual plugins)

| Command | Plugin | Description |
|---|---|---|
| `view` | ViewPlugin | Generate view files |
| `controller` | ControllerPlugin | Generate controller files |
| `presenter` | PresenterPlugin | Generate presenter files |
| `state` | StatePlugin | Generate state classes |
| `usecase` | UseCasePlugin | Generate use case files |
| `repository` | RepositoryPlugin | Generate repository interface + impl |
| `service` | ServicePlugin | Generate service classes |
| `provider` | ProviderPlugin | Generate data providers |
| `datasource` | DataSourcePlugin | Generate remote/local data sources |
| `di` / `modular-di` | DiPlugin | Generate get_it DI registrations |
| `route` | RoutePlugin | Generate route definitions |
| `test` | TestPlugin | Generate unit tests |
| `mock` | MockPlugin | Generate mock data and providers |
| `cache` | CachePlugin | Generate caching logic |
| `sync` | SyncPlugin | Generate offline-first sync layer |
| `graphql` / `gql` | GraphqlPlugin | Generate GraphQL operations |
| `observer` | ObserverPlugin | Generate observer classes |
| `feature` | FeaturePlugin | Generate full feature bundle (wrapper over `make --preset=feature`) |

## `zfa entity create` — Entity Management

Creates Zorphy-annotated entities in a fixed location:

```
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

### Subcommands

| Subcommand | Description |
|---|---|
| `create` / `new` | Create a new entity with fields |
| `enum` | Create a Zorphy enum |
| `add-field` | Add field(s) to an existing entity |
| `list` | List all entities |
| `from-json` | Create entity from a JSON file (infers field types) |

### Examples

```bash
# Basic entity
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double

# Entity with optional, list, and DateTime fields
zfa entity create -n Order \
  --field id:String \
  --field total:double \
  --field createdAt:DateTime \
  --field items:List<OrderItem> \
  --field notes:String?

# Entity from JSON schema
zfa entity create -n User --from-json user_schema.json

# Sealed entity (for polymorphic variants)
zfa entity create -n PaymentMethod --sealed

# Enum
zfa entity enum -n OrderStatus --value pending,paid,shipped

# Add field to existing entity
zfa entity add-field -n Product --field category:String
```

## `zfa make` — Primary Generation Command

The main orchestrator for code generation. Generate architecture around an entity.

### Signature

```bash
zfa make <EntityName> [plugin1 plugin2 ...] [options]
```

### Options

| Option | Description |
|---|---|
| `--preset <name>` | Preset plugin set (crud, feature, vpc, read-only, etc.) |
| `--methods <list>` | CRUD methods (get, getList, create, update, delete) |
| `--with <aliases>` | Enable plugins by alias (vpc, data, quality, full-ui) |
| `--without <plugins>` | Disable specific plugins |
| `--state` | Generate state classes |
| `--di` | Generate DI registrations |
| `--test` | Generate unit tests |
| `--cache` | Generate caching layer |
| `--sync` | Generate offline-first sync |
| `--route` | Generate route definitions |
| `--mock` | Generate mock data/providers |
| `--append` | Append to existing repo/service |
| `--plan` / `--explain` | Show normalized plan without executing |
| `--dry-run` | Simulate generation without file writes |
| `--force` | Overwrite existing files |
| `--revert` | Undo the last generation |
| `--from-json <file>` | Load config from JSON file |
| `--from-stdin` | Load config from stdin |
| `--no-<plugin>` | Mute specific plugin (e.g., `--no-route`) |
| `--format <text\|json>` | Output format |

### Examples

```bash
# Basic CRUD stack
zfa make Product --preset=crud --methods=get,getList,create,update,delete

# CRUD with presentation and tests
zfa make Product --preset=crud --with=vpc --state --di --test

# Data layer only
zfa make Product --preset=crud --methods=get,getList

# With caching
zfa make Product --methods=get,getList --cache --cache-policy=daily --cache-storage=hive

# Custom use case (no entity)
zfa make SearchProducts usecase --domain=search --params=SearchQuery --returns=List<Product>

# Plan preview only
zfa make Product --preset=crud --with=vpc --plan
```

### Presets

| Preset | Plugins Activated |
|---|---|
| `crud` | usecase, repository, datasource, service |
| `feature` | All layers: domain, data, presentation, DI, tests, routes |
| `vpc` | view, presenter, controller |
| `read-only` | usecase (get/getList), repository, datasource |
| `full-stack` | All available plugins |
| `data-layer` | repository, datasource |
| `service-feature` | usecase, service, datasource |

### Aliases

| Alias | Expanded To |
|---|---|
| `data` | repository, datasource |
| `vpc` | view, presenter, controller |
| `full-ui` | view, presenter, controller, state, route |
| `quality` | test, mock, di |

## `zfa build` — Build Generated Code

```bash
zfa build
```

Runs `build_runner build` after generation. Processes Zorphy annotations (`@Entity`, `@ZKey`, `@ZEnum`) and JSON serialization (`@JsonSerializable`).

- Counts entity files before/after to verify generation
- Optionally cleans cache with `--cache-clean`
- Prefer this over calling `build_runner` directly in agent workflows

## `zfa config` — Project Configuration

```bash
zfa config init     # Create .zfa.json
zfa config show     # Display current config
zfa config set <key> <value>  # Modify config
```

Configuration file (`.zfa.json`) supports:

```json
{
  "plugins": {
    "defaults": { "repository": true, "provider": false },
    "disabled": ["graphql"]
  },
  "planning": {
    "presets": { "my-custom": ["usecase", "repository"] },
    "aliases": { "db": ["repository", "datasource"] }
  },
  "entity": {
    "jsonByDefault": true,
    "compareByDefault": true,
    "filterByDefault": false
  },
  "buildByDefault": false,
  "formatByDefault": false
}
```

Key config properties (source: `lib/src/config/zfa_config.dart`):

| Property | Type | Description |
|---|---|---|
| `plugins.defaults` | `Map<String, bool>` | Per-plugin enable defaults |
| `plugins.disabled` | `List<String>` | Permanently disabled plugins |
| `planning.presets` | `Map<String, List<String>>` | Custom presets |
| `planning.aliases` | `Map<String, List<String>>` | Custom aliases |
| `entity.*` | various | Entity generation defaults |
| `buildByDefault` | `bool` | Auto-run build_runner after generation |
| `formatByDefault` | `bool` | Auto-run dart format after generation |

## `zfa doctor` — Environment Health

```bash
zfa doctor
```

Displays installed tooling versions: Dart, Flutter, Zuraffa, build_runner, Zorphy annotation.

## MCP Server

Zuraffa includes an MCP (Model Context Protocol) server at `bin/zuraffa_mcp_server.dart` that exposes all generation capabilities as JSON-RPC tools over stdin/stdout.

### Supported JSON-RPC Methods

| Method | Description |
|---|---|
| `initialize` | Server initialization |
| `tools/list` | List available MCP tools |
| `tools/call` | Execute a tool |
| `resources/list` | List file resources |
| `resources/read` | Read a specific resource |
| `prompts/list` | List available prompts |
| `prompts/get` | Get a specific prompt |

The MCP server wraps plugin capabilities as MCP tools, enabling AI coding assistants (e.g., Zed) to call `zfa` generation commands programmatically.

> **Full MCP server details**: [Integrations](integrations.md#mcp-server)

## File Layout Assumptions

All generated code assumes a fixed project structure:

```
lib/src/
├── domain/
│   ├── entities/{entity_snake}/{entity_snake}.dart
│   ├── repositories/{entity_snake}_repository.dart
│   ├── services/{entity_snake}_service.dart
│   └── usecases/{entity_snake}/
├── data/
│   ├── datasources/{entity_snake}/
│   └── repositories/{entity_snake}_repository.dart
├── presentation/
│   ├── controllers/{entity_snake}_controller.dart
│   ├── presenters/{entity_snake}_presenter.dart
│   ├── states/{entity_snake}_state.dart
│   └── views/{entity_snake}_view.dart
├── di/
├── routes/
├── mocks/
├── cache/
└── sync/
```

These paths are non-negotiable in v5 — do not use `--output` to override entity paths.

## Base Command Classes

| Class | File | Purpose |
|---|---|---|
| `StandardCommand` | `commands/standard_command.dart` | Base for core commands with exit/error/success helpers |
| `PluginCommand` | `commands/base_plugin_command.dart` | Base for plugin-backed commands with standard flags |
| `CapabilityCommand` | `commands/capability_command.dart` | Subcommand wrapper for individual plugin capabilities |

## Source Map

```
bin/
├── zfa.dart                    # Shorthand CLI entrypoint
├── zuraffa.dart                # Full CLI entrypoint
└── zuraffa_mcp_server.dart     # MCP server entrypoint

lib/src/
├── cli/cli_runner.dart         # CLI dispatcher and command registry
├── cli/plugin_loader.dart      # Plugin instantiation and registry building
├── cli/progress_reporter.dart  # Progress display
├── commands/                   # ~30 command implementations
│   ├── make_command.dart       # Primary orchestrator (zfa make)
│   ├── entity_command.dart     # Entity management (zfa entity)
│   ├── build_command.dart      # Build runner wrapper (zfa build)
│   ├── config_command.dart     # Config management (zfa config)
│   └── ... (all other commands)
├── config/zfa_config.dart      # .zfa.json loading and serialization
└── version.dart                # Version constant
```
