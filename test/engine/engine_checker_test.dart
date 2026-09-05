// Spec 1002 — EngineChecker unit tests.
//
// `zfa engine check <Entity>` resolves every getIt<T>() call in the
// generated engine against generated classes and fails with `--> fix:`
// on any dangling reference (issue #1002, deliverable 2). It also guards
// the engine-slice purity exit criterion: zero package:flutter imports in
// the slice's lib files and test tree.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/engine/engine_checker.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_engine_checker_');
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

  /// Minimal canonical engine slice: entity + repository + remote datasource
  /// + mock + per-method usecase DI + repository DI + composition root.
  Future<void> writeCanonicalSlice() async {
    await writeFile('lib/src/domain/entities/login/login.dart', '''
class Login {
  final String id;
  const Login({required this.id});
}
''');
    await writeFile('lib/src/domain/repositories/login_repository.dart', '''
abstract class LoginRepository {}
''');
    await writeFile('lib/src/data/datasources/login/login_datasource.dart', '''
abstract class LoginDataSource {}
''');
    await writeFile(
      'lib/src/data/datasources/login/login_remote_datasource.dart',
      'class LoginRemoteDataSource implements LoginDataSource {}',
    );
    await writeFile(
      'lib/src/data/datasources/login/login_mock_datasource.dart',
      'class LoginMockDataSource implements LoginDataSource {}',
    );
    await writeFile('lib/src/data/mock/login_mock_data.dart', '''
class LoginMockData {}
''');
    await writeFile('lib/src/domain/usecases/login/get_login_usecase.dart', '''
class GetLoginUseCase {
  final LoginRepository repo;
  GetLoginUseCase(this.repo);
}
''');
    await writeFile('lib/src/data/repositories/data_login_repository.dart', '''
class DataLoginRepository implements LoginRepository {}
''');
    await writeFile('lib/src/di/usecases/get_login_usecase_di.dart', '''
import 'package:get_it/get_it.dart';

void registerGetLoginUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetLoginUseCase>(
    () => GetLoginUseCase(getIt<LoginRepository>()),
  );
}
''');
    await writeFile('lib/src/di/repositories/login_repository_di.dart', '''
import 'package:get_it/get_it.dart';

void registerLoginRepository(GetIt getIt) {
  getIt.registerLazySingleton<LoginRepository>(
    () => DataLoginRepository(getIt<LoginRemoteDataSource>()),
  );
}
''');
    await writeFile('lib/src/di/index.dart', '''
import 'package:get_it/get_it.dart';

void setupDependencies(GetIt getIt) {
  registerGetLoginUseCase(getIt);
  registerLoginRepository(getIt);
}
''');
  }

  test('passes on a fully-resolved engine slice', () async {
    await writeCanonicalSlice();

    final result = await EngineChecker.check(
      entity: 'Login',
      projectRoot: workspace.path,
    );

    expect(
      result.failures,
      isEmpty,
      reason: 'failures: ${result.failures.map((f) => f.message)}',
    );
    expect(result.passed, isTrue);
    expect(result.resolvedTypes, containsAll(['LoginRepository']));
    expect(
      result.resolutions.map((r) => r.typeName),
      containsAll(['LoginRepository', 'LoginRemoteDataSource']),
    );
  });

  test('fails with --> fix: on a dangling getIt reference', () async {
    await writeCanonicalSlice();
    // The datasource DI registration was never generated: delete the
    // datasource class so getIt<LoginRemoteDataSource>() dangles.
    await File(
      p.join(
        workspace.path,
        'lib/src/data/datasources/login',
        'login_remote_datasource.dart',
      ),
    ).delete();

    final result = await EngineChecker.check(
      entity: 'Login',
      projectRoot: workspace.path,
    );

    expect(result.passed, isFalse);
    final dangling = result.resolutions.where((r) => !r.resolved).toList();
    expect(dangling.map((r) => r.typeName), contains('LoginRemoteDataSource'));
    final fixMessages = result.failures
        .where((f) => f.typeName == 'LoginRemoteDataSource')
        .map((f) => f.message)
        .toList();
    expect(fixMessages, isNotEmpty);
    expect(
      fixMessages.first,
      contains('--> fix:'),
      reason: 'dangling reference must carry a fix hint',
    );
  });

  test('fails with --> fix: when the entity file is missing', () async {
    final result = await EngineChecker.check(
      entity: 'Ghost',
      projectRoot: workspace.path,
    );

    expect(result.passed, isFalse);
    expect(
      result.failures.map((f) => f.message).any((m) => m.contains('--> fix:')),
      isTrue,
    );
  });

  test('fails on package:flutter imports in the engine slice', () async {
    await writeCanonicalSlice();
    await writeFile('lib/src/domain/repositories/login_repository.dart', '''
import 'package:flutter/material.dart';

abstract class LoginRepository {}
''');

    final result = await EngineChecker.check(
      entity: 'Login',
      projectRoot: workspace.path,
    );

    expect(result.passed, isFalse);
    expect(
      result.failures
          .where((f) => f.code == EngineFindingCode.flutterImport)
          .map((f) => f.message)
          .any((m) => m.contains('--> fix:')),
      isTrue,
      reason: 'flutter import in the slice must fail with a fix hint',
    );
  });

  test('fails on package:flutter imports in the slice test tree', () async {
    await writeCanonicalSlice();
    await writeFile(
      'test/domain/usecases/login/get_login_usecase_test.dart',
      '''
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('boom', () {});
}
''',
    );

    final result = await EngineChecker.check(
      entity: 'Login',
      projectRoot: workspace.path,
    );

    expect(result.passed, isFalse);
    expect(
      result.failures.where((f) => f.code == EngineFindingCode.flutterImport),
      isNotEmpty,
      reason:
          'exit criterion: zero package:flutter references in the '
          "engine slice's test tree",
    );
  });

  test('uncertified mocks fail the engine check', () async {
    await writeCanonicalSlice();
    // The mock datasource class exists but the seeded data fixture does not.
    await File(
      p.join(workspace.path, 'lib/src/data/mock/login_mock_data.dart'),
    ).delete();

    final result = await EngineChecker.check(
      entity: 'Login',
      projectRoot: workspace.path,
      methods: const ['get'],
    );

    expect(result.passed, isFalse);
    expect(
      result.failures.where((f) => f.code == EngineFindingCode.uncertifiedMock),
      isNotEmpty,
    );
  });

  test('getIt resolution ignores lookups in other entities DI files', () async {
    await writeCanonicalSlice();
    // A different entity's registration file references a type that does
    // not exist — engine check Login must NOT fail for Product's wiring.
    await writeFile('lib/src/di/repositories/product_repository_di.dart', '''
import 'package:get_it/get_it.dart';

void registerProductRepository(GetIt getIt) {
  getIt.registerLazySingleton<ProductRepository>(
    () => DataProductRepository(getIt<ProductRemoteDataSource>()),
  );
}
''');

    final result = await EngineChecker.check(
      entity: 'Login',
      projectRoot: workspace.path,
    );

    expect(
      result.resolvedTypes,
      isNot(contains('ProductRemoteDataSource')),
      reason: 'engine check Login is scoped to Login engine files',
    );
    expect(result.passed, isTrue);
  });

  test('resolution accepts a type declared anywhere under lib/', () async {
    await writeCanonicalSlice();
    // LoginService is declared in the domain services layer and looked up
    // from Login's provider DI — resolution must find the declaration even
    // though there is no dedicated DI registration file naming convention.
    await writeFile('lib/src/domain/services/login_service.dart', '''
abstract class LoginService {}
''');
    await writeFile('lib/src/di/providers/login_provider_di.dart', '''
import 'package:get_it/get_it.dart';

void registerLoginProvider(GetIt getIt) {
  getIt.registerLazySingleton<LoginProvider>(
    () => LoginProvider(getIt<LoginService>()),
  );
}
''');
    await writeFile('lib/src/data/providers/login_provider.dart', '''
class LoginProvider {
  final LoginService service;
  LoginProvider(this.service);
}
''');

    final result = await EngineChecker.check(
      entity: 'Login',
      projectRoot: workspace.path,
    );

    expect(
      result.passed,
      isTrue,
      reason: 'failures: ${result.failures.map((f) => f.message)}',
    );
    expect(result.resolvedTypes, contains('LoginService'));
  });
}
