import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../core/plugin_system/capability_invocation_wrapper.dart';
import '../core/project/receipt_store.dart';
import '../core/verdict_envelope.dart';
import '../models/generator_config.dart';
import '../plugins/usecase/conformance/usecase_gate.dart';
import '../plugins/usecase/usecase_plugin.dart';
import '../plugins/usecase/usecase_verdicts.dart';
import '../utils/string_utils.dart';
import '../version.dart';
import '../cli/exit_protocol.dart';

/// Spec #972 — the first-party `zfa usecase create` subcommand.
///
/// Replaces the capability-derived `create` subcommand (auto-registered
/// from CreateUseCaseCapability) with an honest, machine-friendly
/// surface:
///
///   * `--json` prints ONLY the canonical verdict envelope (SPEC 1105,
///     `zuraffa.verdict.v1`): the per-method verdict list rides in
///     `details.methods`, the entity in `subject.id`:
///     `{"schema": "zuraffa.verdict.v1", "command": "zfa usecase create
///     <Entity>", "verdict": "pass|fail", "subject": {"kind": "usecase",
///     "id": "<Entity>"}, "details": {"methods": [
///        {"name": "get", "action": "created"},
///        {"name": "toggle", "action": "skipped",
///         "reason": "interface_missing_method:TaskRepository.toggle"}]}}`
///     with action ∈ {created, appended, skipped} (deleted on revert).
///   * Every successful run ships a proof-carrying receipt in
///     `.zfa/receipts/` (schema `proof.v1`) binding
///     the emitted files to their on-disk digests and recording
///     requested vs generated vs skipped methods plus the guard reason
///     codes — `zfa proof check` verifies it like any other receipt.
///     Issue #1138: the receipt carries the full capability provenance
///     contract `{plugin, capability, entity, hash, methodset, files,
///     receipt_version: 1}` and is keyed
///     `usecase-create-<entity>-<timestamp>.json` like every other
///     standalone capability receipt.
///   * Exit codes tell the truth: 64 for usage errors, 1 when the
///     request produced nothing (issue #769 semantics), 0 on success.
///
/// Revert runs delete the per-method usecase files and never write a
/// receipt; dry-run runs write nothing and prove nothing.
class UseCaseCreateCommand extends Command<void> {
  static const String fixedOutputDir = 'lib/src';

  final UseCasePlugin plugin;

  UseCaseCreateCommand(this.plugin) {
    argParser.addOption(
      'name',
      help: 'Entity / usecase name (alternative to the positional argument)',
    );
    argParser.addMultiOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated methods (get,create,update,delete,toggle,list,'
          'watch,getList,watchList). Default: get,update.',
      splitCommas: true,
    );
    argParser.addOption(
      'type',
      abbr: 't',
      allowed: [
        'future',
        'stream',
        'completable',
        'sync',
        'background',
        'os_background',
      ],
      defaultsTo: 'future',
      help: 'Execution strategy (default: future/fetch)',
    );
    argParser.addMultiOption(
      'usecases',
      abbr: 'u',
      help: 'UseCases to orchestrate (e.g. GetUser,GetProfile)',
      splitCommas: true,
    );
    argParser.addOption(
      'domain',
      help: 'Domain name (required for non-entity usecases)',
    );
    argParser.addOption(
      'repo',
      help: 'Repository class to inject (e.g. UserRepository)',
    );
    argParser.addOption(
      'service',
      help: 'Service class to inject (e.g. AuthService)',
    );
    argParser.addOption(
      'params',
      help: 'Parameter type (e.g. String, UserParams)',
    );
    argParser.addOption(
      'returns',
      help: 'Return type (e.g. void, User, List<User>)',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview generated files without writing to disk',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing files instead of appending',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
    argParser.addFlag(
      'revert',
      negatable: false,
      help: 'Revert (delete) the generated usecase files',
    );
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Print only the per-method verdict envelope (machine output)',
    );
    // SPEC 1119: --certify mirrors mock's certify — after generation, the
    // verify gate runs over the methods the run wired; exit 1 when
    // generation succeeded but verify failed.
    argParser.addFlag(
      'certify',
      negatable: false,
      help:
          'After generation, verify the emitted usecases conform to the '
          'contract; drift exits 1 with a `--> fix:` line naming the '
          'mismatch',
    );
    // SPEC 1119: --explain emits the human-readable contract block (and
    // the additive `explain` envelope key in --json mode, issue #1122
    // pattern).
    argParser.addFlag(
      'explain',
      negatable: false,
      help:
          'After generation, explain the surface: which methods were '
          'generated, which variant each uses, which result type is '
          'bound, which exception type is thrown',
    );
  }

