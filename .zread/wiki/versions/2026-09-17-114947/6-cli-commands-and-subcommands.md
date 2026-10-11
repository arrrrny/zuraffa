The Zuraffa CLI (`zfa`) exposes a layered command architecture: a top-level `CliRunner` that bootstraps the plugin registry, a set of core commands, and plugin-derived subcommands. Every command follows a standardized contract — exit codes, output formats, and error shapes are uniform across the surface.

Sources: [bin/zfa.dart](bin/zfa.dart#L1-L13), [lib/src/zfa_cli.dart](lib/src/zfa_cli.dart#L1-L15), [lib/src/cli/cli_runner.dart](lib/src/cli/cli_runner.dart#L1-L200)

## Architecture Overview

```
zfa (bin/zfa.dart)
  └── CliRunner.run(args)
        ├── _buildRunner()              // CrashSafeCommandRunner
        ├── _ensureInitialized()       // plugin boot + command registration
        └── dispatches to:
              ├── Core Commands (registered always)
              └── Plugin Commands (registered after plugin boot)
```

The runner uses `package:args`'s `CommandRunner` under the hood, but wraps it with `_CrashSafeCommandRunner` to handle edge cases. Two entry points exist: `run()` for process-owning invocations (exits via `exit()`), and `runCapturing()` for embedded use (MCP server, in-process dispatch) that returns output as a string.

Sources: [lib/src/cli/cli_runner.dart](lib/src/cli/cli_runner.dart#L40-L120)

## Global Flags

Every command recognizes five standard global flags, defined in `CliGlobalFlags.standard`:

| Flag | Abbr | Type | Description |
|------|------|------|-------------|
| `--help` | `-h` | boolean | Show help and exit |
| `--version` | `-v` | boolean | Print version and exit |
| `--verbose` | — | boolean | Verbose output (includes stack traces) |
| `--output` | — | value | Output format: `json` or `text` |
| `--no-color` | — | negatable | Disable ANSI color codes |

Additionally, `-C/--directory <dir>` is a runner-level flag that scopes the working directory for the invocation (restored afterward), enabling hermetic test runs.

Sources: [lib/src/cli/standard/cli_contract.dart](lib/src/cli/standard/cli_contract.dart#L180-L220)

## Exit Code Protocol

All commands conform to the ratified exit-code protocol:

| Code | Name | Meaning |
|------|------|---------|
| 0 | success | GREEN / complete |
| 1 | failure | RED (honest, in-loop) / stopped / audit failure |
| 2 | usage | The operation could not run as invoked (grammar error, unknown flag/subcommand) |
| 3 | drift | Contract/spec drift |
| 4 | conflict | State conflict (concurrent run ownership) |

Every non-zero exit closes with a machine-actionable fix line: `--> fix: <remediation>`.

Sources: [lib/src/cli/exit_protocol.dart](lib/src/cli/exit_protocol.dart#L1-L88)

## Core Commands

These commands are always registered, regardless of plugin state:

### Generation Workflow Commands

| Command | Subcommands | Purpose |
|---------|-------------|---------|
| `entity` | `create`, `remove`, `enum`, `add-field`, `list`, `from-json`, `build`, `watch`, `validate`, `cli` | Domain entity lifecycle management |
| `make` | (plugin names as positional args) | Canonical architecture/code generation |
| `build` | — | Run build_runner codegen with post-build verification |
| `feature` | `scaffold`, `route`, `di`, `mock`, `test`, `view`, `presenter`, `controller`, `state` | Wrapper over `zfa make` with normalized feature preset |

The canonical v5 workflow is: `zfa entity create` → `zfa make` → `zfa build`.

Sources: [lib/src/commands/entity_command.dart](lib/src/commands/entity_command.dart#L24-L200), [lib/src/commands/make_command.dart](lib/src/commands/make_command.dart#L46-L100), [lib/src/commands/build_command.dart](lib/src/commands/build_command.dart#L20-L60), [lib/src/commands/feature_command.dart](lib/src/commands/feature_command.dart#L11-L100)

### Configuration & Inspection Commands

| Command | Subcommands | Purpose |
|---------|-------------|---------|
| `config` | `init`, `show`, `set` | Manage `.zfa.json` project defaults |
| `doctor` | — | Inspect tooling and environment health (Dart/Flutter versions, dependencies) |
| `manifest` | `--verify` | List all available capabilities (JSON/MCP format) |
| `proof` | `check`, `chain`, `prune` | Generation receipt verification |
| `migrate` | `state`, `gql`, `di` | Migrate v5 artifacts to v6 equivalents |
| `corpus` | `import`, `catalog`, `run`, `ledger` | Spec corpus onboarding and walking |
| `apply` | — | Execute a previously generated plan (by `--plan-id`) |
| `dream` | — | One-command feature generation from plain English |
| `replay` | — | Re-execute a feature's recorded TDD history |
| `update` | — | Check for and apply CLI updates |

Sources: [lib/src/commands/config_command.dart](lib/src/commands/config_command.dart#L9-L60), [lib/src/commands/doctor_command.dart](lib/src/commands/doctor_command.dart#L11-L80), [lib/src/commands/manifest_command.dart](lib/src/commands/manifest_command.dart#L40-L100), [lib/src/commands/proof_command.dart](lib/src/commands/proof_command.dart#L21-L60), [lib/src/commands/migrate_command.dart](lib/src/commands/migrate_command.dart#L12-L60), [lib/src/commands/corpus_command.dart](lib/src/commands/corpus_command.dart#L24-L60), [lib/src/commands/apply_command.dart](lib/src/commands/apply_command.dart#L10-L40), [lib/src/commands/dream_command.dart](lib/src/commands/dream_command.dart#L19-L60), [lib/src/commands/replay_command.dart](lib/src/commands/replay_command.dart#L14-L40), [lib/src/commands/update_command.dart](lib/src/commands/update_command.dart#L12-L40)

### Project Setup Commands

| Command | Purpose |
|---------|---------|
| `setup <name>` | Bootstrap a new Flutter/Dart app with zuraffa dependencies wired in |
| `init` / `initialize` | In-place project initialization (dependency wiring + entity scaffolding) |

Sources: [lib/src/commands/setup_command.dart](lib/src/commands/setup_command.dart#L33-L80), [lib/src/commands/initialize_command.dart](lib/src/commands/initialize_command.dart#L10-L80)

### Specialized Commands

| Command | Subcommands | Purpose |
|---------|-------------|---------|
| `xray` | `enable`, `disable`, `status`, `deck`, `mock`, `check` | X-Ray debug tools (overlay, control deck) |
| `zap` | `conform`, `serve`, `schema` | ZAP protocol engine |
| `agent` | `shell` | Agent runtime daemon (NDJSON over stdio) |
| `tdd` | `init`, `plan`, `gen`, `make`, `wire`, `func`, `refactor`, `run`, `verify`, `split`, `status`, `prove`, `replay`, `theater`, `verdicts`, `reset`, `doctor`, `realize`, `corpus`, `referee`, `diff-check`, `migrate-paths`, `view`, `compose`, `fake`, `verify-red`, `ingest`, `run-engine`, `run-skin` | Full TDD red-green-refactor cycle driver |
| `plugin` | `list`, `enable`, `disable`, `add`, `mcp` | Plugin lifecycle management |

Sources: [lib/src/commands/xray_command.dart](lib/src/commands/xray_command.dart#L14-L60), [lib/src/commands/zap_command.dart](lib/src/commands/zap_command.dart#L27-L80), [lib/src/commands/agent_command.dart](lib/src/commands/agent_command.dart#L12-L40), [lib/src/commands/tdd_command.dart](lib/src/commands/tdd_command.dart#L33-L60), [lib/src/commands/plugin_command.dart](lib/src/commands/plugin_command.dart#L14-L60)

## Plugin-Derived Commands

Plugin commands inherit from `PluginCommand` and auto-register capabilities as subcommands. Each plugin command accepts the entity name as a positional argument and exposes standard flags:

| Plugin Command | Standard Flags | Purpose |
|----------------|---------------|---------|
| `repository` | `--output`, `--dry-run`, `--force`, `--verbose`, `--revert` | Generate repository layer |
| `datasource` | same | Generate data source layer |
| `usecase` | same | Generate use case layer |
| `controller` | same | Generate controller layer |
| `presenter` | same | Generate presenter layer |
| `view` | same | Generate view layer |
| `route` | same | Generate routing definitions |
| `state` | same | Generate state management |
| `provider` | same | Generate provider/DI setup |
| `service` | same | Generate service layer |
| `api` | same | Generate API integration |
| `mock` | `create`, `data`, `json`, `certify`, `explain`, `dependency` | Mock data generation |
| `cache` | same | Generate caching layer |
| `graphql` / `gql` | same | Generate GraphQL integration |
| `di` | same | Generate dependency injection |
| `sync` | same | Generate sync framework |
| `sqlite` | same | Generate SQLite adapter |
| `test` | same | Generate tests |
| `gym` | `--domain` | Generate GYM artifacts |
| `mcp` | `scaffold`, `replay`, `serve`, `list-tools` | MCP server management |

Sources: [lib/src/commands/base_plugin_command.dart](lib/src/commands/base_plugin_command.dart#L13-L60), [lib/src/commands/mock_command.dart](lib/src/commands/mock_command.dart#L21-L100), [lib/src/commands/mcp_command.dart](lib/src/commands/mcp_command.dart#L27-L80)

## Command Model

Every command is built on the `StandardCommand` declarative model:

```dart
class StandardCommand {
  final String name;           // command name
  final String description;    // one-line help
  final List<CommandArgument> arguments;  // positional args
  final List<CommandFlag> flags;          // named flags
  final List<String> aliases;             // aliases
  final Future<CommandResult> Function(CliInvocation) handler;
}
```

Handlers return a `CommandResult` (`SuccessResult`, `ErrorResult`, or `WarningResult`) which the `CliApp` translates into exit codes and output format. This model keeps commands declarative while leveraging the `args` package conventions.

Sources: [lib/src/cli/standard/command_model.dart](lib/src/cli/standard/command_model.dart#L1-L228)

## Plugin Command Auto-Registration

`PluginCommand` automatically registers every capability of its plugin as a subcommand via `CapabilityCommand`. This means:

- `zfa repository <Entity>` is actually `zfa repository create <Entity>` (the `create` capability)
- Capability flags are derived from the capability's `inputSchema` JSON Schema
- A `--json` flag accepts arguments as a JSON string
- Positional arguments map to required schema properties

Sources: [lib/src/commands/base_plugin_command.dart](lib/src/commands/base_plugin_command.dart#L60-L100), [lib/src/commands/capability_command.dart](lib/src/commands/capability_command.dart#L30-L80)

## No-Plugin Commands

Certain top-level commands skip the heavy plugin boot (27 plugin constructions + registry walk) to avoid overhead in parallel test environments:

- `xray` — debug tools, no plugin registry needed
- `proof` — receipt verification, no plugin registry needed

These are identified by `_noPluginCommands` in the runner.

Sources: [lib/src/cli/cli_runner.dart](lib/src/cli/cli_runner.dart#L120-L140)

## Next Steps

With the CLI surface mapped, the natural progression is:

- **[Plugin System Architecture](7-plugin-system-architecture)** — understand how plugins register capabilities and how the command tree is built
- **[Code Generation Engine & Proof Receipts](9-code-generation-engine-and-proof-receipts)** — dive into the generation pipeline and receipt verification
- **[TDD Cycle & Spec-Driven Development](13-tdd-cycle-and-spec-driven-development)** — explore the full TDD workflow driven by the `tdd` command family