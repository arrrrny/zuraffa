import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('custom_usecase_detection');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test(
    'Logout usecase with service is detected as custom, not entity',
    timeout: Timeout(Duration(minutes: 5)),
    () async {
      // Simulating: zfa usecase create Logout --domain=profile --type=completable --params=NoParams --service=Auth
      final config = GeneratorConfig(
        name: 'Logout',
        methods: const [], // Should be empty for custom
        useCaseType: 'completable',
        paramsType: 'NoParams',
        service: 'Auth',
        domain: 'profile',
        outputDir: outputDir,
      );

      final plugin = UseCasePlugin(outputDir: outputDir);
      final files = await plugin.generate(config);

      expect(files.length, 1);
      expect(files.first.path, contains('domain/usecases/profile/logout_usecase.dart'));
      
      final content = File(files.first.path).readAsStringSync();
      expect(content, contains('class LogoutUseCase'));
      expect(content, contains('final AuthService _authService;'));
      expect(content, contains('LogoutUseCase(this._authService)'));
      expect(content, isNot(contains('GetLogoutUseCase')));
      expect(content, isNot(contains('UpdateLogoutUseCase')));
    },
  );

  test(
    'Simple usecase without flags is detected as entity (default)',
    () async {
      // Simulating: zfa usecase create User
      // Note: Capability logic would set methods to ['get', 'update'] if empty and not custom
      final config = GeneratorConfig(
        name: 'User',
        methods: const ['get', 'update'],
        outputDir: outputDir,
      );

      final plugin = UseCasePlugin(outputDir: outputDir);
      final files = await plugin.generate(config);

      expect(files.length, 2);
      expect(files.any((f) => f.path.contains('get_user_usecase.dart')), isTrue);
      expect(files.any((f) => f.path.contains('update_user_usecase.dart')), isTrue);
    },
  );
}
