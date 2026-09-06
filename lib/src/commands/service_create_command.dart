import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../cli/exit_protocol.dart';
import '../core/plugin_system/capability_invocation_wrapper.dart';
import '../core/plugin_system/plan_store.dart';
import '../core/verdict_envelope.dart';
import '../models/generator_config.dart';
import '../models/generated_file.dart';
import '../plugins/service/capabilities/create_service_capability.dart';
import '../plugins/service/builders/service_interface_builder.dart';
import '../plugins/service/conformance/service_conformance_checker.dart';
import '../plugins/service/service_plugin.dart';
import '../utils/string_utils.dart';

/// SPEC 1127 (issue #1127) — the service plugin's first-party create verb.
///
/// Replaces the generic [CapabilityCommand] auto-registration for the
/// `create` subcommand (wired through `ServiceCommand.manualSubcommandNames`)
/// so the verb can grow a real machine surface:
///
///   * `--json` (a bare FLAG — the machine-OUTPUT seam `zfa state create`
///     and `zfa usecase create` took) emits ONE canonical
///     `zuraffa.verdict.v1` envelope (issue #1105) as the last stdout line,
///     listing the generated service class, the bound provider, the methods
///     created, and the grammar/schema conformance verdict;
///   * `--explain` describes the service shape, the provider binding and
///     the methods the grammar will create WITHOUT generating;
///   * every real generation ships the deterministic per-entity receipt
///     `.zfa/receipts/service-<Entity>.json` (SPEC 1127 order 3, written by
///     [CreateServiceCapability]) plus the #996 wrapper receipt;
///   * the execution path is guarded end-to-end (SPEC 1127 order 4): a
///     malformed entity surfaces as a structured fail envelope, never an
///     uncaught crash.
///
/// The grammar knobs are unchanged (issue #978 schema ≡ grammar):
/// --name/--params/--returns/--type/--init. Only the machine surface and
/// the error path upgrade.
class ServiceCreateCommand extends Command<void> {
  final ServicePlugin plugin;

  /// Project root receipts and provider-binding lookups resolve from.
  /// Defaults to the CWD (the CLI contract); injectable for tests.
  final String? projectRoot;

