/// MockCertifier (spec 1002): per-method certification of the generated
/// mock datasource.
///
/// `zfa make engine <Entity>` chains `mock create --certify` as an
/// explicit step, and `engine.receipt.json` records
/// `mock_certified: true` per method. A method is certified when:
///
///   1. the mock datasource file was generated
///      (`lib/src/data/datasources/<snake>/<snake>_mock_datasource.dart`);
///   2. the method is declared on it (an `@override` member with the
///      method's name);
///   3. the seeded mock data fixture exists
///      (`lib/src/data/mock/<snake>_mock_data.dart`) — without it the
///      mock returns nothing at runtime.
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../core/ast/file_parser.dart';
import '../utils/string_utils.dart';
import 'engine_models.dart';

/// Certifies the generated mock artifacts for one entity.
class MockCertifier {
  /// Certifies [methods] against the mock artifacts of [entity] inside
  /// [projectRoot].
  static MockCertificationResult certify({
    required String entity,
    required List<String> methods,
    required String projectRoot,
  }) {
    final snake = StringUtils.camelToSnake(entity);
    final mockDatasource = File(
      p.join(
        projectRoot,
        'lib',
        'src',
        'data',
        'datasources',
        snake,
        '${snake}_mock_datasource.dart',
      ),
    );
    final mockData = File(
      p.join(
        projectRoot,
        'lib',
        'src',
        'data',
        'mock',
        '${snake}_mock_data.dart',
      ),
    );

    final String? mockDatasourcePath = mockDatasource.existsSync()
        ? p.relative(mockDatasource.path, from: projectRoot)
        : null;
    final String? mockDataPath = mockData.existsSync()
        ? p.relative(mockData.path, from: projectRoot)
        : null;

    final implemented = mockDatasource.existsSync()
        ? _methodNames(mockDatasource.readAsStringSync())
        : const <String>{};

    final certified = <String, bool>{
      for (final method in methods)
        method:
            implemented.contains(method) &&
            mockDatasourcePath != null &&
            mockDataPath != null,
    };

    return MockCertificationResult(
      mockDatasourcePath: mockDatasourcePath,
      mockDataPath: mockDataPath,
      methods: certified,
    );
  }

  /// Method names declared by any class in [source] — the mock datasource
  /// is a single generated class, so any member with the requested name
  /// (the builders emit `@override Future<...> name(...)`) counts as
  /// implemented.
  static Set<String> _methodNames(String source) {
    final result = const FileParser().parseSource(source);
    final unit = result.unit;
    if (unit == null) return const {};
    final names = <String>{};
    for (final declaration in unit.declarations) {
      if (declaration is! ClassDeclaration) continue;
      final body = declaration.body;
      if (body is! BlockClassBody) continue;
      for (final member in body.members) {
        if (member is MethodDeclaration) {
          names.add(member.name.lexeme);
        }
      }
    }
    return names;
  }
}
