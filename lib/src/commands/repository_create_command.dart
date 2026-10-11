import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../cli/exit_protocol.dart';
import '../core/plugin_system/capability.dart';
import '../core/plugin_system/capability_invocation_wrapper.dart';
import '../core/project/project_root.dart';
import '../core/verdict_envelope.dart';
import '../models/generated_file.dart';
import '../models/generator_config.dart';
import '../plugins/repository/capabilities/create_repository_capability.dart';
import '../plugins/repository/conformance/repository_conformance_checker.dart';
import '../plugins/repository/contract/repository_contract_manifest.dart';
import '../plugins/repository/plan/repository_emission_plan.dart';
import '../plugins/repository/repository_plugin.dart';

/// `zfa repository create` — the first-party create verb for the
/// repository plugin (SPEC 1124, issue #1124).
///
/// The generic [CapabilityCommand] used to serve this verb; its `--json`
/// is the JSON-INPUT option, so `zfa repository create Product --json`
/// could not even parse — the repository plugin had conformance gate,
/// contract manifests and `explainEmission`, but emitted NO envelope.
/// This command replaces the generic registration (the
/// `manualSubcommandNames` seam, same as `StateCreateCommand`) and adds
/// the machine channel:
///
///  * `--json` emits the canonical verdict envelope
///    (ZuraffaVerdictEnvelope.schema, issue #1105) as the LAST stdout line:
///    `{schema, command, verdict, exit_class, subject: {kind: repository,
///    entity}, findings[], manifest: {path, sha256, methods}, drifts[],
///    details, timestamp}`;
///  * a conformance-gate failure (spec 0973) under `--json` carries the
///    gate findings in `findings[]` and the expected/actual method sets
///    in `details` — the gate's SEMANTICS are untouched, only the output
///    channel gains a machine surface;
///  * without `--json` the existing human-readable output is unchanged;
///  * `--explain` resolves the SAME [RepositoryEmissionPlanner]
///    `RepositoryPlugin.explainEmission` serves to `zfa make --explain` —
///    the plan is a pure function of the resolved config, so the direct
///    entry point and the orchestrated make flow can never disagree about
///    what would be emitted (on the direct path the datasource plugin is
///    never active — the plugin emits the datasource interface itself,
///    #406);
///  * execution flows through [CapabilityInvocationWrapper] so the
///    standalone proof receipt (issue #996/#1130) keeps shipping exactly
///    as before.
class RepositoryCreateCommand extends Command<void> {
  final RepositoryPlugin plugin;

  /// Project root the receipt/manifest stores live under. Defaults to
  /// the resolved project root; tests inject a temp fixture.
  final String? projectRoot;

  /// The capability the generation flows through (injectable so tests
  /// can drive the gate-failure branch through the same exception the
  /// real gate throws).
  final ZuraffaCapability capability;

