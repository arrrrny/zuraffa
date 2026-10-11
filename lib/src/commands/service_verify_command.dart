import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../cli/exit_protocol.dart';
import '../core/verdict_envelope.dart';
import '../models/generator_config.dart';
import '../plugins/service/conformance/service_conformance_checker.dart';
import '../plugins/service/service_plugin.dart';
import '../plugins/service/service_receipt.dart';
import '../utils/string_utils.dart';

/// SPEC 1127 (issue #1127, order 2) — `zfa service verify <Entity>`.
///
/// The grammar-conformance gate: re-derives the member surface the service
/// schema grammar prescribes (by driving the same builder generation
/// drives — the gate cannot drift from the grammar) and audits the
/// generated service FILE on disk with the analyzer AST. Exit 1 when the
/// file's grammar does not match the schema (missing class, missing
/// method, signature mismatch, parse error); exit 0 when it conforms.
///
/// The knobs resolve from the stable create receipt
/// (`.zfa/receipts/service-<Entity>.json`, SPEC 1127 order 3) and can be
/// overridden per flag — the receipt-then-flags resolution
/// `zfa provider verify` uses. `--json` emits one canonical
/// canonical verdict envelope (issue #1105). Exit codes: 0 = conforms,
/// 1 = findings, 2 = usage.
class ServiceVerifyCommand extends Command<void> {
  final ServicePlugin plugin;

  /// Project root receipts and the output tree resolve from. Defaults to
  /// the CWD (the CLI contract); injectable so tests can point at a temp
  /// fixture.
  final String? projectRoot;

