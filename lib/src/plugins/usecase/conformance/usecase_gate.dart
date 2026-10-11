import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/project/receipt_store.dart';
import '../../../models/generator_config.dart';
import '../../../utils/string_utils.dart';
import '../generators/entity_usecase_generator.dart';
import '../receipts/usecase_receipt_reader.dart';
import 'usecase_conformance_checker.dart';
import 'usecase_drift_checker.dart';

/// SPEC 1119 — the shared usecase gate: ONE implementation of method
/// resolution (receipt-first, flags-override, discovery fallback), file
/// resolution (receipt binding → conventional path), the per-method
/// conformance audit and the entity drift check. Consumed by
/// `zfa usecase verify`, `zfa usecase create --certify` and the
/// standalone verify capability — three verbs, one gate, no drift
/// between them.
class UsecaseGate {
  final EntityUseCaseGenerator generator;
  final UsecaseConformanceChecker checker;
  final UsecaseDriftChecker driftChecker;
  final UsecaseReceiptReader receiptReader;

  UsecaseGate({EntityUseCaseGenerator? generator})
    : generator = generator ?? EntityUseCaseGenerator(outputDir: 'lib/src'),
      checker = UsecaseConformanceChecker(generator: generator),
      driftChecker = const UsecaseDriftChecker(),
      receiptReader = const UsecaseReceiptReader();

  /// The entity-method vocabulary the per-method surface is drawn from.
  static const List<String> validMethods = [
    'get',
    'getList',
    'list',
    'create',
    'update',
    'toggle',
    'delete',
    'watch',
    'watchList',
  ];

  Future<UsecaseGateReport> run({
    required String projectRoot,
    required String entity,
    List<String>? methods,
    String? domain,
    GeneratorConfig? config,
    bool checkDrift = true,
  }) async {
    final receipt = receiptReader.load(projectRoot, entity);
    final resolvedDomain =
        domain ??
        (receipt?.input['domain'] as String?) ??
        StringUtils.camelToSnake(entity);

    // ── Method resolution: flags → receipt → discovery. ──
    final requested = methods;
    final resolvedMethods = (requested != null && requested.isNotEmpty)
        ? _validOnly(requested)
        : receipt != null
        ? _methodsFromReceipt(receipt, projectRoot, resolvedDomain, entity)
        : _discoverMethods(projectRoot, resolvedDomain, entity);

    final audits = <UsecaseMethodAudit>[];
    for (final method in resolvedMethods) {
      final contract = generator.describeMethod(
        _configFor(entity, resolvedDomain, config),
        method,
      );
      if (contract == null) continue;

      // ── File resolution: receipt binding → conventional path. ──
      String? filePath;
      if (receipt != null) {
        final bound = receiptReader.receiptPathFor(receipt, contract.fileName);
        if (bound != null) {
          final candidate = File(
            p.isAbsolute(bound) ? bound : p.join(projectRoot, bound),
          );
          if (candidate.existsSync()) filePath = candidate.path;
        }
      }
      if (filePath == null) {
        final candidate = File(
          p.isAbsolute(contract.filePath)
              ? contract.filePath
              : p.join(projectRoot, contract.filePath),
        );
        if (candidate.existsSync()) filePath = candidate.path;
      }
      if (filePath == null) {
        audits.add(
          UsecaseMethodAudit(
            method: method,
            ok: false,
            file: contract.filePath,
            contract: contract,
            findings: [
              UcaseaseMissingFileFinding(
                entity: entity,
                fileName: contract.fileName,
              ),
            ],
          ),
        );
        continue;
      }

      final audit = checker.checkMethod(
        config: _configFor(entity, resolvedDomain, config),
        method: method,
        source: File(filePath).readAsStringSync(),
        path: filePath,
      );
      audits.add(
        UsecaseMethodAudit(
          method: audit.method,
          ok: audit.ok,
          file: _projectRelativePosix(filePath, projectRoot),
          contract: audit.contract,
          findings: audit.findings,
        ),
      );
    }

    final drift = checkDrift
        ? driftChecker.check(
            projectRoot: projectRoot,
            entity: entity,
            receipt: receipt,
          )
        : null;

    return UsecaseGateReport(
      entity: entity,
      methods: resolvedMethods,
      audits: audits,
      drift: drift,
      receiptBound: receipt != null,
      config: _configFor(entity, resolvedDomain, config),
      domain: resolvedDomain,
    );
  }

  GeneratorConfig _configFor(
    String entity,
    String domain,
    GeneratorConfig? override,
  ) {
    if (override != null) return override;
    return GeneratorConfig(
      name: entity,
      methods: const [],
      domain: domain,
      outputDir: generator.outputDir,
    );
  }

