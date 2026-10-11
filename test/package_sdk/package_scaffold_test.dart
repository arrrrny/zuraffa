@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/package/package_scaffold.dart';
import 'package:yaml/yaml.dart';
import 'package:zuraffa/src/version.dart';

/// The published-looking constraint the hermetic scaffolds pin — distinct
/// from the dev version const, so a regression back to `^$version` shows up
/// on disk.
const String _publishedConstraintStub = '^6.2.2';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_pkg_scaffold_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<PackageScaffoldResult> scaffold({
    String? zuraffaPath,
    String? zuraffaConstraint,
    Future<String> Function()? zuraffaConstraintResolver,
    void Function(String message)? warningSink,
    String name = 'my_pkg',
    String description = 'A test package',
  }) {
    return PackageScaffold(
      // Default to a stub: this suite must not depend on pub.dev.
      zuraffaConstraintResolver:
          zuraffaConstraintResolver ?? () async => _publishedConstraintStub,
      warningSink: warningSink,
    ).create(
      name: name,
      outputParent: tempDir.path,
      description: description,
      zuraffaPath: zuraffaPath,
      zuraffaConstraint: zuraffaConstraint,
    );
  }

  group('PackageScaffold (FR-001 — spec 025)', () {
    test('U2: writes the full standard layout', () async {
      final result = await scaffold();

      final pkg = p.join(tempDir.path, 'my_pkg');
      expect(result.packagePath, pkg);

      final expectedFiles = [
        'pubspec.yaml',
        'zfa.yaml',
        'build.yaml',
        'analysis_options.yaml',
        '.gitignore',
        'README.md',
        p.join('lib', 'my_pkg.dart'),
        p.join('lib', 'src', 'module', 'my_pkg_package_module.dart'),
        p.join('lib', 'src', 'di', 'my_pkg_package_registrar.dart'),
        p.join('test', 'package_smoke_test.dart'),
      ];
      for (final rel in expectedFiles) {
        expect(
          File(p.join(pkg, rel)).existsSync(),
          isTrue,
          reason: '$rel must exist in the scaffold',
        );
      }

      // Standard domain/data directory layout.
      final expectedDirs = [
        p.join('lib', 'src', 'domain', 'entities'),
        p.join('lib', 'src', 'domain', 'repositories'),
        p.join('lib', 'src', 'domain', 'usecases'),
        p.join('lib', 'src', 'data', 'datasources'),
        p.join('lib', 'src', 'data', 'repositories'),
      ];
      for (final rel in expectedDirs) {
        expect(
          Directory(p.join(pkg, rel)).existsSync(),
          isTrue,
          reason: '$rel/ must exist in the scaffold',
        );
      }
    });

    test('U3: pubspec carries correct v6 dependency constraints', () async {
      await scaffold();

      final pubspec = File(
        p.join(tempDir.path, 'my_pkg', 'pubspec.yaml'),
      ).readAsStringSync();
      expect(pubspec, contains('name: my_pkg'));
      expect(pubspec, contains('publish_to: none'));
      expect(pubspec, contains('zuraffa: $_publishedConstraintStub'));
      expect(pubspec, contains('zorphy:'));
      expect(pubspec, contains('zorphy_annotation:'));
      expect(pubspec, contains('build_runner:'));
      expect(pubspec, contains('test:'));
      expect(pubspec, contains('sdk:'));
    });

    test(
      'U3b: --zuraffa-path swaps hosted dep for a path dependency',
      () async {
        final zfaDir = Directory(p.join(tempDir.path, 'zfa_checkout'))
          ..createSync();
        await scaffold(zuraffaPath: zfaDir.path);

        final pubspec = File(
          p.join(tempDir.path, 'my_pkg', 'pubspec.yaml'),
        ).readAsStringSync();
        expect(pubspec, contains('path: ${zfaDir.path}'));
        expect(pubspec, isNot(contains('zuraffa: ^')));
      },
    );

    test(
      'U3c: description containing a colon stays YAML-safe (dogfood bug)',
      () async {
        await scaffold(
          name: 'colon_pkg',
          description: 'Spec 025 reference: one entity, one usecase',
        );

        final pubspec = File(
          p.join(tempDir.path, 'colon_pkg', 'pubspec.yaml'),
        ).readAsStringSync();
        // Round-trip through a real YAML parser — a raw `:` inside the
        // description used to break pubspec parsing entirely.
        final doc = loadYaml(pubspec);
        expect(
          doc['description'],
          'Spec 025 reference: one entity, one usecase',
        );
      },
    );

    test(
      'U2b: zfa.yaml carries the package-mode marker; build.yaml stays build_runner-legal',
      () async {
        await scaffold();

        final zfaYaml = File(
          p.join(tempDir.path, 'my_pkg', 'zfa.yaml'),
        ).readAsStringSync();
        expect(zfaYaml, contains('package_mode: true'));

        final buildYaml = File(
          p.join(tempDir.path, 'my_pkg', 'build.yaml'),
        ).readAsStringSync();
        expect(buildYaml, contains('zorphy:zorphy'));
        expect(buildYaml, contains('json_serializable'));
        // The marker must NOT live in build.yaml — build_runner rejects
        // unknown top-level keys there (verified in the spec-025 e2e).
        expect(buildYaml, isNot(contains('package_mode')));
        expect(buildYaml, isNot(contains('zfa:')));
      },
    );

    test(
      'U4: module stub extends PackageModule and calls the registrar',
      () async {
        await scaffold();

        final module = File(
          p.join(
            tempDir.path,
            'my_pkg',
            'lib',
            'src',
            'module',
            'my_pkg_package_module.dart',
          ),
        ).readAsStringSync();

        expect(
          module,
          contains('class MyPkgPackageModule extends PackageModule'),
        );
        expect(module, contains("String get pluginId => 'my_pkg'"));
        expect(module, contains('registerMyPkgPackage(di)'));
        expect(module, contains('package:zuraffa/zuraffa.dart'));
        expect(module, contains('ZuraffaDIContainer'));
        // The module declares the constraint the pubspec pins (FR-015) —
        // the published one, never the dev version const (#1615).
        expect(
          module,
          contains(
            "String get zuraffaSdkConstraint => '$_publishedConstraintStub'",
          ),
        );
      },
    );

    test('U4a: registrar stub exposes the package registration unit', () async {
      await scaffold();

      final registrar = File(
        p.join(
          tempDir.path,
          'my_pkg',
          'lib',
          'src',
          'di',
          'my_pkg_package_registrar.dart',
        ),
      ).readAsStringSync();

      expect(registrar, contains('void registerMyPkgPackage('));
      expect(registrar, contains('ZuraffaDIContainer'));
      expect(registrar, contains('package:zuraffa/zuraffa.dart'));
    });

    test(
      'U4b: barrel exports module + registrar; smoke test imports barrel',
      () async {
        await scaffold();

        final barrel = File(
          p.join(tempDir.path, 'my_pkg', 'lib', 'my_pkg.dart'),
        ).readAsStringSync();
        expect(barrel, contains("src/module/my_pkg_package_module.dart"));
        expect(barrel, contains("src/di/my_pkg_package_registrar.dart"));

        final smoke = File(
          p.join(tempDir.path, 'my_pkg', 'test', 'package_smoke_test.dart'),
        ).readAsStringSync();
        expect(smoke, contains("package:my_pkg/my_pkg.dart"));
        expect(smoke, contains('MyPkgPackageModule'));
      },
    );

    test(
      'FR-014: existing target directory → clear error, nothing touched',
      () async {
        final existing = Directory(p.join(tempDir.path, 'my_pkg'))
          ..createSync();
        File(p.join(existing.path, 'keep.txt')).writeAsStringSync('keep me');

        await expectLater(
          scaffold(),
          throwsA(
            isA<PackageScaffoldException>().having(
              (e) => e.message,
              'message',
              allOf(contains('my_pkg'), contains('exists')),
            ),
          ),
        );

        // Existing content untouched.
        expect(
          File(p.join(existing.path, 'keep.txt')).readAsStringSync(),
          'keep me',
        );
        expect(
          File(p.join(existing.path, 'pubspec.yaml')).existsSync(),
          isFalse,
          reason: 'scaffold must not write into the existing directory',
        );
      },
    );

    test('invalid name → error before any file is written', () async {
      await expectLater(
        PackageScaffold().create(name: 'Bad-Name', outputParent: tempDir.path),
        throwsA(isA<PackageScaffoldException>()),
      );
      expect(Directory(p.join(tempDir.path, 'Bad-Name')).existsSync(), isFalse);
    });
  });

  group('PackageScaffold — hosted zuraffa constraint (issue #1615 parity)', () {
    test(
      'B12a-parity: the hosted lane stamps the published constraint',
      () async {
        await scaffold();

        final pubspec =
            loadYaml(
                  File(
                    p.join(tempDir.path, 'my_pkg', 'pubspec.yaml'),
                  ).readAsStringSync(),
                )
                as YamlMap;
        expect(
          (pubspec['dependencies'] as YamlMap)['zuraffa'],
          _publishedConstraintStub,
          reason:
              'the stamped constraint must be the published one — a dev '
              'checkout const (e.g. ^$version pre-release) cannot resolve',
        );
      },
    );

    test('B12b-parity: a resolver failure warns and falls back', () async {
      final warnings = <String>[];
      await scaffold(
        zuraffaConstraintResolver: () async =>
            throw const SocketException('offline'),
        warningSink: warnings.add,
      );

      final pubspec =
          loadYaml(
                File(
                  p.join(tempDir.path, 'my_pkg', 'pubspec.yaml'),
                ).readAsStringSync(),
              )
              as YamlMap;
      expect((pubspec['dependencies'] as YamlMap)['zuraffa'], '^$version');
      expect(
        warnings.single,
        allOf(
          contains('pub.dev'),
          contains('^$version'),
          contains('--zuraffa-constraint'),
        ),
      );
    });

    test('B12c-parity: an explicit constraint beats the resolver', () async {
      await scaffold(
        zuraffaConstraint: '^7.0.1',
        zuraffaConstraintResolver: () async =>
            throw const SocketException('resolver must not be consulted'),
      );

      final pubspec =
          loadYaml(
                File(
                  p.join(tempDir.path, 'my_pkg', 'pubspec.yaml'),
                ).readAsStringSync(),
              )
              as YamlMap;
      expect((pubspec['dependencies'] as YamlMap)['zuraffa'], '^7.0.1');

      final module = File(
        p.join(
          tempDir.path,
          'my_pkg',
          'lib',
          'src',
          'module',
          'my_pkg_package_module.dart',
        ),
      ).readAsStringSync();
      expect(
        module,
        contains("String get zuraffaSdkConstraint => '^7.0.1'"),
        reason: 'the module must advertise what the pubspec declares',
      );
    });
  });
}
