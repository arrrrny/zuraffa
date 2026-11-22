import 'dart:io';
import 'package:test/test.dart';
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
      // Issue #1496: the clean-architecture stack is the default tier —
      // init writes the stack plugins ON so a bare `zfa make` scaffolds
      // a runnable slice instead of resolving zero plugins.
      expect(config!.testByDefault, isTrue);
      expect(config.mockByDefault, isTrue);
    });

    test(
      'save and load preserves plugin defaults and disabled plugins',
      () async {
        final config = ZfaConfig(
          testByDefault: true,
          mockByDefault: true,
          disabledPlugins: const {'route'},
        );
        await ZfaConfig.save(config, projectRoot: projectRoot);

        final loaded = ZfaConfig.load(projectRoot: projectRoot);
        expect(loaded, isNotNull);
        expect(loaded!.testByDefault, isTrue);
        expect(loaded.mockByDefault, isTrue);
        expect(loaded.disabledPlugins, contains('route'));
      },
    );

    // Issue #2125: forward references are accepted by default so a parent
    // entity can be created before its nested entity. The default can be
    // turned off (strict on-disk validation) via the constructor or
    // `.zfa.json` `entity.allowForwardRefs: false`.
    group('allowForwardRefs (#2125)', () {
      test('defaults to true', () {
        expect(ZfaConfig().allowForwardRefs, isTrue);
      });

      test('round-trips through .zfa.json entity.allowForwardRefs', () async {
        await ZfaConfig.save(
          ZfaConfig(allowForwardRefs: false),
          projectRoot: projectRoot,
        );
        final loaded = ZfaConfig.load(projectRoot: projectRoot);
        expect(loaded, isNotNull);
        expect(loaded!.allowForwardRefs, isFalse);
      });

      test('loads true from a legacy config without the key', () async {
        await File(
          p.join(projectRoot, '.zfa.json'),
        ).writeAsString('{"entity": {"jsonByDefault": true}}');
        final loaded = ZfaConfig.load(projectRoot: projectRoot);
        expect(loaded, isNotNull);
        expect(loaded!.allowForwardRefs, isTrue);
      });

      test('copyWith preserves allowForwardRefs', () {
        final config = ZfaConfig(allowForwardRefs: false);
        expect(config.copyWith(buildByDefault: true).allowForwardRefs, isFalse);
      });
    });
  });
}
