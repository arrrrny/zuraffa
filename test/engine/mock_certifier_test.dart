// Spec 1002 — MockCertifier unit tests.
//
// The engine preset chains `mock create --certify`: every requested method
// must be certified as implemented on the generated mock datasource with
// seeded mock data present. These tests exercise the certifier against
// hand-written fixture trees (no generation, fast tier).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/engine/mock_certifier.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_mock_certifier_');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  Future<void> writeFile(String relPath, String content) async {
    final file = File(p.join(workspace.path, relPath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  test('certifies every method implemented on the mock datasource', () async {
    await writeFile(
      'lib/src/data/datasources/login/login_mock_datasource.dart',
      '''
// GENERATED - DO NOT EDIT
class LoginMockDataSource implements LoginDataSource {
  @override
  Future<Login> get(QueryParams<Login> params) async => Login();

  @override
  Future<List<Login>> getList(ListQueryParams<Login> params) async => [];

  @override
  Future<Login> create(Login item) async => item;
}
''',
    );
    await writeFile('lib/src/data/mock/login_mock_data.dart', '''
class LoginMockData {
  static final List<Login> logins = [];
}
''');

    final result = MockCertifier.certify(
      entity: 'Login',
      methods: const ['get', 'getList', 'create'],
      projectRoot: workspace.path,
    );

    expect(result.mockDatasourcePath, isNotNull);
    expect(result.mockDataPath, isNotNull);
    expect(result.methods, {'get': true, 'getList': true, 'create': true});
    expect(result.certified, isTrue, reason: 'all methods certified');
  });

  test('flags a method missing from the mock datasource', () async {
    await writeFile(
      'lib/src/data/datasources/login/login_mock_datasource.dart',
      '''
class LoginMockDataSource implements LoginDataSource {
  @override
  Future<Login> get(QueryParams<Login> params) async => Login();
}
''',
    );
    await writeFile('lib/src/data/mock/login_mock_data.dart', '''
class LoginMockData {}
''');

    final result = MockCertifier.certify(
      entity: 'Login',
      methods: const ['get', 'delete'],
      projectRoot: workspace.path,
    );

    expect(result.methods['get'], isTrue);
    expect(result.methods['delete'], isFalse, reason: 'delete not implemented');
    expect(result.certified, isFalse);
  });

  test('uncertified when the mock datasource file is missing', () async {
    final result = MockCertifier.certify(
      entity: 'Login',
      methods: const ['get'],
      projectRoot: workspace.path,
    );

    expect(result.mockDatasourcePath, isNull);
    expect(result.methods['get'], isFalse);
    expect(result.certified, isFalse);
  });

  test('uncertified when the mock data file is missing', () async {
    await writeFile(
      'lib/src/data/datasources/login/login_mock_datasource.dart',
      '''
class LoginMockDataSource implements LoginDataSource {
  @override
  Future<Login> get(QueryParams<Login> params) async => Login();
}
''',
    );

    final result = MockCertifier.certify(
      entity: 'Login',
      methods: const ['get'],
      projectRoot: workspace.path,
    );

    // Method is implemented but the seeded data fixture is absent — the
    // mock would return nothing at runtime, so certification must fail.
    expect(
      result.methods['get'],
      isFalse,
      reason: 'mock data file missing fails certification',
    );
    expect(result.certified, isFalse);
  });

  test('certifies an empty method set when the mock files exist', () async {
    await writeFile(
      'lib/src/data/datasources/login/login_mock_datasource.dart',
      '''
class LoginMockDataSource implements LoginDataSource {}
''',
    );
    await writeFile('lib/src/data/mock/login_mock_data.dart', '''
class LoginMockData {}
''');

    final result = MockCertifier.certify(
      entity: 'Login',
      methods: const [],
      projectRoot: workspace.path,
    );

    expect(result.methods, isEmpty);
    expect(
      result.certified,
      isTrue,
      reason: 'nothing requested, mock artifacts present',
    );
  });
}
