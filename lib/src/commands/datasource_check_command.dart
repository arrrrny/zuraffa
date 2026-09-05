import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../utils/string_utils.dart';

/// A method-parity divergence between the datasource interface and one
/// implementation.
class _Divergence {
  final String method;
  final String implFile;
  final String interfaceFile;
  final String detail;

  const _Divergence({
    required this.method,
    required this.implFile,
    required this.interfaceFile,
    required this.detail,
  });

  String get fixLine =>
      '--> fix: $detail — method `$method`, file `$implFile` '
      '(interface: `$interfaceFile`)';
}

/// `zfa datasource check <Entity>` (spec #977).
///
/// Parity gate between the generated datasource interface and every
/// generated implementation (remote / local / sqlite variants) found in
/// `lib/src/data/datasources/<entity>/`:
///
/// - every PUBLIC method declared in `<Entity>DataSource` must be
///   declared by each implementation (#417 drift class: an impl that
///   silently misses an interface method);
/// - every method an implementation marks `@override` must be declared
///   by the interface (the reverse drift);
/// - extra public methods WITHOUT `@override` (the local Hive variant's
///   `save`/`saveAll`/`clear` helpers) are legitimate and never flagged.
///
/// Exit codes: 0 = parity, 1 = divergence or missing interface (always
/// with a `--> fix:` line naming the method and the file), 64 = missing
/// entity argument.
class DataSourceCheckCommand extends Command<void> {
  /// Project root the datasources are resolved against. Defaults to the
  /// current working directory, mirroring the receipt store.
  final String? projectRoot;

  DataSourceCheckCommand({this.projectRoot});

  @override
  String get name => 'check';

  @override
  String get description =>
      'Check datasource interface/implementation method parity for an entity';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const [];
    if (rest.isEmpty) {
      print('❌ Usage: zfa datasource check <Entity>');
      print('   Example: zfa datasource check Product');
      exitCode = 64;
      return;
    }

    final entity = rest.first;
    final capEntity = entity.isEmpty
        ? entity
        : '${entity[0].toUpperCase()}${entity.substring(1)}';
    final interfaceName = '${capEntity}DataSource';
    final snake = StringUtils.camelToSnake(entity);
    final root = projectRoot ?? Directory.current.path;
    final dir = Directory(
      p.join(root, 'lib', 'src', 'data', 'datasources', snake),
    );

    final interfaceFile = File(p.join(dir.path, '${snake}_datasource.dart'));
    if (!interfaceFile.existsSync()) {
      print(
        '❌ datasource check failed: no interface at '
        '`lib/src/data/datasources/$snake/${snake}_datasource.dart`.',
      );
      print(
        '--> fix: generate the datasource first, e.g. '
        '`zfa datasource create $entity`, then re-run '
        '`zfa datasource check $entity`.',
      );
      exitCode = 1;
      return;
    }

    final interface = _ClassShape.of(
      parseResult: _parse(interfaceFile),
      preferredName: interfaceName,
    );

    if (interface == null) {
      print(
        '❌ datasource check failed: no class `$interfaceName` found in '
        '`$interfaceFile`.',
      );
      print(
        '--> fix: the interface file is corrupted or was renamed — '
        'regenerate it with `zfa datasource create $entity`.',
      );
      exitCode = 1;
      return;
    }

