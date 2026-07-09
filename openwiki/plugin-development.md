# Plugin Development

Zuraffa's plugin system lets you add custom code generation targets. This guide covers the plugin API, lifecycle, and development patterns.

## Architecture

Every plugin implements either `ZuraffaPlugin` (for non-file concerns) or `FileGeneratorPlugin` (for file generation).

```
ZuraffaPlugin                        # Base: lifecycle hooks, capabilities
  └── FileGeneratorPlugin            # Adds generate() / generateWithContext()
```

**Core system**: `lib/src/core/plugin_system/`
**Built-in plugins**: `lib/src/plugins/` (21 plugins)

## Plugin Interface

### `ZuraffaPlugin` (`lib/src/core/plugin_system/plugin_interface.dart`)

```dart
abstract class ZuraffaPlugin {
  String get id;                          // Unique identifier (e.g., 'my-plugin')
  String get name;                        // Human-readable name
  String get version;                     // Semantic version

  List<String> get dependsOn => [];       // Hard dependencies (must be active)
  List<String> get runAfter => [];        // Soft ordering
  Map<String, dynamic> get configSchema => {};  // JSON Schema for CLI arg generation

  Future<ValidationResult> validate(PluginContext context);
  Future<void> beforeGenerate(PluginContext context);
  Future<void> afterGenerate(PluginContext context);
  Future<void> onError(PluginContext context, Object error, StackTrace stackTrace);

  List<ZuraffaCapability> get capabilities => [];
}
```

### `FileGeneratorPlugin` (`lib/src/core/plugin_system/plugin_interface.dart`)

```dart
abstract class FileGeneratorPlugin extends ZuraffaPlugin {
  Future<List<GeneratedFile>> generateWithContext(PluginContext context);
  // Legacy bridge (default implementation calls generateWithContext):
  Future<List<GeneratedFile>> generate(GeneratorConfig config);
}
```

## Lifecycle (in execution order)

1. **`validate(context)`** — Check configuration. Return `ValidationResult.success()` or `ValidationResult.failure(reasons)`.
2. **`beforeGenerate(context)`** — Pre-generation setup (e.g., create directories).
3. **`generateWithContext(context)`** / **`generate(config)`** — Main file generation.
4. **`afterGenerate(context)`** — Post-generation (e.g., formatting, cleanup).
5. **`onError(context, error, stack)`** — Error recovery.

## PluginContext

The `PluginContext` (`lib/src/core/plugin_system/plugin_context.dart`) carries all runtime data:

| Component | Type | Access |
|---|---|---|
| `core` | `CoreConfig` | Plugin name, project root, output dir, flags (dryRun, force, verbose) |
| `data` | `Map<String, dynamic>` | Plugin-specific options from CLI args (validated against `configSchema`) |
| `sharedData` | `Map<String, dynamic>` | Data shared between plugins (files created by one plugin discovered by another) |
| `discovery` | `DiscoveryEngine` | Finds existing project files using glob patterns |
| `fileSystem` | `FileSystem` | Abstracted file I/O (wraps transactional writes) |

## Capability System

Fine-grained execution model for AI/CLI interrogation (`lib/src/core/plugin_system/capability.dart`):

```dart
abstract class ZuraffaCapability {
  String get name;              // e.g. "create_usecase"
  String get description;       // Prompt for AI/CLI
  Map get inputSchema;          // JSON Schema for input
  Map get outputSchema;         // JSON Schema for output

  Future<EffectReport> plan(Map<String, dynamic> args);        // Preview
  Future<ExecutionResult> execute(Map<String, dynamic> args);  // Execute
}
```

- **`EffectReport`** — Describes all effects before execution (enables `--plan`/`--explain`)
- **`ExecutionResult`** — Success/failure with list of modified files

## Development Checklist

1. Create a new file in `lib/src/plugins/<your_plugin>/`
2. Extend `FileGeneratorPlugin` (or `ZuraffaPlugin` directly)
3. Implement `id`, `name`, `version`
4. Override `validate()` for config checks
5. Return `List<GeneratedFile>` from `generateWithContext()`
6. Respect `dryRun`, `force`, `verbose` flags from `context.core`
7. Use `FileUtils.writeFile()` from `lib/src/utils/file_utils.dart` to write outputs
8. For AST insertion (append mode), use `AppendExecutor` with `AppendRequest`
9. Use `code_builder` + `SpecLibrary` for structured Dart code generation
10. Add tests under `test/plugins/`

