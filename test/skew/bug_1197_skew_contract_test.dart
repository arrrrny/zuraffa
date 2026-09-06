import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'package:zuraffa/src/skew/skew_contract.dart';
import 'package:zuraffa/src/version.dart';

/// Issue #1197 (part of #908 P0): the generator/runtime version-skew
/// contract. Every emitted `package:zuraffa/*` import URI must either
/// exist in BOTH ends of the supported core range (oldest tag and
/// newest master) or be registered as a declared floor AND gated at
/// runtime. Without this contract a master generator happily emits
/// imports the published core does not provide (the `skin.dart`
/// barrel shipped on master after the v6.1.0 tag).
void main() {
  group('floors registry', () {
    test('exposes the supported core floor of the two-end matrix', () {
      expect(supportedCoreFloor, '6.0.0');
    });

    test('registers the skin barrel as a declared floor', () {
      final skin = coreApiFloors
          .where((f) => f.uri == 'skin.dart')
          .toList(growable: false);
      expect(skin, hasLength(1), reason: 'skin.dart must be floor-registered');
      expect(skin.single.requiredBy, contains('view --skin'));
      expect(skin.single.requiredBy, contains('--skin-audit'));
      expect(skin.single.requiredBy, contains('zfa skin kit'));
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
      ).writeAsStringSync('name: zuraffa\nversion: 6.0.1\n');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('exposes URIs that exist under the core lib/', () {
      final core = InstalledCore(root: temp.path, version: '6.0.1');
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
      expect(core!.version, '6.0.1');
      expect(core.fromPackageConfig, isTrue);
    });
  });

  group('SkewContract.evaluate', () {
    late Directory temp;
    late Directory coreOld;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('zfa1197_target_');
      coreOld = await Directory.systemTemp.createTemp('zfa1197_old_');
      Directory(path.join(coreOld.path, 'lib')).createSync(recursive: true);
      File(
        path.join(coreOld.path, 'lib', 'zuraffa.dart'),
      ).writeAsStringSync('export "src/core/result.dart";\n');
      File(
        path.join(coreOld.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: zuraffa\nversion: 6.0.1\n');
      Directory(path.join(temp.path, '.dart_tool')).createSync(recursive: true);
      File(
        path.join(temp.path, '.dart_tool', 'package_config.json'),
      ).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'zuraffa',
              'rootUri': coreOld.uri.toString(),
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
      await coreOld.delete(recursive: true);
    });

    test('ok verdict when the resolved core exposes required surfaces', () {
      final verdict = SkewContract.evaluate(
        projectRoot: temp.path,
        requiredUris: ['zuraffa.dart'],
      );
      expect(verdict.ok, isTrue);
      expect(verdict.missingSurfaces, isEmpty);
      expect(verdict.coreVersion, '6.0.1');
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
        expect(verdict.missingSurfaces, ['skin.dart']);
        expect(verdict.prescription, contains('dart pub upgrade zuraffa'));
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
  });
}