    final implFiles =
        dir
            .listSync()
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('_datasource.dart') &&
                  p.basename(f.path) != '${snake}_datasource.dart',
            )
            .toList()
          ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    final divergences = <_Divergence>[];
    final checkedImpls = <String>[];

    for (final implFile in implFiles) {
      final relImpl = _rel(implFile.path);
      final unit = _parse(implFile);
      final allShapes = _ClassShape.allOf(parseResult: unit);

      // The implementation class: the one that implements/extends the
      // interface; fall back to the first class declared in the file.
      _ClassShape? impl;
      for (final shape in allShapes) {
        if (shape.supertypeNames.contains(interfaceName)) {
          impl = shape;
          break;
        }
      }
      impl ??= allShapes.isEmpty ? null : allShapes.first;

      if (impl == null) {
        divergences.add(
          _Divergence(
            method: interface.publicMethods.join(', '),
            implFile: relImpl,
            interfaceFile: _rel(interfaceFile.path),
            detail: 'no implementation class of `$interfaceName` found',
          ),
        );
        continue;
      }

      checkedImpls.add(relImpl);

      for (final method in interface.publicMethods) {
        if (!impl.declaredMethods.contains(method)) {
          divergences.add(
            _Divergence(
              method: method,
              implFile: relImpl,
              interfaceFile: _rel(interfaceFile.path),
              detail:
                  'implementation `${impl.name}` is missing a method declared '
                  'in `$interfaceName`',
            ),
          );
        }
      }

      for (final method in impl.overrideMethods) {
        if (!interface.declaredMethods.contains(method)) {
          divergences.add(
            _Divergence(
              method: method,
              implFile: relImpl,
              interfaceFile: _rel(interfaceFile.path),
              detail:
                  '`${impl.name}` marks `@override` for a method the '
                  'interface `$interfaceName` does not declare',
            ),
          );
        }
      }
    }

    if (divergences.isNotEmpty) {
      print(
        '❌ datasource check failed for `$entity`: '
        '${divergences.length} parity divergence(s) '
        'between `$interfaceName` and its implementations.',
      );
      for (final d in divergences) {
        print(d.fixLine);
      }
      exitCode = 1;
      return;
    }

    print(
      '✅ datasource parity OK for `$entity`: `$interfaceName` vs '
      '${checkedImpls.isEmpty ? '(no implementation files)' : checkedImpls.join(', ')} '
      '— all public methods at parity.',
    );
    exitCode = 0;
  }

  /// Parses [file] syntactically; an unparsable file yields an empty
  /// unit, which the parity logic reports as a divergence via the
  /// missing-class path.
  CompilationUnit _parse(File file) {
    try {
      return parseString(
        content: file.readAsStringSync(),
        path: file.path,
        throwIfDiagnostics: false,
      ).unit;
    } catch (_) {
      return parseString(content: '').unit;
    }
  }

  String _rel(String filePath) {
    final root = projectRoot ?? Directory.current.path;
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: root)
        : filePath;
    return p.normalize(rel).replaceAll('\\', '/');
  }
}

/// The parity-relevant shape of one class declaration.
class _ClassShape {
  final String name;
  final Set<String> declaredMethods;
  final Set<String> overrideMethods;
  final Set<String> supertypeNames;

  const _ClassShape({
    required this.name,
    required this.declaredMethods,
    required this.overrideMethods,
    required this.supertypeNames,
  });

  /// Public method names the class declares (private helpers are not
  /// part of the parity contract).
  Set<String> get publicMethods =>
      declaredMethods.where((m) => !m.startsWith('_')).toSet();

  static List<_ClassShape> allOf({required CompilationUnit parseResult}) {
    final shapes = <_ClassShape>[];
    for (final declaration
        in parseResult.declarations.whereType<ClassDeclaration>()) {
      final body = declaration.body;
      if (body is! BlockClassBody) continue;
      final className = declaration.namePart.typeName.lexeme;
      final methods = <String>{};
      final overrides = <String>{};
      final supers = <String>{};

      for (final member in body.members) {
        if (member is! MethodDeclaration) continue;
        final methodName = member.name.lexeme;
        methods.add(methodName);
        final isOverride = member.metadata.any(
          (a) => a.name.name == 'override',
        );
        if (isOverride) overrides.add(methodName);
      }

      final implementsClause = declaration.implementsClause;
      if (implementsClause != null) {
        for (final t in implementsClause.interfaces) {
          supers.add(t.name.lexeme);
        }
      }
      final extendsClause = declaration.extendsClause;
      if (extendsClause != null) {
        supers.add(extendsClause.superclass.name.lexeme);
      }
      final withClause = declaration.withClause;
      if (withClause != null) {
        for (final t in withClause.mixinTypes) {
          supers.add(t.name.lexeme);
        }
      }

      shapes.add(
        _ClassShape(
          name: className,
          declaredMethods: methods,
          overrideMethods: overrides,
          supertypeNames: supers,
        ),
      );
    }
    return shapes;
  }

  static _ClassShape? of({
    required CompilationUnit parseResult,
    required String preferredName,
  }) {
    final all = allOf(parseResult: parseResult);
    for (final shape in all) {
      if (shape.name == preferredName) return shape;
    }
    return all.isEmpty ? null : all.first;
  }
}
