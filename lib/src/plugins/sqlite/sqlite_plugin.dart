import 'package:args/command_runner.dart';

import '../../commands/sqlite_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/sqlite_datasource_builder.dart';
import 'capabilities/create_sqlite_adapter_capability.dart';

/// SQLite data source generation (issue #464).
///
/// Complements the Hive cache plugin with a production SQLite store for
/// server / Dart-VM projects: `zfa sqlite adapter <Entity>` generates an
/// `<Entity>SqliteDataSource` implementing the entity's DataSource
/// interface on top of `package:sqlite3` (WAL journaling, schema_version
/// marker, id-keyed SQL writes, mock-compatible read semantics).
///
/// Example:
/// ```dart
/// final plugin = SqlitePlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Task'));
/// ```
class SqlitePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final SqliteDataSourceBuilder builder;

  SqlitePlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    builder = SqliteDataSourceBuilder(outputDir: outputDir, options: options);
  }

  @override
  List<ZuraffaCapability> get capabilities => [
    CreateSqliteAdapterCapability(this),
  ];

  @override
  Command createCommand() => SqliteCommand(this);

  @override
  String get id => 'sqlite';

  @override
  String get name => 'SQLite Plugin';

  @override
  String get version => '1.0.0';

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'default': ['get', 'getList', 'create', 'update', 'delete'],
      },
    },
  };

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      methods:
          context.data['methods']?.cast<String>().toList() ??
          const ['get', 'getList', 'create', 'update', 'delete'],
      idField: context.data['id-field'] ?? 'id',
      idFieldType: context.data['id-field-type'] ?? 'String',
    );

    return generate(config);
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    return builder.generate(config);
  }
}
