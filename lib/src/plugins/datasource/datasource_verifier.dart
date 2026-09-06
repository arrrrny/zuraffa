/// Spec #1131 (order 1) — `zfa datasource verify <Entity>`.
///
/// The entity-conformance gate: verifies that the generated datasource
/// INTERFACE matches the ENTITY's field signatures. Where
/// `zfa datasource check` compares the interface against its
/// implementations (method parity), `verify` compares it against the
/// entity definition it was generated FROM:
///
///   * the entity source must exist and parse (a malformed entity is a
///     finding, never an uncaught exception — order 4);
///   * the entity class must exist and declare the configured id field;
///   * every `UpdateParams<T, ..>` / `DeleteParams<T>` /
///     `ToggleParams<T, ..>` type argument the interface wires must be
///     the entity's actual id-field type;
///   * every standard CRUD method the interface declares must reference
///     the entity type it serves.
///
/// Every divergence is a [DatasourceVerifyFinding] with a machine-actionable
/// `--> fix:` line; the CLI maps them onto exit 1 (drift) / 0 (clean).
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../../utils/string_utils.dart';

/// One entity-conformance divergence the verifier found.
class DatasourceVerifyFinding {
  /// The machine taxonomy: `missing entity source`, `malformed entity
  /// source`, `missing entity class`, `missing id field`,
  /// `missing interface`, `missing interface class`,
  /// `id-field type drift`, `entity type drift`.
  final String kind;

  /// The project-relative file the finding is about.
  final String file;

  /// The member (method or class) the finding is about.
  final String member;

  final String detail;

  final String fix;

  const DatasourceVerifyFinding({
    required this.kind,
    required this.file,
    required this.member,
    required this.detail,
    required this.fix,
  });

  String get fixLine => '--> fix: $fix';

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'file': file,
    'member': member,
    'detail': detail,
    'fix': fix,
  };
}

/// One entity field the verifier extracted from the entity source.
class EntityFieldRecord {
  final String name;
  final String type;

  const EntityFieldRecord({required this.name, required this.type});

  Map<String, dynamic> toJson() => {'name': name, 'type': type};
}

/// One interface method signature the verifier checked.
class InterfaceMethodRecord {
  final String name;
  final String signature;

  const InterfaceMethodRecord({required this.name, required this.signature});
}

/// The verify verdict for one entity.
class DatasourceVerifyReport {
  final String entity;
  final bool ok;
  final String? entitySourcePath;
  final String? interfacePath;
  final String idField;
  final String? entityFieldType;
  final List<EntityFieldRecord> entityFields;
  final List<InterfaceMethodRecord> methodsChecked;
  final List<DatasourceVerifyFinding> findings;

  const DatasourceVerifyReport({
    required this.entity,
    required this.ok,
    this.entitySourcePath,
    this.interfacePath,
    required this.idField,
    this.entityFieldType,
    this.entityFields = const [],
    this.methodsChecked = const [],
    this.findings = const [],
  });

  /// `drift` when the interface exists but drifts from the entity;
  /// `fail` for structural failures (missing/malformed sources).
  String get exitClass {
    if (ok) return 'ok';
    final structural = {
      'missing entity source',
      'malformed entity source',
      'missing entity class',
      'missing interface',
      'missing interface class',
    };
    return findings.any((f) => structural.contains(f.kind)) ? 'fail' : 'drift';
  }
}

/// The datasource verify gate. Stateless; instantiate freely.
class DatasourceVerifier {
  const DatasourceVerifier();

  /// The standard CRUD method names whose signatures must reference the
  /// entity type. Custom (non-CRUD) methods are never entity-checked.
  static const Set<String> _entityTypedMethods = {
    'get',
    'getList',
    'list',
    'create',
    'update',
    'toggle',
    'watch',
    'watchList',
  };

