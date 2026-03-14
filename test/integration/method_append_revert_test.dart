import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
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
      // 1. First, generate a service via method_append
      final config = GeneratorConfig(
        name: 'CheckPermission',
        domain: 'profile',
        service: 'Permission',
        returnsType: 'PermissionStatus',
        paramsType: 'CheckPermissionParams',
        generateUseCase: true,
        appendToExisting: true,
        outputDir: outputDir,
      );

      final generator = CodeGenerator(
        config: config,
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      final result = await generator.generate();
      print('Provider files: ${result.files.map((f) => f.path).toList()}');
      print('Provider errors: ${result.errors}');
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
      print('Config to revert: ${revertConfig.toJson()}');
      final revertGenerator = CodeGenerator(
        config: revertConfig,
        outputDir: outputDir,
        options: GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: true,
          revert: true,
        ),
      );

      print('CodeGenerator.config.revert: ${revertGenerator.config.revert}');
      print('CodeGenerator.options.revert: ${revertGenerator.options.revert}');

      final revertResult = await revertGenerator.generate();
      print('Revert files: ${revertResult.files.map((f) => f.path).toList()}');
      print('Revert errors: ${revertResult.errors}');
      print('Config revert: ${revertGenerator.config.revert}');
      print('Service snake: ${revertGenerator.config.serviceSnake}');
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
    print('Generator result: ${result.success}');
    print('Generator errors: ${result.errors}');
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

    print('OutputDir: $outputDir');
    final enumsIdxFile = File(
      path.join(outputDir, 'domain', 'entities', 'enums', 'index.dart'),
    );
    print('Enums index exists: ${enumsIdxFile.existsSync()}');
    print('Enums index content: ${enumsIdxFile.readAsStringSync()}');

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
      expect(serviceContent, contains("domain/entities/enums/index.dart"));
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
    expect(mockDataContent, contains("domain/entities/enums/index.dart"));
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
