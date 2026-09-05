import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../core/context/file_system.dart';
import '../core/project/receipt_store.dart';
import '../models/generated_file.dart';
import '../models/generator_config.dart';
import '../plugins/state/state_plugin.dart';
import '../utils/project_flavor.dart';
import '../version.dart';

/// `zfa state create` — the state plugin's first-party create verb
/// (issue #976).
///
/// Replaces the generic [CapabilityCommand] auto-registration for the
/// `create` subcommand (wired through
/// [StateCommand.manualSubcommandNames]) so the verb can grow a real
/// verdict surface for automation:
///
///  * `--json` emits a single-line envelope
///    `{path, fields[], modes[], flavor, schema: 1}` as the LAST stdout
///    line (human output stays above it, so the default path is
///    unchanged);
///  * every real generation ships a `proof.v1` receipt at
///    `.zfa/receipts/state-<entity>.json` (via [ReceiptStore], stable
///    per-entity name, refreshed on regeneration) binding the final
///    on-disk bytes, so `zfa proof check` covers state artifacts;
///  * the emission is unchanged — the same [StatePlugin.generate] the
///    `zfa make --state` entry point drives (the drift gate under
///    test/plugins/state/ keeps both byte-identical).
///
/// The old generic `--json <input-json>` OPTION is intentionally
/// replaced by the `--json` FLAG: nothing in the repo consumed the
/// input form for state, and the issue pins the output form.
class StateCreateCommand extends Command<void> {
  final StatePlugin plugin;

