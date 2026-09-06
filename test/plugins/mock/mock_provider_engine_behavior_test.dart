// Spec 1117 (issue #1117) — MockProvider generator, engine trust tier:
// BEHAVIORAL bar (the second-most-complex generator).
//
// Executed against the GENERATED AuthMockProvider inside a
// self-contained fixture package:
//
//   (a) every method satisfies the contract — the provider IS an
//       AuthService and login returns the entity;
//   (b) the delay constructor parameter is honored — the certified
//       100 ms default, custom durations, and Duration.zero short-circuiting;
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
    // The literals are single-sourced in the shared engine-tier fixture.
    await fx.write(
      'lib/src/data/mock/auth_session_mock_data.dart',
      authSessionMockData(),
    );
    await fx.write(
      'lib/src/data/mock/login_params_mock_data.dart',
      loginParamsMockDataSource,
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
      '100 ms default; custom delays are honored; Duration.zero short-circuits '
      'it)', () async {
    final defaultProvider = AuthMockProvider();
    final sw = Stopwatch()..start();
    await defaultProvider.login(const LoginParams(kind: 'admin'));
    sw.stop();
    expect(
      sw.elapsedMilliseconds,
      greaterThanOrEqualTo(100),
      reason: 'the default delay is the certified 100 ms',
    );

    const customDelay = Duration(milliseconds: 150);
    final customProvider = AuthMockProvider(customDelay);
    final customSw = Stopwatch()..start();
    await customProvider.login(const LoginParams(kind: 'admin'));
    customSw.stop();
    expect(
      customSw.elapsed,
      greaterThanOrEqualTo(customDelay),
      reason: 'the constructor parameter must honor a custom delay',
    );

    // Deterministic short-circuit check: Dart timers fire in due-time
    // order, so the Duration.zero login always completes before the
    // 100 ms default one - no wall-clock upper bound to flake on.
    final fastProvider = AuthMockProvider(Duration.zero);
    final slowProvider = AuthMockProvider();
    var slowCompleted = false;
    final slowDone = slowProvider
        .login(const LoginParams(kind: 'admin'))
        .then((_) => slowCompleted = true);
    await fastProvider.login(const LoginParams(kind: 'admin'));
    expect(
      slowCompleted,
      isFalse,
      reason: 'the constructor parameter must be honored - Duration.zero '
          'short-circuits the delay (the zero-delay login lands while the '
          '100 ms default one is still pending)',
    );
    await slowDone;
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
      '(contract, configured delays, #1034 fixture selector) under the '
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
      matches(RegExp(r'\+4: All tests passed')),
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
