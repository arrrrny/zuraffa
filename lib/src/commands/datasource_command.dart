import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../version.dart';
import '../core/project/receipt_store.dart';
import '../models/generated_file.dart';
import '../utils/string_utils.dart';
import 'base_plugin_command.dart';
import 'datasource_check_command.dart';
import '../plugins/datasource/datasource_plugin.dart';
import '../plugins/datasource/capabilities/create_datasource_capability.dart';

class DataSourceCommand extends PluginCommand {
  @override
  final DataSourcePlugin plugin;

  /// The parent-level options run() actually reads (spec #979): unlike
  /// the #856-family commands, this command's run() consumes its parent
  /// flags on the (programmatically reachable) positional path — so they
  /// are LIVE and `zfa manifest --verify` certifies them through this
  /// declaration instead of flagging them dead.
  @override
  Set<String> get consumedParentFlags => const {
    'methods',
    'local',
    'remote',
    'cache',
    'init',
  };

  DataSourceCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: 'get,update',
    );
    // Spec #977: the capability input schema is canonical — CLI flag
    // defaults DERIVE from it so a flag has exactly one truth. The
    // parity is regression-tested (datasource_default_parity_test.dart).
    argParser.addFlag(
      'local',
      help: 'Generate local data source (and Hive/DB integration)',
      defaultsTo: _schemaBoolDefault(_createCapability.inputSchema, 'local'),
    );
    argParser.addFlag(
      'remote',
      help: 'Generate remote data source (and API integration)',
      defaultsTo: _schemaBoolDefault(_createCapability.inputSchema, 'remote'),
    );
    argParser.addFlag(
      'cache',
      help: 'Enable caching',
      defaultsTo: _schemaBoolDefault(_createCapability.inputSchema, 'cache'),
    );
    argParser.addFlag(
      'init',
      abbr: 'i',
      help: 'Generate initialization and disposal methods',
      defaultsTo: false,
      negatable: false,
    );

    // Spec #977: parity gate verb (`zfa datasource check <Entity>`).
    // Registered manually — it is not a capability subcommand.
    addSubcommand(DataSourceCheckCommand());
  }

  CreateDataSourceCapability get _createCapability =>
      plugin.capabilities.firstWhere((c) => c is CreateDataSourceCapability)
          as CreateDataSourceCapability;

  static bool _schemaBoolDefault(Map<String, dynamic> schema, String key) {
    final properties = schema['properties'];
    if (properties is! Map<String, dynamic>) return false;
    final property = properties[key];
    if (property is! Map<String, dynamic>) return false;
    final value = property['default'];
    return value is bool ? value : false;
  }

  @override
  String get name => 'datasource';

  @override
  String get description => 'Generate DataSources';

  @override
  Future<void> run() async {
    if (argResults?.command != null) {
      return super.run();
    }

    if (argResults?.rest.isEmpty ?? true) {
      reportSubcommandUsage();
      return;
    }

    final entityName = argResults!.rest.first;
    final generateLocal = argResults?['local'] as bool? ?? false;
    final generateRemote = argResults?['remote'] as bool? ?? true;
    final enableCache = argResults?['cache'] as bool? ?? false;

    final result = await _createCapability.execute({
      'name': entityName,
      'local': generateLocal,
      'remote': generateRemote,
      'cache': enableCache,
      'init': argResults?['init'] == true,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (!result.success) {
      // Spec #977: the failure branch is honest — the reason is printed
      // with a `--> fix:` line and the process exits 1, never 0.
      print('❌ Failed to generate datasource for `$entityName`.');
      final reason = result.message;
      if (reason != null) {
        print('   Reason: $reason');
      }
      print(
        '--> fix: address the reason above and re-run '
        '`zfa datasource create $entityName`.',
      );
      exitCode = 1;
      return;
    }

    final files = result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];

    if (files.isEmpty && !isDryRun) {
      // #769 zero-files guard, mirrored onto the standalone path: zero
      // emitted files means the request produced nothing — that is not a
      // success, and automation must not read it as one.
      print(
        '⚠️ No files were generated (nothing changed). Re-run with '
        '--verbose to inspect the resolved arguments.',
      );
      exitCode = 1;
      return;
    }

    logSummary(files);

    if (!isDryRun && files.isNotEmpty) {
      await _emitReceipt(entityName, files, result);
    }
  }

  /// Spec #977: ship the standalone generation with its own proof.v1
  /// receipt (`.zfa/receipts/datasource-<entity>.json`) binding the
  /// emitted artifacts' digests and the id-field / query-field
  /// resolution the run consumed (#294 audit trail).
  ///
  /// Best-effort by design, mirroring the entity path: the artifacts
  /// already exist, so a receipt failure degrades to a warning.
  Future<void> _emitReceipt(
    String entityName,
    List<GeneratedFile> files,
    result,
  ) async {
    try {
      final receiptFiles = <GenerationReceiptFile>[];
      for (final file in files) {
        final artifact = File(file.path);
        if (!artifact.existsSync()) continue;
        final bytes = artifact.readAsBytesSync();
        final keepSnapshot = bytes.length <= ReceiptStore.maxSnapshotBytes;
        receiptFiles.add(
          GenerationReceiptFile(
            path: _projectRelativePosix(file.path),
            action: file.action,
            sha256: crypto.sha256.convert(bytes).toString(),
            bytes: bytes.length,
            snapshot: keepSnapshot ? artifact.readAsStringSync() : null,
          ),
        );
      }
      if (receiptFiles.isEmpty) return;

      final snake = StringUtils.camelToSnake(entityName);
      final resolvedInput =
          result.data?['input'] as Map<String, dynamic>? ?? const {};

      await ReceiptStore(projectRoot: Directory.current.path).save(
        GenerationReceipt(
          command: 'datasource create',
          target: entityName,
          repro: 'zfa datasource create $entityName',
          at: DateTime.now().toUtc(),
          generatorVersion: version,
          input: resolvedInput,
          files: receiptFiles,
        ),
        fileName: 'datasource-$snake.json',
      );
    } catch (e) {
      print('⚠️  Generation receipt not written: $e');
    }
  }

  /// Normalizes a possibly-relative file path to a project-relative POSIX
  /// path so receipts stay portable across machines.
  String _projectRelativePosix(String filePath) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: Directory.current.path)
        : filePath;
    return p.normalize(rel).replaceAll('\\', '/');
  }
}