  /// The parameter type prefixes whose FIRST type argument is the entity's
  /// id-field type.
  static const Set<String> _idTypedParams = {
    'UpdateParams',
    'DeleteParams',
    'ToggleParams',
  };

  Future<DatasourceVerifyReport> verify({
    required String projectRoot,
    required String outputDir,
    required String entity,
    String idField = 'id',
  }) async {
    final findings = <DatasourceVerifyFinding>[];
    final capEntity = entity.isEmpty
        ? entity
        : '${entity[0].toUpperCase()}${entity.substring(1)}';
    final interfaceName = '${capEntity}DataSource';
    final snake = StringUtils.camelToSnake(entity);

    final entityFile = File(
      p.isAbsolute(outputDir)
          ? p.join(outputDir, 'domain', 'entities', snake, '$snake.dart')
          : p.join(
              projectRoot,
              outputDir,
              'domain',
              'entities',
              snake,
              '$snake.dart',
            ),
    );
    final interfaceFile = File(
      p.isAbsolute(outputDir)
          ? p.join(
              outputDir,
              'data',
              'datasources',
              snake,
              '${snake}_datasource.dart',
            )
          : p.join(
              projectRoot,
              outputDir,
              'data',
              'datasources',
              snake,
              '${snake}_datasource.dart',
            ),
    );

    final relEntity = _rel(entityFile.path, projectRoot);
    final relInterface = _rel(interfaceFile.path, projectRoot);

    // --- Entity source ---------------------------------------------------
    CompilationUnit? entityUnit;
    if (!entityFile.existsSync()) {
      findings.add(
        DatasourceVerifyFinding(
          kind: 'missing entity source',
          file: relEntity,
          member: capEntity,
          detail:
              'the datasource was generated FROM this entity, but the '
              'entity source is gone',
          fix:
              'restore the entity at `$relEntity` (e.g. `zfa make '
              '$capEntity`), then re-run `zfa datasource verify $entity`.',
        ),
      );
    } else {
      final parsed = _parse(entityFile);
      if (parsed == null) {
        findings.add(
          DatasourceVerifyFinding(
            kind: 'malformed entity source',
            file: relEntity,
            member: capEntity,
            detail:
                'the entity source does not parse — a malformed entity '
                'cannot prove the interface right or wrong',
            fix:
                'repair the syntax errors in `$relEntity`, then re-run '
                '`zfa datasource verify $entity`.',
          ),
        );
      } else {
        entityUnit = parsed;
      }
    }

    // --- Interface source ------------------------------------------------
    CompilationUnit? interfaceUnit;
    if (!interfaceFile.existsSync()) {
      findings.add(
        DatasourceVerifyFinding(
          kind: 'missing interface',
          file: relInterface,
          member: interfaceName,
          detail: 'no datasource interface at `$relInterface`',
          fix:
              'generate the datasource first, e.g. `zfa datasource create '
              '$entity`, then re-run `zfa datasource verify $entity`.',
        ),
      );
    } else {
      final parsed = _parse(interfaceFile);
      if (parsed == null) {
        findings.add(
          DatasourceVerifyFinding(
            kind: 'missing interface class',
            file: relInterface,
            member: interfaceName,
            detail: 'the interface file does not parse — regenerate it',
            fix:
                'the interface file is corrupted — regenerate it with '
                '`zfa datasource create $entity --force`.',
          ),
        );
      } else {
        interfaceUnit = parsed;
      }
    }

    // --- Entity class + fields -------------------------------------------
    String? entityFieldType;
    var entityFields = <EntityFieldRecord>[];
    var entityClassFound = false;

    if (entityUnit != null) {
      ClassDeclaration? entityClass;
      for (final decl
          in entityUnit.declarations.whereType<ClassDeclaration>()) {
        if (_className(decl) == capEntity) {
          entityClass = decl;
          break;
        }
      }
      if (entityClass == null) {
        findings.add(
          DatasourceVerifyFinding(
            kind: 'missing entity class',
            file: relEntity,
            member: capEntity,
            detail:
                'no class `$capEntity` in `$relEntity` — the entity was '
                'renamed or removed',
            fix:
                'regenerate the datasource against the real entity class '
                '(zfa datasource create <Entity> --force) or restore the '
                '`$capEntity` class in `$relEntity`.',
          ),
        );
      } else {
        entityClassFound = true;
        entityFields = _fieldsOf(entityClass);
        final idFieldRecord = entityFields
            .where((f) => f.name == idField)
            .toList();
        if (idFieldRecord.isNotEmpty) {
          entityFieldType = idFieldRecord.first.type;
        } else {
          entityFieldType = null;
        }
      }
    }

    // --- Interface class + method signatures ------------------------------
    var methodRecords = <InterfaceMethodRecord>[];
    ClassDeclaration? interfaceClass;
    if (interfaceUnit != null) {
      for (final decl
          in interfaceUnit.declarations.whereType<ClassDeclaration>()) {
        if (_className(decl) == interfaceName) {
          interfaceClass = decl;
          break;
        }
      }
      if (interfaceClass == null) {
        findings.add(
          DatasourceVerifyFinding(
            kind: 'missing interface class',
            file: relInterface,
            member: interfaceName,
            detail:
                'no class `$interfaceName` in `$relInterface` — the '
                'interface was renamed or hand-deleted',
            fix:
                'regenerate the interface with `zfa datasource create '
                '$entity --force`.',
          ),
        );
      } else {
        methodRecords = _methodsOf(interfaceClass);
      }
    }

    // --- Signature conformance -------------------------------------------
    if (interfaceClass != null && entityClassFound) {
      for (final method in methodRecords) {
        // 1. id-field type conformance: the first type argument of every
        //    UpdateParams/DeleteParams/ToggleParams parameter is the
        //    entity's id-field type.
        for (final idType in _idTypeArguments(method.signature)) {
          if (entityFieldType == null) {
            findings.add(
              DatasourceVerifyFinding(
                kind: 'missing id field',
                file: relInterface,
                member: method.name,
                detail:
                    '`${method.name}` wires the id-field type into '
                    'UpdateParams/DeleteParams/ToggleParams, but the entity '
                    'declares no field named `$idField`',
                fix:
                    'create the entity with an `$idField` field, or pass '
                    '--id-field when generating '
                    '(zfa datasource create $entity), then re-run '
                    '`zfa datasource verify $entity`.',
              ),
            );
          } else if (idType != entityFieldType) {
            findings.add(
              DatasourceVerifyFinding(
                kind: 'id-field type drift',
                file: relInterface,
                member: method.name,
                detail:
                    'the interface wires id-field type `$idType` but the '
                    'entity declares `$entityFieldType $idField`',
                fix:
                    'regenerate the datasource so the signature matches '
                    '`$entityFieldType $idField` '
                    '(zfa datasource create $entity --force), or pass '
                    '--id-field-type $entityFieldType when creating.',
              ),
            );
          }
        }

        // 2. entity-type conformance: standard CRUD methods must reference
        //    the entity class they serve.
        if (_entityTypedMethods.contains(method.name)) {
          final referenced = _referencedTypeNames(method.signature);
          if (!referenced.contains(capEntity)) {
            findings.add(
              DatasourceVerifyFinding(
                kind: 'entity type drift',
                file: relInterface,
                member: method.name,
                detail:
                    '`$method.name` no longer references the entity type '
                    '`$capEntity` (signature: ${method.signature})',
                fix:
                    'regenerate the datasource so `$method.name` maps the '
                    '`$capEntity` entity '
                    '(zfa datasource create $entity --force).',
              ),
            );
          }
        }
      }
    }

    return DatasourceVerifyReport(
      entity: entity,
      ok: findings.isEmpty,
      entitySourcePath: entityFile.existsSync() ? relEntity : null,
      interfacePath: interfaceFile.existsSync() ? relInterface : null,
      idField: idField,
      entityFieldType: entityFieldType,
      entityFields: entityFields,
      methodsChecked: methodRecords,
      findings: findings,
    );
  }

