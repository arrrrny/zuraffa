import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../core/constants/known_types.dart';
import '../../core/context/file_system.dart';
import '../../core/project/receipt_store.dart';
import '../../utils/entity_analyzer.dart';
import '../../utils/string_utils.dart';

/// `zfa cache verify` (spec #975, Order 3) — the cache drift gate.
///
/// Reads the Hive registrar and the entity graph, and reports every
/// entity whose adapter is **missing** (discovered by the graph but not
/// registered in `hive_registrar.dart`) or **stale** (the registrar bytes
/// or the entity source drifted from what the last
/// `zfa cache adapter` run recorded in its generation receipt).
///
/// This is a read-only mirror of the adapter capability's discovery
/// semantics (entity + recursive sub-entities + `*_cache.dart` entities +
/// manual additions) — the discovery/merge semantics themselves are
/// correct per spec #975 and are intentionally NOT changed here; this
/// class only makes drift against them observable and CI-gateable.

/// One verification finding: [kind] is `missing` or `stale`, [entity]
/// names the entity (or `registrar` for file-level drift), and [fix] is
/// the pasteable `zfa ...` command that heals it.
class CacheVerifyFinding {
  static const kindMissing = 'missing';
  static const kindStale = 'stale';

  final String kind;
  final String entity;
  final String detail;
  final String fix;

  const CacheVerifyFinding({
    required this.kind,
    required this.entity,
    required this.detail,
    required this.fix,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'entity': entity,
    'detail': detail,
    'fix': fix,
  };
}

/// Machine-verifiable verdict for one `zfa cache verify <Entity>`
/// invocation (schema `cache.verify.v1`).
class CacheVerifyReport {
  static const schemaName = 'cache.verify.v1';

  final String entity;

  /// Every entity the current graph expects to have an adapter.
  final List<String> expectedEntities;

  /// Entities actually registered in the registrar (parsed from
  /// `AdapterSpec<X>()`).
  final List<String> registeredEntities;

  final List<CacheVerifyFinding> findings;

  const CacheVerifyReport({
    required this.entity,
    required this.expectedEntities,
    required this.registeredEntities,
    required this.findings,
  });

  bool get ok => findings.isEmpty;

  Map<String, dynamic> toJson() => {
    'schema': schemaName,
    'entity': entity,
    'ok': ok,
    'expected': expectedEntities,
    'registered': registeredEntities,
    'findings': findings.map((f) => f.toJson()).toList(),
  };
}

/// Thrown when the entity named on the command line does not exist —
/// the verifier cannot read a graph for an entity that is not there.
class CacheEntityNotFoundException implements Exception {
  final String message;
  CacheEntityNotFoundException(this.message);
  @override
  String toString() => message;
}

/// Read-only drift verifier for the Hive adapter registrar.
class CacheAdapterVerifier {
  /// Output dir the cache plugin generates into (e.g. `lib/src`), the
  /// same root the adapter capability uses.
  final String outputDir;

  /// Project root used to locate `.zfa/receipts/` and to make receipt
  /// paths project-relative.
  final String projectRoot;

  final FileSystem fileSystem;

