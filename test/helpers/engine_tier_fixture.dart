/// Spec 1117 — shared fixture for the engine trust-tier generator tests.
///
/// Every trust-tier test generates into a throwaway pure-Dart package that
/// depends on THIS repo via a path dependency (the pattern pinned by
/// `test/plugins/usecase/usecase_compile_test.dart` and
/// `test/plugins/di/di_setup_execution_test.dart`), so the compile bar and
/// the behavioral bar see exactly what a consumer project sees.
///
/// Issue #1044 rule (enforced here for every behavioral run): the test
/// runner command is ALWAYS resolved from the project's TDD profile
/// (`.specify/memory/tdd-profile.md`) through [SingleTestRunner] — never a
/// literal `dart test` string in test source. If the profile says
/// `flutter test {file}`, these suites run under flutter with zero source
/// changes.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_reporter_args.dart';

import 'project_root.dart';

/// A throwaway pure-Dart package the generators under test write into.
class EngineTierFixture {
  /// The fixture package root (the temp directory itself).
  final Directory root;

  /// `<root>/lib/src` — the `outputDir` every plugin writes under.
  final String libSrc;

  /// The fixture package name (used by the inner behavior tests' imports).
  final String name;

  /// The absolute path of the zuraffa repo backing the path dependency.
  final String repoRoot;

  EngineTierFixture._(this.root, this.libSrc, this.name, this.repoRoot);

  /// Creates the fixture package with a pubspec depending on this repo.
  ///
  /// [withTestDep] adds `test: any` to dev_dependencies (behavioral
  /// fixtures whose inner suites run through the profile-resolved runner).
  /// [withGetIt] adds `get_it: ^9.2.1` (fixtures exercising the generated
  /// DI wiring).
  static Future<EngineTierFixture> create({
    required String name,
    bool withTestDep = false,
    bool withGetIt = false,
  }) async {
    final repoRoot = await findProjectRoot();
    final root = await Directory.systemTemp.createTemp('zfa_engine_tier_');
    final deps = StringBuffer('''
dependencies:
  zuraffa:
    path: $repoRoot
''');
    if (withGetIt) {
      deps.writeln('  get_it: ^9.2.1');
    }
    final devDeps = withTestDep ? '\ndev_dependencies:\n  test: any\n' : '';
    await File(p.join(root.path, 'pubspec.yaml')).writeAsString('''
name: $name
publish_to: none
environment:
  sdk: ^3.11.0
$deps$devDeps
''');
    return EngineTierFixture._(
      root,
      p.join(root.path, 'lib', 'src'),
      name,
      repoRoot,
    );
  }