  StateCreateCommand(this.plugin) {
    argParser.addOption(
      'name',
      abbr: 'n',
      help: 'Name of the entity (e.g. Product)',
    );
    argParser.addMultiOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods '
          '(get,create,update,delete,watch,getList,watchList)',
      defaultsTo: const ['get', 'update'],
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview changes without executing',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Force overwrite existing files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit the versioned state-create verdict envelope '
          '{path, fields[], modes[], flavor, schema:1} as the final '
          'stdout line (issue #976)',
    );
  }

  @override
  String get name => 'create';

  @override
  String get description =>
      'Create a State class (entity / orchestrator / custom emission)';

  @override
  Future<void> run() async {
    final entityName = _resolveEntityName();
    if (entityName == null || entityName.isEmpty) {
      print('❌ Error: Missing required arguments: name');
      print('Usage: zfa state create --name <Entity> [--methods get,update]');
      exitCode = 64;
      return;
    }

    final methods = _resolveMethods();
    final dryRun = argResults?['dry-run'] == true;
    final force = argResults?['force'] == true;
    final verbose = argResults?['verbose'] == true;
    final jsonMode = argResults?['json'] == true;

    final config = GeneratorConfig(
      name: entityName,
      outputDir: plugin.outputDir,
      generateState: true,
      methods: methods,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    final files = await plugin.generate(config);
    if (files.isEmpty) {
      // Issue #769 semantics: a generator that emits nothing must not
      // dress the outcome up as success.
      print(
        '⚠️ No files were generated (nothing changed). Re-run with '
        '--verbose to inspect the resolved arguments.',
      );
      exitCode = 1;
      return;
    }

    final file = files.single;
    final projectRoot = Directory.current.path;
    final relativePath = _projectRelativePosix(file.path, projectRoot);

    // Human summary first (the envelope is the last stdout line when
    // --json is on, so automation reads exactly one JSON document).
    switch (file.action) {
      case 'created':
        print('✅ Success! Created/Modified:');
        print('  ✨ ${file.path}');
      case 'overwritten':
        print('✅ Success! Created/Modified:');
        print('  📝 ${file.path}');
      case 'deleted':
        print('🗑 Deleted: ${file.path}');
      case 'skipped':
        print('⏭ Skipped (use --force to overwrite):');
        print('  ${file.path}');
      default:
        print('${file.action}: ${file.path}');
    }
    if (dryRun && file.action != 'skipped') {
      print('ℹ️  Dry run: nothing written.');
    }

    // Receipt: only for bytes that actually landed (created/overwritten,
    // not dry-run, not skipped — a skipped file's provenance stays with
    // the run that wrote it; binding old bytes to this run's input would
    // be a lie). Best-effort by design, matching entity create (#807).
    if (!dryRun && (file.action == 'created' || file.action == 'overwritten')) {
      await _emitReceipt(
        entityName: entityName,
        methods: methods,
        force: force,
        file: file,
        relativePath: relativePath,
      );
    }

    if (jsonMode) {
      final flavor = await detectProjectFlavor(
        plugin.outputDir,
        FileSystem.create(),
      );
      print(
        jsonEncode(
          StateCreateVerdict(
            path: relativePath,
            fields: _fieldNamesOf(file),
            modes: [_emissionModeOf(config)],
            flavor: flavor.name,
          ).toJson(),
        ),
      );
    }
  }

  String? _resolveEntityName() {
    final viaOption = argResults?['name'] as String?;
    if (viaOption != null && viaOption.isNotEmpty) return viaOption;
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isNotEmpty) return rest.first;
    return null;
  }

  List<String> _resolveMethods() {
    final raw =
        argResults?['methods'] as List<String>? ??
        const <String>['get', 'update'];
    return raw
        .expand((entry) => entry.split(','))
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();
  }

  /// Field names parsed from the EMITTED constructor's `this.<field>`
  /// tokens, in declaration order — the envelope reports what the bytes
  /// actually carry, so it cannot drift from the emission the way a
  /// re-derived field list would.
  List<String> _fieldNamesOf(GeneratedFile file) {
    final content = file.content;
    if (content == null) return const [];
    final ctor = RegExp(
      r'const\s+\w+\(\{([^}]*)\}\);',
      dotAll: true,
    ).firstMatch(content);
    if (ctor == null) return const [];
    return RegExp(r'this\.([A-Za-z_]\w*)')
        .allMatches(ctor.group(1)!)
        .map((m) => m.group(1)!)
        .toList(growable: false);
  }

  /// The emission mode the builder branched into, reported as a
  /// single-element list (the envelope's `modes[]` is a list so future
  /// multi-mode composites stay shape-compatible).
  String _emissionModeOf(GeneratorConfig config) {
    if (config.isOrchestrator) return 'orchestrator';
    if (config.isCustomUseCase) return 'custom';
    return 'entity';
  }

  Future<void> _emitReceipt({
    required String entityName,
    required List<String> methods,
    required bool force,
    required GeneratedFile file,
    required String relativePath,
  }) async {
    try {
      final artifact = File(file.path);
      if (!artifact.existsSync()) return;
      final bytes = artifact.readAsBytesSync();
      await ReceiptStore(projectRoot: Directory.current.path).save(
        GenerationReceipt(
          command: 'state create',
          target: entityName,
          repro: _reproCommand(entityName, methods, force),
          at: DateTime.now().toUtc(),
          generatorVersion: version,
          input: {
            'name': entityName,
            'methods': methods,
            if (force) 'force': true,
          },
          files: [
            GenerationReceiptFile(
              path: relativePath,
              action: file.action == 'overwritten' ? 'modify' : 'create',
              sha256: crypto.sha256.convert(bytes).toString(),
              bytes: bytes.length,
              snapshot: bytes.length <= ReceiptStore.maxSnapshotBytes
                  ? artifact.readAsStringSync()
                  : null,
            ),
          ],
        ),
        fileName: 'state-$entityName.json',
      );
    } catch (e) {
      // Provenance is best-effort at this layer (the artifact already
      // exists); loud warning, never a failed generation.
      print('⚠️  Generation receipt not written: $e');
    }
  }

  String _reproCommand(String entityName, List<String> methods, bool force) {
    final buffer = StringBuffer('zfa state create --name $entityName');
    if (methods.isNotEmpty) {
      buffer.write(' --methods ${methods.join(',')}');
    }
    if (force) buffer.write(' --force');
    return buffer.toString();
  }

  String _projectRelativePosix(String path, String projectRoot) {
    final rel = p.isAbsolute(path)
        ? p.relative(path, from: projectRoot)
        : p.normalize(path);
    return rel.replaceAll('\\', '/');
  }
}

/// The `zfa state create --json` verdict envelope (issue #976).
///
/// Contract (schema 1 — integer, stable key agents can switch on):
///  * `path`     — project-relative POSIX path of the state artifact;
///  * `fields`   — the emitted state's field names, declaration order;
///  * `modes`    — emission mode list (`entity` | `orchestrator` |
///                 `custom`);
///  * `flavor`   — target-project flavor the import follows (#512):
///                 `flutter` | `pureDart` | `unknown`;
///  * `schema`   — this envelope's version.
class StateCreateVerdict {
  static const int schemaVersion = 1;

  final String path;
  final List<String> fields;
  final List<String> modes;
  final String flavor;

  const StateCreateVerdict({
    required this.path,
    required this.fields,
    required this.modes,
    required this.flavor,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'fields': fields,
    'modes': modes,
    'flavor': flavor,
    'schema': schemaVersion,
  };
}
