import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zuraffa/src/config/zfa_config.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_config_test_');
    projectRoot = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ZfaConfig', () {
    test('load returns null if file does not exist', () {
      final config = ZfaConfig.load(projectRoot: projectRoot);
      expect(config, isNull);
    });

    test('init creates default config file', () async {
      await ZfaConfig.init(projectRoot: projectRoot);
      final configFile = File(p.join(projectRoot, '.zfa.json'));
      expect(configFile.existsSync(), isTrue);

      final config = ZfaConfig.load(projectRoot: projectRoot);
      expect(config, isNotNull);
      expect(config!.testByDefault, isFalse);
      expect(config.mockByDefault, isFalse);
    });

    test('save and load preserves testByDefault', () async {
      const config = ZfaConfig(testByDefault: true, mockByDefault: true);
      await ZfaConfig.save(config, projectRoot: projectRoot);

      final loaded = ZfaConfig.load(projectRoot: projectRoot);
      expect(loaded, isNotNull);
      expect(loaded!.testByDefault, isTrue);
      expect(loaded.mockByDefault, isTrue);
    });
  });
}