  /// Parses [file] syntactically; null when the source is malformed (the
  /// caller reports it — a broken entity must never crash the gate).
  CompilationUnit? _parse(File file) {
    try {
      final result = parseString(
        content: file.readAsStringSync(),
        path: file.path,
        throwIfDiagnostics: false,
      );
      // parseString collects SYNTACTIC diagnostics only — any diagnostic
      // here means the source is malformed for gate purposes.
      if (result.errors.isNotEmpty) return null;
      return result.unit;
    } catch (_) {
      return null;
    }
  }

  String _className(ClassDeclaration decl) => decl.namePart.typeName.lexeme;

  List<EntityFieldRecord> _fieldsOf(ClassDeclaration decl) {
    final body = decl.body;
    if (body is! BlockClassBody) return const [];
    final fields = <EntityFieldRecord>[];
    for (final member in body.members) {
      if (member is FieldDeclaration) {
        for (final variable in member.fields.variables) {
          final type = member.fields.type;
          fields.add(
            EntityFieldRecord(
              name: variable.name.lexeme,
              type: type == null ? 'dynamic' : type.toString(),
            ),
          );
        }
      }
    }
    return fields;
  }

  List<InterfaceMethodRecord> _methodsOf(ClassDeclaration decl) {
    final body = decl.body;
    if (body is! BlockClassBody) return const [];
    final records = <InterfaceMethodRecord>[];
    for (final member in body.members) {
      if (member is! MethodDeclaration) continue;
      if (member.isStatic) continue;
      final name = member.name.lexeme;
      // Rebuild the signature from the source tokens — the analyzer AST's
      // toString() is a debug form, not the emitted signature.
      final returnType = member.returnType?.toString() ?? 'void';
      final params = member.parameters?.toString() ?? '()';
      final signature = '$returnType $name$params';
      records.add(InterfaceMethodRecord(name: name, signature: signature));
    }
    return records;
  }