  CacheAdapterVerifier({
    required this.outputDir,
    required this.projectRoot,
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create();

  /// Verifies the adapter coverage for [entityName] against the current
  /// tree.
  Future<CacheVerifyReport> verify(String entityName) async {
    // Fail fast (with the parity error UX) when the target entity does
    // not exist — there is no graph to verify otherwise.
    await _resolveEntity(entityName);

    // 1. Expected set: same discovery shape as the adapter capability.
    final expected = <String>[];
    final seen = <String>{};
    await _collectGraph(entityName, expected, seen);
    await _collectCacheFileEntities(expected, seen);
    _collectManualAdditions(expected, seen);

    // 2. Registered set: what the registrar actually declares.
    final registered = await _registeredEntities();

    // 3. Drift findings.
    final findings = <CacheVerifyFinding>[];
    for (final name in expected) {
      if (!registered.contains(name)) {
        findings.add(
          CacheVerifyFinding(
            kind: CacheVerifyFinding.kindMissing,
            entity: name,
            detail: 'adapter for $name is missing from the Hive registrar',
            fix: 'zfa cache adapter $name',
          ),
        );
      }
    }
    findings.addAll(await _receiptDriftFindings(entityName));

    return CacheVerifyReport(
      entity: entityName,
      expectedEntities: expected,
      registeredEntities: registered,
      findings: findings,
    );
  }

  /// Resolves the entity the way the adapter capability does: a regular
  /// entity file, an enum in `enums/index.dart`, or a per-file enum.
  Future<String> _resolveEntity(String entityName) async {
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityFile = p.join(
      outputDir,
      'domain',
      'entities',
      entitySnake,
      '$entitySnake.dart',
    );
    if (await fileSystem.exists(entityFile)) return entityFile;

    final enumIndex = p.join(
      outputDir,
      'domain',
      'entities',
      'enums',
      'index.dart',
    );
    if (await fileSystem.exists(enumIndex) &&
        (await fileSystem.read(enumIndex)).contains('enum $entityName')) {
      return enumIndex;
    }

    final enumFile = p.join(
      outputDir,
      'domain',
      'entities',
      'enums',
      '$entitySnake.dart',
    );
    if (await fileSystem.exists(enumFile) &&
        (await fileSystem.read(enumFile)).contains('enum $entityName')) {
      return enumFile;
    }

    final available = await _availableEntities();
    final suggestions = available.isNotEmpty
        ? '\nAvailable entities:\n${available.map((e) => '  - $e').join('\n')}'
        : '';
    throw CacheEntityNotFoundException(
      "Entity '$entityName' not found.$suggestions",
    );
  }

  /// Recursively walks [entityName]'s field types — the read-only mirror
  /// of `CreateCacheAdapterCapability._collectSubtypeAdapters`.
  Future<void> _collectGraph(
    String entityName,
    List<String> into,
    Set<String> seen,
  ) async {
    if (seen.contains(entityName)) return;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityFile = p.join(
      outputDir,
      'domain',
      'entities',
      entitySnake,
      '$entitySnake.dart',
    );
    if (!await fileSystem.exists(entityFile)) return;

    seen.add(entityName);
    if (!into.contains(entityName)) into.add(entityName);

    final fields = EntityAnalyzer.analyzeEntity(
      entityName,
      outputDir,
      fileSystem: fileSystem,
    );
    for (final fieldType in fields.values) {
      final baseType = _extractBaseType(fieldType);
      if (baseType == null || seen.contains(baseType)) continue;
      if (KnownTypes.isExcluded(baseType)) continue;

      final subSnake = StringUtils.camelToSnake(baseType);
      final subFile = p.join(
        outputDir,
        'domain',
        'entities',
        subSnake,
        '$subSnake.dart',
      );
      if (await fileSystem.exists(subFile)) {
        await _collectGraph(baseType, into, seen);
      }
    }
  }

  /// Entities that already have `*_cache.dart` files — the registrar
  /// regeneration re-registers them, so they are always expected.
  Future<void> _collectCacheFileEntities(
    List<String> into,
    Set<String> seen,
  ) async {
    final cacheDir = p.join(outputDir, 'cache');
    if (!await fileSystem.exists(cacheDir)) return;
    for (final item in await fileSystem.list(cacheDir)) {
      if (await fileSystem.isDirectory(item)) continue;
      final fileName = p.basename(item);
      if (fileName.endsWith('_cache.dart') &&
          !fileName.endsWith('index.dart') &&
          !fileName.endsWith('timestamp_cache.dart')) {
        final entityName = StringUtils.convertToPascalCase(
          fileName.replaceAll('_cache.dart', ''),
        );
        if (!seen.contains(entityName)) {
          await _collectGraph(entityName, into, seen);
        }
      }
    }
  }

  /// Manual additions (`import|Entity` lines) — user-declared expected
  /// adapters.
  void _collectManualAdditions(List<String> into, Set<String> seen) {
    final manualPath = p.join(outputDir, 'cache', 'hive_manual_additions.txt');
    final content = fileSystem.existsSync(manualPath)
        ? fileSystem.readSync(manualPath)
        : '';
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split('|');
      if (parts.length != 2) continue;
      final entityName = parts[1].trim();
      if (entityName.isEmpty || seen.contains(entityName)) continue;
      seen.add(entityName);
      into.add(entityName);
    }
  }

  /// Parses `AdapterSpec<X>()` declarations out of the registrar.
  Future<List<String>> _registeredEntities() async {
    final registrarPath = p.join(outputDir, 'cache', 'hive_registrar.dart');
    if (!await fileSystem.exists(registrarPath)) return const [];
    final content = await fileSystem.read(registrarPath);
    final registered = <String>[];
    for (final match in RegExp(r'AdapterSpec<(\w+)>').allMatches(content)) {
      final name = match.group(1)!;
      if (!registered.contains(name)) registered.add(name);
    }
    return registered;
  }

  /// Receipt-based staleness: compares the current registrar bytes and
  /// the entity source against the digests the last `zfa cache adapter`
  /// run recorded. Only `cache adapter` receipts are consulted (the
  /// canonical `<plugin> <capability>` command format — issue #996).
  Future<List<CacheVerifyFinding>> _receiptDriftFindings(
    String entityName,
  ) async {
    final findings = <CacheVerifyFinding>[];
    final store = ReceiptStore(projectRoot: projectRoot);
    final records = await store.loadAll();
    final relevant = records
        .where((r) => r.receipt.command == 'cache adapter')
        .toList();
    if (relevant.isEmpty) return findings;

    // Registrar digest drift (latest receipt wins per path).
    final registrarRel = _projectRelative(
      p.join(outputDir, 'cache', 'hive_registrar.dart'),
    );
    final latestRegistrar = ReceiptStore.latestForPath(relevant, registrarRel);
    if (latestRegistrar != null) {
      final registrarFile = File(p.join(projectRoot, registrarRel));
      if (registrarFile.existsSync()) {
        final actual = crypto.sha256
            .convert(registrarFile.readAsBytesSync())
            .toString();
        if (actual != latestRegistrar.entry.sha256) {
          findings.add(
            CacheVerifyFinding(
              kind: CacheVerifyFinding.kindStale,
              entity: 'registrar',
              detail:
                  'hive_registrar.dart drifted from the bytes its '
                  'generation receipt recorded (hand-edited?)',
              fix: 'zfa cache adapter $entityName',
            ),
          );
        }
      }
    }

    // Entity source drift: the spec the receipt bound no longer matches.
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityRel = _projectRelative(
      p.join(outputDir, 'domain', 'entities', entitySnake, '$entitySnake.dart'),
    );
    final latestEntity = ReceiptStore.latestForPath(relevant, entityRel);
    if (latestEntity != null) {
      final spec = latestEntity.record.receipt.spec;
      if (spec != null && spec.path == entityRel) {
        final entityFile = File(p.join(projectRoot, entityRel));
        if (entityFile.existsSync()) {
          final actual = crypto.sha256
              .convert(entityFile.readAsBytesSync())
              .toString();
          if (actual != spec.sha256) {
            findings.add(
              CacheVerifyFinding(
                kind: CacheVerifyFinding.kindStale,
                entity: entityName,
                detail:
                    'entity source $entityRel changed since the adapter '
                    'registration — the discovered adapter set may be '
                    'outdated',
                fix: 'zfa cache adapter $entityName',
              ),
            );
          }
        }
      }
    }

    return findings;
  }

  Future<List<String>> _availableEntities() async {
    final entitiesDir = p.join(outputDir, 'domain', 'entities');
    final available = <String>[];
    if (!await fileSystem.exists(entitiesDir)) return available;
    for (final item in await fileSystem.list(entitiesDir)) {
      if (!await fileSystem.isDirectory(item)) continue;
      final dirName = p.basename(item);
      if (dirName == 'enums') {
        final enumIndex = p.join(item, 'index.dart');
        if (await fileSystem.exists(enumIndex)) {
          final content = await fileSystem.read(enumIndex);
          for (final match in RegExp(r'enum\s+(\w+)').allMatches(content)) {
            available.add(match.group(1)!);
          }
        }
        continue;
      }
      if (await fileSystem.exists(p.join(item, '$dirName.dart'))) {
        available.add(StringUtils.convertToPascalCase(dirName));
      }
    }
    return available;
  }

  /// Extracts the base type from a field type string (handles generics)
  /// — same shape as the adapter capability's helper.
  String? _extractBaseType(String type) {
    final cleanType = type.replaceAll('?', '');
    final genericMatch = RegExp(r'(\w+)<(.+)>').firstMatch(cleanType);
    if (genericMatch != null) {
      return genericMatch.group(2)?.replaceAll('?', '');
    }
    return cleanType;
  }

  String _projectRelative(String path) {
    final abs = p.isAbsolute(path)
        ? p.canonicalize(path)
        : p.canonicalize(p.absolute(path));
    final rel = p.relative(abs, from: p.canonicalize(projectRoot));
    return p.normalize(rel).replaceAll('\\', '/');
  }
}
