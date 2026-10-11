import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/plugin_loader.dart';

/// Bug 1269: `zfa make` breaks when run from a subproject because
/// plugin_loader.dart imported feature_contract via a *relative* path
/// (`../domain/entities/feature_contract/feature_contract.dart`). Relative
/// imports resolve against the importing file's location, which does not
/// hold when the CLI is compiled/launched from a consumer subproject — the
/// feature_contract entity lives in the zuraffa package, not in the app.
/// The loader must therefore reference it through an absolute
/// `package:zuraffa/` import, which the package config resolves
/// regardless of the invoking working directory.
const _pluginLoaderSourcePath = 'lib/src/cli/plugin_loader.dart';

List<String> _featureContractImportLines(String source) {
  return source
      .split('\n')
      .where((line) => line.trimLeft().startsWith('import'))
      .where((line) => line.contains('feature_contract'))
      .toList();
}

void main() {
  test('PluginLoader registers the api plugin', () {
    final loader = PluginLoader(
      outputDir: Directory.systemTemp.createTempSync('zuraffa_loader_').path,
      dryRun: false,
      force: false,
      verbose: false,
      config: PluginConfig(),
    );

    final ids = loader.listPlugins().map((p) => p.id).toList();
    // The API bridge plugin must be discoverable so `zfa api <Entity>` works.
    expect(ids, contains('api'));
  });

  test('plugin_loader.dart imports feature_contract via absolute package '
      'import (bug 1269: relative import breaks subproject runs)', () {
    final source = File(_pluginLoaderSourcePath).readAsStringSync();
    final importLines = _featureContractImportLines(source);

    expect(
      importLines,
      isNotEmpty,
      reason:
          'plugin_loader.dart is expected to import the FeatureContract '
          'entity; if the import was removed this test must be revisited.',
    );

    for (final line in importLines) {
      expect(
        line,
        contains("import 'package:zuraffa/"),
        reason:
            'Bug 1269 regression: found a non-package (relative) import of '
            'feature_contract in lib/src/cli/plugin_loader.dart → `$line`. '
            'Relative imports resolve against the importing file location '
            'and break when `zfa make` is compiled/launched from a '
            'subproject. Use an absolute `package:zuraffa/...` import.',
      );
    }
  });

  test('the absolute feature_contract import resolves to a real file that '
      'declares FeatureContract', () {
    final source = File(_pluginLoaderSourcePath).readAsStringSync();
    final importLines = _featureContractImportLines(source);
    expect(importLines, isNotEmpty);

    final pattern = RegExp("import\\s*'package:zuraffa/([^']+)';");
    for (final line in importLines) {
      final match = pattern.firstMatch(line);
      expect(
        match,
        isNotNull,
        reason: 'Import must be an absolute package import: `$line`.',
      );
      final libPath = 'lib/${match!.group(1)}';
      final target = File(libPath);
      expect(
        target.existsSync(),
        isTrue,
        reason:
            'Import target `$libPath` (from `$line`) does not exist in this '
            'package — the absolute import would fail to compile.',
      );
      expect(
        RegExp(
          r'class\s+\$?FeatureContract',
        ).hasMatch(target.readAsStringSync()),
        isTrue,
        reason:
            'Import target `$libPath` must declare the FeatureContract type '
            '(concrete `class FeatureContract` or zorphy base '
            '`abstract class \$FeatureContract`).',
      );
    }
  });
}
