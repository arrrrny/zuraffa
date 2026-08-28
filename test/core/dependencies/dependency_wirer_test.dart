import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/dependencies/dependency_wirer.dart';

void main() {
  group('DependencyWirer', () {
    group('standardSet', () {
      test('flutter project includes zuraffa_flutter + flutter_lints', () {
        final specs = DependencyWirer.standardSet(isFlutter: true);
        final names = specs.map((s) => s.name).toList();

        expect(names, contains('zuraffa_flutter'));
        expect(names, isNot(contains('zuraffa')));
        expect(names, contains('zorphy_annotation'));
        expect(names, contains('build_runner'));
        expect(names, contains('json_annotation'));
        expect(names, contains('json_serializable'));
        expect(names, contains('flutter_lints'));
        expect(names, contains('analyzer'));
      });

      test(
        'dart project includes zuraffa (not zuraffa_flutter) and no flutter_lints',
        () {
          final specs = DependencyWirer.standardSet(isFlutter: false);
          final names = specs.map((s) => s.name).toList();

          expect(names, contains('zuraffa'));
          expect(names, isNot(contains('zuraffa_flutter')));
          expect(names, contains('zorphy_annotation'));
          expect(names, contains('build_runner'));
          expect(names, contains('json_annotation'));
          expect(names, contains('json_serializable'));
          expect(names, contains('test'));
          expect(names, isNot(contains('flutter_lints')));
          expect(names, contains('analyzer'));
        },
      );

      test('zuraffa_flutter is a hosted dependency', () {
        final specs = DependencyWirer.standardSet(isFlutter: true);
        final zuraffaFlutter = specs.firstWhere(
          (s) => s.name == 'zuraffa_flutter',
        );

        expect(zuraffaFlutter.kind, DependencyKind.regular);
        expect(zuraffaFlutter.isGit, isFalse);
        expect(zuraffaFlutter.version, '^6.0.0');
      });

      test('zuraffa (dart) is a hosted dependency', () {
        final specs = DependencyWirer.standardSet(isFlutter: false);
        final zuraffa = specs.firstWhere((s) => s.name == 'zuraffa');

        expect(zuraffa.isGit, isFalse);
        expect(zuraffa.version, '^6.0.0');
      });

      test('zorphy_annotation is a hosted dependency', () {
        final specs = DependencyWirer.standardSet(isFlutter: true);
        final zorphyAnn = specs.firstWhere(
          (s) => s.name == 'zorphy_annotation',
        );

        expect(zorphyAnn.isGit, isFalse);
        expect(zorphyAnn.version, '^2.0.0');
      });

      test('build_runner is a dev dependency', () {
        final specs = DependencyWirer.standardSet(isFlutter: true);
        final buildRunner = specs.firstWhere((s) => s.name == 'build_runner');

        expect(buildRunner.kind, DependencyKind.dev);
        expect(buildRunner.isGit, isFalse);
      });

      test('test is a hosted dev dependency for pure-Dart projects', () {
        final specs = DependencyWirer.standardSet(isFlutter: false);
        final testPackage = specs.firstWhere((s) => s.name == 'test');

        expect(testPackage.kind, DependencyKind.dev);
        expect(testPackage.isGit, isFalse);
      });

      test('flutter project overrides analyzer ^13.1.0 + meta ^1.19.0', () {
        final specs = DependencyWirer.standardSet(isFlutter: true);
        final analyzer = specs.firstWhere((s) => s.name == 'analyzer');
        final meta = specs.firstWhere((s) => s.name == 'meta');

        expect(analyzer.kind, DependencyKind.override);
        expect(
          analyzer.version,
          DependencyWirer.flutterAnalyzerOverrideVersion,
        );
        expect(analyzer.isOverride, isTrue);
        // Flutter apps need the meta overlay too: the Flutter SDK pins
        // meta 1.18.0 while analyzer >=13.1.0 requires meta ^1.18.3.
        expect(meta.kind, DependencyKind.override);
        expect(meta.version, DependencyWirer.flutterMetaOverrideVersion);
        expect(meta.isOverride, isTrue);
      });

      test('dart project keeps the pinned analyzer 14.1.0 override only', () {
        final specs = DependencyWirer.standardSet(isFlutter: false);
        final analyzer = specs.firstWhere((s) => s.name == 'analyzer');

        expect(analyzer.kind, DependencyKind.override);
        expect(analyzer.version, DependencyWirer.analyzerOverrideVersion);
        expect(analyzer.isOverride, isTrue);
        // Pure Dart packages do not overlay meta.
        expect(specs.map((s) => s.name), isNot(contains('meta')));
      });
    });

    group('findMissing', () {
      test('returns all specs for an empty pubspec', () {
        final pubspec = '''
name: my_app
description: A new app
environment:
  sdk: ^3.11.0
''';
        final missing = DependencyWirer.findMissing(pubspec, isFlutter: true);

        final names = missing.map((s) => s.name).toSet();
        expect(
          names,
          containsAll([
            'zuraffa_flutter',
            'zorphy_annotation',
            'json_annotation',
            'build_runner',
            'json_serializable',
            'flutter_lints',
            'analyzer',
          ]),
        );
      });

      test('returns empty when all deps are present', () {
        final pubspec = '''
name: my_app
environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter:
    git:
      url: https://github.com/arrrrny/zuraffa
      path: zuraffa_flutter
      ref: development
  zorphy_annotation:
    git:
      url: https://github.com/arrrrny/zorphy
      path: zorphy_annotation
      ref: development
  json_annotation: ^4.12.0

dev_dependencies:
  build_runner: ^2.15.2
  json_serializable: ^6.13.2

  flutter_lints: ^6.0.0

dependency_overrides:
  analyzer: ^13.1.0
  meta: ^1.19.0
''';
        final missing = DependencyWirer.findMissing(pubspec, isFlutter: true);

        expect(missing, isEmpty);
      });

      test('detects missing zuraffa_flutter only', () {
        final pubspec = '''
name: my_app
environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
  zorphy_annotation:
    git:
      url: https://github.com/arrrrny/zorphy
      path: zorphy_annotation
  json_annotation: ^4.12.0

dev_dependencies:
  build_runner: ^2.15.2
  json_serializable: ^6.13.2

  flutter_lints: ^6.0.0

dependency_overrides:
  analyzer: ^13.1.0
  meta: ^1.19.0
''';
        final missing = DependencyWirer.findMissing(pubspec, isFlutter: true);

        expect(missing.length, 1);
        expect(missing.first.name, 'zuraffa_flutter');
      });

      test('detects missing build_runner only', () {
        final pubspec = '''
name: my_app
environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter:
    git:
      url: https://github.com/arrrrny/zuraffa
      path: zuraffa_flutter
  zorphy_annotation:
    git:
      url: https://github.com/arrrrny/zorphy
      path: zorphy_annotation
  json_annotation: ^4.12.0

dev_dependencies:
  json_serializable: ^6.13.2

  flutter_lints: ^6.0.0

dependency_overrides:
  analyzer: ^13.1.0
  meta: ^1.19.0
''';
        final missing = DependencyWirer.findMissing(pubspec, isFlutter: true);

        expect(missing.length, 1);
        expect(missing.first.name, 'build_runner');
        expect(missing.first.kind, DependencyKind.dev);
      });

      test('detects missing analyzer + meta overrides only', () {
        final pubspec = '''
name: my_app
environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter:
    git:
      url: https://github.com/arrrrny/zuraffa
      path: zuraffa_flutter
  zorphy_annotation:
    git:
      url: https://github.com/arrrrny/zorphy
      path: zorphy_annotation
  json_annotation: ^4.12.0

dev_dependencies:
  build_runner: ^2.15.2
  json_serializable: ^6.13.2

  flutter_lints: ^6.0.0
''';
        final missing = DependencyWirer.findMissing(pubspec, isFlutter: true);

        expect(missing.length, 2);
        expect(missing.map((s) => s.name), containsAll(['analyzer', 'meta']));
        expect(missing.every((s) => s.kind == DependencyKind.override), isTrue);
      });

      test('dart project: missing analyzer override only', () {
        final pubspec = '''
name: my_pkg
environment:
  sdk: ^3.11.0

dependencies:
  zuraffa:
    git:
      url: https://github.com/arrrrny/zuraffa
  zorphy_annotation:
    git:
      url: https://github.com/arrrrny/zorphy
      path: zorphy_annotation
  json_annotation: ^4.12.0

dev_dependencies:
  build_runner: ^2.15.2
  json_serializable: ^6.13.2
  test: ^1.25.0

''';
        final missing = DependencyWirer.findMissing(pubspec, isFlutter: false);

        expect(missing.length, 1);
        expect(missing.first.name, 'analyzer');
        expect(missing.first.kind, DependencyKind.override);
      });

      test('dart project: zuraffa present means not missing', () {
        final pubspec = '''
name: my_pkg
environment:
  sdk: ^3.11.0

dependencies:
  zuraffa:
    git:
      url: https://github.com/arrrrny/zuraffa
  zorphy_annotation:
    git:
      url: https://github.com/arrrrny/zorphy
      path: zorphy_annotation
  json_annotation: ^4.12.0

dev_dependencies:
  build_runner: ^2.15.2
  json_serializable: ^6.13.2
  test: ^1.25.0


dependency_overrides:
  analyzer: 14.1.0
''';
        final missing = DependencyWirer.findMissing(pubspec, isFlutter: false);

        expect(missing, isEmpty);
      });

      test(
        'flutter project: stale analyzer override version is detected as missing',
        () {
          final pubspec = '''
name: my_app
environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter:
    git:
      url: https://github.com/arrrrny/zuraffa
      path: zuraffa_flutter
  zorphy_annotation:
    git:
      url: https://github.com/arrrrny/zorphy
      path: zorphy_annotation
  json_annotation: ^4.12.0

dev_dependencies:
  build_runner: ^2.15.2
  json_serializable: ^6.13.2

  flutter_lints: ^6.0.0

dependency_overrides:
  analyzer: 14.1.0
  meta: ^1.19.0
''';
          final missing = DependencyWirer.findMissing(pubspec, isFlutter: true);

          // Flutter projects expect analyzer: ^13.1.0, not 14.1.0, so analyzer
          // should be detected as needing an update.
          expect(missing.length, 1);
          expect(missing.first.name, 'analyzer');
          expect(missing.first.kind, DependencyKind.override);
          expect(
            missing.first.version,
            DependencyWirer.flutterAnalyzerOverrideVersion,
          );
        },
      );

      test('returns all specs for unparseable pubspec', () {
        final pubspec = 'this is not ::: valid yaml {{{';
        final missing = DependencyWirer.findMissing(pubspec, isFlutter: true);

        expect(missing.length, greaterThan(0));
      });
    });

    group('isFlutterProject', () {
      test('returns true when flutter SDK dep is present', () {
        final pubspec = '''
name: my_app
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
''';
        expect(DependencyWirer.isFlutterProject(pubspec), isTrue);
      });

      test('returns false for a pure Dart package', () {
        final pubspec = '''
name: my_pkg
environment:
  sdk: ^3.11.0
dependencies:
  http: ^1.6.0
''';
        expect(DependencyWirer.isFlutterProject(pubspec), isFalse);
      });

      test('returns false for unparseable pubspec', () {
        expect(DependencyWirer.isFlutterProject('garbage'), isFalse);
      });
    });

    group('addOverrideToPubspec', () {
      test('appends new dependency_overrides section when absent', () {
        final pubspec = '''
name: my_app
environment:
  sdk: ^3.11.0
dependencies:
  http: ^1.6.0
''';
        final result = DependencyWirer.addOverrideToPubspec(
          pubspec,
          'analyzer',
          '14.1.0',
        );

        expect(result, contains('dependency_overrides:'));
        expect(result, contains('  analyzer: 14.1.0'));
        // Original content preserved
        expect(result, contains('name: my_app'));
        expect(result, contains('dependencies:'));
      });

      test('inserts key into existing dependency_overrides section', () {
        final pubspec = '''
name: my_app
environment:
  sdk: ^3.11.0

dependency_overrides:
  meta: ^1.19.0

dependencies:
  http: ^1.6.0
''';
        final result = DependencyWirer.addOverrideToPubspec(
          pubspec,
          'analyzer',
          '14.1.0',
        );

        expect(result, contains('  analyzer: 14.1.0'));
        expect(result, contains('  meta: ^1.19.0'));
        // The analyzer entry should be in the overrides section (before dependencies)
        final analyzerIdx = result.indexOf('  analyzer: 14.1.0');
        final depsIdx = result.indexOf('\ndependencies:');
        expect(analyzerIdx, lessThan(depsIdx));
      });

      test('is idempotent when key already exists with matching value', () {
        final pubspec = '''
name: my_app
environment:
  sdk: ^3.11.0

dependency_overrides:
  analyzer: 14.1.0

dependencies:
  http: ^1.6.0
''';
        final result = DependencyWirer.addOverrideToPubspec(
          pubspec,
          'analyzer',
          '14.1.0',
        );

        // Should be unchanged — value already matches
        expect(result, equals(pubspec));
      });

      test('replaces existing value when it differs from new value', () {
        final pubspec = '''
name: my_app
environment:
  sdk: ^3.11.0

dependency_overrides:
  analyzer: 14.1.0

dependencies:
  http: ^1.6.0
''';
        final result = DependencyWirer.addOverrideToPubspec(
          pubspec,
          'analyzer',
          '^13.1.0',
        );

        // Old value (14.1.0) should be replaced with new value (^13.1.0)
        expect(result, contains('  analyzer: ^13.1.0'));
        expect(result, isNot(contains('  analyzer: 14.1.0')));
        // Other content should be preserved
        expect(result, contains('name: my_app'));
        expect(result, contains('dependencies:'));
        expect(result, contains('http: ^1.6.0'));
      });

      test('handles pubspec with no trailing newline', () {
        final pubspec = 'name: my_app\nenvironment:\n  sdk: ^3.11.0';
        final result = DependencyWirer.addOverrideToPubspec(
          pubspec,
          'analyzer',
          '14.1.0',
        );

        expect(result, contains('dependency_overrides:'));
        expect(result, contains('  analyzer: 14.1.0'));
      });

      test('does not modify entries in other sections', () {
        final pubspec = '''
name: my_app

dependencies:
  analyzer: ^5.0.0

dev_dependencies:
  build_runner: ^2.0.0
''';
        final result = DependencyWirer.addOverrideToPubspec(
          pubspec,
          'analyzer',
          '14.1.0',
        );

        // The original analyzer in dependencies should be untouched
        expect(result, contains('  analyzer: ^5.0.0'));
        // And the new override entry added
        expect(result, contains('dependency_overrides:'));
        expect(result, contains('  analyzer: 14.1.0'));
      });
    });

    group('DependencySpec', () {
      test('toString renders dev deps with dev: prefix', () {
        const spec = DependencySpec(
          name: 'build_runner',
          kind: DependencyKind.dev,
        );
        expect(spec.toString(), 'dev:build_runner');
      });

      test('toString renders overrides with version', () {
        const spec = DependencySpec(
          name: 'analyzer',
          kind: DependencyKind.override,
          version: '14.1.0',
        );
        expect(spec.toString(), 'override:analyzer=14.1.0');
      });

      test('toString renders git deps with (git) marker', () {
        const spec = DependencySpec(
          name: 'zuraffa',
          kind: DependencyKind.regular,
          gitUrl: 'https://github.com/arrrrny/zuraffa',
        );
        expect(spec.toString(), 'zuraffa (git)');
      });

      test('equality compares all fields', () {
        const a = DependencySpec(
          name: 'analyzer',
          kind: DependencyKind.override,
          version: '14.1.0',
        );
        const b = DependencySpec(
          name: 'analyzer',
          kind: DependencyKind.override,
          version: '14.1.0',
        );
        const c = DependencySpec(
          name: 'analyzer',
          kind: DependencyKind.override,
          version: '15.0.0',
        );
        expect(a, equals(b));
        expect(a, isNot(equals(c)));
      });
    });

    group('WireResult', () {
      test('isSuccess when no failures', () {
        const result = WireResult(added: ['build_runner'], failed: []);
        expect(result.isSuccess, isTrue);
      });

      test('is not success when there are failures', () {
        const result = WireResult(added: [], failed: ['zuraffa_flutter']);
        expect(result.isSuccess, isFalse);
      });

      test('dryRun flag is preserved', () {
        const result = WireResult(added: ['a'], dryRun: true);
        expect(result.dryRun, isTrue);
      });
    });

    group('buildYamlContent', () {
      test('contains zorphy builder registration', () {
        expect(DependencyWirer.buildYamlContent, contains('zorphy:zorphy'));
        expect(DependencyWirer.buildYamlContent, contains('enabled: true'));
      });

      test('contains json_serializable builder', () {
        expect(DependencyWirer.buildYamlContent, contains('json_serializable'));
      });

      test('contains source_gen combining_builder', () {
        expect(
          DependencyWirer.buildYamlContent,
          contains('source_gen:combining_builder'),
        );
      });

      test('targets lib/src/** and test/**', () {
        expect(DependencyWirer.buildYamlContent, contains('lib/src/**'));
        expect(DependencyWirer.buildYamlContent, contains('test/**'));
      });
    });

    group('standardDirs', () {
      test('includes domain/entities', () {
        expect(
          DependencyWirer.standardDirs,
          contains('lib/src/domain/entities'),
        );
      });

      test('includes domain/repositories', () {
        expect(
          DependencyWirer.standardDirs,
          contains('lib/src/domain/repositories'),
        );
      });

      test('includes domain/usecases', () {
        expect(
          DependencyWirer.standardDirs,
          contains('lib/src/domain/usecases'),
        );
      });

      test('includes data/datasources', () {
        expect(
          DependencyWirer.standardDirs,
          contains('lib/src/data/datasources'),
        );
      });

      test('includes data/repositories', () {
        expect(
          DependencyWirer.standardDirs,
          contains('lib/src/data/repositories'),
        );
      });
    });

    group('resolvePackageOverrides', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('zfa_resolve_');
      });

      tearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('reads dependency_overrides from the resolved package', () {
        final pkgRoot =
            Directory('${tempDir.path}/pkgs/zuraffa_flutter')
              ..createSync(recursive: true);
        File('${pkgRoot.path}/pubspec.yaml').writeAsStringSync('''
name: zuraffa_flutter
dependency_overrides:
  analyzer: ^13.1.0
  meta: ^1.19.0
''');
        Directory('${tempDir.path}/.dart_tool').createSync();
        File('${tempDir.path}/.dart_tool/package_config.json')
            .writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [
    { "name": "zuraffa_flutter", "rootUri": "../pkgs/zuraffa_flutter/" }
  ]
}
''');
        final overrides = DependencyWirer.resolvePackageOverrides(
          'zuraffa_flutter',
          projectRoot: tempDir.path,
        );
        expect(overrides['analyzer'], '^13.1.0');
        expect(overrides['meta'], '^1.19.0');
      });

      test('returns empty when package_config.json is missing', () {
        final overrides = DependencyWirer.resolvePackageOverrides(
          'zuraffa_flutter',
          projectRoot: tempDir.path,
        );
        expect(overrides, isEmpty);
      });

      test('returns empty when the package is not in the config', () {
        Directory('${tempDir.path}/.dart_tool').createSync();
        File('${tempDir.path}/.dart_tool/package_config.json')
            .writeAsStringSync('{"configVersion":2,"packages":[]}');
        final overrides = DependencyWirer.resolvePackageOverrides(
          'zuraffa_flutter',
          projectRoot: tempDir.path,
        );
        expect(overrides, isEmpty);
      });
    });

    group('ensureProjectStructure', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('zfa_structure_');
      });

      tearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('creates build.yaml and every standard directory', () async {
        await DependencyWirer.ensureProjectStructure(projectRoot: tempDir.path);

        expect(File('${tempDir.path}/build.yaml').existsSync(), isTrue);
        for (final dir in DependencyWirer.standardDirs) {
          expect(
            Directory('${tempDir.path}/$dir').existsSync(),
            isTrue,
            reason: 'expected $dir to be created',
          );
        }
      });

      test('does not overwrite an existing build.yaml', () async {
        final buildYaml = File('${tempDir.path}/build.yaml');
        await buildYaml.writeAsString('custom: true\n');

        await DependencyWirer.ensureProjectStructure(projectRoot: tempDir.path);

        expect(buildYaml.readAsStringSync(), 'custom: true\n');
      });

      test('dryRun creates nothing', () async {
        await DependencyWirer.ensureProjectStructure(
          projectRoot: tempDir.path,
          dryRun: true,
        );

        expect(File('${tempDir.path}/build.yaml').existsSync(), isFalse);
        for (final dir in DependencyWirer.standardDirs) {
          expect(
            Directory('${tempDir.path}/$dir').existsSync(),
            isFalse,
            reason: 'expected $dir NOT to be created in dry-run',
          );
        }
      });
    });
  });
}
