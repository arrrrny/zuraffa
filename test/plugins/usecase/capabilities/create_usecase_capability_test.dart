import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/plugins/usecase/capabilities/create_usecase_capability.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';
import 'dart:io';

void main() {
  late Directory tempDir;
  late String outputDir;
  late UseCasePlugin plugin;
  late CreateUseCaseCapability capability;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_cap_test_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
    plugin = UseCasePlugin(outputDir: outputDir);
    capability = CreateUseCaseCapability(plugin);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('CreateUseCaseCapability handles Logout example correctly', () async {
    // Simulating args from CLI for:
    // zfa usecase create Logout --domain=profile --type=completable --params=NoParams --service=Auth
    final args = {
      'name': 'Logout',
      'domain': 'profile',
      'type': 'completable',
      'params': 'NoParams',
      'service': 'Auth',
      'outputDir': outputDir,
      // Note: 'methods' is missing because we removed the default from schema
    };

    final result = await capability.execute(args);
    expect(result.success, isTrue);
    
    final generatedFiles = result.data!['generatedFiles'] as List;
    expect(generatedFiles.length, 1);
    expect(generatedFiles.first.path, contains('domain/usecases/profile/logout_usecase.dart'));
  });

  test('CreateUseCaseCapability defaults to entity usecases if no custom flags', () async {
    // Simulating args for: zfa usecase create User
    final args = {
      'name': 'User',
      'outputDir': outputDir,
    };

    final result = await capability.execute(args);
    expect(result.success, isTrue);
    
    final generatedFiles = result.data!['generatedFiles'] as List;
    expect(generatedFiles.length, 2); // get, update
    expect(generatedFiles.any((f) => f.path.contains('get_user_usecase.dart')), isTrue);
    expect(generatedFiles.any((f) => f.path.contains('update_user_usecase.dart')), isTrue);
  });
}
