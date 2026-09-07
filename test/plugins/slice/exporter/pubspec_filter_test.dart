@Tags(['flutter'])
/// Tests for PubspecFilter (U54, U55, U56; issue #1304 adds U1304a/U1304b).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U54: The filtered pubspec keeps only dependencies actually imported by
///        the sliced files
///   U55: `flutter` and `flutter_test` SDK entries are always kept
///   U56: Git, path, and hosted sources of kept dependencies are preserved
///   U1304a: A package imported by the copied closure but only TRANSITIVE in
///           the host (declared via another package, e.g. `zuraffa` via
///           `zuraffa_flutter`) is declared in the sandbox pubspec, pinned
///           to the version resolved in the host's pubspec.lock — the cut
///           must not emit a sandbox that fails self-containment by
///           construction.
///   U1304b: When the host lock has no entry for such a package, it is
///           declared as `any` with an inline warning instead of being
///           silently dropped.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:zuraffa/src/plugins/slice/exporter/pubspec_filter.dart';

void main() {
  late Directory tmpDir;
  late PubspecFilter filter;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('slice_pubspec_filter_');
    filter = PubspecFilter();
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Future<String> writeProjectPubspec() async {
    final pubspec = File('${tmpDir.path}/pubspec.yaml');
    await pubspec.writeAsString('''
name: zik_zak
description: A fixture app.
publish_to: 'none'
version: 1.2.0

environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
  get_it: ^8.0.3
  equatable: ^2.0.7
  unused_package: ^1.0.0
  git_dep:
    git:
      url: https://github.com/example/git_dep.git
  path_dep:
    path: ../path_dep

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0

flutter:
  uses-material-design: true
''');
    return tmpDir.path;
  }

  Future<void> writeSliceFile(String rel, String content) async {
    final file = File('${tmpDir.path}/$rel');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  group('PubspecFilter (FR-017)', () {
    test('U54: keeps only dependencies the sliced files import', () async {
      final projectRoot = await writeProjectPubspec();
      await writeSliceFile('lib/a.dart', '''
import 'package:get_it/get_it.dart';
import 'package:flutter/material.dart';
class A {}
''');
      await writeSliceFile('lib/b.dart', '''
import 'package:equatable/equatable.dart';
class B {}
''');

      final filtered = await filter.filter(
        projectRoot: projectRoot,
        sandboxDir: tmpDir.path,
        sliceDartFiles: const ['lib/a.dart', 'lib/b.dart'],
      );

      final doc = loadYaml(filtered) as Map;
      final deps = doc['dependencies'] as Map;
      expect(deps.keys, containsAll(['flutter', 'get_it', 'equatable']));
      expect(deps.keys, isNot(contains('unused_package')));
      expect(deps.keys, isNot(contains('git_dep')));
      expect(deps.keys, isNot(contains('path_dep')));
    });

    test('U55: flutter and flutter_test are always kept', () async {
      final projectRoot = await writeProjectPubspec();
      await writeSliceFile('lib/a.dart', '''
import 'package:get_it/get_it.dart';
class A {}
''');
      // NOTE: no flutter import anywhere in the slice files.

      final filtered = await filter.filter(
        projectRoot: projectRoot,
        sandboxDir: tmpDir.path,
        sliceDartFiles: const ['lib/a.dart'],
      );

      final doc = loadYaml(filtered) as Map;
      expect((doc['dependencies'] as Map).keys, contains('flutter'));
      expect((doc['dev_dependencies'] as Map).keys, contains('flutter_test'));
    });

    test('U56: git, path, and hosted sources are preserved verbatim', () async {
      final projectRoot = await writeProjectPubspec();
      await writeSliceFile('lib/a.dart', '''
import 'package:git_dep/git_dep.dart';
import 'package:path_dep/path_dep.dart';
import 'package:equatable/equatable.dart';
class A {}
''');

      final filtered = await filter.filter(
        projectRoot: projectRoot,
        sandboxDir: tmpDir.path,
        sliceDartFiles: const ['lib/a.dart'],
      );

      final doc = loadYaml(filtered) as Map;
      final deps = doc['dependencies'] as Map;
      expect(
        (deps['git_dep'] as Map)['git'],
        isA<Map>().having((g) => g['url'], 'url', contains('git_dep.git')),
      );
      expect((deps['path_dep'] as Map)['path'], equals('../path_dep'));
      expect(deps['equatable'], equals('^2.0.7'));
    });

    test(
      'the filtered pubspec keeps name, environment, and flutter section',
      () async {
        final projectRoot = await writeProjectPubspec();
        await writeSliceFile('lib/a.dart', 'class A {}\n');

        final filtered = await filter.filter(
          projectRoot: projectRoot,
          sandboxDir: tmpDir.path,
          sliceDartFiles: const ['lib/a.dart'],
        );

        final doc = loadYaml(filtered) as Map;
        expect(doc['name'], equals('zik_zak'));
        expect(doc['description'], equals('A fixture app.'));
        expect((doc['environment'] as Map)['sdk'], equals('^3.11.0'));
        expect((doc['flutter'] as Map)['uses-material-design'], isTrue);
      },
    );
  });

  group('PubspecFilter transitive closure (issue #1304)', () {
    /// A zuraffa_flutter-shaped host: declares `zuraffa_flutter` (which
    /// resolves `zuraffa` transitively) but NOT `zuraffa` itself — exactly
    /// the shape from issue #1304's repro (`apps/login_demo`).
    Future<String> writeHostPubspec({bool withLock = true}) async {
      final pubspec = File('${tmpDir.path}/pubspec.yaml');
      await pubspec.writeAsString('''
name: login_demo
description: Host app that uses zuraffa via zuraffa_flutter.
publish_to: 'none'
version: 1.0.0

environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
  get_it: ^8.0.3
  zuraffa_flutter: ^3.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
''');
      if (withLock) {
        final lock = File('${tmpDir.path}/pubspec.lock');
        await lock.writeAsString('''
# Generated by pub. See https://pub.dev/packages/pub's pubspec.lock.
packages:
  get_it:
    dependency: "direct main"
    description:
      name: get_it
      sha256: "8f9ee8b4d8f9a9a2c0af00a5b9c9d9e3c6b3d2f1a0e9d8c7b6a5f4e3d2c1b0a9"
      url: "https://pub.dev"
    source: hosted
    version: "8.0.3"
  zuraffa:
    dependency: transitive
    description:
      name: zuraffa
      sha256: "0a9b8c7d6e5f4e3d2c1b0a99887766554433221100ffeeddccbbaa9988776655"
      url: "https://pub.dev"
    source: hosted
    version: "6.2.0"
  zuraffa_flutter:
    dependency: "direct main"
    description:
      name: zuraffa_flutter
      sha256: "1b0a9b8c7d6e5f4e3d2c1b0a99887766554433221100ffeeddccbbaa99887766"
      url: "https://pub.dev"
    source: hosted
    version: "3.0.1"
sdks:
  dart: ">=3.11.0 <4.0.0"
''');
      }
      return tmpDir.path;
    }

    test('U1304a: a package imported by the closure but only transitive in the '
        'host is declared with the host lock version', () async {
      final projectRoot = await writeHostPubspec();
      // The copied closure imports package:zuraffa directly (like the
      // host app's own lib files do), but the host pubspec never declares
      // `zuraffa` — only `zuraffa_flutter`.
      await writeSliceFile('lib/a.dart', '''
import 'package:get_it/get_it.dart';
import 'package:zuraffa/zuraffa.dart';
class A {}
''');

      final filtered = await filter.filter(
        projectRoot: projectRoot,
        sandboxDir: tmpDir.path,
        sliceDartFiles: const ['lib/a.dart'],
      );

      final doc = loadYaml(filtered) as Map;
      final deps = doc['dependencies'] as Map;
      // Host-declared packages keep their host constraints verbatim.
      expect(deps['get_it'], equals('^8.0.3'));
      // `zuraffa_flutter` is declared by the host but NOT imported by the
      // closure — U54 filtering still drops it (only imports are kept).
      expect(deps.keys, isNot(contains('zuraffa_flutter')));
      // The transitive-only import is declared, pinned to the version the
      // host lock resolved — the sandbox is self-contained by construction.
      expect(deps.keys, contains('zuraffa'));
      expect(deps['zuraffa'], equals('^6.2.0'));
    });

    test('U1304b: falls back to any with a warning comment when the host lock '
        'has no entry for the imported package', () async {
      final projectRoot = await writeHostPubspec(withLock: false);
      await writeSliceFile('lib/a.dart', '''
import 'package:zuraffa/zuraffa.dart';
class A {}
''');

      final filtered = await filter.filter(
        projectRoot: projectRoot,
        sandboxDir: tmpDir.path,
        sliceDartFiles: const ['lib/a.dart'],
      );

      final doc = loadYaml(filtered) as Map;
      final deps = doc['dependencies'] as Map;
      expect(deps.keys, contains('zuraffa'));
      expect(deps['zuraffa'], equals('any'));
      expect(filtered, contains('#1304'));
      expect(filtered.toUpperCase(), contains('WARNING'));
    });

    test('U1304a: sandbox pubspec stays loadable with the derived entries and '
        'the emission is deterministic across runs', () async {
      final projectRoot = await writeHostPubspec();
      await writeSliceFile('lib/a.dart', '''
import 'package:zuraffa/zuraffa.dart';
import 'package:meta/meta.dart';
class A {}
''');
      final lock = File('${tmpDir.path}/pubspec.lock');
      await lock.writeAsString('''
packages:
  meta:
    dependency: transitive
    description:
      name: meta
      url: "https://pub.dev"
    source: hosted
    version: "1.17.0"
  zuraffa:
    dependency: transitive
    description:
      name: zuraffa
      url: "https://pub.dev"
    source: hosted
    version: "6.2.0"
''');

      final first = await filter.filter(
        projectRoot: projectRoot,
        sandboxDir: tmpDir.path,
        sliceDartFiles: const ['lib/a.dart'],
      );
      final second = await filter.filter(
        projectRoot: projectRoot,
        sandboxDir: tmpDir.path,
        sliceDartFiles: const ['lib/a.dart'],
      );

      expect(second, equals(first), reason: 'emission must be deterministic');
      final doc = loadYaml(first) as Map;
      final deps = doc['dependencies'] as Map;
      expect(deps['zuraffa'], equals('^6.2.0'));
      expect(deps['meta'], equals('^1.17.0'));
      // Derived entries are sorted for byte-identical output.
      expect(
        first.indexOf('meta: ^1.17.0') < first.indexOf('zuraffa: ^6.2.0'),
        isTrue,
      );
    });
  });
}
