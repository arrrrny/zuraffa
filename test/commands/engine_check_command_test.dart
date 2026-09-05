// Spec 1002 — the `zfa engine check <Entity>` top-level verb.
//
// New verb: resolves all getIt<T>() calls in the generated engine against
// generated classes; fails with `--> fix:` on any dangling reference.
// Exit 0 on a clean engine, exit 1 + fix hints on a broken one.
//
// Driven through a real subprocess ([runZfaSource]) so the exit-code
// protocol (0 green / 1 findings / 64 usage) is exercised exactly as CI
// consumes it, and the process-global `Directory.current` that `-C`
// mutates never races between parallel test files (issue #506 pattern).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_engine_check_cmd_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: engine_check_cmd_test
environment:
  sdk: ^3.11.0
''');
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
    await writeFile('lib/src/data/repositories/data_login_repository.dart', '''
class DataLoginRepository implements LoginRepository {}
''');
    await writeFile('lib/src/di/repositories/login_repository_di.dart', '''
import 'package:get_it/get_it.dart';

void registerLoginRepository(GetIt getIt) {
  getIt.registerLazySingleton<LoginRepository>(
    () => DataLoginRepository(getIt<LoginRemoteDataSource>()),
  );
}
''');
  }

  test('exits 0 on a clean engine slice', () async {
    await writeCanonicalSlice();

    final result = await runZfaSource([
      'engine',
      'check',
      'Login',
    ], workingDirectory: workspace.path);

    expect(
      result.exitCode,
      0,
      reason: 'clean engine must exit 0; stdout=${result.stdout}',
    );
  });

  test('exits 1 and prints --> fix: on a dangling getIt reference', () async {
    await writeCanonicalSlice();
    // Delete the remote datasource so getIt<LoginRemoteDataSource>() dangles.
    await File(
      p.join(
        workspace.path,
        'lib/src/data/datasources/login',
        'login_remote_datasource.dart',
      ),
    ).delete();

    final result = await runZfaSource([
      'engine',
      'check',
      'Login',
    ], workingDirectory: workspace.path);

    expect(result.exitCode, 1, reason: 'dangling reference must exit 1');
    expect(result.stdout as String, contains('LoginRemoteDataSource'));
    expect(
      result.stdout as String,
      contains('--> fix:'),
      reason: 'dangling references print a fix hint',
    );
  });

  test('exits 1 with a fix hint when the entity file is missing', () async {
    final result = await runZfaSource([
      'engine',
      'check',
      'Ghost',
    ], workingDirectory: workspace.path);

    expect(result.exitCode, 1);
    expect(result.stdout as String, contains('--> fix:'));
  });

  test('usage error (exit 64) when the entity name is missing', () async {
    final result = await runZfaSource([
      'engine',
      'check',
    ], workingDirectory: workspace.path);

    expect(result.exitCode, 64, reason: 'missing entity is a usage error');
    expect(result.stdout as String, contains('Usage'));
  });
}
