// Spec 1117 (issue #1117) — UseCase generator, engine trust tier:
// BEHAVIORAL bar (the most-complex generator).
//
// The 005-login-engine pilot hand-wrote `_FailingAuthService`
// (tdd/006-login-skin/skin_harness.dart) to test the failure path a
// framework failure preset would own. This suite is the executable
// version of that lesson, driven through the GENERATED LoginUseCase
// inside a self-contained fixture package:
//
//   (a) it returns the Service's Future<T> — the exact instance the
//       service completes with surfaces as Success;
//   (b) it surfaces Result.failure when the Service throws;
//   (c) the failure path goes through the same sealed AppFailure the
//       service threw (ServerFailure surfaces AS ServerFailure);
//   (d) the generated DI registration is idempotent —
//       registerLoginUseCase(getIt) twice in one process must not throw
//       "already registered" (the pilot's lesson 4, #1102's
//       unregister-first fix).
//
// Issue #1044: the inner suite runs through the runner resolved from the
// repo's TDD profile (SingleTestRunner -> `.specify/memory/
// tdd-profile.md` `file:` key) — never a literal `dart test` invocation.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

import '../../helpers/engine_tier_fixture.dart';

void main() {
  late EngineTierFixture fx;

  setUpAll(() async {
    fx = await EngineTierFixture.create(
      name: 'uc_engine_behavior_fixture',
      withTestDep: true,
      withGetIt: true,
    );
    await writeLoginPilotEntities(fx);

    final opts = const GeneratorOptions(dryRun: false, force: true);
    final config = GeneratorConfig(
      name: 'Login',
      useCaseType: 'usecase',
      domain: 'auth',
      service: 'Auth',
      paramsType: 'LoginParams',
      returnsType: 'AuthSession',
      outputDir: fx.libSrc,
    );

    // The engine chain: service interface, custom usecase, DI wiring.
    await ServicePlugin(outputDir: fx.libSrc, options: opts).generate(config);
    await UseCasePlugin(outputDir: fx.libSrc, options: opts).generate(config);
    await DiPlugin(
      outputDir: fx.libSrc,
      options: opts,
    ).generate(config.copyWith(generateDi: true, generateUseCase: true));

    // The inner behavioral suite: the pilot's skin-harness lesson,
    // executed against the generated artifacts.
    await fx.write('test/login_engine_behavior_test.dart', '''
import 'package:get_it/get_it.dart';
import 'package:test/test.dart';
import 'package:uc_engine_behavior_fixture/src/di/usecases/login_usecase_di.dart';
import 'package:uc_engine_behavior_fixture/src/domain/entities/login_params/login_params.dart';
import 'package:uc_engine_behavior_fixture/src/domain/entities/auth_session/auth_session.dart';
import 'package:uc_engine_behavior_fixture/src/domain/services/auth_service.dart';
import 'package:uc_engine_behavior_fixture/src/domain/usecases/auth/login_usecase.dart';
import 'package:zuraffa/zuraffa.dart';

/// The pilot's hand-rolled failing double (005-login-engine
/// skin_harness): throws the framework's sealed failure type.
class _FailingAuthService implements AuthService {
  @override
  Future<AuthSession> login(LoginParams params) async {
    throw AppFailure.server('invalid credentials', statusCode: 401);
  }
}

class _SucceedingAuthService implements AuthService {
  final AuthSession session;
  _SucceedingAuthService(this.session);
  @override
  Future<AuthSession> login(LoginParams params) async => session;
}

void main() {
  const params = LoginParams(kind: 'admin');

  test("(a) returns the Service's Future<T> - the exact instance surfaces as Success", () async {
    final session = AuthSession(token: 'tok-1');
    final useCase = LoginUseCase(_SucceedingAuthService(session));
    final result = await useCase(params);
    expect(result, isA<Success<AuthSession, AppFailure>>());
    expect((result as Success<AuthSession, AppFailure>).value, same(session));
  });

  test('(b) surfaces Result.failure when the Service throws', () async {
    final useCase = LoginUseCase(_FailingAuthService());
    final result = await useCase(params);
    expect(
      result.isFailure,
      isTrue,
      reason: 'the sealed UseCase.call() must convert the throw into '
          'Result.failure',
    );
  });

  test("(c) the failure path goes through the same sealed AppFailure (the pilot's _FailingAuthService shape)", () async {
    final useCase = LoginUseCase(_FailingAuthService());
    final result = await useCase(params);
    final failure = result.fold<AppFailure?>((_) => null, (f) => f);
    expect(
      failure,
      isA<ServerFailure>(),
      reason: 'the surfaced failure must be the sealed AppFailure subtype '
          'the service threw - not a generic wrap',
    );
    expect(failure?.message, 'invalid credentials');
  });

  test('the generated DI registration is idempotent - registerLoginUseCase '
      'twice, unregister-first', () async {
    final getIt = GetIt.instance;
    getIt.reset();
    getIt.registerLazySingleton<AuthService>(
      () => _SucceedingAuthService(AuthSession(token: 'tok-di')),
    );
    registerLoginUseCase(getIt);
    // The pilot's killer (lesson 4): the second call must not throw
    // "already registered" - the unregister-first guard re-registers.
    registerLoginUseCase(getIt);
    expect(getIt<LoginUseCase>(), isA<LoginUseCase>());
  });
}
''');

    await fx.pubGet();
  });

  tearDownAll(() async {
    await fx.dispose();
  });

  test('the generated LoginUseCase passes the behavioral suite (service '
      'delegation, Result.failure on throw, sealed AppFailure path, '
      'idempotent DI) under the profile-resolved runner', () async {
    // Issue #1044: the runner argv resolves from the repo's TDD
    // profile — never a literal dart test.
    final argv = await resolvedRunnerArgs(
      repoRoot: fx.repoRoot,
      testPath: 'test/login_engine_behavior_test.dart',
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

  test('the behavioral fixture generated pair also passes the compile bar '
      '(dart analyze, zero errors)', () async {
    final result = await fx.analyzeLib();
    expect(
      result.exitCode,
      0,
      reason:
          'the engine trust-tier UseCase output (usecase + service + DI) '
          'must compile in a consumer package.\n'
          '${result.stdout}\n${result.stderr}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
