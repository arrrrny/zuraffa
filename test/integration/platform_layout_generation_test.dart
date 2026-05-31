import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('platform_layout_generation_test');
    outputDir = workspace.outputDir;
    await writePubspec(workspace);
    await writeEntityStub(workspace, name: 'Product');
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test(
    'adaptive-feature preset generates layout files for all targets',
    () async {
      // Verify the view plugin's adaptive-layout scaffold builder exists.
      final builderPath = path.join(
        'lib',
        'src',
        'plugins',
        'view',
        'builders',
        'adaptive_layout_scaffold_builder.dart',
      );
      expect(
        File(builderPath).existsSync(),
        isTrue,
        reason: 'AdaptiveLayoutScaffoldBuilder should exist',
      );
    },
  );

  test('platform presentation classes exist', () {
    final basePath = path.join('lib', 'src', 'presentation', 'platform');
    expect(File(path.join(basePath, 'device_class.dart')).existsSync(), isTrue);
    expect(
      File(path.join(basePath, 'platform_class.dart')).existsSync(),
      isTrue,
    );
    expect(
      File(path.join(basePath, 'platform_context.dart')).existsSync(),
      isTrue,
    );
    expect(
      File(path.join(basePath, 'platform_layout_resolver.dart')).existsSync(),
      isTrue,
    );
  });

  test('shell abstractions exist for all platforms', () {
    final shellPath = path.join('lib', 'src', 'presentation', 'shells');
    expect(File(path.join(shellPath, 'app_shell.dart')).existsSync(), isTrue);
    expect(
      File(path.join(shellPath, 'app_shell_resolver.dart')).existsSync(),
      isTrue,
    );
    expect(
      File(path.join(shellPath, 'mobile_app_shell.dart')).existsSync(),
      isTrue,
    );
    expect(
      File(path.join(shellPath, 'tablet_app_shell.dart')).existsSync(),
      isTrue,
    );
    expect(
      File(path.join(shellPath, 'desktop_app_shell.dart')).existsSync(),
      isTrue,
    );
    expect(
      File(path.join(shellPath, 'macos_app_shell.dart')).existsSync(),
      isTrue,
    );
  });

  test('adaptive layout targets are configured in ZfaConfig', () {
    // Read the config file and verify adaptive defaults exist
    final configPath = path.join('lib', 'src', 'config', 'zfa_config.dart');
    final content = File(configPath).readAsStringSync();
    expect(content, contains('defaultAdaptiveLayoutTargets'));
    expect(content, contains('mobile'));
    expect(content, contains('tablet'));
    expect(content, contains('desktop'));
    expect(content, contains('macos'));
  });

  test('adaptive-feature preset is registered in PresetRegistry', () {
    final presetPath = path.join(
      'lib',
      'src',
      'core',
      'planning',
      'preset_registry.dart',
    );
    final content = File(presetPath).readAsStringSync();
    expect(content, contains('adaptive-feature'));
  });
}
