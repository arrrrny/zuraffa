import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/sqlite/sqlite_plugin.dart';
import '../plugins/sqlite/capabilities/create_sqlite_adapter_capability.dart';

/// `zfa sqlite [adapter] <Entity>` — generates a SQLite-backed DataSource.
///
/// Both spellings work: the issue's `zfa sqlite adapter Task` and the
/// terser `zfa sqlite Task` (a leading `adapter` positional is skipped).
class SqliteCommand extends PluginCommand {
  @override
  final SqlitePlugin plugin;

  SqliteCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods '
          '(get,getList,list,create,update,toggle,delete,watch,watchList,initialize)',
      defaultsTo: 'get,getList,create,update,delete',
    );
  }

  @override
  String get name => 'sqlite';

  @override
  String get description =>
      'Generate a SQLite-backed DataSource for an entity (adapter)';

  @override
  Future<void> run() async {
    if (argResults?.command != null) {
      return super.run();
    }

    var rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      print('❌ Usage: zfa sqlite [adapter] <EntityName> [options]');
      return;
    }
    // Tolerate the issue's `zfa sqlite adapter <Entity>` spelling.
    if (rest.first == 'adapter' && rest.length > 1) {
      rest = rest.sublist(1);
    }
    final entityName = rest.first;

    final methodsStr = argResults?['methods'] as String?;
    final methods = methodsStr == null || methodsStr.trim().isEmpty
        ? const <String>[]
        : methodsStr
              .split(',')
              .map((m) => m.trim())
              .where((m) => m.isNotEmpty)
              .toList();

    final capability =
        plugin.capabilities.firstWhere(
              (c) => c is CreateSqliteAdapterCapability,
            )
            as CreateSqliteAdapterCapability;

    final result = await capability.execute({
      'name': entityName,
      'methods': methods,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
      print(
        '\n💡 Add the sqlite3 dependency to pubspec.yaml to use the adapter:\n'
        '   dart pub add sqlite3'
        '\n   (Flutter apps also need sqlite3_flutter_libs)',
      );
      print(
        '\n   The generated class takes an open Database:\n'
        '   final ds = ${entityName}SqliteDataSource(\n'
        '     sqlite3.openInMemory(), // or sqlite3.open(dbPath)\n'
        '   );',
      );
    } else {
      print('❌ ${result.message}');
    }
  }
}
