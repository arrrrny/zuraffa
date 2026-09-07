import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../core/context/file_system.dart';
import '../core/plugin_system/capability_invocation_wrapper.dart';
import '../core/project/receipt_store.dart';
import '../core/verdict_envelope.dart';
import '../models/generated_file.dart';
import '../models/generator_config.dart';
import '../plugins/state/state_explainer.dart';
import '../plugins/state/state_plugin.dart';
import '../plugins/state/state_receipt.dart';
import '../utils/project_flavor.dart';
import '../utils/string_utils.dart';
import '../version.dart';
import '../cli/exit_protocol.dart';

/// `zfa state create` — the state plugin's first-party create verb
/// (issue #976).
///
/// Replaces the generic [CapabilityCommand] auto-registration for the
/// `create` subcommand (wired through
/// [StateCommand.manualSubcommandNames]) so the verb can grow a real
/// verdict surface for automation:
///
///  * `--json` emits a single-line canonical verdict envelope
///    (`zuraffa.verdict.v1`, SPEC 1105 — the state surface: path, fields[],
///    modes[], flavor — lives in `details`) as the LAST stdout
///    line (human output stays above it, so the default path is
///    unchanged);
///  * every real generation ships a `proof.v1` receipt at
///    `.zfa/receipts/state-<entity>.json` (via [ReceiptStore], stable
///    per-entity name, refreshed on regeneration) binding the final
///    on-disk bytes, so `zfa proof check` covers state artifacts;
///  * `--explain` describes the plan WITHOUT generating: which state
///    members are generated, which derivation methods are included
///    (each method generates a state member), and which state class
///    name is output (spec 1126 order 3);
///  * the config vocabulary (`--methods`, `--no-entity`, `--domain`)
///    validates against the plugin configSchema before anything runs
///    (spec 1126 order 4 — unknown keys are a usage refusal);
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
      'no-entity',
      negatable: false,
      help:
          'Emit entity-free state (no entity field; custom mode). '
          'Implies an empty default methodset (spec 1126)',
    );
    argParser.addOption(
      'domain',
      help:
          'Domain folder the state file is emitted under '
          '(defaults to the entity snake name)',
    );
    argParser.addFlag(
      'explain',
      negatable: false,
      help:
          'Describe the plan — state class, output file, generated '
          'members, the method → state-member derivation — without '
          'generating (spec 1126)',
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
          'Emit the canonical zuraffa.verdict.v1 state-create verdict '
          'envelope (state surface in details: path, fields[], modes[], '
          'flavor) as the final stdout line (issue #976, SPEC 1105)',
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
      exitCode = ExitProtocol.usage;
      return;
    }

    final dryRun = argResults?['dry-run'] == true;
    final force = argResults?['force'] == true;
    final verbose = argResults?['verbose'] == true;
    final jsonMode = argResults?['json'] == true;
    final explainMode = argResults?['explain'] == true;
    final noEntity = argResults?['no-entity'] == true;
    final domain = argResults?['domain'] as String?;
    final methods = _resolveMethods(noEntity: noEntity);

    // Spec 1126 (order 4): the config gate — the resolved config
    // vocabulary validates against the plugin schema before anything
    // runs. Unknown keys / type mismatches are a usage refusal.
    final configViolations = validateStateConfig({
      if (argResults?.wasParsed('methods') == true || methods.isNotEmpty)
        'methods': methods,
      if (noEntity) 'no-entity': true,
      if (domain != null && domain.isNotEmpty) 'domain': domain,
    });
    if (configViolations.isNotEmpty) {
      final fix =
          'pass only the declared state config keys '
          '(methods, no-entity, domain) with matching types';
      if (jsonMode) {
        print(
          VerdictEnvelope(
            command: 'zfa state create --name $entityName',
            verdict: VerdictKind.fail,
            exitClass: ExitProtocol.usage,
            subject: VerdictSubject(kind: 'state', id: entityName),
            details: {
              'error':
                  'state config rejected: '
                  '${configViolations.join('; ')}',
            },
            fix: fix,
          ).toJsonLine(),
        );
      } else {
        print('❌ Error: state config rejected:');
        for (final violation in configViolations) {
          print('  - $violation');
        }
      }
      print(ExitProtocol.fixLine(fix));
      exitCode = ExitProtocol.usage;
      return;
    }

    final config = GeneratorConfig(
      name: entityName,
      outputDir: plugin.outputDir,
      generateState: true,
      methods: methods,
      noEntity: noEntity,
      domain: domain,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    // ── Explain: describe, never generate (spec 1126 order 3). ──
    if (explainMode) {
      final plan = const StateExplainer().explain(config: config);
      if (jsonMode) {
        print(
          VerdictEnvelope(
            command: 'zfa state create --name $entityName',
            verdict: VerdictKind.skip,
            exitClass: ExitProtocol.success,
            subject: VerdictSubject(kind: 'state', id: entityName),
            details: {'stateClass': plan['stateClass']},
            explain: plan,
          ).toJsonLine(),
        );
      } else {
        print(const StateExplainer().format(plan));
      }
      exitCode = ExitProtocol.success;
      return;
    }

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

    // Receipts: only for bytes that actually landed (created/overwritten,
    // not dry-run, not skipped — a skipped file's provenance stays with
    // the run that wrote it; binding old bytes to this run's input would
    // be a lie). Best-effort by design, matching entity create (#807).
    // Spec 1126: BOTH receipts ship — the stable per-entity document
    // (state-<entity>.json, the verify gate's contract) and the
    // timestamped capability receipt (#1138, the generation history).
    List<String> receiptPaths = const <String>[];
    if (!dryRun && (file.action == 'created' || file.action == 'overwritten')) {
      receiptPaths = await _emitReceipt(
        entityName: entityName,
        methods: methods,
        noEntity: noEntity,
        domain: domain,
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
      VerdictEnvelope.emit(
        VerdictEnvelope(
          command: 'zfa state create --name $entityName',
          verdict: VerdictKind.pass,
          exitClass: ExitProtocol.success,
          subject: VerdictSubject(kind: 'state', id: entityName),
          artifacts: VerdictArtifacts(
            created: file.action == 'created'
                ? [relativePath]
                : const <String>[],
            modified: file.action == 'created'
                ? const <String>[]
                : [relativePath],
            deleted: file.action == 'deleted' ? [relativePath] : const [],
          ),
          receipts: receiptPaths,
          details: {
            'path': relativePath,
            'fields': _fieldNamesOf(file),
            'modes': [_emissionModeOf(config)],
            'flavor': flavor.name,
          },
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

  List<String> _resolveMethods({required bool noEntity}) {
    final wasParsed = argResults?.wasParsed('methods') == true;
    // The generateWithContext defaulting: an explicit --methods wins;
    // otherwise a no-entity run wires no CRUD methods (custom mode).
    if (!wasParsed && noEntity) return const <String>[];
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

  /// Writes BOTH receipts; returns the project-relative receipt paths
  /// (stable per-entity first — the verify gate's contract — then the
  /// timestamped capability receipt; empty when nothing was written —
  /// the envelope's `receipts` list only lists receipts that exist).
  Future<List<String>> _emitReceipt({
    required String entityName,
    required List<String> methods,
    required bool noEntity,
    required String? domain,
    required bool force,
    required GeneratedFile file,
    required String relativePath,
  }) async {
    final paths = <String>[];
    final root = Directory.current.path;
    try {
      final artifact = File(file.path);
      if (!artifact.existsSync()) return paths;
      final bytes = artifact.readAsBytesSync();
      final receiptFiles = [
        GenerationReceiptFile(
          path: relativePath,
          action: file.action == 'overwritten' ? 'modify' : 'create',
          sha256: crypto.sha256.convert(bytes).toString(),
          bytes: bytes.length,
          snapshot: bytes.length <= ReceiptStore.maxSnapshotBytes
              ? artifact.readAsStringSync()
              : null,
        ),
      ];

      // Spec 1126 (order 2): the STABLE per-entity document — the
      // proof.v1 digests plus the ledger the verify gate audits
      // (state_sha256, entity_source, state_class, methods).
      final stableWritten = await StateReceiptWriter().write(
        projectRoot: root,
        outputDir: plugin.outputDir,
        entity: entityName,
        files: [file],
        stateClass: '${StringUtils.convertToPascalCase(entityName)}State',
        methods: methods,
        input: {
          'name': entityName,
          'methods': methods,
          if (noEntity) 'no-entity': true,
          if (domain != null && domain.isNotEmpty) 'domain': domain,
          if (force) 'force': true,
        },
        repro: _reproCommand(entityName, methods, noEntity, domain, force),
      );
      paths.add(_projectRelativePosix(stableWritten.path, root));

      // Issue #1138: full capability provenance on the standalone
      // timestamped receipt — same schema and hash derivation as the
      // wrapper's receipts, keyed
      // state-create-<entity>-<timestamp>.json like every other
      // standalone capability receipt.
      final written = await ReceiptStore(projectRoot: root).saveCapability(
        GenerationReceipt(
          command: 'state create',
          target: entityName,
          repro: _reproCommand(entityName, methods, noEntity, domain, force),
          at: DateTime.now().toUtc(),
          generatorVersion: version,
          input: {
            'name': entityName,
            'methods': methods,
            if (noEntity) 'no-entity': true,
            if (domain != null && domain.isNotEmpty) 'domain': domain,
            if (force) 'force': true,
          },
          files: receiptFiles,
          plugin: 'state',
          capability: 'create',
          entity: entityName,
          methodset: methods,
          runHash: CapabilityInvocationWrapper.computeRunHash(
            files: receiptFiles,
            entity: entityName,
            methodset: methods,
          ),
          receiptVersion: CapabilityInvocationWrapper.receiptVersion,
        ),
      );
      paths.add(_projectRelativePosix(written.path, root));
    } catch (e) {
      // Provenance is best-effort at this layer (the artifact already
      // exists); loud warning, never a failed generation.
      print('⚠️  Generation receipt not written: $e');
      return paths;
    }
    return paths;
  }

  String _reproCommand(
    String entityName,
    List<String> methods,
    bool noEntity,
    String? domain,
    bool force,
  ) {
    final buffer = StringBuffer('zfa state create --name $entityName');
    if (methods.isNotEmpty) {
      buffer.write(' --methods ${methods.join(",")}');
    }
    if (noEntity) buffer.write(' --no-entity');
    if (domain != null && domain.isNotEmpty) {
      buffer.write(' --domain $domain');
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