  ServiceVerifyCommand(this.plugin, {this.projectRoot}) {
    argParser.addOption(
      'params',
      help:
          'Override the audited parameter type (default: the create '
          'receipt, then NoParams)',
    );
    argParser.addOption(
      'returns',
      help:
          'Override the audited return type (default: the create '
          'receipt, then void)',
    );
    argParser.addOption(
      'type',
      allowed: ['sync', 'stream', 'completable', 'usecase'],
      help:
          'Override the audited method type (default: the create '
          'receipt, then usecase)',
    );
    argParser.addFlag(
      'init',
      negatable: false,
      help: 'Audit the init/dispose lifecycle members too',
    );
    argParser.addOption(
      'service',
      help:
          'The Service interface name (default: derived from the '
          'receipt, then <Entity>Service)',
    );
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit one canonical ${VerdictEnvelope.canonicalSchema} envelope '
          'on stdout (CI-able, issue #1105)',
    );
  }

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Verify a service file conforms to the schema grammar (class, '
      'methods, signatures) — exit 1 with --> fix: lines otherwise '
      '(spec 1127)';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty || rest.first.trim().isEmpty) {
      print(
        '❌ Usage: zfa service verify <Entity> [--json] [--params T] '
        '[--returns R] [--type t] [--init]',
      );
      print(
        ExitProtocol.fixLine(
          're-run with the entity the service was created from — '
          '`zfa service verify <Entity>` (e.g. zfa service verify '
          'SendEmail)',
        ),
      );
      exitCode = ExitProtocol.usage;
      return;
    }

    final jsonMode = argResults?['json'] == true;
    final root = projectRoot ?? Directory.current.path;
    final entity = StringUtils.convertToPascalCase(rest.first.trim());
    if (entity.isEmpty) {
      print('❌ Error: `${rest.first}` does not name an entity');
      print(
        ExitProtocol.fixLine(
          're-run with the entity the service was created from — '
          '`zfa service verify <Entity>`',
        ),
      );
      exitCode = ExitProtocol.usage;
      return;
    }

    // ── Knobs: receipt first, flags override. ──
    final receipt = ServiceReceiptWriter.load(root, entity);
    final params =
        (argResults?['params'] as String?) ?? receipt?['params'] as String?;
    final returns =
        (argResults?['returns'] as String?) ?? receipt?['returns'] as String?;
    final type =
        (argResults?['type'] as String?) ??
        receipt?['type'] as String? ??
        'usecase';
    final init = argResults?['init'] == true || receipt?['init'] == true;
    final serviceOverride = argResults?['service'] as String?;
    final serviceName =
        serviceOverride ?? (receipt?['interface'] as String?) ?? entity;

    final config = GeneratorConfig(
      name: entity,
      outputDir: plugin.outputDir,
      service: serviceName,
      methods: const [],
      paramsType: params,
      returnsType: returns,
      useCaseType: type,
      generateInit: init,
    );

    // ── File resolution: receipt path, then the conventional shapes. ──
    final serviceFile = _resolveServiceFile(config, receipt, root, entity);
    if (serviceFile == null || !serviceFile.existsSync()) {
      final fix =
          '--> fix: generate it first — `zfa service create $entity` '
          '(the gate cannot audit a file that does not exist)';
      if (jsonMode) {
        print(
          VerdictEnvelope(
            command: 'zfa service verify',
            verdict: VerdictKind.fail,
            exitClass: ExitProtocol.failure,
            subject: VerdictSubject(
              kind: 'service',
              id: config.effectiveService ?? entity,
            ),
            findings: [
              VerdictFinding(
                kind: 'missing_file',
                member: config.effectiveService ?? entity,
                fix: fix,
              ),
            ],
            details: {'entity': entity},
          ).toJsonLine(),
        );
        print(fix);
      } else {
        print(
          '❌ [missing_file] no service file found for $entity '
          '(${config.effectiveService})',
        );
        print(fix);
      }
      exitCode = ExitProtocol.failure;
      return;
    }

    final conformance = const ServiceConformanceChecker().check(
      config: config,
      source: serviceFile.readAsStringSync(),
      path: serviceFile.path,
    );

    if (jsonMode) {
      print(
        VerdictEnvelope(
          command: 'zfa service verify',
          verdict: conformance.ok ? VerdictKind.pass : VerdictKind.fail,
          exitClass: conformance.ok
              ? ExitProtocol.success
              : ExitProtocol.failure,
          subject: VerdictSubject(
            kind: 'service',
            id: conformance.serviceClass,
          ),
          findings: conformance.findings
              .map(
                (f) => VerdictFinding(
                  kind: f.kind,
                  member: f.member,
                  file: _projectRelative(serviceFile.path, root),
                  fix: f.fix,
                ),
              )
              .toList(growable: false),
          details: {
            'entity': entity,
            'serviceFile': _projectRelative(serviceFile.path, root),
            'methods': conformance.expectedMethods,
            'extraMethods': conformance.extraMethods,
            'conformance': {
              'ok': conformance.ok,
              'expectedSignatures': conformance.expectedSignatures,
            },
            if (receipt != null) 'receiptVerified': true,
          },
        ).toJsonLine(),
      );
    } else {
      print('Service Verify — $entity');
      print('  interface : ${conformance.serviceClass}');
      print('  file      : ${_projectRelative(serviceFile.path, root)}');
      print(
        '  members   : '
        '${conformance.expectedMethods.length} prescribed, '
        '${conformance.extraMethods.length} extra',
      );
      if (conformance.ok) {
        print(
          '✅ verified: the service grammar matches the schema '
          '(conformance proven).',
        );
      } else {
        for (final finding in conformance.findings) {
          print('❌ [${finding.kind}] ${finding.message}');
          print('   ${finding.fix}');
        }
      }
    }
    exitCode = conformance.ok ? ExitProtocol.success : ExitProtocol.failure;
  }

  File? _resolveServiceFile(
    GeneratorConfig config,
    Map<String, dynamic>? receipt,
    String root,
    String entity,
  ) {
    // 1. The receipt binds the exact file the create run wrote.
    final receiptFiles = receipt?['files'];
    if (receiptFiles is List && receiptFiles.isNotEmpty) {
      final first = receiptFiles.first;
      if (first is Map && first['path'] is String) {
        final candidate = File(
          p.isAbsolute(first['path'] as String)
              ? first['path'] as String
              : p.join(root, first['path'] as String),
        );
        if (candidate.existsSync()) return candidate;
      }
    }

    // 2. The conventional flat path (`zfa service create`).
    final snake = config.serviceSnake ?? StringUtils.camelToSnake(entity);
    final flat = File(
      p.join(plugin.outputDir, 'domain', 'services', '${snake}_service.dart'),
    );
    if (flat.existsSync()) return flat;

    // 3. The entity-scoped path (make-triad services).
    final servicesDir = Directory(
      p.join(plugin.outputDir, 'domain', 'services'),
    );
    if (servicesDir.existsSync()) {
      for (final entry in servicesDir.listSync().whereType<Directory>()) {
        final candidate = File(p.join(entry.path, '${snake}_service.dart'));
        if (candidate.existsSync()) return candidate;
      }
    }
    return null;
  }

  String _projectRelative(String filePath, String root) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: root)
        : p.normalize(filePath);
    return rel.replaceAll('\\', '/');
  }
}
