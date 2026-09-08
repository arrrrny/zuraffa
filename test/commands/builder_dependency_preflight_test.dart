// Issue #1322 — the phase-0 preflight and the shared
// missing-builder-dependency classifier.
//
// In a clean Dart package where zorphy_annotation is a direct dependency
// but the zorphy BUILDER package is not in the dependency graph, `zfa tdd
// run` phase-0 scaffolds the entity + build.yaml, build_runner warns
// "Ignoring options for unknown builder zorphy:zorphy", generates
// nothing — and the #276 safety net blamed the generate_for globs. The
// classifier here names the missing package from
// .dart_tool/package_config.json (the dependency-graph truth store) and
// corroborates it with the build_runner signal; the preflight auto-adds
// the missing dev dependency BEFORE the entity is written.
//
// Hermetic: the `pub add --dev` spawn is intercepted by an injectable
// runner (the doctor_checks.dart `ZfaProcessRunner` /
// `PubspecProcessRunner` convention); the fake records invocations so the
// end state is pinned without a network.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/dependencies/builder_dependency_preflight.dart';
import 'package:zuraffa/src/core/dependencies/dependency_wirer.dart';

/// Records spawned pub commands without side effects.
class _RecordingRunner {
  final List<String> invocations = [];
  final int exitCode;

  _RecordingRunner({this.exitCode = 0});

  Future<ProcessResult> call(
    String executable,
    List<String> args,
    String workingDirectory,
  ) async {
    invocations.add('$executable ${args.join(' ')} [$workingDirectory]');
    return ProcessResult(1, exitCode, '', '');
  }
}

/// The build_runner signal the issue quotes verbatim.
const _zorphyWarning =
    '[WARNING] Ignoring options for unknown builder "zorphy:zorphy" '
    'found in build.yaml.';

/// A minimal resolved-package-config naming exactly [names].
String packageConfigJson(List<String> names) =>
    '{"configVersion":2,"packages":['
    '${names.map((n) => '{"name":"$n","rootUri":"../"}').join(',')}'
    ']}';

