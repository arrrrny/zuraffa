import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'package:zuraffa/src/core/dependencies/dependency_wirer.dart';
import 'package:zuraffa/src/core/dependencies/pubspec_zuraffa_ensure.dart';
import 'package:zuraffa/src/skew/skew_contract.dart';
import 'package:zuraffa/src/version.dart';

/// Issue #1197 (part of #908 P0): the generator/runtime version-skew
/// contract. The supported core range is the generator's own major.
/// Inside it, every emitted `package:zuraffa/*` import URI must either
/// exist in BOTH ends of the range (oldest tag and newest master) or be
/// registered as a declared floor AND gated at runtime. Across it, a
/// core from another major is refused outright: it has every file but
/// the old API shape, so no surface check could ever see the skew.
void main() {
  final otherMajor = generatorMajor + 1;

  group('the supported range is derived from the generator', () {
    test('the generator major is the major of the running version', () {
      expect(version, startsWith('$generatorMajor.'));
      expect(generatorMajor, greaterThan(0));
    });

    test('the floor is <major>.0.0, never a hand-kept literal', () {
      expect(supportedCoreFloor, '$generatorMajor.0.0');
    });

    test('the consumer constraint is the caret of the floor', () {
      expect(consumerCoreConstraint, '^$generatorMajor.0.0');
    });

    test('every core spec the generator wires declares that constraint', () {
      for (final isFlutter in [true, false]) {
        final specs = DependencyWirer.standardSet(isFlutter: isFlutter);
        final core = specs.firstWhere(
          (s) => s.name == (isFlutter ? 'zuraffa_flutter' : 'zuraffa'),
        );
        expect(
          core.version,
          consumerCoreConstraint,
          reason:
              'a wired range wider than the supported one resolves a '
              'core the generated code cannot compile against',
        );
      }
      expect(PubspecZuraffaEnsure.constraint, consumerCoreConstraint);
    });

    test(
      'the wired zorphy_annotation range is the one this package resolves',
      () {
        final wired = DependencyWirer.standardSet(
          isFlutter: false,
        ).firstWhere((s) => s.name == 'zorphy_annotation').version;
        final own =
            loadYaml(
                  File(
                    path.join(_repoRoot(), 'pubspec.yaml'),
                  ).readAsStringSync(),
                )
                as YamlMap;
        expect(
          wired,
          (own['dependencies'] as YamlMap)['zorphy_annotation'].toString(),
          reason:
              'the generated code is only as new as the annotation '
              'major both sides resolve (dependency_wirer.dart)',
        );
      },
    );
  });

  group('floors registry', () {
    test('every declared floor sits inside the supported range', () {
      for (final floor in coreApiFloors) {
        expect(
          compareVersions(floor.introducedIn, supportedCoreFloor),
          greaterThanOrEqualTo(0),
          reason:
              '${floor.id} predates the floor: dead data. A surface '
              'that ships in every supported core needs no floor.',
        );
        expect(
          InstalledCore(root: _repoRoot()).exposes(floor.uri),
          isTrue,
          reason:
              '${floor.id} (${floor.uri}) does not exist on master — '
              'the generator self-inconsistent',
        );
      }
    });
  });

  group('InstalledCore', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('zfa1197_core_');
      Directory(path.join(temp.path, 'lib')).createSync(recursive: true);
      File(
        path.join(temp.path, 'lib', 'zuraffa.dart'),
      ).writeAsStringSync('export "src/core/result.dart";\n');
      File(
        path.join(temp.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: zuraffa\nversion: $generatorMajor.0.1\n');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('exposes URIs that exist under the core lib/', () {
      final core = InstalledCore(
        root: temp.path,
        version: '$generatorMajor.0.1',
      );
      expect(core.exposes('zuraffa.dart'), isTrue);
      expect(core.exposes('skin.dart'), isFalse);
    });

    test('resolved core surfaces its pubspec version', () {
      // A self-referencing package config: the core dir resolves as its
      // own consumer (the shape a path dependency produces).
      Directory(path.join(temp.path, '.dart_tool')).createSync();
      File(
        path.join(temp.path, '.dart_tool', 'package_config.json'),
      ).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'zuraffa',
              'rootUri': temp.uri.toString(),
              'packageUri': 'lib/',
              'languageVersion': '3.11',
            },
          ],
        }),
      );
      final core = SkewContract.resolveCoreFromRoot(temp.path);
      expect(core, isNotNull);
      expect(core!.version, '$generatorMajor.0.1');
      expect(core.fromPackageConfig, isTrue);
    });
  });

  group('SkewContract.evaluate', () {
    late Directory temp;
    late Directory coreDir;

    /// Rewrites the core's pubspec version: the package config points
    /// here, so the next resolve reads whatever this wrote.
    void setCoreVersion(String v) {
      File(
        path.join(coreDir.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: zuraffa\nversion: $v\n');
    }

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('zfa1197_target_');
      coreDir = await Directory.systemTemp.createTemp('zfa1197_core_');
      Directory(path.join(coreDir.path, 'lib')).createSync(recursive: true);
      File(
        path.join(coreDir.path, 'lib', 'zuraffa.dart'),
      ).writeAsStringSync('export "src/core/result.dart";\n');
      setCoreVersion('$generatorMajor.0.1');
      Directory(path.join(temp.path, '.dart_tool')).createSync(recursive: true);
      File(
        path.join(temp.path, '.dart_tool', 'package_config.json'),
      ).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'zuraffa',
              'rootUri': coreDir.uri.toString(),
              'packageUri': 'lib/',
              'languageVersion': '3.11',
            },
          ],
        }),
      );
    });

    tearDown(() async {
      SkewContract.resetForTest();
      await temp.delete(recursive: true);
      await coreDir.delete(recursive: true);
    });

    test('ok verdict when the resolved core exposes required surfaces', () {
      final verdict = SkewContract.evaluate(
        projectRoot: temp.path,
        requiredUris: ['zuraffa.dart'],
      );
      expect(verdict.ok, isTrue);
      expect(verdict.unsupportedCore, isFalse);
      expect(verdict.missingSurfaces, isEmpty);
      expect(verdict.coreVersion, '$generatorMajor.0.1');
      expect(verdict.generatorVersion, version);
    });

    test(
      'fail verdict naming the missing surface when core lacks the floor',
      () {
        final verdict = SkewContract.evaluate(
          projectRoot: temp.path,
          requiredUris: ['skin.dart'],
        );
        expect(verdict.ok, isFalse);
        expect(verdict.unsupportedCore, isFalse);
        expect(verdict.missingSurfaces, ['skin.dart']);
        expect(verdict.prescription, 'dart pub upgrade zuraffa');
      },
    );

    test('fail-open verdict when no core is resolvable', () {
      final empty = Directory.systemTemp.createTempSync('zfa1197_empty_');
      try {
        final verdict = SkewContract.evaluate(
          projectRoot: empty.path,
          requiredUris: ['skin.dart'],
        );
        expect(verdict.ok, isTrue, reason: 'unresolvable core must fail-open');
        expect(verdict.coreVersion, isNull);
        expect(verdict.unknown, isTrue);
      } finally {
        empty.deleteSync(recursive: true);
      }
    });

    test('requireSurfaces throws VersionSkewException on missing surface', () {
      expect(
        () => SkewContract.requireSurfaces(
          projectRoot: temp.path,
          command: 'zfa skin kit',
          requiredUris: ['skin.dart'],
        ),
        throwsA(
          isA<VersionSkewException>()
              .having((e) => e.verdict.missingSurfaces, 'missing', [
                'skin.dart',
              ])
              .having((e) => e.command, 'command', 'zfa skin kit')
              .having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('version skew'),
                  contains('skin.dart'),
                  contains('dart pub upgrade zuraffa'),
                ),
              ),
        ),
      );
    });

    test('requireSurfaces is a no-op when surfaces exist', () {
      expect(
        () => SkewContract.requireSurfaces(
          projectRoot: temp.path,
          command: 'zfa skin kit',
          requiredUris: ['zuraffa.dart'],
        ),
        returnsNormally,
      );
    });

    test('the exception annotates a gap with its declared floor', () {
      const floor = CoreApiFloor(
        id: 'test-barrel',
        uri: 'test.dart',
        introducedIn: '9.2.0',
        requiredBy: 'zfa test',
      );
      final verdict = SkewContract.evaluate(
        projectRoot: temp.path,
        requiredUris: ['test.dart'],
      );
      final message = VersionSkewException(
        SkewVerdict(
          ok: verdict.ok,
          unknown: verdict.unknown,
          generatorVersion: verdict.generatorVersion,
          coreVersion: verdict.coreVersion,
          coreRoot: verdict.coreRoot,
          missingSurfaces: verdict.missingSurfaces,
          floors: const [floor],
        ),
        'zfa test',
      ).toString();
      expect(message, contains('declared floor: 9.2.0, required by zfa test'));
    });
  });

  group('the major gate', () {
    late Directory temp;
    late Directory coreDir;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('zfa1197_major_');
      coreDir = await Directory.systemTemp.createTemp('zfa1197_major_core_');
      Directory(path.join(coreDir.path, 'lib')).createSync(recursive: true);
      File(
        path.join(coreDir.path, 'lib', 'zuraffa.dart'),
      ).writeAsStringSync('export "src/core/result.dart";\n');
      Directory(path.join(temp.path, '.dart_tool')).createSync(recursive: true);
      File(
        path.join(temp.path, '.dart_tool', 'package_config.json'),
      ).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'zuraffa',
              'rootUri': coreDir.uri.toString(),
              'packageUri': 'lib/',
              'languageVersion': '3.11',
            },
          ],
        }),
      );
    });

    tearDown(() async {
      SkewContract.resetForTest();
      await temp.delete(recursive: true);
      await coreDir.delete(recursive: true);
    });

    void resolveCore(String version) {
      File(
        path.join(coreDir.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: zuraffa\nversion: $version\n');
    }

    test('refuses a core from the previous major', () {
      resolveCore('${generatorMajor - 1}.99.99');
      final verdict = SkewContract.evaluate(
        projectRoot: temp.path,
        requiredUris: const [],
      );
      expect(verdict.ok, isFalse);
      expect(verdict.unsupportedCore, isTrue);
      expect(verdict.missingSurfaces, isEmpty);
      expect(verdict.prescription, contains('pubspec.yaml'));
      expect(
        verdict.prescription,
        contains('zuraffa: $consumerCoreConstraint'),
      );
    });

    test('refuses a core from the next major just the same', () {
      resolveCore('$otherMajor.0.0');
      expect(
        SkewContract.evaluate(
          projectRoot: temp.path,
          requiredUris: const [],
        ).unsupportedCore,
        isTrue,
      );
    });

    test('a cross-major core is refused even when every surface exists', () {
      // The blind spot of a surface-only gate: a previous-major core
      // has skin.dart and simulation.dart, with the old contents.
      resolveCore('${generatorMajor - 1}.99.99');
      File(path.join(coreDir.path, 'lib', 'skin.dart')).writeAsStringSync('');
      final verdict = SkewContract.evaluate(
        projectRoot: temp.path,
        requiredUris: ['skin.dart'],
      );
      expect(verdict.missingSurfaces, isEmpty);
      expect(verdict.ok, isFalse);
    });

    test('requireSupportedCore throws with the re-pin prescription', () {
      resolveCore('${generatorMajor - 1}.99.99');
      expect(
        () => SkewContract.requireSupportedCore(
          projectRoot: temp.path,
          command: 'zfa make Todo',
        ),
        throwsA(
          isA<VersionSkewException>()
              .having(
                (e) => e.verdict.unsupportedCore,
                'unsupportedCore',
                isTrue,
              )
              .having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('zfa make Todo refused'),
                  contains('emits the $generatorMajor.x core API'),
                  contains('v${generatorMajor - 1}.99.99'),
                  contains('zuraffa: $consumerCoreConstraint'),
                ),
              ),
        ),
      );
    });

    test('requireSupportedCore passes inside the supported major', () {
      resolveCore('$generatorMajor.9.9');
      expect(
        () => SkewContract.requireSupportedCore(
          projectRoot: temp.path,
          command: 'zfa make Todo',
        ),
        returnsNormally,
      );
    });

    test('requireSupportedCore fails open when no core resolves', () {
      final empty = Directory.systemTemp.createTempSync('zfa1197_open_');
      try {
        expect(
          () => SkewContract.requireSupportedCore(
            projectRoot: empty.path,
            command: 'zfa make Todo',
          ),
          returnsNormally,
        );
      } finally {
        empty.deleteSync(recursive: true);
      }
    });

    test('the generator checkout is supported whatever its version says', () {
      // fromPackageConfig=false is the generator's own lib/: it IS the
      // generator's API, so a stale pubspec string proves nothing.
      SkewContract.seedForTest(
        InstalledCore(
          root: coreDir.path,
          version: '0.0.0',
          fromPackageConfig: false,
        ),
      );
      expect(
        SkewContract.evaluate(
          projectRoot: temp.path,
          requiredUris: const [],
        ).ok,
        isTrue,
      );
    });

    test('an unreadable core version is unknown, not refused', () {
      SkewContract.seedForTest(
        InstalledCore(root: coreDir.path, version: 'not-a-version'),
      );
      expect(
        SkewContract.evaluate(
          projectRoot: temp.path,
          requiredUris: const [],
        ).ok,
        isTrue,
      );
      SkewContract.seedForTest(InstalledCore(root: coreDir.path));
      expect(
        SkewContract.evaluate(
          projectRoot: temp.path,
          requiredUris: const [],
        ).ok,
        isTrue,
      );
    });
  });

  group('version comparison', () {
    test('orders semver-ish versions', () {
      expect(compareVersions('6.0.1', '6.0.0'), greaterThan(0));
      expect(compareVersions('6.0.0', '6.0.1'), lessThan(0));
      expect(compareVersions('6.1.0', '6.1.0'), 0);
      expect(compareVersions('6.10.0', '6.9.0'), greaterThan(0));
      expect(compareVersions('7.0.0', '6.9.9'), greaterThan(0));
      expect(
        compareVersions('6.1.0', 'unknown'),
        0,
        reason: 'unparseable versions compare equal (advisory only)',
      );
    });

    test('a pre-release compares by its release core', () {
      expect(compareVersions('8.0.0-dev.1', '8.0.0'), 0);
      expect(compareVersions('8.0.0-dev.1', '7.99.99'), greaterThan(0));
    });
  });
}

String _repoRoot() {
  var dir = Directory.current.path;
  while (true) {
    final pubspec = File(path.join(dir, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().startsWith('name: zuraffa')) {
      return dir;
    }
    final parent = path.dirname(dir);
    if (parent == dir) {
      throw StateError(
        'zuraffa repo root not found from ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}
