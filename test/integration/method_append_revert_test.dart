@Tags(['integration', 'slow'])
library;

import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('method_append_revert_test');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test(
    'MethodAppendPlugin revert deletes the service file it created',
    timeout: Timeout(Duration(minutes: 5)),
    () async {
      // 1. First, generate a service via method_append.
      // The usecase plugin is disabled: this test exercises the MethodAppend
      // service create + revert path only. A custom usecase (this config has
      // no entity methods) would bind to `PermissionService`, which the #1799
      // guard refuses to generate against until the interface declares a
      // matching method — a different contract, unrelated to method-append
      // revert.
      final config = GeneratorConfig(
        name: 'CheckPermission',
        domain: 'profile',
        service: 'Permission',
        returnsType: 'PermissionStatus',
        paramsType: 'CheckPermissionParams',
        appendToExisting: true,
        outputDir: outputDir,
      );

      final generator = CodeGenerator(
        config: config,
        outputDir: outputDir,
        disabledPluginIds: const {'usecase'},
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      final result = await generator.generate();
      expect(result.success, isTrue);

      final servicePath = path.join(
        outputDir,
        'domain',
        'services',
        'permission_service.dart',
      );
      expect(
        File(servicePath).existsSync(),
        isTrue,
        reason: 'Service file should be created',
      );

      // 2. Now, run revert
      final revertConfig = config.copyWith(revert: true);
      final revertGenerator = CodeGenerator(
        config: revertConfig,
        outputDir: outputDir,
        disabledPluginIds: const {'usecase'},
        options: GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: true,
          revert: true,
        ),
      );

      final revertResult = await revertGenerator.generate();
      expect(revertResult.success, isTrue);

      // 3. Verify the service file is gone
      expect(
        File(servicePath).existsSync(),
        isFalse,
        reason: 'Service file should be deleted on revert',
      );
    },
  );

  test('UseCasePlugin revert deletes custom usecases', () async {
    // The #1799 guard refuses to emit a custom usecase against a service that
    // declares no matching method, so establish the `PermissionService`
    // interface first (the single declared method is trusted when no
    // --params/--returns are supplied). Without it the usecase generation
    // fails closed and there is nothing to revert.
    final serviceDir = Directory(path.join(outputDir, 'domain', 'services'));
    serviceDir.createSync(recursive: true);
    File(
      path.join(serviceDir.path, 'permission_service.dart'),
    ).writeAsStringSync(
      'abstract class PermissionService {\n'
      '  Future<void> checkPermission(NoParams params);\n'
      '}',
    );

    // 1. Generate custom usecase
    final config = GeneratorConfig(
      name: 'CheckPermission',
      domain: 'profile',
      useCaseType: 'completable',
      service: 'Permission',
      outputDir: outputDir,
    );

    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );

    final result = await generator.generate();
    expect(result.success, isTrue);

    final usecasePath = path.join(
      outputDir,
      'domain',
      'usecases',
      'profile',
      'check_permission_usecase.dart',
    );
    expect(File(usecasePath).existsSync(), isTrue);

    // 2. Revert
    final revertConfig = config.copyWith(revert: true);
    final revertGenerator = CodeGenerator(
      config: revertConfig,
      outputDir: outputDir,
      options: const GeneratorOptions(force: true, revert: true),
    );

    final revertResult = await revertGenerator.generate();
    expect(revertResult.success, isTrue);

    // 3. Verify deleted
    expect(File(usecasePath).existsSync(), isFalse);
  });

  test('Enum imports are correctly handled in Provider and Service', () async {
    // 1. Setup enums directory and an enum
    final enumsDir = Directory(
      path.join(outputDir, 'domain', 'entities', 'enums'),
    );
    enumsDir.createSync(recursive: true);
    File(
      path.join(enumsDir.path, 'permission_status.dart'),
    ).writeAsStringSync('enum PermissionStatus { allowed, denied }');
    File(
      path.join(enumsDir.path, 'permission_type.dart'),
    ).writeAsStringSync('enum PermissionType { camera, location }');
    File(path.join(enumsDir.path, 'index.dart')).writeAsStringSync(
      "export 'permission_status.dart';\nexport 'permission_type.dart';",
    );

    // 2. Generate Provider with enum returns/params
    final config = GeneratorConfig(
      name: 'CheckPermission',
      domain: 'check_permission',
      service: 'Permission',
      returnsType: 'PermissionStatus',
      paramsType: 'PermissionType',
      generateUseCase: true,
      generateData: true,
      generateMock: true,
      outputDir: outputDir,
    );

    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );

    final result = await generator.generate();
    expect(result.success, isTrue);

    // 3. Verify Provider imports
    final providerPath = path.join(
      outputDir,
      'data',
      'providers',
      'check_permission',
      'permission_provider.dart',
    );
    final providerFile = File(providerPath);
    if (providerFile.existsSync()) {
      final providerContent = providerFile.readAsStringSync();
      expect(providerContent, contains("domain/entities/enums/index.dart"));
      expect(
        providerContent,
        isNot(
          contains(
            "import '../../../domain/entities/permission_status/permission_status.dart';",
          ),
        ),
      );
    } else {
      fail('Provider file was not created');
    }

    // 4. Verify Service imports
    final servicePath = path.join(
      outputDir,
      'domain',
      'services',
      'permission_service.dart',
    );
    final serviceFile = File(servicePath);
    if (serviceFile.existsSync()) {
      final serviceContent = serviceFile.readAsStringSync();
      // The writer emits a RELATIVE import from the service's own location
      // (`../entities/enums/index.dart`), not a domain-rooted absolute path
      // (issue #395 Bug B). Pin the relative form it actually produces.
      expect(serviceContent, contains("../entities/enums/index.dart"));
    } else {
      fail('Service file was not created');
    }

    // 5. Verify Mock Data was generated for enums correctly
    final mockDataPath = path.join(
      outputDir,
      'data',
      'mock',
      'permission_status_mock_data.dart',
    );
    expect(
      File(mockDataPath).existsSync(),
      isTrue,
      reason: 'Mock data should be generated for enums',
    );
    final mockDataContent = File(mockDataPath).readAsStringSync();
    // The mock data imports the enum from the file that DECLARES it — here the
    // specific `enums/permission_status.dart`, not the barrel — and never a
    // different enum in the same directory (e.g. `permission_type.dart`) nor
    // the old nested `permission_status/permission_status.dart` path
    // (issues #1735, #395 Bug B). Pin the complete import so a wrong enum in
    // `enums/` cannot satisfy this assertion.
    expect(
      mockDataContent,
      contains("../../domain/entities/enums/permission_status.dart"),
    );
    expect(
      mockDataContent,
      isNot(
        contains(
          "import '../../domain/entities/permission_status/permission_status.dart';",
        ),
      ),
    );
    expect(
      mockDataContent,
      contains(
        'PermissionStatus.values[seed % PermissionStatus.values.length]',
      ),
    );
  });

  test('Mock data is skipped for completable usecases', () async {
    final config = GeneratorConfig(
      name: 'OpenAppSettings',
      domain: 'permission',
      useCaseType: 'completable',
      paramsType: 'NoParams',
      service: 'Permission',
      generateUseCase: true,
      generateData: true,
      generateMock: true,
      outputDir: outputDir,
    );

    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );

    final result = await generator.generate();
    expect(result.success, isTrue);

    final mockDataPath = path.join(
      outputDir,
      'data',
      'mock',
      'void_mock_data.dart',
    );
    expect(
      File(mockDataPath).existsSync(),
      isFalse,
      reason: 'Mock data should be skipped for completable/void returns',
    );
  });
}
