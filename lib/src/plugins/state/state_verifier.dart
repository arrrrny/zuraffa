/// Spec 1126 (order 1) — the state drift gate.
///
/// [StateVerifier] compares the CURRENT state class on disk against the
/// contract `zfa state create` recorded in the stable per-entity
/// receipt (`.zfa/receipts/state-<entity>.json`, spec 1126 order 2):
///
///   * which contract methods MATCH the class (their derived
///     `is<Continuous>` member is declared and every digest is clean),
///   * which are STALE — the member is declared but the artifact bytes
///     or the entity source drifted after create (entity changed, state
///     not regenerated; hand-edited state),
///   * which are MISSING — the contract method has no member in the
///     parsed state class.
///
/// Detection is AST-driven (package:analyzer `parseString`, defensive —
/// a malformed state file is a finding, never a crash), so comments or
/// strings never trip the gate. Every finding carries the file, the
/// member and the `--> fix:` line; the command turns the report into
/// the canonical verdict envelope (SPEC 1105).
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import '../../utils/string_utils.dart';
import 'state_receipt.dart';

/// One verification finding (the provider/datasource shape).
class StateVerifyFinding {
  static const kindMissingReceipt = 'missing_receipt';
  static const kindMissingFile = 'missing_file';
  static const kindParseError = 'parse_error';
  static const kindModified = 'modified';
  static const kindStaleEntity = 'stale_entity';
  static const kindMissingMethod = 'missing_method';

  final String kind;
  final String file;
  final String method;
  final String detail;

  /// The actionable line, already prefixed `--> fix: `.
  final String fix;

  const StateVerifyFinding({
    required this.kind,
    required this.file,
    required this.method,
    required this.detail,
    required this.fix,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'file': file,
    'method': method,
    'detail': detail,
    'fix': fix,
  };
}

/// The verdict of one `zfa state verify <Entity>` run.
class StateVerifyReport {
  final bool ok;
  final String entity;
  final String stateClass;

  /// The state file that was audited (null when none was found).
  final String? stateFile;

  /// Contract methods whose derived member is present and whose
  /// artifact + entity digests are clean.
  final List<String> methodsMatched;

  /// Contract methods whose member is present but whose artifact or
  /// entity digest drifted (entity changed, state not regenerated).
  final List<String> methodsStale;

  /// Contract methods with no member in the parsed state class.
  final List<String> methodsMissing;

  final List<StateVerifyFinding> findings;

  /// The receipt the gate audited against (null when absent).
  final String? receiptFile;

  const StateVerifyReport({
    required this.ok,
    required this.entity,
    required this.stateClass,
    required this.stateFile,
    required this.methodsMatched,
    required this.methodsStale,
    required this.methodsMissing,
    required this.findings,
    this.receiptFile,
  });

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'ok': ok,
    'entity': entity,
    'stateClass': stateClass,
    'stateFile': stateFile,
    'receipt': receiptFile,
    'methodsMatched': methodsMatched,
    'methodsStale': methodsStale,
    'methodsMissing': methodsMissing,
    'findings': findings.map((f) => f.toJson()).toList(),
  };
}

/// The state drift gate. Stateless; instantiate freely.
class StateVerifier {
  const StateVerifier();

