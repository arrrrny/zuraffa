@Tags(['flutter'])
/// Tests for PubspecFilter (U54, U55, U56).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U54: The filtered pubspec keeps only dependencies actually imported by
///        the sliced files
///   U55: `flutter` and `flutter_test` SDK entries are always kept
///   U56: Git, path, and hosted sources of kept dependencies are preserved
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
}