  RepositoryCreateCommand(
    this.plugin, {
    this.projectRoot,
    ZuraffaCapability? capability,
  }) : capability = capability ?? CreateRepositoryCapability(plugin) {
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
          '(get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: const ['get', 'update'],
    );
    argParser.addFlag(
      'data',
      help: 'Generate repository implementation',
      defaultsTo: true,
      negatable: true,
    );
    argParser.addFlag(
      'datasource',
      help: 'Generate data sources along with repository',
      defaultsTo: true,
      negatable: true,
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
          'Emit the canonical ${ZuraffaVerdictEnvelope.schema} envelope '
          'on stdout (SPEC 1124, issue #1105)',
    );
    argParser.addFlag(
      'explain',
      negatable: false,
      help:
          'Print the resolved emission plan (the explainEmission planner) '
          'without generating',
    );
  }

  @override
  String get name => 'create';

  @override
  String get description =>
      'Create a Repository Interface and Implementation '
      '(the direct `zfa repository create Product` entry point)';

  @override
  Future<void> run() async {
    final entityName = _resolveEntityName();
    final jsonMode = argResults?['json'] == true;
    final explainMode = argResults?['explain'] == true;

    if (entityName == null || entityName.isEmpty) {
      final fix = 'zfa repository create --name <Entity>';
      if (jsonMode) {
        ZuraffaVerdictEnvelope.emit(
          command: _commandLabel,
          status: VerdictStatus.fail,
          exitClass: ExitProtocol.usage,
          subject: null,
          findings: [
            {
              'side': 'invocation',
              'kind': 'missing_argument',
              'method': 'name',
              'message': 'Missing required arguments: name',
              'fix': fix,
            },
          ],
          details: const {
            'missing': ['name'],
          },
        );
        // The envelope carries the fix in findings[] and must remain the
        // LAST stdout line — no prose may follow it.
      } else {
        print('❌ Error: Missing required arguments: name');
        print('   --> fix: $fix');
      }
      exitCode = ExitProtocol.usage;
      return;
    }

    // ── --explain: the explainEmission planner, zero generation ────────
    // Mirrors [RepositoryPlugin.explainEmission]: configFromContext builds
    // the config the plugin WOULD run with and the planner resolves the
    // emission decisions. The direct path's context is null, so the
    // datasource plugin is never active here — when --datasource is
    // requested the repository plugin emits the interface itself (#406).
    if (explainMode) {
      final config = GeneratorConfig(
        name: entityName,
        outputDir: plugin.outputDir,
        generateRepository: true,
        generateData: argResults?['data'] != false,
        generateDataSource: argResults?['datasource'] != false,
        methods: _resolveMethods(),
        dryRun: true,
        force: argResults?['force'] == true,
        verbose: argResults?['verbose'] == true,
      );
      final plan = const RepositoryEmissionPlanner().resolve(
        config,
        datasourcePluginActive: false,
      );
      if (jsonMode) {
        print(jsonEncode(plan.toJson()));
      } else {
        print(plan.renderText());
      }
      exitCode = plan.valid ? ExitProtocol.success : ExitProtocol.failure;
      return;
    }

    // Dry run keeps the generic plan-report contract: the EffectReport is
    // the machine surface here (no files land, so there is no verdict to
    // give beyond the plan).
    if (argResults?['dry-run'] == true) {
      final report = await capability.plan({
        'name': entityName,
        'methods': _resolveMethods(),
        'dryRun': true,
        'force': argResults?['force'] == true,
        'verbose': argResults?['verbose'] == true,
      });
      print(jsonEncode(report.toJson()));
      return;
    }

    final args = <String, dynamic>{
      'name': entityName,
      'methods': _resolveMethods(),
      'data': argResults?['data'] != false,
      'datasource': argResults?['datasource'] != false,
      'dryRun': false,
      'force': argResults?['force'] == true,
      'verbose': argResults?['verbose'] == true,
    };

    final wrapper = CapabilityInvocationWrapper(
      capability: capability,
      pluginId: plugin.id,
      projectRoot: projectRoot ?? ProjectRoot.find(),
    );

    final ExecutionResult result;
    try {
      result = await wrapper.execute(args);
    } on RepositoryConformanceException catch (e) {
      if (!jsonMode) rethrow;
      // SPEC 1124 order 3: gate failures ride the envelope's findings[]
      // and the expected/actual methods ride details. The gate semantics
      // are unchanged — this is the output channel only.
      _emitGateFailureEnvelope(entityName, e.result);
      exitCode = ExitProtocol.failure;
      return;
    }

    if (!result.success) {
      final message = result.message ?? 'generation failed';
      if (jsonMode) {
        ZuraffaVerdictEnvelope.emit(
          command: _commandLabel,
          status: VerdictStatus.fail,
          exitClass: ExitProtocol.failure,
          subject: {'kind': 'repository', 'entity': entityName},
          findings: [
            {
              'side': 'generation',
              'kind': 'generation_failed',
              'message': message,
              'fix': 'zfa repository create --name $entityName --verbose',
            },
          ],
        );
      } else {
        print('❌ Failed: $message');
      }
      exitCode = ExitProtocol.failure;
      return;
    }

    final files = result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];

    // Issue #769 zero-files guard (same semantics as the generic
    // CapabilityCommand path: a generator that emits nothing is not a
    // success).
    if (files.isEmpty) {
      const note =
          'No files were generated (nothing changed). If the generator '
          'printed a skip note above, re-run inside a project that '
          'satisfies its guard; otherwise re-run with --verbose to '
          'inspect the resolved arguments.';
      if (jsonMode) {
        ZuraffaVerdictEnvelope.emit(
          command: _commandLabel,
          status: VerdictStatus.fail,
          exitClass: ExitProtocol.failure,
          subject: {'kind': 'repository', 'entity': entityName},
          findings: [
            {
              'side': 'generation',
              'kind': 'no_files',
              'message': note,
              'fix': 'zfa repository create --name $entityName --verbose',
            },
          ],
        );
      } else {
        print('⚠️ $note');
      }
      exitCode = ExitProtocol.failure;
      return;
    }

    // Human summary first — the envelope (when --json is on) is the LAST
    // stdout line, so automation reads exactly one JSON document. Without
    // --json the human channel ends here and nothing machine-shaped leaks.
    if (!jsonMode) {
      _printHumanSummary(files);
      return;
    }

    ZuraffaVerdictEnvelope.emit(
      command: _commandLabel,
      status: VerdictStatus.pass,
      exitClass: ExitProtocol.success,
      subject: {'kind': 'repository', 'entity': entityName},
      manifest: await _manifestBinding(entityName),
      details: {
        'files': files.map((f) => f.path).toList(),
        'created': files.where((f) => f.action == 'created').length,
        'overwritten': files.where((f) => f.action == 'overwritten').length,
        'skipped': files.where((f) => f.action == 'skipped').length,
      },
    );
  }

  String get _commandLabel => 'zfa ${plugin.id} create';

  /// Stable machine vocabulary for a conformance mismatch, classified
  /// from the side + failure shape the checker already reports (output-
  /// channel classification only — the gate itself is untouched).
  static String _findingKind(ConformanceFailure failure) {
    if (failure.side == 'interface') return 'override_without_declaration';
    if (failure.message.contains('missing @override')) {
      return 'missing_override';
    }
    if (failure.message.contains('no implementation')) {
      return 'missing_implementation';
    }
    return 'conformance_mismatch';
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
        .toList(growable: false);
  }

  /// SPEC 1124 order 3: the gate-failure envelope — gate findings ride
  /// `findings[]`, the expected/actual method sets ride `details`, and no
  /// `manifest` key is claimed (a failed gate writes no manifest).
  void _emitGateFailureEnvelope(String entityName, ConformanceResult result) {
    ZuraffaVerdictEnvelope.emit(
      command: _commandLabel,
      status: VerdictStatus.fail,
      exitClass: ExitProtocol.failure,
      subject: {'kind': 'repository', 'entity': entityName},
      findings: result.failures
          .map(
            (f) => {
              'side': f.side,
              'kind': _findingKind(f),
              'method': f.method,
              'message': f.message,
              'fix': f.fix,
            },
          )
          .toList(),
      details: {
        'expected_methods': result.interfaceMethods,
        'actual_methods': result.implementationOverrides,
        'interface_class': result.interfaceClass,
        'implementation_class': result.implementationClass,
      },
    );
  }

  /// The manifest binding for a passing run: `{path, sha256, methods}` of
  /// the contract manifest the gate just persisted (best-effort — the
  /// manifest write itself is best-effort by design, so a missing file
  /// omits the key instead of lying with a digest).
  Future<Map<String, Object?>?> _manifestBinding(String entityName) async {
    try {
      final root = repositoryProjectRootFor(
        plugin.outputDir,
        explicitProjectRoot: projectRoot,
      );
      final store = RepositoryContractManifestStore(projectRoot: root);
      final file = store.fileFor(entityName);
      if (!file.existsSync()) return null;
      final manifest = await store.loadForEntity(entityName);
      if (manifest == null) return null;
      return {
        'path': _projectRelativePosix(file.path, root),
        'sha256': crypto.sha256.convert(file.readAsBytesSync()).toString(),
        'methods': manifest.methodNames,
      };
    } catch (_) {
      // A manifest binding failure must never fail the run (the
      // artifacts exist) — the envelope just omits the key.
      return null;
    }
  }

  String _projectRelativePosix(String filePath, String root) {
    final absolute = p.isAbsolute(filePath)
        ? filePath
        : p.join(p.absolute(root), filePath);
    final relative = p.relative(absolute, from: p.absolute(root));
    return p.normalize(relative).replaceAll('\\', '/');
  }

  /// The existing human-readable summary (the generic CapabilityCommand
  /// prose, preserved verbatim when `--json` is absent).
  void _printHumanSummary(List<GeneratedFile> files) {
    final created = files.where((f) => f.action == 'created').toList();
    final overwritten = files.where((f) => f.action == 'overwritten').toList();
    final updated = files.where((f) => f.action == 'updated').toList();
    final skipped = files.where((f) => f.action == 'skipped').toList();
    final deleted = files.where((f) => f.action == 'deleted').toList();

    if (created.isNotEmpty ||
        overwritten.isNotEmpty ||
        updated.isNotEmpty ||
        deleted.isNotEmpty) {
      print('✅ Success! Created/Modified:');
      for (final file in created) {
        print('  ✨ ${file.path}');
      }
      for (final file in overwritten) {
        print('  📝 ${file.path}');
      }
      for (final file in updated) {
        print('  📝 ${file.path}');
      }
      for (final file in deleted) {
        print('  🗑 ${file.path}');
      }
    }

    if (skipped.isNotEmpty) {
      print('\n⏭ Skipped (use --force to overwrite):');
      for (final file in skipped) {
        print('  ${file.path}');
      }
    }
  }
}