  Future<StateVerifyReport> verify({
    required String projectRoot,
    required String outputDir,
    required String entity,
    List<String>? methods,
    String? domain,
  }) async {
    final receiptDoc = StateReceiptWriter.load(projectRoot, entity);
    final receiptPath = StateReceiptWriter.receiptPath(projectRoot, entity);

    if (receiptDoc == null) {
      final fix = ExitFix.createFirst(entity);
      return StateVerifyReport(
        ok: false,
        entity: entity,
        stateClass: '${entity}State',
        stateFile: null,
        methodsMatched: const [],
        methodsStale: const [],
        methodsMissing: const [],
        findings: [
          StateVerifyFinding(
            kind: StateVerifyFinding.kindMissingReceipt,
            file: _rel(receiptPath, projectRoot),
            method: '',
            detail:
                'no state receipt for $entity — the gate cannot audit '
                'a generation that never recorded a contract',
            fix: fix,
          ),
        ],
      );
    }

    final stateClass =
        receiptDoc['state_class']?.toString() ?? '${entity}State';

    // ── File resolution: receipt path first, then the conventional shape.
    final stateFile = _resolveStateFile(
      projectRoot: projectRoot,
      outputDir: outputDir,
      entity: entity,
      domain: domain ?? (receiptDoc['domain']?.toString()),
      receiptDoc: receiptDoc,
    );
    if (stateFile == null || !stateFile.existsSync()) {
      return StateVerifyReport(
        ok: false,
        entity: entity,
        stateClass: stateClass,
        stateFile: null,
        methodsMatched: const [],
        methodsStale: const [],
        methodsMissing: const [],
        findings: [
          StateVerifyFinding(
            kind: StateVerifyFinding.kindMissingFile,
            file: _receiptBoundPath(receiptDoc) ?? '(unknown)',
            method: '',
            detail:
                'the state file for $stateClass does not exist (deleted '
                'or never generated)',
            fix: ExitFix.regenerate(entity),
          ),
        ],
        receiptFile: _rel(receiptPath, projectRoot),
      );
    }
    final stateFileRel = _rel(stateFile.path, projectRoot);

    // ── Contract methodset: receipt methods, flags override.
    final contract =
        methods ??
        ((receiptDoc['methods'] as List?)
                ?.map((m) => m.toString())
                .toList(growable: false) ??
            const <String>[]);

    final findings = <StateVerifyFinding>[];

    // ── Artifact freshness: current bytes vs the create digest.
    final stateSha =
        receiptDoc['state_sha256']?.toString() ?? _receiptBoundSha(receiptDoc);
    final currentBytes = stateFile.readAsBytesSync();
    final currentSha = crypto.sha256.convert(currentBytes).toString();
    final artifactClean = stateSha == null || stateSha == currentSha;
    if (stateSha != null && stateSha != currentSha) {
      findings.add(
        StateVerifyFinding(
          kind: StateVerifyFinding.kindModified,
          file: stateFileRel,
          method: '',
          detail:
              'the state file bytes changed after create '
              '(receipt sha256 $stateSha, on disk $currentSha)',
          fix: ExitFix.regenerate(entity),
        ),
      );
    }

    // ── Entity freshness: the entity source hash the create bound.
    final entitySource = receiptDoc['entity_source'] as Map<String, dynamic>?;
    var entityClean = true;
    if (entitySource != null) {
      final entityPath = entitySource['path']?.toString();
      final entitySha = entitySource['sha256']?.toString();
      if (entityPath != null) {
        final entityFile = File(
          p.isAbsolute(entityPath)
              ? entityPath
              : p.join(projectRoot, entityPath),
        );
        if (!entityFile.existsSync()) {
          entityClean = false;
          findings.add(
            StateVerifyFinding(
              kind: StateVerifyFinding.kindStaleEntity,
              file: entityPath,
              method: '',
              detail:
                  'the entity source the state was generated FROM is '
                  'gone (state not regenerated since)',
              fix: ExitFix.regenerate(entity),
            ),
          );
        } else {
          final currentEntitySha = crypto.sha256
              .convert(entityFile.readAsBytesSync())
              .toString();
          if (entitySha != null && entitySha != currentEntitySha) {
            entityClean = false;
            findings.add(
              StateVerifyFinding(
                kind: StateVerifyFinding.kindStaleEntity,
                file: entityPath,
                method: '',
                detail:
                    'the entity source changed after create (the state '
                    'class was not regenerated against the new entity)',
                fix: ExitFix.regenerate(entity),
              ),
            );
          }
        }
      }
    }

    // ── Member conformance: every contract method must surface its
    //    derived is<Continuous> member in the parsed state class.
    final parsed = _parseStateClassMembers(stateFile, stateClass);
    if (parsed.parseFailed) {
      findings.add(
        StateVerifyFinding(
          kind: StateVerifyFinding.kindParseError,
          file: stateFileRel,
          method: '',
          detail:
              'the state file does not parse — the gate cannot audit a '
              'malformed class',
          fix: ExitFix.regenerate(entity),
        ),
      );
    } else if (parsed.classMissing) {
      findings.add(
        StateVerifyFinding(
          kind: StateVerifyFinding.kindMissingFile,
          file: stateFileRel,
          method: '',
          detail: 'no `$stateClass` class declared in the state file',
          fix: ExitFix.regenerate(entity),
        ),
      );
    }

    final matched = <String>[];
    final stale = <String>[];
    final missing = <String>[];
    for (final method in contract) {
      final member = 'is${StringUtils.toContinuous(method)}';
      if (!parsed.classMissing && parsed.members.contains(member)) {
        if (artifactClean && entityClean) {
          matched.add(method);
        } else {
          stale.add(method);
        }
      } else {
        missing.add(method);
        findings.add(
          StateVerifyFinding(
            kind: StateVerifyFinding.kindMissingMethod,
            file: stateFileRel,
            method: member,
            detail:
                'the contract method `$method` has no `$member` member '
                'in $stateClass',
            fix: ExitFix.regenerate(entity),
          ),
        );
      }
    }

    return StateVerifyReport(
      ok: findings.isEmpty,
      entity: entity,
      stateClass: stateClass,
      stateFile: stateFileRel,
      methodsMatched: matched,
      methodsStale: stale,
      methodsMissing: missing,
      findings: findings,
      receiptFile: _rel(receiptPath, projectRoot),
    );
  }