## File Generation

Use `FileUtils.writeFile()` for all file writes:

```dart
import '../utils/file_utils.dart';

Future<GeneratedFile> writeMyFile(
  String outputDir,
  String name,
  String content,
) async {
  final filePath = FileUtils.writeFile(
    baseDir: outputDir,
    subDir: 'my_plugin',
    fileName: '${name.snakeCase()}_helper.dart',
    content: content,
  );
  return GeneratedFile(
    path: filePath,
    type: 'helper',
    action: 'created',
    content: content,
  );
}
```

**Source**: `lib/src/utils/file_utils.dart`

## AST Append Mode

For adding methods to existing classes without overwriting user edits:

```dart
final executor = AppendExecutor();
final result = executor.execute(
  AppendRequest.method(
    targetFile: existingFilePath,
    methodName: 'newMethod',
    returnType: 'void',
    params: 'String param1, int param2',
    body: '''
  print(param1);
  print(param2);
''',
  ),
);
```

Use this in plugins when `--append` flag is set. The `method_append` plugin (`lib/src/plugins/method_append/`) handles this for generated code.

## Plugin Dependencies

Control execution ordering:

```dart
@override
List<String> get dependsOn => ['usecase'];    // Plugin won't run without usecase plugin
List<String> get runAfter => ['repository'];   // Runs after repository if present
```

The `PluginRegistry` performs topological sort with cycle detection.

## Capability CLI Commands

Implement `CliAwarePlugin` mixin (`lib/src/core/plugin_system/cli_aware_plugin.dart`) to expose your plugin as a CLI subcommand:

```dart
class MyPlugin extends FileGeneratorPlugin with CliAwarePlugin {
  @override
  Command createCommand() => MyPluginCommand(this);
}
```

The command is automatically registered with the CLI runner.

## Testing

Recommended test structure for plugins:

```dart
test('generates expected output', () async {
  // 1. Create temp workspace
  final workspace = Directory.systemTemp.createTemp('test_plugin_');
  
  // 2. Instantiate plugin
  final plugin = MyPlugin(outputDir: workspace.path, options: ...);
  
  // 3. Generate
  final files = await plugin.generate(GeneratorConfig(
    name: 'Product',
    methods: ['get'],
    ...
  ));
  
  // 4. Assert file exists
  expect(File('${workspace.path}/my_plugin/product_helper.dart').existsSync(), isTrue);
  
  // 5. Assert content
  final content = File('${workspace.path}/my_plugin/product_helper.dart').readAsStringSync();
  expect(content, contains('class ProductHelper'));
  
  // 6. Cleanup
  workspace.deleteSync(recursive: true);
});
```

## Examples

- **Minimal plugin**: `example/custom_plugin/minimal_plugin_example.dart`
- **Advanced plugin**: `example/custom_plugin/advanced_plugin_example.dart` (uses `code_builder`, `SpecLibrary`)

## Key Source Files

| File | Purpose |
|---|---|
| `lib/src/core/plugin_system/plugin_interface.dart` | `ZuraffaPlugin`, `FileGeneratorPlugin` base classes |
| `lib/src/core/plugin_system/plugin_lifecycle.dart` | `PluginLifecycleStage`, `ValidationResult` |
| `lib/src/core/plugin_system/plugin_registry.dart` | Plugin registration, sorting, lifecycle orchestration |
| `lib/src/core/plugin_system/plugin_manager.dart` | Plan resolution, context building, execution |
| `lib/src/core/plugin_system/plugin_context.dart` | `PluginContext`, `CoreConfig` |
| `lib/src/core/plugin_system/capability.dart` | `ZuraffaCapability`, `Effect`, `EffectReport`, `ExecutionResult` |
| `lib/src/core/plugin_system/plan_store.dart` | Persisted plan for revert |
| `lib/src/utils/file_utils.dart` | File writing utilities |
| `lib/src/models/generated_file.dart` | `GeneratedFile` model |
| `doc/PLUGIN_API_REFERENCE.md` | API reference |
| `doc/PLUGIN_DEVELOPMENT.md` | Development guide |