  /// Writes [content] at [relativePath] under the package root, creating
  /// parent directories as needed.
  Future<void> write(String relativePath, String content) async {
    final file = File(p.join(root.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Reads a file under the package root (empty string when missing).
  String read(String relativePath) =>
      File(p.join(root.path, relativePath)).readAsStringSync();

  /// True when a file exists under the package root.
  bool exists(String relativePath) =>
      File(p.join(root.path, relativePath)).existsSync();

  /// `dart pub get --no-example` in the fixture. Asserted (exit 0) so a
  /// resolution failure fails the suite naming the output, like the
  /// existing compile fixtures do.
  Future<void> pubGet() async {
    final result = await Process.run('dart', [
      'pub',
      'get',
      '--no-example',
    ], workingDirectory: root.path);
    expect(
      result.exitCode,
      0,
      reason:
          'dart pub get must succeed in the engine trust-tier fixture.\n'
          '${result.stdout}\n${result.stderr}',
    );
  }

  /// `dart analyze --no-fatal-warnings lib` — the spec 1117 compile bar:
  /// zero errors (warnings are reported but non-fatal, matching the
  /// existing trust-tier compile gates).
  Future<ProcessResult> analyzeLib() => Process.run('dart', [
    'analyze',
    '--no-fatal-warnings',
    'lib',
  ], workingDirectory: root.path);

  /// Deletes the fixture (disk housekeeping between phases).
  Future<void> dispose() async {
    if (root.existsSync()) {
      try {
        await root.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  }
}

/// Issue #1044: resolve the whole-file test runner argv from the repo's
/// TDD profile — never a hard-coded `dart test`.
///
/// Resolution: [SingleTestRunner.loadFileTemplate] reads the `file:` key
/// of `.specify/memory/tdd-profile.md` (falling back to the human-facing
/// bullet), the `{file}` placeholder is substituted with [testPath], and
/// [SingleTestRunner.splitCommand] tokenizes the result into an
/// executable + argument list. Returns the argv so callers stay runner
/// agnostic (dart or flutter).
///
/// The argv is pinned to the compact reporter ([withCompactReporter]):
/// package:test silently switches to its `github` reporter when
/// `GITHUB_ACTIONS=true` (every Actions runner), and the github reporter
/// emits `🎉 N tests passed.` instead of the compact `+N: All tests
/// passed!` the behavioral probes assert on.
Future<List<String>> resolvedRunnerArgs({
  required String repoRoot,
  required String testPath,
}) async {
  final template = await const SingleTestRunner().loadFileTemplate(
    workingDirectory: repoRoot,
  );
  expect(
    template.trim(),
    isNotEmpty,
    reason:
        'the TDD profile must resolve a whole-file runner template '
        '(issue #1044: a profile present without a usable file: key must '
        'stop the run, not silently fall back)',
  );
  final command = template.replaceAll('{file}', testPath);
  return withCompactReporter(SingleTestRunner.splitCommand(command));
}

/// The login-pilot entity pair (005-login-engine): `AuthSession` is what
/// the service returns; `LoginParams` is the request. `AuthSession` (not
/// `Session`) avoids an ambiguous_import with zuraffa's own exported
/// `Session` class, and `kind` is the ONLY String field so the #1034
/// per-method fixture selector threads it deterministically (the
/// selector picks the first field whose type matches the selector's
/// parameter type).
const String authSessionEntitySource = '''
class AuthSession {
  final String token;
  const AuthSession({required this.token});
}
''';

const String loginParamsEntitySource = '''
class LoginParams {
  final String kind;
  const LoginParams({required this.kind});
}
''';

/// Writes the login-pilot entity pair into a fixture at the canonical
/// entity paths the generators import.
Future<void> writeLoginPilotEntities(EngineTierFixture fx) async {
  await fx.write(
    'lib/src/domain/entities/auth_session/auth_session.dart',
    authSessionEntitySource,
  );
  await fx.write(
    'lib/src/domain/entities/login_params/login_params.dart',
    loginParamsEntitySource,
  );
}

/// The `AuthSessionMockData` source every mock suite seeds as pre-existing
/// project state — the sanctioned AUGMENTED escape hatch (#1034):
/// mock-data VALUES may be hand-written; provider ROUTING stays 100%
/// generated.
///
/// `withSelector: true` (default) declares the per-method fixture
/// selector the provider threads (`forMethod(params.kind)`); `false`
/// emits the single-fixture shape so the structural suite can pin the
/// fallback routing too.
String authSessionMockData({bool withSelector = true}) {
  final fixtures = withSelector
      ? "  static const _adminSession = AuthSession(token: 'admin-token');\n"
            "  static const _guestSession = AuthSession(token: 'guest-token');\n"
      : '';
  final selector = withSelector
      ? '\n'
            '  static AuthSession forMethod(String kind) {\n'
            "    switch (kind) {\n"
            "      case 'admin':\n"
            '        return _adminSession;\n'
            "      case 'guest':\n"
            '        return _guestSession;\n'
            '      default:\n'
            '        return _defaultSession;\n'
            '    }\n'
            '  }\n'
      : '';
  return '''
import '../../domain/entities/auth_session/auth_session.dart';

/// Mock data for AuthSession (the sanctioned AUGMENTED escape hatch:
/// mock-data VALUES may be hand-written; provider routing stays 100%
/// generated).
class AuthSessionMockData {
$fixtures  static const _defaultSession = AuthSession(token: 'default-token');
  static AuthSession get sampleAuthSession => _defaultSession;
  static List<AuthSession> get sampleList => [_defaultSession];$selector
}
''';
}

/// The params entity's mock data — fixture pre-existing state that
/// satisfies the provider's entity-graph import.
const String loginParamsMockDataSource = '''
import '../../domain/entities/login_params/login_params.dart';
class LoginParamsMockData {
  static const _admin = LoginParams(kind: 'admin');
  static const _guest = LoginParams(kind: 'guest');
  static LoginParams get sampleLoginParams => _admin;
  static List<LoginParams> get sampleList => [_admin, _guest];
}
''';