  /// The first type argument of every UpdateParams/DeleteParams/
  /// ToggleParams occurrence in [signature] (e.g. `UpdateParams<int,
  /// ProductPatch>` -> `int`).
  static Iterable<String> _idTypeArguments(String signature) sync* {
    for (final prefix in _idTypedParams) {
      var index = signature.indexOf('$prefix<');
      while (index >= 0) {
        final start = index + prefix.length + 1;
        final arg = _firstTypeArgument(signature, start);
        if (arg != null && arg.isNotEmpty) yield arg;
        index = signature.indexOf('$prefix<', start);
      }
    }
  }

  /// Scans forward from [start] (just after a `prefix<`) and returns the
  /// top-level first type argument, honouring nesting.
  static String? _firstTypeArgument(String source, int start) {
    final buffer = StringBuffer();
    var depth = 1;
    for (var i = start; i < source.length; i++) {
      final ch = source[i];
      if (ch == '<') depth++;
      if (ch == '>') {
        depth--;
        if (depth == 0) return buffer.toString().trim();
      }
      if (ch == ',' && depth == 1) {
        return buffer.toString().trim();
      }
      buffer.write(ch);
    }
    return null;
  }

  /// The identifier tokens in [signature] that look like type names
  /// (capitalised), so entity-type references are detectable regardless of
  /// where the emitter placed them.
  static Set<String> _referencedTypeNames(String signature) {
    final names = RegExp(
      r'\b[A-Z][A-Za-z0-9_]*',
    ).allMatches(signature).map((m) => m.group(0)!).toSet();
    return names;
  }

  static String _rel(String filePath, String projectRoot) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: projectRoot)
        : filePath;
    return p.normalize(rel).replaceAll('\\', '/');
  }
}
