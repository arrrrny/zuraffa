/// The certification registry (spec 1110, issue #1110): the existence +
/// freshness proof for `mock-cert.<Entity>.json`.
///
/// "Mocks the framework certifies, not the agent" (VISION.md §9) got its
/// receipts in spec 1001, but the engine pipeline never blocked on them:
/// a CORE entity could stay wired into the engine slice with no
/// certification at all. This registry is the gate's read side — one
/// place that answers, for a single entity:
///
///   1. **Reference** — is the entity wired into the engine tree? An
///      entity with a mock datasource on disk (or a certification
///      receipt already committed) is referenced; anything else is not
///      the gate's business (the loop generates mocks, it does not
///      require them up front).
///   2. **Existence** — a `mock-cert.<Entity>.json` receipt exists at
///      `test/mock/<snake>/`, parses, and every method is
///      `satisfied: true`.
///   3. **Freshness** — the receipt was written AFTER the entity source
///      file's last modification (mtime comparison). A receipt older
///      than the entity it certifies is stale: the certification no
///      longer describes the entity on disk.
///
/// Every blocked status carries the exact fix command
/// (`zfa mock create <Entity> --certify`) so the refusal receipt
/// (`engine.gate.<Entity>.refused.json`, written by the callers) and
/// `zfa tdd status` can render it.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../utils/string_utils.dart';
import 'mock_contract_test_writer.dart';
import 'mock_cert_receipt.dart';

/// The registry's verdict for one entity.
enum CertRegistryStatus {
  /// Fresh, all-satisfied receipt — the entity is certified.
  certified,

  /// No mock datasource and no receipt on disk — the entity is not
  /// referenced by the engine tree; the gate does not apply.
  notReferenced,

  /// The entity is referenced but has no `mock-cert.<Entity>.json`.
  missing,

  /// The receipt exists but at least one method is `satisfied: false`.
  unsatisfied,

  /// The receipt exists but does not parse (or parses to nothing).
  corrupt,

  /// The receipt is older than the entity source file — the
  /// certification no longer describes the entity on disk.
  stale,
}

/// One entity's certification state, as the registry sees it.
class CertRegistryEntry {
  final String entity;
  final CertRegistryStatus status;

  /// The human-readable block reason (empty when the entry is fine).
  final String reason;

  /// The exact cert command to run (empty when the entry is fine).
  final String fix;

  const CertRegistryEntry({
    required this.entity,
    required this.status,
    required this.reason,
    required this.fix,
  });

  /// True when this entry should block the engine pipeline.
  bool get blocked =>
      status != CertRegistryStatus.certified &&
      status != CertRegistryStatus.notReferenced;

  Map<String, dynamic> toJson() => {
    'entity': entity,
    'status': status.name,
    'reason': reason,
    'fix': fix,
  };
}

/// Reads the certification state of engine-tree entities.
class CertRegistry {
  const CertRegistry();

  /// The fix command every blocked entry carries (spec 1110, the exact
  /// cert command to run).
  static String certifyFixCommand(String entity) =>
      'zfa mock create $entity --certify';

  /// The mock datasource path (project-root relative) — the wired double
  /// whose certification the gate requires.
  static String mockDatasourceRel(String entity) => p.join(
    'lib',
    'src',
    'data',
    'datasources',
    StringUtils.camelToSnake(entity),
    '${StringUtils.camelToSnake(entity)}_mock_datasource.dart',
  );

  /// The canonical entity source path (project-root relative).
  static String entityFileRel(String entity) => p.join(
    'lib',
    'src',
    'domain',
    'entities',
    StringUtils.camelToSnake(entity),
    '${StringUtils.camelToSnake(entity)}.dart',
  );

