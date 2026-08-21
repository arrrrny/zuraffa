import 'package:path/path.dart' as path;

import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

/// Generates the GYM artifact for a given [GeneratorConfig].
///
/// Mirrors [TestBuilder] in shape (constructed with outputDir/options/
/// fileSystem, returns `List<GeneratedFile>`) but emits a `gym/` folder
/// instead of a `test/` folder. The artifact is a folder of exercises with
/// two phases:
///
/// - **WARMUP** — mandatory reps that build reflex (call the generated API,
///   build the app). No reps, no phase 2.
/// - **EXERCISES** — graded work that proves the muscle under real load. A
///   brief + a workspace + an automated `evaluate()` against the operator's
///   actual output.
///
/// The `gym.yaml` is the machine-readable spec the miki GYM runner
/// (github.com/arrrrny/miki `gym.mjs`) consumes to execute the gym headless.
class GymBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final FileSystem fileSystem;

  /// Creates a [GymBuilder].
  GymBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create();

  /// Emits the full GYM artifact for [config].
  ///
  /// Returns one [GeneratedFile] per emitted file:
  /// - `gym/warmup/01-smoke.dart`
  /// - `gym/warmup/02-build.dart`
  /// - `gym/exercise-implement-feature.dart`
  /// - `gym/gym.yaml`
  Future<List<GeneratedFile>> generateArtifact(GeneratorConfig config) async {
    final files = <GeneratedFile>[];

    final projectRoot = _resolveProjectRoot(config.outputDir);
    final entityName = config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final gymDir = path.join(projectRoot, 'gym');
    final warmupDir = path.join(gymDir, 'warmup');

    files.add(
      await _writeFile(
        path: path.join(warmupDir, '01-smoke.dart'),
        content: _smokeRep(entityName, entitySnake),
        type: 'gym.warmup',
        config: config,
      ),
    );

    files.add(
      await _writeFile(
        path: path.join(warmupDir, '02-build.dart'),
        content: _buildRep(entityName),
        type: 'gym.warmup',
        config: config,
      ),
    );

    files.add(
      await _writeFile(
        path: path.join(gymDir, 'exercise-implement-feature.dart'),
        content: _exerciseImplementFeature(entityName, entitySnake),
        type: 'gym.exercise',
        config: config,
      ),
    );

    files.add(
      await _writeFile(
        path: path.join(gymDir, 'gym.yaml'),
        content: _gymYaml(entityName, entitySnake),
        type: 'gym.spec',
        config: config,
      ),
    );

    return files;
  }

  /// The project root is the parent of `lib/src` (mirrors TestBuilder which
  /// computes `projectRoot = outputDir.replaceAll('lib/src', '')`).
  String _resolveProjectRoot(String outputDir) {
    if (outputDir.endsWith('lib/src')) {
      return outputDir.substring(0, outputDir.length - 'lib/src'.length);
    }
    if (outputDir.endsWith('lib')) {
      return outputDir.substring(0, outputDir.length - 'lib'.length);
    }
    // Fall back to the parent of outputDir — best effort for non-standard
    // layouts. The gym/ folder will sit next to lib/ in the canonical case.
    return path.dirname(outputDir);
  }

  Future<GeneratedFile> _writeFile({
    required String path,
    required String content,
    required String type,
    required GeneratorConfig config,
  }) async {
    return FileUtils.writeFile(
      path,
      content,
      type,
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }

  // ------------------------------------------------------------------
  // WARMUP REP #1 — smoke-test the generated API.
  // ------------------------------------------------------------------
  String _smokeRep(String entityName, String entitySnake) {
    final useCaseName = '${entityName}UseCase';
    return '''/// GYM warmup rep #1 — smoke-test the generated $entityName API.
///
/// A warmup rep proves the operator can drive the generated code at all.
/// Run: `dart run gym/warmup/01-smoke.dart`
///
/// Rep: resolve the generated $useCaseName from the DI container,
/// execute it, and assert the result type matches `$entityName`. Throw on
/// any mismatch — a mis-fire is a DROP CARD, not a silent pass.
///
/// See github.com/arrrrny/gym for the paradigm,
///     github.com/arrrrny/drop-card for mis-fire capture.
library;

import 'package:zuraffa/zuraffa.dart';

Future<void> main() async {
  // 1. Bootstrap DI (getIt or whichever framework zfa wired).
  // 2. Resolve $useCaseName from the container.
  // 3. Execute it with NoParams (or the entity's id params).
  // 4. Assert the result type matches $entityName.
  //
  // A mis-fire (unexpected outcome, not a clean failure) is captured as a
  // DROP CARD — see github.com/arrrrny/drop-card.
  throw UnimplementedError(
    'Warmup rep 01-smoke not implemented yet for $entityName. '
    'Resolve $useCaseName from DI, execute, and assert the result.',
  );
}
''';
  }

  // ------------------------------------------------------------------
  // WARMUP REP #2 — build the host app under load.
  // ------------------------------------------------------------------
  String _buildRep(String entityName) {
    return '''/// GYM warmup rep #2 — build the host app under load.
///
/// Rep: run `flutter build` (or `dart compile`) on the host project and
/// assert the build exits 0. Failures here mean the generated $entityName
/// code does not compile — a hard gate, not a soft suggestion.
///
/// Run: `dart run gym/warmup/02-build.dart`
library;

import 'dart:io';

Future<void> main() async {
  // Detect Flutter vs pure-Dart from pubspec.yaml. The generated $entityName
  // code may pull in Flutter-only deps (e.g. shadcn_ui views), so prefer
  // `flutter build` when a flutter block is present.
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('No pubspec.yaml found in cwd=\${Directory.current.path}');
    exit(1);
  }
  final isFlutter = pubspec.readAsStringSync().contains('flutter:');

  final result = isFlutter
      ? await Process.run('flutter', ['build', 'apk'])
      : await Process.run('dart', ['compile', 'exe', 'bin/main.dart']);

  if (result.exitCode != 0) {
    stderr.writeln('Build FAILED (exit \${result.exitCode}) for $entityName:');
    stderr.writeln(result.stderr);
    exit(result.exitCode);
  }
  print('Build OK for $entityName — exit code \${result.exitCode}');
}
''';
  }

  // ------------------------------------------------------------------
  // EXERCISE — implement the feature end-to-end (graded).
  // ------------------------------------------------------------------
  String _exerciseImplementFeature(String entityName, String entitySnake) {
    return '''/// GYM exercise — implement the $entityName feature end-to-end (graded).
///
/// Brief: Using the generated $entityName scaffolding, wire a working
/// list+detail flow that fetches $entityName records from a real (or
/// mocked) data source and renders them via the generated view. The
/// exercise is graded against your actual output, not against reading
/// source.
///
/// Setup:
///   - Ensure `flutter` or `dart` is on PATH.
///   - Run the warmup reps first (gym/warmup/*).
///   - Write your implementation under lib/src/ and your tests under
///     test/$entitySnake/.
///
/// verifyCommand: `flutter test test/$entitySnake/`
/// evaluate: `exit 0 => pass; exit !=0 => fail`
///
/// A mis-fire (unexpected outcome, not a clean failure) is captured as a
/// DROP CARD — see github.com/arrrrny/drop-card.
library;

import 'dart:io';

Future<void> main() async {
  final result = await Process.run('flutter', [
    'test',
    'test/$entitySnake/',
  ]);
  if (result.exitCode != 0) {
    stderr.writeln('Exercise FAILED for $entityName:');
    stderr.writeln(result.stderr);
    exit(result.exitCode);
  }
  print('Exercise PASSED: $entityName feature is wired correctly.');
}
''';
  }

  // ------------------------------------------------------------------
  // gym.yaml — machine-readable spec for the miki GYM runner.
  // ------------------------------------------------------------------
  String _gymYaml(String entityName, String entitySnake) {
    return '''# GYM artifact — machine-readable spec for the miki GYM runner.
# See github.com/arrrrny/gym for the paradigm,
#     github.com/arrrrny/miki (gym.mjs) for the runner that consumes this file.
#
# A gym is a folder of exercises with two phases:
#   WARMUP    — mandatory reps that build reflex. No reps, no phase 2.
#   EXERCISES — graded work that proves the muscle under real load.
# The gate only lets the proven through. A mis-fire is a DROP CARD.
name: $entitySnake
version: 1.0.0
warmup:
  - id: 01-smoke
    name: Smoke-test the generated $entityName API
    command: dart run gym/warmup/01-smoke.dart
  - id: 02-build
    name: Build the host app under load
    command: dart run gym/warmup/02-build.dart
exercises:
  - id: implement-feature
    brief: |
      Using the generated $entityName scaffolding, wire a working list+detail
      flow that fetches $entityName records from a real (or mocked) data
      source and renders them via the generated view.
    setup: |
      Ensure `flutter` or `dart` is on PATH.
      Run the warmup reps first (gym/warmup/*).
      Write your implementation under lib/src/ and your tests under
      test/$entitySnake/.
    verifyCommand: flutter test test/$entitySnake/
    evaluate: exit 0 => pass; exit !=0 => fail
''';
  }
}
