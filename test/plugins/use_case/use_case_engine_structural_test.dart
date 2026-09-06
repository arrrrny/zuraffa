// Spec 1117 (issue #1117) — UseCase generator, engine trust tier:
// STRUCTURAL bar.
//
// The 005-login-engine pilot generated `LoginUseCase` (custom usecase
// backed by AuthService) by hand-trusting the generator. This suite pins
// the generated shape the engine preset produces for that exact config:
// file path, class name, imports, method signature, service delegation,
// and — the pilot's lesson 4 — the DI file's unregister-first
// registration guard (the non-idempotency bug class #1102 fixed; the
// assertion here is the regression pin the spec's success criteria
// demand).
//
// Fast tier: in-process plugin invocation into a throwaway directory; no
// subprocess, no pub get.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_uc_struct_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// The pilot's exact generation shape: custom `Login` usecase, service
  /// `Auth`, domain `auth`, params `LoginParams`, returns `AuthSession` —
  /// the config `zfa make engine` resolves for the login vertical.
  GeneratorConfig loginUseCaseConfig(String dir) => GeneratorConfig(
    name: 'Login',
    useCaseType: 'usecase',
    domain: 'auth',
    service: 'Auth',
    paramsType: 'LoginParams',
    returnsType: 'AuthSession',
    outputDir: dir,
  );

  test(
    'generates exactly one usecase file at the canonical domain path with '
    'the LoginUseCase class, imports, signature, and service delegation',
    () async {
      final files = await UseCasePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      ).generate(loginUseCaseConfig(outputDir));

      // File count: one usecase artifact, nothing else.
      final usecaseFiles = files.where((f) => f.type == 'usecase').toList();
      expect(usecaseFiles, hasLength(1), reason: 'exactly one usecase file');
      expect(
        usecaseFiles.first.path,
        p.join(outputDir, 'domain', 'usecases', 'auth', 'login_usecase.dart'),
        reason:
            'the engine preset writes the pilot path '
            'domain/usecases/auth/login_usecase.dart',
      );

      final content = usecaseFiles.first.content ?? '';
      // Class name + base contract.
      expect(
        content,
        contains(
          'class LoginUseCase extends UseCase<AuthSession, LoginParams>',
        ),
        reason:
            'the class must extend the framework UseCase contract with '
            'the requested params/returns types',
      );
      // Imports: the framework surface + the backing service.
      expect(
        content,
        contains("import 'package:zuraffa/zuraffa.dart';"),
        reason: 'the framework import must be present',
      );
      expect(
        content,
        contains("import '../../services/auth_service.dart';"),
        reason:
            'the generated usecase must import the service it calls '
            '(the engine chain writes domain/services/auth_service.dart)',
      );
      // Method signature: Future<AuthSession> execute(LoginParams, [CancelToken?]).
      expect(
        content,
        contains('Future<AuthSession> execute('),
        reason: 'execute must return Future<AuthSession>',
      );
      expect(
        content,
        contains('LoginParams params, ['),
        reason:
            'execute must take the params type and the optional '
            'cancel token',
      );
      expect(
        content,
        contains('CancelToken? cancelToken,'),
        reason: 'the cancel token parameter must keep the framework type',
      );
      // Service delegation: the field, the constructor, the call.
      expect(
        content,
        contains('final AuthService _authService;'),
        reason: 'the service dependency field must be declared',
      );
      expect(
        content,
        contains('LoginUseCase(this._authService);'),
        reason: 'the constructor must inject the service',
      );
      expect(
        content,
        contains('return await _authService.login(params);'),
        reason:
            'execute must delegate to the service method — the '
            "pilot's LoginUseCase shape",
      );
      expect(
        content,
        contains('cancelToken?.throwIfCancelled();'),
        reason: 'the cancellation guard must precede the delegation',
      );
      expect(
        content.indexOf('cancelToken?.throwIfCancelled();'),
        lessThan(content.indexOf('return await _authService.login(params);')),
        reason: 'the cancellation guard must occur before service delegation',
      );
    },
  );

  test(
    'the generated DI file registers LoginUseCase through the '
    "unregister-first pattern (the pilot's non-idempotency bug pinned)",
    () async {
      // The engine preset's DI chain: same config, generateDi +
      // generateUseCase so DiPlugin emits the per-usecase registration.
      final diFiles =
          await DiPlugin(
            outputDir: outputDir,
            options: const GeneratorOptions(dryRun: false, force: true),
          ).generate(
            loginUseCaseConfig(
              outputDir,
            ).copyWith(generateDi: true, generateUseCase: true),
          );

      final diFile = diFiles.firstWhere(
        (f) =>
            f.path.endsWith(p.join('di', 'usecases', 'login_usecase_di.dart')),
        orElse: () => throw StateError(
          'di/usecases/login_usecase_di.dart was not generated. '
          'Generated: ${diFiles.map((f) => f.path)}',
        ),
      );
      final content = diFile.content ?? '';

      // The registration function the composition root calls.
      expect(
        content,
        contains('void registerLoginUseCase(GetIt getIt)'),
        reason: 'the per-usecase DI registration function must exist',
      );
      // THE regression pin: the unregister-first guard that makes
      // setupDependencies callable twice. The pilot caught its absence
      // by hand (lesson 4: generated DI was not idempotent, #1102).
      expect(
        content,
        contains('if (getIt.isRegistered<LoginUseCase>())'),
        reason:
            'the unregister-first guard must precede the registration '
            '(issue #1102: without it a second setup call throws "already '
            'registered")',
      );
      expect(
        content,
        contains('getIt.unregister<LoginUseCase>();'),
        reason: 'the guard body must unregister before re-registering',
      );
      // The registration itself resolves the service from the container.
      expect(
        content,
        contains('getIt.registerLazySingleton<LoginUseCase>('),
        reason: 'the lazy singleton registration must be emitted',
      );
      expect(
        content.indexOf('getIt.unregister<LoginUseCase>();'),
        lessThan(content.indexOf('getIt.registerLazySingleton<LoginUseCase>(')),
        reason:
            'the unregister action in the guard must occur before DI '
            'registration',
      );
      expect(
        content.indexOf('if (getIt.isRegistered<LoginUseCase>())'),
        lessThan(content.indexOf('getIt.registerLazySingleton<LoginUseCase>(')),
        reason: 'the unregister-first guard must occur before DI registration',
      );
      expect(
        content,
        contains('LoginUseCase(getIt<AuthService>())'),
        reason:
            'the registration must construct the usecase from the '
            'container-resolved service',
      );
      expect(
        content,
        contains("import '../../domain/services/auth_service.dart';"),
        reason: 'the DI file must import the service it resolves',
      );
    },
  );
}