  /// Checks one entity under [projectRoot].
  static CertRegistryEntry checkEntity({
    required String entity,
    required String projectRoot,
  }) {
    final fix = certifyFixCommand(entity);
    final mockDatasource = File(p.join(projectRoot, mockDatasourceRel(entity)));
    final receiptFile = File(
      p.join(projectRoot, MockContractTestWriter.receiptPath(entity)),
    );

    // 1. Reference: nothing wired, nothing committed → not the gate's
    //    business. The loop generates mocks; entities without mocks are
    //    not blocked up front.
    if (!mockDatasource.existsSync() && !receiptFile.existsSync()) {
      return CertRegistryEntry(
        entity: entity,
        status: CertRegistryStatus.notReferenced,
        reason: '',
        fix: '',
      );
    }

    // 2. Existence: the receipt must exist and parse.
    if (!receiptFile.existsSync()) {
      return CertRegistryEntry(
        entity: entity,
        status: CertRegistryStatus.missing,
        reason:
            'CORE entity "$entity" is wired into the engine tree but has '
            'no mock-cert.$entity.json receipt — the framework never '
            'certified its mock.',
        fix: fix,
      );
    }
    final receipt = loadMockCertReceipt(projectRoot, entity);
    if (receipt == null) {
      return CertRegistryEntry(
        entity: entity,
        status: CertRegistryStatus.corrupt,
        reason:
            'mock-cert.$entity.json exists but does not parse — a corrupt '
            'receipt is not a certification.',
        fix: fix,
      );
    }
    if (!receipt.allSatisfied) {
      final unsatisfied =
          receipt.methods.where((m) => !m.value).map((m) => m.key).toList()
            ..sort();
      return CertRegistryEntry(
        entity: entity,
        status: CertRegistryStatus.unsatisfied,
        reason:
            'mock-cert.$entity.json has unsatisfied methods '
            '(${unsatisfied.join(', ')}) — the certification is red.',
        fix: fix,
      );
    }

    // 3. Freshness: the receipt must postdate the entity source it
    //    certifies. The entity file missing (moved/never generated) is
    //    not decidable — the receipt stands as the last honest
    //    certification.
    final entityFile = _locateEntityFile(projectRoot, entity);
    if (entityFile != null &&
        receiptFile.lastModifiedSync().isBefore(
          entityFile.lastModifiedSync(),
        )) {
      return CertRegistryEntry(
        entity: entity,
        status: CertRegistryStatus.stale,
        reason:
            'mock-cert.$entity.json is stale: the entity source '
            '${p.relative(entityFile.path, from: projectRoot)} changed '
            'after the mock was certified.',
        fix: fix,
      );
    }

    return CertRegistryEntry(
      entity: entity,
      status: CertRegistryStatus.certified,
      reason: '',
      fix: '',
    );
  }

  /// Checks many entities (the gate's walk). Order preserved; one entry
  /// per entity.
  static List<CertRegistryEntry> checkEntities({
    required List<String> entities,
    required String projectRoot,
  }) => [
    for (final entity in entities)
      checkEntity(entity: entity, projectRoot: projectRoot),
  ];

  /// The first blocked entry, or null when every entity is clean.
  static CertRegistryEntry? firstBlocked(List<CertRegistryEntry> entries) =>
      entries.where((e) => e.blocked).firstOrNull;

  /// Canonical entity path first, then a recursive fallback under the
  /// entities root (the entity file may live at a nested path when the
  /// project config moved it — same tolerance as entity_lookup).
  static File? _locateEntityFile(String projectRoot, String entity) {
    final snake = StringUtils.camelToSnake(entity);
    final canonical = File(p.join(projectRoot, entityFileRel(entity)));
    if (canonical.existsSync()) return canonical;
    final entitiesRoot = Directory(
      p.join(projectRoot, 'lib', 'src', 'domain', 'entities'),
    );
    if (!entitiesRoot.existsSync()) return null;
    for (final entry in entitiesRoot.listSync(recursive: true)) {
      if (entry is File && p.basename(entry.path) == '$snake.dart') {
        return entry;
      }
    }
    return null;
  }
}