  @override
  String get name => 'create';

  @override
  String get description =>
      'Create a Clean Architecture UseCase — per-method verdicts (--json) '
      'and a proof receipt';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      exitCode = ExitProtocol.usage;
      return;
    }

    final entityName = results.rest.isNotEmpty
        ? results.rest.first
        : results['name'] as String?;
    if (entityName == null || entityName.trim().isEmpty) {
      print('❌ Usage: zfa usecase create <EntityName> [options]');
      print('   Run `zfa usecase create --help` for the full grammar.');
      exitCode = ExitProtocol.usage;
      return;
    }

    final jsonMode = results['json'] == true;
    final dryRun = results['dry-run'] == true;
    final force = results['force'] == true;
    final verbose = results['verbose'] == true;
    final revert = results['revert'] == true;

    var useCaseType = results['type'] as String?;
    final returns = results['returns'] as String?;

    // Smart Type Inference (mirrors CreateUseCaseCapability): a Stream
    // return type upgrades the future default to stream.
    if (useCaseType == null || useCaseType == 'future') {
      if (returns != null && returns.startsWith('Stream<')) {
        useCaseType = 'stream';
      }
    }
    useCaseType ??= 'future';

    var methods = const <String>[];
    final rawMethods = results['methods'];
    if (rawMethods is List) {
      methods = rawMethods
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    } else if (rawMethods is String && rawMethods.isNotEmpty) {
      methods = rawMethods
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    final usecases = ((results['usecases'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    final domain = results['domain'] as String?;
    final repo = results['repo'] as String?;
    final service = results['service'] as String?;
    final params = results['params'] as String?;

    final isCustomUseCase =
        repo != null ||
        service != null ||
        usecases.isNotEmpty ||
        params != null ||
        returns != null ||
        domain != null;

    // Entity runs default to the honest vocabulary (spec #972 FR-5):
    // get,update — toggle only when explicitly requested.
    final effectiveMethods = (methods.isEmpty && !isCustomUseCase)
        ? ['get', 'update']
        : methods;

    final config = GeneratorConfig(
      name: entityName,
      useCaseType: useCaseType,
      methods: effectiveMethods,
      outputDir: fixedOutputDir,
      domain: domain,
      repo: repo,
      service: service,
      usecases: usecases,
      paramsType: params,
      returnsType: returns,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
      revert: revert,
    );

    final report = await plugin.generateWithReport(config, quiet: jsonMode);

    if (report.files.isEmpty && !revert) {
      // Issue #769 semantics: zero files means the request produced
      // nothing — that is not a success. SPEC 1105: the refusal still
      // speaks the ONE canonical envelope (verdict=fail).
      if (jsonMode) {
        VerdictEnvelope.emit(
          VerdictEnvelope(
            command: 'zfa usecase create $entityName',
            verdict: VerdictKind.fail,
            exitClass: ExitProtocol.failure,
            subject: VerdictSubject(kind: 'usecase', id: entityName),
            findings: [
              VerdictFinding(
                kind: 'no-files',
                fix: 're-run with --verbose to inspect the resolved args',
                extra: {
                  'detail':
                      'no files were generated (nothing changed) — a '
                      'guard skip above explains why',
                },
              ),
            ],
            details: {
              'methods': report.verdicts.map((v) => v.toJson()).toList(),
            },
          ),
        );
      } else {
        print(
          '⚠️ No files were generated (nothing changed). If a guard skip '
          'note printed above explains why, re-run with a matching '
          'interface; otherwise re-run with --verbose.',
        );
      }
      exitCode = 1;
      return;
    }

    // ── SPEC 1119: certify + explain surface ──────────────────────────
    // The surface certify/explain describe: the methods THIS RUN wired —
    // created + appended, plus already-present skips (their files are on
    // disk and part of the proven surface). Guard-dropped and unknown
    // methods are NOT part of it (there is nothing to audit).
    final certify = results['certify'] == true;
    final explain = results['explain'] == true;
    final surfaceMethods = {
      for (final verdict in report.verdicts)
        if (verdict.action == MethodVerdict.actionCreated ||
            verdict.action == MethodVerdict.actionAppended ||
            (verdict.action == MethodVerdict.actionSkipped &&
                verdict.reason == MethodVerdict.reasonAlreadyPresent))
          verdict.name,
    }.toList(growable: false);

    // Certify (SPEC 1119, mirrors mock's certify): the gate runs right
    // after generation, over the surface this run wired. Drift checking
    // is the verify command's job — the receipt binding is written in
    // THIS run, so certify proves conformance alone.
    UsecaseGateReport? certification;
    if (certify && !dryRun && !revert && surfaceMethods.isNotEmpty) {
      certification = await UsecaseGate().run(
        projectRoot: Directory.current.path,
        entity: entityName,
        methods: surfaceMethods,
        config: config,
        checkDrift: false,
      );
    }

    // ── Receipt (spec #972 FR-3) ──────────────────────────────────────
    // Revert and dry-run runs ship no receipt: nothing was generated, so
    // there is nothing to prove (mirrors the make receipt contract).
    String? receiptPath;
    if (!dryRun && !revert) {
      receiptPath = await _writeReceipt(
        entityName: entityName,
        requestedMethods: effectiveMethods,
        report: report,
        type: useCaseType,
        certify: certify,
        certification: !certify
            ? 'skipped'
            : certification == null
            ? 'nothing-to-certify'
            : certification.ok
            ? 'pass'
            : 'fail',
      );
    }

    final certifyFailed = certification != null && !certification.ok;
    final explainBlock = explain
        ? _explainBlock(
            entityName: entityName,
            config: config,
            methods: surfaceMethods,
          )
        : null;

    if (jsonMode) {
      var envelope = VerdictEnvelope(
        command: 'zfa usecase create $entityName',
        verdict: certifyFailed ? VerdictKind.fail : VerdictKind.pass,
        exitClass: certifyFailed ? ExitProtocol.failure : ExitProtocol.success,
        subject: VerdictSubject(kind: 'usecase', id: entityName),
        artifacts: VerdictArtifacts(
          created: [
            for (final file in report.files)
              if (file.action == 'created')
                _projectRelativePosix(file.path, fixedOutputDir),
          ],
          modified: [
            for (final file in report.files)
              if (file.action == 'overwritten' || file.action == 'updated')
                _projectRelativePosix(file.path, fixedOutputDir),
          ],
          deleted: [
            for (final file in report.files)
              if (file.action == 'deleted')
                _projectRelativePosix(file.path, fixedOutputDir),
          ],
        ),
        receipts: receiptPath == null ? null : [receiptPath],
        findings: certifyFailed
            ? [
                for (final finding in certification.findings)
                  VerdictFinding(
                    kind: finding.kind,
                    member: finding.member,
                    fix: finding.fix,
                    extra: {'message': finding.message},
                  ),
              ]
            : null,
        details: {
          'methods': report.verdicts.map((v) => v.toJson()).toList(),
          if (certification != null)
            'certification': {
              'ok': certification.ok,
              'methods': certification.methods,
              'audits': certification.audits.map((a) => a.toJson()).toList(),
            },
        },
      );
      if (explainBlock != null) {
        // Issue #1122: the additive explain block rides the envelope —
        // the base shape is byte-compatible either way.
        envelope = envelope.withExplain(explainBlock);
      }
      VerdictEnvelope.emit(envelope);
      if (certifyFailed) exitCode = ExitProtocol.failure;
      return;
    }

    _printHumanSummary(
      entityName: entityName,
      report: report,
      receiptPath: receiptPath,
      revert: revert,
    );
    if (explainBlock != null) {
      _printExplainBlock(explainBlock);
    }
    if (certification != null) {
      if (certification.ok) {
        print(
          '✅ certified: ${certification.methods.length} method(s) conform '
          'to the contract (conformance proven).',
        );
      } else {
        print(
          '❌ certification failed — generation succeeded but the surface '
          'drifted:',
        );
        for (final audit in certification.audits) {
          for (final finding in audit.findings) {
            print('❌ [${finding.kind}] ${finding.message}');
            print('   ${finding.fix}');
          }
        }
        exitCode = ExitProtocol.failure;
      }
    }
  }

  /// SPEC 1119: the explain contract block — which methods were
  /// generated, which variant each uses, which result type is bound,
  /// which exception type is thrown — read off the SAME derivation the
  /// generator drives.
  Map<String, dynamic> _explainBlock({
    required String entityName,
    required GeneratorConfig config,
    required List<String> methods,
  }) {
    final generator = plugin.entityGenerator;
    final contracts = [
      for (final method in methods)
        if (generator.describeMethod(config, method) case final contract?)
          contract.toJson(),
    ];
    return {
      'entity': entityName,
      'methods': contracts,
      'exception': 'CancelledException',
    };
  }

  void _printExplainBlock(Map<String, dynamic> block) {
    print('Explain — ${block['entity']} usecases');
    for (final raw in block['methods'] as List) {
      final method = raw as Map<String, dynamic>;
      final variantDisplay = method['variant'] == 'stream'
          ? 'Stream<${method['resultType']}>'
          : method['variant'] == 'void'
          ? 'Future<void>'
          : 'Future<${method['resultType']}>';
      print(
        '  ${method['name'].toString().padRight(10)} '
        '${method['class'].toString().padRight(26)} '
        '${method['baseClass']} · $variantDisplay · '
        'result: ${method['resultType']} · '
        'params: ${method['paramsType']} · '
        'throws: ${method['exception']}',
      );
    }
  }

  /// Human-facing summary (non---json mode).
  void _printHumanSummary({
    required String entityName,
    required UsecaseGenerationReport report,
    required String? receiptPath,
    required bool revert,
  }) {
    final headline = revert
        ? '✅ UseCase revert complete for $entityName:'
        : '✅ UseCase generation complete for $entityName:';
    print(headline);
    for (final verdict in report.verdicts) {
      switch (verdict.action) {
        case MethodVerdict.actionCreated:
          print('  ✨ created  ${verdict.name}');
        case MethodVerdict.actionAppended:
          print('  📝 appended ${verdict.name}');
        case MethodVerdict.actionDeleted:
          print('  🗑 deleted  ${verdict.name}');
        default:
          print('  ⏭  skipped  ${verdict.name} — ${verdict.reason}');
      }
    }
    if (report.verdicts.isEmpty) {
      for (final file in report.files) {
        final prefix = switch (file.action) {
          'created' => '  ✨',
          'overwritten' => '  📝',
          'updated' => '  📝',
          'deleted' => '  🗑',
          _ => '  ⏭',
        };
        print('$prefix ${file.path}');
      }
    }
    if (receiptPath != null) {
      print('Receipt: $receiptPath');
    }
  }

  /// Writes the proof.v1 capability receipt (issue #1138) keyed
  /// `usecase-create-<entity>-<timestamp>.json`.
  ///
  /// Best-effort by design (the artifacts already exist; a receipt
  /// failure degrades to a warning). The provenance fields match the
  /// CapabilityInvocationWrapper contract exactly — same schema, same
  /// `hash` derivation via [CapabilityInvocationWrapper.computeRunHash] —
  /// so `zfa proof check` and machine readers need no special cases.
  Future<String?> _writeReceipt({
    required String entityName,
    required List<String> requestedMethods,
    required UsecaseGenerationReport report,
    required String type,
    required bool certify,
    required String certification,
  }) async {
    try {
      final projectRoot = Directory.current.path;
      final generated = report.verdicts
          .where((v) => v.action == MethodVerdict.actionCreated)
          .map((v) => v.name)
          .toList();
      final appended = report.verdicts
          .where((v) => v.action == MethodVerdict.actionAppended)
          .map((v) => v.name)
          .toList();
      final skipped = report.verdicts
          .where((v) => v.action == MethodVerdict.actionSkipped)
          .map((v) => v.name)
          .toList();

      final files = <GenerationReceiptFile>[];
      for (final file in report.files) {
        if (file.action == 'deleted' || file.action == 'reverted') continue;
        final absolute = p.isAbsolute(file.path)
            ? file.path
            : p.join(projectRoot, file.path);
        final f = File(absolute);
        if (!f.existsSync()) continue;
        final bytes = f.readAsBytesSync();
        final keepSnapshot = bytes.length <= ReceiptStore.maxSnapshotBytes;
        files.add(
          GenerationReceiptFile(
            path: _projectRelativePosix(file.path, projectRoot),
            action: file.action == 'created' ? 'create' : 'modify',
            sha256: crypto.sha256.convert(bytes).toString(),
            bytes: bytes.length,
            snapshot: keepSnapshot ? f.readAsStringSync() : null,
          ),
        );
      }
      if (files.isEmpty) return null;

      // Issue #1138 provenance: the generated+appended methods ARE the
      // methodset the run wired; the hash binds entity + methodset +
      // every file tuple via the shared wrapper derivation.
      final methodset = [...generated, ...appended];

      final receipt = GenerationReceipt(
        command: 'usecase create',
        target: entityName,
        repro:
            'zfa usecase create $entityName'
            '${requestedMethods.isEmpty ? '' : ' --methods=${requestedMethods.join(',')}'}',
        at: DateTime.now().toUtc(),
        generatorVersion: version,
        input: {
          'type': type,
          'requested_methods': requestedMethods,
          'generated_methods': [...generated, ...appended],
          'skipped_methods': skipped,
          'guard_reason_codes': report.guardReasonCodes,
          'interface_absent': report.interfaceAbsent,
          // SPEC 1119: the certification outcome this run shipped.
          'certify': certify,
          'certification': certification,
        },
        spec: _entitySpecReceipt(entityName, projectRoot),
        files: files,
        plugin: 'usecase',
        capability: 'create',
        entity: entityName,
        methodset: methodset,
        runHash: CapabilityInvocationWrapper.computeRunHash(
          files: files,
          entity: entityName,
          methodset: methodset,
        ),
        receiptVersion: CapabilityInvocationWrapper.receiptVersion,
      );

      final store = ReceiptStore(projectRoot: projectRoot);
      final written = await store.saveCapability(receipt);
      return _projectRelativePosix(written.path, projectRoot);
    } catch (e) {
      print('⚠️  Generation receipt not written: $e');
      return null;
    }
  }

  /// Binds the receipt to the entity source the run consumed, when it
  /// exists — the spec whose drift makes the usecases stale.
  GenerationReceiptSpec? _entitySpecReceipt(String entityName, String root) {
    final snake = StringUtils.camelToSnake(entityName);
    final specPath = 'lib/src/domain/entities/$snake/$snake.dart';
    final specFile = File(p.join(root, specPath));
    if (!specFile.existsSync()) return null;
    final bytes = specFile.readAsBytesSync();
    return GenerationReceiptSpec(
      path: specPath,
      sha256: crypto.sha256.convert(bytes).toString(),
      snapshot: bytes.length <= ReceiptStore.maxSnapshotBytes
          ? specFile.readAsStringSync()
          : null,
    );
  }

  String _projectRelativePosix(String filePath, String projectRoot) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: projectRoot)
        : p.normalize(filePath);
    return rel.replaceAll('\\', '/');
  }
}
