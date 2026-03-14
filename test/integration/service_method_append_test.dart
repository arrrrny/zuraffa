import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('service_append_test');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test('append mode correctly adds methods to existing service', () async {
    // Step 1: Create initial service with first method
    final initial = CodeGenerator(
      config: GeneratorConfig(
        name: 'CheckPermission',
        domain: 'profile',
        service: 'Permission',
        returnsType: 'PermissionStatus',
        paramsType: 'CheckPermissionParams',
        generateUseCase: true,
        appendToExisting: true,
        outputDir: outputDir,
      ),
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: true,
      ),
    );

    final initialResult = await initial.generate();
    print('Initial generation result: ${initialResult.success}');
    print('Initial files: ${initialResult.files.map((f) => f.path).toList()}');
    print('Initial errors: ${initialResult.errors}');
    expect(initialResult.success, isTrue);

    final servicePath = '$outputDir/domain/services/permission_service.dart';
    final serviceFile = File(servicePath);
    expect(serviceFile.existsSync(), isTrue);

    final initialContent = serviceFile.readAsStringSync();
    print('Initial service content:\n$initialContent');
    expect(initialContent.contains('checkPermission'), isTrue);

    // Step 2: Append a second method to the existing service
    final append = CodeGenerator(
      config: GeneratorConfig(
        name: 'RequestPermission',
        domain: 'profile',
        service: 'Permission',
        returnsType: 'PermissionStatus',
        paramsType: 'RequestPermissionParams',
        generateUseCase: true,
        appendToExisting: true,
        outputDir: outputDir,
      ),
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: true,
      ),
    );

    final appendResult = await append.generate();
    print('\nAppend generation result: ${appendResult.success}');
    print('Append files: ${appendResult.files.map((f) => f.path).toList()}');
    print('Append errors: ${appendResult.errors}');
    expect(appendResult.success, isTrue);

    // Step 3: Verify both methods exist in the service
    final updatedContent = serviceFile.readAsStringSync();
    print('\nUpdated service content:\n$updatedContent');

    expect(
      updatedContent.contains('checkPermission'),
      isTrue,
      reason: 'Original checkPermission method should still exist',
    );
    expect(
      updatedContent.contains('requestPermission'),
      isTrue,
      reason: 'New requestPermission method should be added',
    );
  });

  test('append mode works with generateData for service providers', () async {
    // Step 1: Create initial service with provider
    final initial = CodeGenerator(
      config: GeneratorConfig(
        name: 'CheckPermission',
        domain: 'profile',
        service: 'Permission',
        returnsType: 'PermissionStatus',
        paramsType: 'CheckPermissionParams',
        generateUseCase: true,
        generateData: true,
        appendToExisting: true,
        outputDir: outputDir,
      ),
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,  // Keep non-verbose for cleaner output
      ),
    );

    final initialResult = await initial.generate();
    expect(initialResult.success, isTrue);

    // Step 2: Append a second method
    final append = CodeGenerator(
      config: GeneratorConfig(
        name: 'RequestPermission',
        domain: 'profile',
        service: 'Permission',
        returnsType: 'PermissionStatus',
        paramsType: 'RequestPermissionParams',
        generateUseCase: true,
        generateData: true,
        appendToExisting: true,
        outputDir: outputDir,
      ),
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,  // Keep non-verbose for cleaner output
      ),
    );

    final appendResult = await append.generate();
    expect(appendResult.success, isTrue);

    // Step 3: Verify service interface has both methods
    final serviceContent = File(
      '$outputDir/domain/services/permission_service.dart',
    ).readAsStringSync();
    expect(serviceContent.contains('checkPermission'), isTrue);
    expect(serviceContent.contains('requestPermission'), isTrue);

    // Step 4: Verify provider implementation has both methods
    final providerContent = File(
      '$outputDir/data/providers/profile/permission_provider.dart',
    ).readAsStringSync();
    expect(providerContent.contains('checkPermission'), isTrue);
    expect(providerContent.contains('requestPermission'), isTrue);
  });

  test('ServicePlugin logs info message in verbose mode during append', () async {
    // Capture print output
    final logs = <String>[];
    void capturePrint(String message) {
      logs.add(message);
    }

    // Run in verbose mode to trigger the message
    await runZoned(
      () async {
        final generator = CodeGenerator(
          config: GeneratorConfig(
            name: 'CheckPermission',
            domain: 'profile',
            service: 'Permission',
            returnsType: 'PermissionStatus',
            paramsType: 'CheckPermissionParams',
            generateUseCase: true,
            appendToExisting: true,
            outputDir: outputDir,
          ),
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: true,  // Enable verbose to trigger the log message
          ),
        );

        await generator.generate();
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, message) {
          capturePrint(message);
        },
      ),
    );

    // Verify the message was logged
    final hasServicePluginMessage = logs.any(
      (log) =>
          log.contains('ServicePlugin') &&
          log.contains('append mode') &&
          log.contains('MethodAppendPlugin'),
    );
    expect(
      hasServicePluginMessage,
      isTrue,
      reason:
          'ServicePlugin should log info message in verbose mode when skipping due to append mode',
    );
  });
}
