// Spec 1117 (issue #1117) — Service generator, engine trust tier:
// STRUCTURAL bar.
//
// The 005-login-engine pilot's AuthService was trusted blind. This suite
// pins the shape the ServicePlugin emits for the login vertical's config
// (service `Auth` backed by LoginParams/AuthSession): file path, class
// declaration, the one method the generated LoginUseCase calls, and the
// entity imports the interface references.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_svc_struct_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates the AuthService interface at the canonical services path '
      'with the login method signature and entity imports', () async {
    final files =
        await ServicePlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: false, force: true),
        ).generate(
          GeneratorConfig(
            name: 'Login',
            domain: 'auth',
            service: 'Auth',
            paramsType: 'LoginParams',
            returnsType: 'AuthSession',
            outputDir: outputDir,
          ),
        );

    // File count: exactly one service interface for the vertical.
    final serviceFiles = files.where((f) => f.type == 'service').toList();
    expect(
      serviceFiles,
      hasLength(1),
      reason: 'exactly one service interface file',
    );
    expect(
      serviceFiles.first.path,
      p.join(outputDir, 'domain', 'services', 'auth_service.dart'),
      reason:
          'the engine preset writes the pilot path '
          'domain/services/auth_service.dart',
    );

    final content = serviceFiles.first.content ?? '';
    // Class declaration: the abstract interface the mock provider and
    // the usecase both bind to.
    expect(
      content,
      contains('abstract class AuthService {'),
      reason:
          'the service must be an abstract interface named '
          'AuthService',
    );
    // Method signature: the exact method the generated LoginUseCase
    // calls (`_authService.login(params)`).
    expect(
      content,
      contains('Future<AuthSession> login(LoginParams params);'),
      reason:
          'the interface method must match the usecase delegation '
          'target — Future<AuthSession> login(LoginParams)',
    );
    // Imports: the framework surface + the referenced entities.
    expect(
      content,
      contains("import 'package:zuraffa/zuraffa.dart';"),
      reason: 'the framework import must be present',
    );
    expect(
      content,
      contains("import '../entities/login_params/login_params.dart';"),
      reason: 'the params entity import must resolve',
    );
    expect(
      content,
      contains("import '../entities/auth_session/auth_session.dart';"),
      reason: 'the returns entity import must resolve',
    );
  });
}