  List<String> _validOnly(List<String> raw) => [
    for (final method in raw)
      if (validMethods.contains(method.trim()) && method.trim().isNotEmpty)
        method.trim(),
  ];

  /// The receipt's surface: the methods the run wired (created +
  /// appended), plus skipped methods whose conventional file exists on
  /// disk (the already-present case — they are part of the surface).
  List<String> _methodsFromReceipt(
    GenerationReceipt receipt,
    String projectRoot,
    String domain,
    String entity,
  ) {
    final generated = [
      ...?receipt.methodset,
      ...((receipt.input['generated_methods'] as List?) ?? const []).map(
        (m) => m.toString(),
      ),
    ];
    final skipped = ((receipt.input['skipped_methods'] as List?) ?? const [])
        .map((m) => m.toString())
        .toList();
    final surface = <String>{
      for (final method in generated)
        if (validMethods.contains(method)) method,
      for (final method in skipped)
        if (validMethods.contains(method) &&
            _conventionalFileExists(projectRoot, domain, entity, method))
          method,
    };
    return surface.toList(growable: false);
  }

  /// Conventional-shape discovery when no receipt exists: every
  /// `*_<snake>_usecase.dart` file under the usecases tree, method name
  /// recovered from the canonical file name.
  List<String> _discoverMethods(
    String projectRoot,
    String domain,
    String entity,
  ) {
    final snake = StringUtils.camelToSnake(entity);
    final found = <String>{};
    final root = Directory(
      p.join(projectRoot, generator.outputDir, 'domain', 'usecases'),
    );
    if (!root.existsSync()) return const [];
    final dirs = [root, ...root.listSync().whereType<Directory>()];
    for (final dir in dirs) {
      for (final entry in dir.listSync().whereType<File>()) {
        final name = p.basename(entry.path);
        if (!name.endsWith('_${snake}_usecase.dart')) continue;
        final method = _methodFromCanonicalFile(name, snake);
        if (method != null) found.add(method);
      }
    }
    return found.toList(growable: false);
  }

  bool _conventionalFileExists(
    String projectRoot,
    String domain,
    String entity,
    String method,
  ) {
    final contract = generator.describeMethod(
      GeneratorConfig(
        name: entity,
        methods: const [],
        domain: domain,
        outputDir: generator.outputDir,
      ),
      method,
    );
    if (contract == null) return false;
    final file = File(
      p.isAbsolute(contract.filePath)
          ? contract.filePath
          : p.join(projectRoot, contract.filePath),
    );
    return file.existsSync();
  }

  /// `get_product_usecase.dart` → `get`;
  /// `get_product_list_usecase.dart` → `getList`.
  String? _methodFromCanonicalFile(String fileName, String snake) {
    final stem = fileName.replaceAll('_usecase.dart', '');
    final withoutEntity = stem.endsWith('_${snake}_list')
        ? stem.replaceAll('_${snake}_list', '')
        : stem.replaceAll('_$snake', '');
    if (UsecaseGate.validMethods.contains(withoutEntity)) {
      return withoutEntity;
    }
    return null;
  }
}

/// The `missing_file` finding — a usecase file the surface prescribes
/// but the tree does not carry.
class UcaseaseMissingFileFinding extends UsecaseConformanceFinding {
  UcaseaseMissingFileFinding({required String entity, required String fileName})
    : super(
        kind: 'missing_file',
        member: fileName,
        message:
            'no usecase file found for $entity ($fileName) — the gate '
            'cannot audit a file that does not exist',
        fix:
            '--> fix: generate it first — `zfa usecase create $entity` '
            '(the gate cannot audit a file that does not exist)',
      );
}

/// The gate verdict: per-method audits + the drift check.
class UsecaseGateReport {
  final String entity;
  final List<String> methods;
  final List<UsecaseMethodAudit> audits;
  final UsecaseDriftResult? drift;
  final bool receiptBound;
  final GeneratorConfig config;
  final String domain;

  const UsecaseGateReport({
    required this.entity,
    required this.methods,
    required this.audits,
    required this.drift,
    required this.receiptBound,
    required this.config,
    required this.domain,
  });

  bool get ok =>
      audits.every((audit) => audit.ok) && !(drift?.drifted ?? false);

  List<UsecaseConformanceFinding> get findings => [
    for (final audit in audits) ...audit.findings,
  ];
}

/// Project-relative POSIX form of [filePath] against [root] — the shape
/// every receipt and envelope path uses.
String _projectRelativePosix(String filePath, String root) {
  final rel = p.isAbsolute(filePath)
      ? p.relative(filePath, from: root)
      : p.normalize(filePath);
  return rel.replaceAll('\\', '/');
}
