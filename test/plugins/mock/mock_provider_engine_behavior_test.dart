// Spec 1117 (issue #1117) — MockProvider generator, engine trust tier:
// BEHAVIORAL bar (the second-most-complex generator).
//
// Executed against the GENERATED AuthMockProvider inside a
// self-contained fixture package:
//
//   (a) every method satisfies the contract — the provider IS an
//       AuthService and login returns the entity;
//   (b) the delay constructor parameter is honored — the certified
//       100 ms default, and Duration.zero short-circuits it;
//   (c) the per-method fixture selector works (#1034): the params'
//       discriminator field routes to the matching canned fixture.
//
// Issue #1044: the inner suite runs through the runner resolved from
// the repo's TDD profile (SingleTestRunner ->
// `.specify/memory/tdd-profile.md` `file:` key) — never a literal
// `dart test` invocation.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

import '../../helpers/engine_tier_fixture.dart';

void main() {
  late EngineTierFixture fx;

  setUpAll(() async {
    fx = await EngineTierFixture.create(
      name: 'mock_engine_behavior_fixture',
      withTestDep: true,
    );
    await writeLoginPilotEntities(fx);

    final opts = const GeneratorOptions(dryRun: false, force: false);
    await ServicePlugin(outputDir: fx.libSrc, options: opts).generate(
      GeneratorConfig(
        name: 'Login',
        domain: 'auth',
        service: 'Auth',
        paramsType: 'LoginParams',
        returnsType: 'AuthSession',
        outputDir: fx.libSrc,
      ),
    );

    // The #1034 sanctioned AUGMENTED mock data: values hand-augmented
    // (forMethod selector + fixtures); provider routing stays generated.
    await fx.write(
      'lib/src/data/mock/auth_session_mock_data.dart',
      "import '../../domain/entities/auth_session/auth_session.dart';\n"
          'class AuthSessionMockData {\n'
          "  static const _adminSession = AuthSession(token: 'admin-token');\n"
          "  static const _guestSession = AuthSession(token: 'guest-token');\n"
          "  static const _defaultSession = AuthSession(token: 'default-token');\n"
          '  static AuthSession get sampleAuthSession => _defaultSession;\n'
          '  static List<AuthSession> get sampleList => [_defaultSession];\n'
          '  static AuthSession forMethod(String kind) {\n'
          '    switch (kind) {\n'
          "      case 'admin':\n"
          '        return _adminSession;\n'
          "      case 'guest':\n"
          '        return _guestSession;\n'
          '      default:\n'
          '        return _defaultSession;\n'
          '    }\n'
          '  }\n'
          '}\n',
    );
    await fx.write(
      'lib/src/data/mock/login_params_mock_data.dart',
      "import '../../domain/entities/login_params/login_params.dart';\n"
          'class LoginParamsMockData {\n'
          "  static const _admin = LoginParams(kind: 'admin');\n"
          "  static const _guest = LoginParams(kind: 'guest');\n"
          '  static LoginParams get sampleLoginParams => _admin;\n'
          '  static List<LoginParams> get sampleList => [_admin, _guest];\n'
          '}\n',
    );

    await MockPlugin(outputDir: fx.libSrc, options: opts).generate(
      GeneratorConfig(
        name: 'Login',
        domain: 'auth',
        service: 'Auth',
        methods: const [],
        useCaseType: 'usecase',
        generateMock: true,
        generateData: true,
        paramsType: 'LoginParams',
        returnsType: 'AuthSession',
        outputDir: fx.libSrc,
      ),
    );

    // The inner behavioral suite: contract, delay, fixture selector.
    await fx.write('test/mock_engine_behavior_test.dart', '''
import 'package:test/test.dart';
import 'package:mock_engine_behavior_fixture/src/data/mock/auth_session_mock_data.dart';
import 'package:mock_engine_behavior_fixture/src/domain/entities/auth_session/auth_session.dart';
import 'package:mock_engine_behavior_fixture/src/domain/entities/login_params/login_params.dart';
import 'package:mock_engine_behavior_fixture/src/domain/services/auth_service.dart';
import 'package:mock_engine_behavior_fixture/src/data/providers/auth/auth_mock_provider.dart';

void main() {
  test('(a) every method satisfies the contract - the provider is an '
      'AuthService and login returns the entity', () async {
    final provider = AuthMockProvider();
    expect(provider, isA<AuthService>());
    final session = await provider.login(const LoginParams(kind: 'admin'));
    expect(session, isA<AuthSession>());
  });

  test('(b) the delay constructor parameter is honored (the certified '
      '100 ms default; Duration.zero short-circuits it)', () async {
    final defaultProvider = AuthMockProvider();
    final sw = Stopwatch()..start();
    await defaultProvider.login(const LoginParams(kind: 'admin'));
    sw.stop();
    expect(
      sw.elapsedMilliseconds,
      greaterThanOrEqualTo(100),
      reason: 'the default delay is the certified 100 ms',
    );

    final fastProvider = AuthMockProvider(Duration.zero);
    final sw2 = Stopwatch()..start();
    await fastProvider.login(const LoginParams(kind: 'admin'));
    sw2.stop();
    expect(
      sw2.elapsedMilliseconds,
      lessThan(100),
      reason: 'the constructor parameter must be honored - Duration.zero '
          'short-circuits the delay',
    );
  });

  test('(c) the per-method fixture selector routes on the params '
      'discriminator (#1034)', () async {
    final provider = AuthMockProvider(Duration.zero);
    final admin = await provider.login(const LoginParams(kind: 'admin'));
    expect(admin.token, 'admin-token');
    final guest = await provider.login(const LoginParams(kind: 'guest'));
    expect(guest.token, 'guest-token');
    final other = await provider.login(const LoginParams(kind: 'other'));
    expect(other.token, 'default-token');
  });

  test('the stub bodies log through the framework Loggable mixin', () {
    // Compiles + callable: the generated provider mixes in Loggable and
    // uses logger.info in every stub body (the framework contract).
    final provider = AuthMockProvider(Duration.zero);
    expect(provider.logger, isNotNull);
  });
}
''');

    await fx.pubGet();
  });

  tearDownAll(() async {
    await fx.dispose();
  });

  test('the generated AuthMockProvider passes the behavioral suite '
      '(contract, 100 ms delay default, #1034 fixture selector) under the '
      'profile-resolved runner', () async {
    // Issue #1044: the runner argv resolves from the repo's TDD
    // profile — never a literal dart test.
    final argv = await resolvedRunnerArgs(
      repoRoot: fx.repoRoot,
      testPath: 'test/mock_engine_behavior_test.dart',
    );
    final result = await Process.run(
      argv.first,
      argv.skip(1).toList(),
      workingDirectory: fx.root.path,
    );
    final output = '${result.stdout}${result.stderr}';

    expect(
      result.exitCode,
      0,
      reason:
          'the inner behavioral suite must pass under the profile-'
          "resolved runner (${argv.join(' ')}).\n$output",
    );
    expect(
      output,
      contains('All tests passed!'),
      reason: 'the inner suite must report a clean pass; output:\n$output',
    );
    expect(
      output,
      contains('+4'),
      reason: 'all four behaviors (a)-(d) must run green; output:\n$output',
    );
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('the behavioral fixture generated provider also passes the compile '
      'bar (dart analyze, zero errors)', () async {
    final result = await fx.analyzeLib();
    expect(
      result.exitCode,
      0,
      reason:
          'the engine trust-tier MockProvider output must compile in a '
          'consumer package.\n${result.stdout}\n${result.stderr}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