/// The canonical builder set as packages ( DependencyWirer.buildYamlContent).
const _canonicalPackages = ['zorphy', 'json_serializable', 'source_gen'];

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('zfa_1322_preflight_');
  });

  tearDown(() {
    if (sandbox.existsSync()) {
      sandbox.deleteSync(recursive: true);
    }
  });

  /// Resolves the sandbox against [packages]; null config = absent file.
  Future<void> seedResolved(List<String>? packages, {String? pubspec}) async {
    if (packages != null) {
      final dartTool = Directory(p.join(sandbox.path, '.dart_tool'));
      await dartTool.create(recursive: true);
      await File(
        p.join(dartTool.path, 'package_config.json'),
      ).writeAsString(packageConfigJson(packages));
    }
    await File(p.join(sandbox.path, 'pubspec.yaml')).writeAsString(
      pubspec ?? 'name: sandbox_1322\nenvironment:\n  sdk: ^3.11.0\n',
    );
  }

  group('registeredBuilders (build.yaml builder-key parsing)', () {
    test('parses the canonical scaffold content into its packages', () {
      final builders = BuilderDependencyPreflight.registeredBuilders(
        DependencyWirer.buildYamlContent,
      );
      final packages = builders.map((b) => b.package).toSet();
      expect(packages, containsAll(_canonicalPackages));
      expect(
        builders.where((b) => b.package == 'zorphy').single.key,
        'zorphy:zorphy',
      );
      expect(
        builders.where((b) => b.package == 'source_gen').single.key,
        'source_gen:combining_builder',
      );
    });

    test('parses the pipe form and deduplicates repeated keys', () {
      final builders = BuilderDependencyPreflight.registeredBuilders('''
targets:
  \$default:
    builders:
      some_pkg|its_builder:
        enabled: true
      some_pkg:its_builder:
        enabled: true
''');
      expect(builders.map((b) => b.package).toSet(), {'some_pkg'});
    });

    test('empty / builder-less content yields nothing (fail-open)', () {
      expect(BuilderDependencyPreflight.registeredBuilders(''), isEmpty);
      expect(
        BuilderDependencyPreflight.registeredBuilders('not: [a, yaml, map'),
        isEmpty,
      );
    });
  });

  group('tryResolvablePackages (dependency-graph truth store)', () {
    test('returns the package names from package_config.json', () async {
      await seedResolved(['test', 'mocktail', 'zorphy']);
      expect(BuilderDependencyPreflight.tryResolvablePackages(sandbox.path), {
        'test',
        'mocktail',
        'zorphy',
      });
    });

    test('returns null when the project has not been pub-resolved', () async {
      await seedResolved(null);
      expect(
        BuilderDependencyPreflight.tryResolvablePackages(sandbox.path),
        isNull,
      );
    });
  });

  group('missingBuilderPackages (the shared #1322 classifier)', () {
    test('diagnoses zorphy when absent from a resolved project', () async {
      // Resolved, zorphy NOT in the graph (json_serializable/source_gen
      // resolvable so only zorphy is named); no build.yaml → the canonical
      // scaffold set is the effective set.
      await seedResolved([..._canonicalPackages, 'test', 'mocktail']);
      final missing = BuilderDependencyPreflight.missingBuilderPackages(
        projectRoot: sandbox.path,
      );
      expect(missing, isEmpty, reason: 'all canonical packages resolvable');

      // Drop zorphy from the graph — the exact #1322 state.
      await seedResolved(['json_serializable', 'source_gen', 'test']);
      final missing2 = BuilderDependencyPreflight.missingBuilderPackages(
        projectRoot: sandbox.path,
        buildOutput: _zorphyWarning,
      );
      expect(missing2.map((b) => b.package), ['zorphy']);
    });

    test(
      'never diagnoses an unresolved (package_config-less) project',
      () async {
        await seedResolved(null);
        expect(
          BuilderDependencyPreflight.missingBuilderPackages(
            projectRoot: sandbox.path,
            buildOutput: _zorphyWarning,
          ),
          isEmpty,
        );
      },
    );

    test('the output signal alone does not fire on a resolvable package '
        '(builder-name typo class)', () async {
      await seedResolved([..._canonicalPackages]);
      expect(
        BuilderDependencyPreflight.missingBuilderPackages(
          projectRoot: sandbox.path,
          buildOutput:
              '[WARNING] Ignoring options for unknown builder '
              '"zorphy:typo" found in build.yaml.',
        ),
        isEmpty,
      );
    });

    test('a project build.yaml extends the effective builder set', () async {
      await seedResolved([..._canonicalPackages, 'test']);
      await File(p.join(sandbox.path, 'build.yaml')).writeAsString('''
targets:
  \$default:
    builders:
      some_other_pkg:its_builder:
        enabled: true
''');
      final missing = BuilderDependencyPreflight.missingBuilderPackages(
        projectRoot: sandbox.path,
      );
      expect(missing.map((b) => b.package), ['some_other_pkg']);
      expect(missing.single.key, 'some_other_pkg:its_builder');
    });

    test(
      'extracts unknown-builder keys from build output (quoted and not)',
      () {
        final keys = BuilderDependencyPreflight.unknownBuildersFromOutput('''
[WARNING] Ignoring options for unknown builder "zorphy:zorphy" found in build.yaml.
[WARNING] Ignoring options for unknown builder other:thing found in build.yaml.
fine line
''');
        expect(keys.map((b) => b.key).toSet(), {
          'zorphy:zorphy',
          'other:thing',
        });
      },
    );
  });

  group('missingBuildersForFailedBuild (the AC-3 evidence rule)', () {
    test('attributes a failed build to the missing package when the output '
        'carries the build_runner signal', () async {
      await seedResolved(['test', 'json_serializable', 'source_gen']);
      final missing = BuilderDependencyPreflight.missingBuildersForFailedBuild(
        projectRoot: sandbox.path,
        buildOutput: _zorphyWarning,
      );
      expect(missing.map((b) => b.package), ['zorphy']);
    });

    test('attributes a failed build when the child zfa build failed through '
        'the #276 safety net (marker in the captured output)', () async {
      await seedResolved(['test', 'json_serializable', 'source_gen']);
      final missing = BuilderDependencyPreflight.missingBuildersForFailedBuild(
        projectRoot: sandbox.path,
        buildOutput:
            '❌ build_runner wrote 0 outputs although @Zorphy sources exist.\n'
            '   The builder package(s) zorphy (registered in build.yaml as '
            'zorphy:zorphy) are NOT in the dependency graph — fix: '
            '`dart pub add --dev zorphy`',
      );
      expect(missing.map((b) => b.package), ['zorphy']);
    });

    test('NEVER attributes a generic failure to the missing package — the '
        'static state alone cannot attribute an unrelated failure '
        '(the U-991b class)', () async {
      await seedResolved(['test', 'json_serializable', 'source_gen']);
      expect(
        BuilderDependencyPreflight.missingBuildersForFailedBuild(
          projectRoot: sandbox.path,
          buildOutput: 'build_runner exited 1',
        ),
        isEmpty,
      );
      expect(
        BuilderDependencyPreflight.missingBuildersForFailedBuild(
          projectRoot: sandbox.path,
        ),
        isEmpty,
      );
    });
  });

  group('missingBuilderDependencyLines (the message contract)', () {
    test(
      'names the package, quotes the signal, prescribes the exact fix',
      () async {
        // The real #1322 repro state: tdd init wires json_serializable (dev),
        // only zorphy is missing from the graph.
        await seedResolved(['test', 'json_serializable', 'source_gen']);
        final missing = BuilderDependencyPreflight.missingBuilderPackages(
          projectRoot: sandbox.path,
          buildOutput: _zorphyWarning,
        );
        final lines = BuilderDependencyPreflight.missingBuilderDependencyLines(
          missing: missing,
          buildOutput: _zorphyWarning,
        ).join('\n');
        expect(lines, contains('zorphy'));
        expect(lines, contains('dart pub add --dev zorphy'));
        expect(lines, contains('Ignoring options for unknown builder'));
        expect(lines, contains('package_config.json'));
        // The misdiagnosis this spec kills: the glob remedy must NOT be the
        // message for the missing-dependency class.
        expect(lines, isNot(contains('generate_for')));
        expect(lines, isNot(contains('zfa setup')));
      },
    );

    test('is generic over any registered builder', () async {
      await seedResolved([..._canonicalPackages]);
      await File(p.join(sandbox.path, 'build.yaml')).writeAsString('''
targets:
  \$default:
    builders:
      some_other_pkg:its_builder:
        enabled: true
''');
      final missing = BuilderDependencyPreflight.missingBuilderPackages(
        projectRoot: sandbox.path,
      );
      final lines = BuilderDependencyPreflight.missingBuilderDependencyLines(
        missing: missing,
      ).join('\n');
      expect(lines, contains('some_other_pkg'));
      expect(lines, contains('dart pub add --dev some_other_pkg'));
      expect(lines, isNot(contains('zorphy')));
    });
  });

  group('ensureBuilderDependencies (the AC-1 phase-0 preflight)', () {
    test('no-op when every builder package is resolvable (no spawn)', () async {
      await seedResolved([..._canonicalPackages, 'test']);
      final runner = _RecordingRunner();
      final result = await BuilderDependencyPreflight.ensureBuilderDependencies(
        projectRoot: sandbox.path,
        runner: runner.call,
      );
      expect(result.isNoOp, isTrue);
      expect(result.added, isEmpty);
      expect(result.failed, isEmpty);
      expect(runner.invocations, isEmpty);
    });

    test('runs `dart pub add --dev zorphy` in the project root', () async {
      // The real #1322 repro state: tdd init wires json_serializable (dev),
      // only zorphy is missing from the graph.
      await seedResolved([
        'test',
        'mocktail',
        'json_serializable',
        'source_gen',
      ]);
      final runner = _RecordingRunner();
      final result = await BuilderDependencyPreflight.ensureBuilderDependencies(
        projectRoot: sandbox.path,
        runner: runner.call,
      );
      expect(result.failed, isEmpty);
      expect(result.added, contains('zorphy'));
      expect(runner.invocations, hasLength(1));
      expect(runner.invocations.single, contains('dart pub add --dev zorphy'));
      expect(runner.invocations.single, contains(sandbox.path));
    });

    test('blocks when the add fails: failed names the package', () async {
      await seedResolved(['test', 'json_serializable', 'source_gen']);
      final runner = _RecordingRunner(exitCode: 1);
      final result = await BuilderDependencyPreflight.ensureBuilderDependencies(
        projectRoot: sandbox.path,
        runner: runner.call,
      );
      expect(result.blocked, isTrue);
      expect(result.added, isEmpty);
      expect(result.failed, ['zorphy']);
      expect(result.commandLine, contains('dart pub add --dev'));
      // The blocking prescription is available for the caller to print.
      final lines = BuilderDependencyPreflight.missingBuilderDependencyLines(
        missing: result.missing,
      ).join('\n');
      expect(lines, contains('dart pub add --dev zorphy'));
    });

    test('dry-run reports the would-add without spawning or writing', () async {
      await seedResolved(['test', 'json_serializable', 'source_gen']);
      final pubspecBefore = File(
        p.join(sandbox.path, 'pubspec.yaml'),
      ).readAsStringSync();
      final runner = _RecordingRunner();
      final result = await BuilderDependencyPreflight.ensureBuilderDependencies(
        projectRoot: sandbox.path,
        dryRun: true,
        runner: runner.call,
      );
      expect(result.dryRun, isTrue);
      expect(result.missing.map((b) => b.package), contains('zorphy'));
      expect(result.added, isEmpty);
      expect(runner.invocations, isEmpty);
      expect(
        File(p.join(sandbox.path, 'pubspec.yaml')).readAsStringSync(),
        pubspecBefore,
      );
    });

    test('a Flutter project uses `flutter pub add --dev`', () async {
      await seedResolved(
        ['test', 'json_serializable', 'source_gen'],
        pubspec:
            'name: sandbox_1322\n'
            'environment:\n  sdk: ^3.11.0\n'
            'dependencies:\n  flutter:\n    sdk: flutter\n',
      );
      final runner = _RecordingRunner();
      await BuilderDependencyPreflight.ensureBuilderDependencies(
        projectRoot: sandbox.path,
        runner: runner.call,
      );
      expect(runner.invocations, hasLength(1));
      expect(
        runner.invocations.single,
        contains('flutter pub add --dev zorphy'),
      );
    });
  });
}
