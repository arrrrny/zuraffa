/// GYM warmup rep #3 — authenticated smoke call into the package API.
///
/// The issue asks for "one authenticated smoke call" per package. zuraffa is
/// a codegen framework, not a service, so the equivalent of an authenticated
/// API call is driving the package's public codegen surface end to end. This
/// rep drives `GymPlugin.generateWithContext()` to scaffold a `Product`
/// feature artifact in a temp sandbox and asserts the four canonical files
/// (warmup #1, warmup #2, exercise, gym.yaml) landed on disk with the
/// expected shape. A clean exit proves the operator can wield the package's
/// codegen API — the muscle every later exercise grows on.
///
/// Run: `dart run .gym/warmup/03-smoke.dart`
///
/// A mis-fire (unexpected outcome, not a clean failure) is a DROP CARD —
/// see github.com/arrrrny/drop-card.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/plugins/gym/gym_plugin.dart';

/// Entry point for warmup rep #3.
Future<void> main() async {
  final tempDir = await Directory.systemTemp.createTemp('zuraffa_gym_smoke_');
  final outputDir = p.join(tempDir.path, 'lib', 'src');
  await Directory(outputDir).create(recursive: true);

  try {
    final plugin = GymPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    final context = PluginContext(
      core: CoreConfig(
        name: 'Product',
        projectRoot: tempDir.path,
        outputDir: outputDir,
      ),
      discovery: DiscoveryEngine(projectRoot: outputDir),
    );

    final files = await plugin.generateWithContext(context);

    // The GymPlugin emits exactly four files per entity — see
    // GymBuilder.generateArtifact. Anything else is a mis-fire.
    if (files.length != 4) {
      stderr.writeln(
        'REP FAIL: 03-smoke — expected 4 generated files, got ${files.length}. '
        'Mis-fire — drop a card: github.com/arrrrny/drop-card',
      );
      for (final f in files) {
        stderr.writeln('  - ${f.path}');
      }
      exit(1);
    }

    final expectedPaths = <String>[
      p.join(tempDir.path, 'gym', 'warmup', '01-smoke.dart'),
      p.join(tempDir.path, 'gym', 'warmup', '02-build.dart'),
      p.join(tempDir.path, 'gym', 'exercise-implement-feature.dart'),
      p.join(tempDir.path, 'gym', 'gym.yaml'),
    ];

    for (final expected in expectedPaths) {
      final matches = files.where((f) => f.path == expected).toList();
      if (matches.isEmpty) {
        stderr.writeln(
          'REP FAIL: 03-smoke — expected file not emitted: $expected',
        );
        exit(1);
      }
      if (!File(expected).existsSync()) {
        stderr.writeln(
          'REP FAIL: 03-smoke — file not written to disk: $expected',
        );
        exit(1);
      }
    }

    // The gym.yaml is the machine-readable contract the miki runner consumes
    // — sanity-check the canonical keys are present.
    final yamlFile = File(p.join(tempDir.path, 'gym', 'gym.yaml'));
    final yaml = yamlFile.readAsStringSync();
    for (final key in <String>[
      'name: product',
      'version: 1.0.0',
      'warmup:',
      'exercises:',
      'id: 01-smoke',
      'id: 02-build',
      'id: implement-feature',
      'verifyCommand:',
      'evaluate:',
    ]) {
      if (!yaml.contains(key)) {
        stderr.writeln(
          'REP FAIL: 03-smoke — gym.yaml missing canonical key "$key"',
        );
        exit(1);
      }
    }

    stdout.writeln('REP OK: 03-smoke — GymPlugin codegen round-trip OK.');
  } finally {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}