  ServiceCreateCommand(this.plugin, {this.projectRoot}) {
    argParser.addOption(
      'name',
      help:
          'Name of the service (e.g. SendEmail); the positional form '
          '`zfa service create <Name>` is the live grammar',
    );
    argParser.addOption(
      'params',
      help: 'Parameter type for the service method (e.g. String, MyParams)',
      defaultsTo: 'NoParams',
    );
    argParser.addOption(
      'returns',
      help: 'Return type for the service method (e.g. String, List<int>)',
      defaultsTo: 'void',
    );
    argParser.addOption(
      'type',
      allowed: ['sync', 'stream', 'completable', 'usecase'],
      defaultsTo: 'usecase',
      help: 'Service method type (sync, stream, completable)',
    );
    argParser.addFlag(
      'init',
      negatable: false,
      help: 'Generate initialization and disposal methods',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview the plan report without executing',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing files',
    );
    argParser.addFlag(
      'verbose',
      negatable: false,
      help: 'Enable verbose logging',
    );
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit one canonical zuraffa.verdict.v1 envelope on stdout '
          '(CI-able, issue #1105)',
    );
    argParser.addFlag(
      'explain',
      negatable: false,
      help:
          'Describe the service shape, the provider binding and the '
          'methods generated — without generating',
    );
  }

  @override
  String get name => 'create';

  @override
  String get description =>
      'Create a Service interface — canonical --json verdict (issue #1105), '
      '--explain, per-entity receipts and a grammar-conformance proof';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      exitCode = ExitProtocol.usage;
      return;
    }

    final jsonMode = results['json'] == true;
    final explainMode = results['explain'] == true;

    final entityName = _resolveName();
    if (entityName == null || entityName.trim().isEmpty) {
      _usageRefusal(
        'Missing required argument: name',
        'zfa service create <ServiceName> [--params T --returns R --type t]',
        jsonMode,
      );
      return;
    }
    if (!_isValidName(entityName)) {
      _usageRefusal(
        'Invalid service name: `$entityName` — a service name must be a '
            'Dart identifier (letters, digits, underscore; no spaces or '
            'symbols)',
        'zfa service create <ValidName> (e.g. zfa service create '
            'SendEmail)',
        jsonMode,
      );
      return;
    }

    final args = <String, dynamic>{
      'name': entityName,
      'params': results['params'] as String?,
      'returns': results['returns'] as String?,
      'type': results['type'] as String? ?? 'usecase',
      'init': results['init'] == true,
      'force': results['force'] == true,
      'verbose': results['verbose'] == true,
      'dryRun': results['dry-run'] == true,
    };

    final config = _configFor(entityName, args);
    final root = projectRoot ?? Directory.current.path;

    // ── Explain: describe, never generate. ──
    if (explainMode) {
      final explanation = _explain(config, root);
      if (jsonMode) {
        print(
          VerdictEnvelope(
            command: 'zfa service create',
            verdict: VerdictKind.skip,
            exitClass: ExitProtocol.success,
            subject: VerdictSubject(
              kind: 'service',
              id: config.effectiveService,
            ),
            details: {'serviceClass': config.effectiveService},
            explain: explanation,
          ).toJsonLine(),
        );
      } else {
        _printExplanation(explanation);
      }
      exitCode = ExitProtocol.success;
      return;
    }

    // ── Dry-run: the plan surface (unchanged semantics, issue #978). ──
    if (results['dry-run'] == true) {
      final capability = CreateServiceCapability(plugin, projectRoot: root);
      final report = await capability.plan(args);
      await PlanStore.instance.savePlan(report);
      print(jsonEncode(report.toJson()));
      exitCode = ExitProtocol.success;
      return;
    }

    // ── Execute through the wrapper (issue #996 receipt + order-4 guard).
    final wrapper = CapabilityInvocationWrapper(
      capability: CreateServiceCapability(plugin, projectRoot: root),
      pluginId: plugin.id,
      projectRoot: root,
    );
    final result = await wrapper.execute(args);

    if (!result.success) {
      final message = result.message ?? 'service create failed';
      if (jsonMode) {
        print(
          VerdictEnvelope(
            command: 'zfa service create',
            verdict: VerdictKind.error,
            exitClass: ExitProtocol.failure,
            subject: VerdictSubject(
              kind: 'service',
              id: config.effectiveService,
            ),
            details: {'error': message},
            fix:
                're-run with --verbose for the cause, then check '
                '`zfa service create --help`',
          ).toJsonLine(),
        );
        print(
          ExitProtocol.fixLine(
            're-run with --verbose for the cause, '
            'then check `zfa service create --help`',
          ),
        );
      } else {
        print('❌ Failed: $message');
        print(
          ExitProtocol.fixLine(
            're-run with --verbose for the cause, then check '
            '`zfa service create --help`',
          ),
        );
      }
      exitCode = ExitProtocol.failure;
      return;
    }

    final files =
        result.data?['generatedFiles'] as List<GeneratedFile>? ?? const [];
    final changed = files
        .where(
          (f) =>
              f.action == 'created' ||
              f.action == 'overwritten' ||
              f.action == 'updated',
        )
        .toList();
    final skipped = files.where((f) => f.action == 'skipped').toList();
    final receiptPath = result.data?['serviceReceipt'] as String?;

    // ── Conformance proof: the fresh artifact must satisfy the grammar.
    ServiceConformanceResult? conformance;
    if (changed.isNotEmpty) {
      final artifact = File(changed.first.path);
      if (artifact.existsSync()) {
        conformance = const ServiceConformanceChecker().check(
          config: config,
          source: artifact.readAsStringSync(),
          path: artifact.path,
        );
      }
    }

    final proven = conformance == null || conformance.ok;
    final serviceClass = config.effectiveService ?? 'Service';

    if (jsonMode) {
      // Verdict resolution: proven generation → pass; declined generation
      // (skipped) → skip; unprovable/empty → fail. Issue #769: a declined
      // generation is never dressed up as success.
      final VerdictKind outcome;
      final int exitClass;
      if (changed.isEmpty) {
        outcome = VerdictKind.skip;
        exitClass = ExitProtocol.failure;
      } else if (!proven) {
        outcome = VerdictKind.fail;
        exitClass = ExitProtocol.failure;
      } else {
        outcome = VerdictKind.pass;
        exitClass = ExitProtocol.success;
      }
      print(
        VerdictEnvelope(
          command: 'zfa service create',
          verdict: outcome,
          exitClass: exitClass,
          subject: VerdictSubject(kind: 'service', id: serviceClass),
          artifacts: VerdictArtifacts(
            created: files
                .where((f) => f.action == 'created')
                .map((f) => _projectRelative(f.path, root))
                .toList(growable: false),
            modified: files
                .where(
                  (f) => f.action == 'overwritten' || f.action == 'updated',
                )
                .map((f) => _projectRelative(f.path, root))
                .toList(growable: false),
          ),
          receipts: receiptPath == null ? const <String>[] : [receiptPath],
          // Conformance findings — a fresh generation that does not
          // satisfy the grammar is a defect, never a pass.
          findings: conformance?.findings
              .map(
                (f) => VerdictFinding(
                  kind: f.kind,
                  member: f.member,
                  file: changed.firstOrNull?.path,
                  fix: f.fix,
                ),
              )
              .toList(),
          // The declined-generation remediation (issue #769): a skip
          // verdict carries its fix at the canonical top-level fix slot.
          fix: changed.isEmpty && files.isNotEmpty
              ? 're-run with --force to overwrite '
                    '${_projectRelative(files.first.path, root)}'
              : null,
          details: {
            'serviceClass': serviceClass,
            'provider': _boundProvider(config, root),
            'methods': conformance?.expectedMethods ?? const <String>[],
            'type': args['type'],
            if (conformance != null)
              'conformance': {
                'ok': conformance.ok,
                'expectedSignatures': conformance.expectedSignatures,
                'extraMethods': conformance.extraMethods,
              },
          },
        ).toJsonLine(),
      );
      exitCode = exitClass;
      if (exitClass != ExitProtocol.success) {
        print(
          ExitProtocol.fixLine(
            changed.isEmpty
                ? 're-run with --force to overwrite the existing service file'
                : 'inspect the conformance findings above',
          ),
        );
      }
      return;
    }

    // ── Prose mode (byte-compatible framing with the old runner). ──
    if (changed.isEmpty) {
      print(
        '⚠️ No files were generated (nothing changed). Re-run with '
        '--force to overwrite the existing service file.',
      );
      exitCode = ExitProtocol.failure;
      return;
    }
    print('✅ Success! Created/Modified:');
    for (final file in changed) {
      print('  ${file.action == 'created' ? '✨' : '📝'} ${file.path}');
    }
    for (final file in skipped) {
      print('  ${file.path}');
    }
    if (conformance != null && conformance.ok) {
      print(
        '✅ Conformance: ${conformance.serviceClass} matches the schema '
        'grammar (${conformance.expectedMethods.length} member(s)).',
      );
    } else if (conformance != null) {
      for (final finding in conformance.findings) {
        print('❌ [${finding.kind}] ${finding.message}');
        print('   ${finding.fix}');
      }
    }
    if (receiptPath != null) {
      print('Receipt: $receiptPath');
    }
    exitCode = proven ? ExitProtocol.success : ExitProtocol.failure;
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  GeneratorConfig _configFor(String name, Map<String, dynamic> args) {
    return GeneratorConfig(
      name: name,
      outputDir: plugin.outputDir,
      service: name,
      methods: [],
      paramsType: args['params'] as String?,
      returnsType: args['returns'] as String?,
      useCaseType: args['type'] as String? ?? 'usecase',
      generateInit: args['init'] == true,
    );
  }

  String? _resolveName() {
    final viaOption = argResults?['name'] as String?;
    if (viaOption != null && viaOption.isNotEmpty) return viaOption;
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isNotEmpty) return rest.first;
    return null;
  }

  /// A service name becomes a Dart class and a file name — it must be a
  /// plain identifier. Spaces/symbols are the malformed-entity family that
  /// used to crash or write garbage files.
  bool _isValidName(String name) =>
      RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(name);

  /// The provider bound to this service, resolved from the per-entity
  /// provider receipts (spec 979) first, then the conventional provider
  /// file on disk. Null when nothing is bound — reported honestly.
  Map<String, dynamic>? _boundProvider(GeneratorConfig config, String root) {
    final serviceClass = config.effectiveService;
    if (serviceClass == null) return null;

    // 1. Receipt scan: provider-<Entity>.json documents record the
    //    interface they implement (the entity rides `target` — the
    //    writer predates the #996 entity field).
    final receiptsDir = Directory(p.join(root, '.zfa', 'receipts'));
    if (receiptsDir.existsSync()) {
      for (final entity in receiptsDir.listSync().whereType<File>()) {
        final name = p.basename(entity.path);
        if (!name.startsWith('provider-') || !name.endsWith('.json')) {
          continue;
        }
        try {
          final doc =
              jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
          final boundEntity = (doc['entity'] ?? doc['target'])?.toString();
          if (doc['interface'] == serviceClass &&
              boundEntity != null &&
              boundEntity.isNotEmpty) {
            return {
              'class': '${boundEntity}Provider',
              'source': 'receipt',
              'receipt': _projectRelative(entity.path, root),
            };
          }
        } catch (_) {
          // Skip corrupted receipts.
        }
      }
    }

    // 2. Conventional provider file: data/providers/[<base>/]
    //    <base>_provider.dart (the provider plugin nests per-domain).
    var base = serviceClass;
    if (base.endsWith('Service')) base = base.substring(0, base.length - 7);
    final snake = StringUtils.camelToSnake(base);
    final providersDir = Directory(
      p.join(plugin.outputDir, 'data', 'providers'),
    );
    if (providersDir.existsSync()) {
      final flat = File(p.join(providersDir.path, '${snake}_provider.dart'));
      if (flat.existsSync()) {
        return {
          'class': '${base}Provider',
          'source': 'file',
          'file': _projectRelative(flat.path, root),
        };
      }
      for (final entry in providersDir.listSync().whereType<Directory>()) {
        final candidate = File(p.join(entry.path, '${snake}_provider.dart'));
        if (candidate.existsSync()) {
          return {
            'class': '${base}Provider',
            'source': 'file',
            'file': _projectRelative(candidate.path, root),
          };
        }
      }
    }
    return null;
  }

  /// The explain payload: service shape, provider binding, methods.
  Map<String, dynamic> _explain(GeneratorConfig config, String root) {
    final checker = const ServiceConformanceChecker().check(
      config: config,
      source: const ServiceInterfaceBuilder().build(config),
      path: 'explain_preview.dart',
    );
    final provider = _boundProvider(config, root);
    return {
      'serviceClass': config.effectiveService,
      'file': _serviceFilePath(config),
      'knobs': {
        'params': config.paramsType ?? 'NoParams',
        'returns': config.returnsType ?? 'void',
        'type': config.useCaseType,
        'init': config.generateInit,
      },
      'methods': checker.expectedMethods,
      'signatures': checker.expectedSignatures,
      'provider': provider,
      'providerHint': provider == null
          ? 'no provider bound yet — `zfa provider create '
                '${_baseName(config)} --service ${config.effectiveService}` '
                'binds one'
          : null,
      'receipt': '.zfa/receipts/service-${_receiptEntityName(config)}.json',
    };
  }

  void _printExplanation(Map<String, dynamic> explanation) {
    print('Service shape — ${explanation['serviceClass']}:');
    print('  file      : ${explanation['file']}');
    final knobs = explanation['knobs'] as Map;
    print(
      '  knobs     : params=${knobs['params']}, returns=${knobs['returns']}, '
      'type=${knobs['type']}, init=${knobs['init']}',
    );
    print('  methods   :');
    for (final signature in explanation['signatures'] as List) {
      print('    - $signature');
    }
    final provider = explanation['provider'] as Map?;
    if (provider == null) {
      print('  provider  : none bound — ${explanation['providerHint']}');
    } else {
      print(
        '  provider  : ${provider['class']} (bound via '
        '${provider['source']})',
      );
    }
    print('  receipt   : ${explanation['receipt']}');
  }

  String _serviceFilePath(GeneratorConfig config) {
    final snake = config.serviceSnake ?? StringUtils.camelToSnake(config.name);
    return p.posix.join(
      plugin.outputDir,
      'domain',
      'services',
      '${snake}_service.dart',
    );
  }

  String _baseName(GeneratorConfig config) {
    final service = config.effectiveService ?? config.name;
    return service.endsWith('Service')
        ? service.substring(0, service.length - 7)
        : service;
  }

  String _receiptEntityName(GeneratorConfig config) {
    final name = config.name;
    final parts = name
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ')
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty);
    final buffer = StringBuffer();
    for (final part in parts) {
      buffer.write(part[0].toUpperCase());
      buffer.write(part.substring(1));
    }
    return buffer.isEmpty ? name : buffer.toString();
  }

  void _usageRefusal(String message, String fix, bool jsonMode) {
    if (jsonMode) {
      print(
        VerdictEnvelope(
          command: 'zfa service create',
          verdict: VerdictKind.fail,
          exitClass: ExitProtocol.usage,
          details: {'error': message},
          fix: fix,
        ).toJsonLine(),
      );
    } else {
      print('❌ Error: $message');
    }
    print(ExitProtocol.fixLine(fix));
    exitCode = ExitProtocol.usage;
  }

  String _projectRelative(String filePath, String root) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: root)
        : p.normalize(filePath);
    return rel.replaceAll('\\', '/');
  }
}
