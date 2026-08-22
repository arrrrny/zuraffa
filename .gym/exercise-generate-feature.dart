/// GYM exercise — generate a feature end-to-end (graded).
///
/// Brief: Using zuraffa's codegen API, scaffold a `Product` feature in a
/// temp sandbox and prove the produced artifact is real, runnable, and
/// shaped the way the miki GYM runner expects. The exercise is graded
/// against the artifact you leave on disk, not against reading source.
///
/// Setup:
///   - Ensure `dart` is on PATH.
///   - Run the warmup reps first (.gym/warmup/*).
///   - The exercise drives `GymPlugin.generateWithContext()` against a temp
///     directory under .gym/.sandbox/ so the package source tree is never
///     mutated.
///
/// What this exercise proves under load:
///   1. The operator can drive zuraffa's plugin API to generate a feature
///      artifact end to end (the same path `zfa feature <Name>` walks).
///   2. The produced warmup rep #1 references the entity AND its UseCase,
///      so the operator can drive the generated API by hand.
///   3. The produced gym.yaml is consumable by the miki GYM runner —
///      every canonical key is present, the warmup board lists both reps,
///      the exercise board lists the implement-feature rep.
///   4. The produced exercise's verifyCommand is a real `flutter test`
///      invocation against the entity's test folder, so a downstream
///      runner can grade an operator's submission headless.
///
/// verifyCommand: `dart run .gym/exercise-generate-feature.dart`
/// evaluate: exit 0 => pass; exit !=0 => fail
///
/// A mis-fire (unexpected outcome, not a clean failure) is captured as a
/// DROP CARD — see github.com/arrrrny/drop-card.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/plugins/gym/gym_plugin.dart';

/// Entry point for the graded exercise.
Future<void> main() async {
  // The sandbox lives under .gym/.sandbox/ so the runner can wipe it
  // between runs without touching the package source tree. Resolve to an
  // absolute path — the GymPlugin's internal FileSystem canonicalizes
  // relative paths against the current cwd, and the plugin's transaction
  // machinery may shift that cwd mid-run, which would double-prefix any
  // relative path. Absolute paths are immune to that.
  final sandboxRoot = Directory(
    p.canonicalize('.gym/.sandbox/exercise-generate-feature'),
  );
  if (sandboxRoot.existsSync()) {
    await sandboxRoot.delete(recursive: true);
  }
  await sandboxRoot.create(recursive: true);

  final outputDir = p.join(sandboxRoot.path, 'lib', 'src');
  await Directory(outputDir).create(recursive: true);

  final plugin = GymPlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: true),
  );

  final context = PluginContext(
    core: CoreConfig(
      name: 'Product',
      projectRoot: sandboxRoot.path,
      outputDir: outputDir,
    ),
    discovery: DiscoveryEngine(projectRoot: outputDir),
  );

  final files = await plugin.generateWithContext(context);

  // ── 1. Artifact shape ───────────────────────────────────────────────
  // The GymPlugin emits exactly four files per entity. Anything else is
  // a mis-fire — the gate stays closed.
  if (files.length != 4) {
    _fail('Expected 4 generated files, got ${files.length}.');
  }

  final paths = files.map((f) => f.path).toList();
  final expectedPaths = <String>[
    p.join(sandboxRoot.path, 'gym', 'warmup', '01-smoke.dart'),
    p.join(sandboxRoot.path, 'gym', 'warmup', '02-build.dart'),
    p.join(sandboxRoot.path, 'gym', 'exercise-implement-feature.dart'),
    p.join(sandboxRoot.path, 'gym', 'gym.yaml'),
  ];
  for (final expected in expectedPaths) {
    if (!paths.contains(expected)) {
      _fail('Expected file not emitted: $expected');
    }
    if (!File(expected).existsSync()) {
      _fail('File not written to disk: $expected');
    }
  }

  // ── 2. Warmup rep #1 references the entity and its UseCase ─────────
  final smokeFile = File(
    p.join(sandboxRoot.path, 'gym', 'warmup', '01-smoke.dart'),
  );
  final smoke = smokeFile.readAsStringSync();
  for (final needle in <String>[
    'Product',
    'ProductUseCase',
    'drop-card',
    'dart run gym/warmup/01-smoke.dart',
  ]) {
    if (!smoke.contains(needle)) {
      _fail('warmup/01-smoke.dart missing "$needle".');
    }
  }

  // ── 3. gym.yaml is consumable by the miki GYM runner ───────────────
  final yamlFile = File(p.join(sandboxRoot.path, 'gym', 'gym.yaml'));
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
    'flutter test test/product/',
  ]) {
    if (!yaml.contains(key)) {
      _fail('gym.yaml missing canonical key "$key".');
    }
  }

  // ── 4. The produced exercise's verifyCommand is a real flutter test ─
  // The exercise artifact must grade the operator's submission by running
  // the entity's tests, not by reading source.
  final exerciseFile = File(
    p.join(sandboxRoot.path, 'gym', 'exercise-implement-feature.dart'),
  );
  final exerciseSrc = exerciseFile.readAsStringSync();
  if (!exerciseSrc.contains('flutter') ||
      !exerciseSrc.contains('test') ||
      !exerciseSrc.contains('test/product/')) {
    _fail('exercise-implement-feature.dart does not run flutter test.');
  }

  stdout.writeln('EXERCISE PASSED: generate-feature — artifact is real.');
  // Leave the sandbox in place so a downstream grader can inspect the
  // produced files. Wiped on the next run.
  exit(0);
}

/// Print a structured failure message and exit non-zero so the miki runner
/// records this exercise as failed.
void _fail(String message) {
  stderr.writeln('EXERCISE FAILED: generate-feature — $message');
  stderr.writeln(
    'Mis-fire? Drop a card: '
    'github.com/arrrrny/drop-card',
  );
  exit(1);
}