  File? _resolveStateFile({
    required String projectRoot,
    required String outputDir,
    required String entity,
    required String? domain,
    required Map<String, dynamic> receiptDoc,
  }) {
    // 1. The receipt binds the exact file the create run wrote.
    final files = receiptDoc['files'];
    if (files is List && files.isNotEmpty) {
      final first = files.first;
      if (first is Map) {
        final path = Map<String, dynamic>.from(first)['path']?.toString();
        if (path != null) {
          final candidate = File(
            p.isAbsolute(path) ? path : p.join(projectRoot, path),
          );
          if (candidate.existsSync()) return candidate;
        }
      }
    }

    // 2. The conventional shape the builder emits.
    final snake = StringUtils.camelToSnake(entity);
    final domainSnake = domain ?? StringUtils.camelToSnake(entity);
    return File(
      p.isAbsolute(outputDir)
          ? p.join(
              outputDir,
              'presentation',
              'pages',
              domainSnake,
              '${snake}_state.dart',
            )
          : p.join(
              projectRoot,
              outputDir,
              'presentation',
              'pages',
              domainSnake,
              '${snake}_state.dart',
            ),
    );
  }

  String? _receiptBoundPath(Map<String, dynamic> receiptDoc) {
    final files = receiptDoc['files'];
    if (files is List && files.isNotEmpty) {
      final first = files.first;
      if (first is Map) {
        return Map<String, dynamic>.from(first)['path']?.toString();
      }
    }
    return null;
  }

  String? _receiptBoundSha(Map<String, dynamic> receiptDoc) {
    final files = receiptDoc['files'];
    if (files is List && files.isNotEmpty) {
      final first = files.first;
      if (first is Map) {
        return Map<String, dynamic>.from(first)['sha256']?.toString();
      }
    }
    return null;
  }

  ({bool parseFailed, bool classMissing, Set<String> members})
  _parseStateClassMembers(File stateFile, String stateClass) {
    try {
      final result = parseString(
        content: stateFile.readAsStringSync(),
        path: stateFile.path,
        throwIfDiagnostics: false,
      );
      for (final decl
          in result.unit.declarations.whereType<ClassDeclaration>()) {
        if (decl.namePart.beginToken.lexeme != stateClass) continue;
        final body = decl.body;
        if (body is! BlockClassBody) continue;
        final members = <String>{};
        for (final member in body.members) {
          if (member is FieldDeclaration) {
            for (final variable in member.fields.variables) {
              members.add(variable.name.lexeme);
            }
          } else if (member is MethodDeclaration && member.isGetter) {
            members.add(member.name.lexeme);
          }
        }
        return (parseFailed: false, classMissing: false, members: members);
      }
      return (
        parseFailed: false,
        classMissing: true,
        members: const <String>{},
      );
    } catch (_) {
      return (parseFailed: true, classMissing: true, members: const <String>{});
    }
  }

  static String _rel(String filePath, String projectRoot) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: projectRoot)
        : filePath;
    return p.normalize(rel).replaceAll('\\', '/');
  }
}

/// The `--> fix:` lines (the machine-actionable suffix every finding
/// ends with — VISION §4).
abstract final class ExitFix {
  static String createFirst(String entity) =>
      '--> fix: generate it first — `zfa state create --name $entity` '
      '(the gate cannot audit a generation that has no receipt)';

  static String regenerate(String entity) =>
      '--> fix: regenerate — `zfa state create --name $entity --force` '
      'brings the state class back under the contract';
}
