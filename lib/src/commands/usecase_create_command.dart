import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../core/project/receipt_store.dart';
import '../models/generator_config.dart';
import '../plugins/usecase/usecase_plugin.dart';
import '../plugins/usecase/usecase_verdicts.dart';
import '../utils/string_utils.dart';
import '../version.dart';

/// Spec #972 — the first-party `zfa usecase create` subcommand.
///
/// Replaces the capability-derived `create` subcommand (auto-registered
/// from CreateUseCaseCapability) with an honest, machine-friendly
/// surface:
///
///   * `--json` prints ONLY a per-method verdict envelope:
///     `{"schema": 1, "entity": ..., "methods": [
///        {"name": "get", "action": "created"},
///        {"name": "toggle", "action": "skipped",
///         "reason": "interface_missing_method:TaskRepository.toggle"}]}`
///     with action ∈ {created, appended, skipped} (deleted on revert).
///   * Every successful run ships a proof-carrying receipt at
///     `.zfa/receipts/usecase-<entity>.json` (schema `proof.v1`) binding
///     the emitted files to their on-disk digests and recording
///     requested vs generated vs skipped methods plus the guard reason
///     codes — `zfa proof check` verifies it like any other receipt.
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
      exitCode = 64;
      return;
    }

    final entityName = results.rest.isNotEmpty
        ? results.rest.first
        : results['name'] as String?;
    if (entityName == null || entityName.trim().isEmpty) {
      print('❌ Usage: zfa usecase create <EntityName> [options]');
      print('   Run `zfa usecase create --help` for the full grammar.');
      exitCode = 64;
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
      // nothing — that is not a success.
      if (jsonMode) {
        print(
          jsonEncode({
            'schema': 1,
            'entity': entityName,
            'methods': report.verdicts.map((v) => v.toJson()).toList(),
          }),
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
      );
    }

    if (jsonMode) {
      print(
        jsonEncode({
          'schema': 1,
          'entity': entityName,
          'methods': report.verdicts.map((v) => v.toJson()).toList(),
          'receipt': receiptPath,
        }),
      );
      return;
    }

    _printHumanSummary(
      entityName: entityName,
      report: report,
      receiptPath: receiptPath,
      revert: revert,
    );
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

  /// Writes the proof.v1 receipt at `.zfa/receipts/usecase-<entity>.json`.
  ///
  /// Best-effort by design (the artifacts already exist; a receipt
  /// failure degrades to a warning), but unlike the timestamped make
  /// receipts this one uses the deterministic spec #972 name so a
  /// rerun replaces its own proof instead of accumulating one per run.
  Future<String?> _writeReceipt({
    required String entityName,
    required List<String> requestedMethods,
    required UsecaseGenerationReport report,
    required String type,
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

      final receipt = GenerationReceipt(
        command: 'usecase',
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
        },
        spec: _entitySpecReceipt(entityName, projectRoot),
        files: files,
      );

      final dir = Directory(p.join(projectRoot, '.zfa', 'receipts'));
      await dir.create(recursive: true);
      final target = _sanitize(entityName);
      final path = p.join(dir.path, 'usecase-$target.json');
      const encoder = JsonEncoder.withIndent('  ');
      await File(path).writeAsString(encoder.convert(receipt.toJson()));
      return _projectRelativePosix(path, projectRoot);
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

  static String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
}
