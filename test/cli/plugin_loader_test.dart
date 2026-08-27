import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/plugin_loader.dart';

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
}
