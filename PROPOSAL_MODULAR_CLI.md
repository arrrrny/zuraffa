# Modular CLI Architecture & Consistency Proposal

## Objective
Transform the Zuraffa CLI from a monolithic executor into a modular, plugin-driven system where every plugin can be executed independently (e.g., `zfa route`, `zfa presenter`). This ensures consistency, reduces code duplication, and makes the CLI extensible.

## Current State Analysis

### Existing Standalone Commands
The following commands currently exist but use ad-hoc implementations (manual `ArgParser`, custom `execute` methods):
- `zfa view <ViewName>`: Manually implemented in `ViewCommand`.
- `zfa di <UseCaseName>`: Manually implemented in `DiCommand`.
- `zfa entity <Name>`: Manually implemented in `EntityCommand`.
- `zfa test <Name>`: Manually implemented in `TestCommand`.

### Missing Standalone Commands
The following plugins are currently only accessible via the monolithic `zfa generate` command:
- `route` (RoutePlugin)
- `repository` (RepositoryPlugin)
- `datasource` (DataSourcePlugin)
- `usecase` (UseCasePlugin)
- `presenter` (PresenterPlugin)
- `controller` (ControllerPlugin)
- `state` (StatePlugin)
- `cache` (CachePlugin)
- `mock` (MockPlugin)

### Issues
1.  **Inconsistency**: `ViewCommand` and `DiCommand` duplicate flag parsing (`--dry-run`, etc.) and error handling logic.
2.  **Rigidity**: Adding a new CLI capability requires modifying `zfa_cli.dart` switch-case logic.
3.  **Coupling**: `GeneratorConfig` is a monolithic object that all plugins depend on, even when running independently.

## Architectural Design

### 1. `CliPlugin` Interface
A mixin/interface for plugins that wish to expose a CLI command.

```dart
import 'package:args/command_runner.dart';

abstract class CliAwarePlugin {
  /// Creates the command instance for this plugin.
  Command createCommand();
}
```

### 2. Base `PluginCommand`
A standardized base class extending `Command` from `package:args/command_runner`.

```dart
abstract class PluginCommand extends Command {
  final ZuraffaPlugin plugin;

  PluginCommand(this.plugin) {
    // Standard flags for ALL plugins
    argParser.addOption('output', abbr: 'o', help: 'Output directory', defaultsTo: 'lib/src');
    argParser.addFlag('dry-run', negatable: false, help: 'Preview changes');
    argParser.addFlag('force', abbr: 'f', negatable: false, help: 'Overwrite files');
    argParser.addFlag('verbose', abbr: 'v', negatable: false, help: 'Detailed logging');
  }

  @override
  String get name => plugin.id;

  @override
  String get description => 'Run the ${plugin.name} generator';
  
  /// Helper to extract standard options
  bool get isDryRun => globalResults?['dry-run'] == true || argResults?['dry-run'] == true;
  bool get isForce => globalResults?['force'] == true || argResults?['force'] == true;
  bool get isVerbose => globalResults?['verbose'] == true || argResults?['verbose'] == true;
  String get outputDir => globalResults?['output'] ?? argResults?['output'] ?? 'lib/src';
}
```

### 3. Proposed Command Structure
All plugins will expose a consistent command structure:
`zfa <plugin-id> <SubjectName> [flags]`

| Plugin | Command | Arguments | Notes |
| :--- | :--- | :--- | :--- |
| **Route** | `zfa route <Entity>` | `--methods=get,create` | Generates routes for an entity |
| **View** | `zfa view <ViewName>` | `--presenter=...` | Migrated from existing `ViewCommand` |
| **DI** | `zfa di <UseCase>` | `--domain=...` | Migrated from existing `DiCommand` |
| **Presenter** | `zfa presenter <Entity>` | `--methods=...` | Generates presenter only |
| **Repo** | `zfa repository <Entity>` | `--datasource=...` | Generates repo & impl |
| **UseCase** | `zfa usecase <Entity>` | `--methods=...` | Generates usecases |
| **State** | `zfa state <Entity>` | | Generates state class |
| **Controller**| `zfa controller <Entity>`| | Generates controller |

### 4. Migration Strategy

#### Phase 1: Foundation (Current Step)
1.  Implement `CliAwarePlugin` interface.
2.  Implement `PluginCommand` base class.
3.  Refactor `zfa_cli.dart` to use `CommandRunner`.

#### Phase 2: Pilot Implementation
1.  Implement `RouteCommand` in `RoutePlugin`.
2.  Verify `zfa route` works independently.

#### Phase 3: Standardization
1.  Refactor `ViewCommand` to inherit from `PluginCommand` and attach to `ViewPlugin`.
2.  Refactor `DiCommand` to inherit from `PluginCommand` and attach to `DiPlugin`.
3.  Deprecate the old manual command classes.

#### Phase 4: Expansion
1.  Add commands for `presenter`, `controller`, `repository`, etc.

## Implementation Details

### `zfa_cli.dart` Refactoring
```dart
Future<void> run(List<String> args) async {
  final runner = CommandRunner('zfa', 'Zuraffa Code Generator')
    ..addCommand(GenerateCommand()) // Legacy/Macro command
    ..addCommand(InitCommand());

  // Dynamic Plugin Loading
  for (final plugin in PluginRegistry.instance.plugins) {
    if (plugin is CliAwarePlugin) {
      runner.addCommand(plugin.createCommand());
    }
  }

  await runner.run(args);
}
```

### `GeneratorConfig` Adaptation
Plugins often rely on `GeneratorConfig`. `PluginCommand` subclasses will be responsible for constructing a minimal valid `GeneratorConfig` from their specific CLI arguments to pass to the plugin's `generate` method.

```dart
// Inside RouteCommand
@override
Future<void> run() async {
  final name = argResults!.rest.first;
  final config = GeneratorConfig(
    name: name,
    generateRoute: true, // Force enable this plugin's flag
    // ... other mappings
  );
  await plugin.generate(config);
}
```
