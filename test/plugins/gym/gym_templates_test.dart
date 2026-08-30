import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../helpers/project_root.dart';

void main() async {
  final repoRoot = await findProjectRoot();
  final zuraffaGym = File(p.join(repoRoot, '.gym', 'gym.yaml'));
  final templatesRoot = Directory(
    p.join(repoRoot, 'examples', 'gym-templates'),
  );

  group('zuraffa .gym/gym.yaml (B04, B05, B07, B12, B13)', () {
    late YamlMap doc;
    setUp(() {
      expect(zuraffaGym.existsSync(), isTrue);
      doc = loadYaml(zuraffaGym.readAsStringSync()) as YamlMap;
    });

    test('has canonical top-level keys (B12)', () {
      expect(doc['name'], equals('zuraffa'));
      expect(doc['version'], equals('1.0.0'));
      expect(doc['warmup'], isNotNull);
      expect(doc['exercises'], isNotNull);
    });

    test('existing warmup reps are unchanged (B04, no regression)', () {
      final warmup = doc['warmup'] as YamlList;
      final ids = warmup.map((w) => (w as YamlMap)['id'].toString()).toList();
      expect(ids, containsAll(['01-deps', '02-build', '03-smoke']));
    });

    test('existing graded exercises are unchanged (B05, no regression)', () {
      final exercises = doc['exercises'] as YamlList;
      final ids = exercises
          .map((e) => (e as YamlMap)['id'].toString())
          .toList();
      expect(ids, containsAll(['generate-feature', 'agent-rewrite-zfa-only']));
    });

    test('new extend-zfa-cli exercise is registered (B07)', () {
      final exercises = doc['exercises'] as YamlList;
      final ids = exercises
          .map((e) => (e as YamlMap)['id'].toString())
          .toList();
      expect(ids, contains('extend-zfa-cli'));
    });

    test('every exercise has canonical keys (B12)', () {
      final exercises = doc['exercises'] as YamlList;
      for (final e in exercises) {
        final m = e as YamlMap;
        expect(m['id'], isNotNull);
        expect(m['brief'], isNotNull);
        expect(m['setup'], isNotNull);
        expect(m['verifyCommand'], isNotNull);
        expect(m['evaluate'], isNotNull);
      }
    });
  });

  group('examples/gym-templates/ (B09, B10, B11, B16)', () {
    test('templates root exists', () {
      expect(templatesRoot.existsSync(), isTrue);
    });

    test('README.md exists and documents consumption (B16)', () {
      final readme = File(p.join(templatesRoot.path, 'README.md'));
      expect(readme.existsSync(), isTrue);
      final content = readme.readAsStringSync();
      expect(content, contains('copy-paste-ready'));
      expect(content, contains('zorphy'));
      expect(content, contains('zikzak_inappwebview'));
      expect(content, contains('vendure-flutter-sdk'));
    });

    for (final pkg in const [
      'zorphy',
      'zikzak_inappwebview',
      'vendure-flutter-sdk',
    ]) {
      group('$pkg template', () {
        final pkgRoot = Directory(p.join(templatesRoot.path, pkg));
        final gym = File(p.join(pkgRoot.path, '.gym', 'gym.yaml'));

        test('template directory exists (B09/B10/B11)', () {
          expect(
            pkgRoot.existsSync(),
            isTrue,
            reason: 'examples/gym-templates/$pkg/ must exist',
          );
          expect(
            gym.existsSync(),
            isTrue,
            reason: 'examples/gym-templates/$pkg/.gym/gym.yaml must exist',
          );
        });

        test('gym.yaml has canonical top-level keys (B12)', () {
          final doc = loadYaml(gym.readAsStringSync()) as YamlMap;
          expect(doc['name'], equals(pkg));
          expect(doc['version'], equals('1.0.0'));
          expect(doc['warmup'], isNotNull);
          expect(doc['exercises'], isNotNull);
        });

        test(
          'has 3 warmup reps (01-deps, 02-build, 03-smoke) (B09/B10/B11)',
          () {
            final doc = loadYaml(gym.readAsStringSync()) as YamlMap;
            final warmup = doc['warmup'] as YamlList;
            final ids = warmup
                .map((w) => (w as YamlMap)['id'].toString())
                .toList();
            expect(ids, containsAll(['01-deps', '02-build', '03-smoke']));
            expect(warmup.length, equals(3));
          },
        );

        test('has at least one graded exercise with canonical keys (B12)', () {
          final doc = loadYaml(gym.readAsStringSync()) as YamlMap;
          final exercises = doc['exercises'] as YamlList;
          expect(exercises, isNotEmpty);
          for (final e in exercises) {
            final m = e as YamlMap;
            expect(m['id'], isNotNull);
            expect(m['brief'], isNotNull);
            expect(m['setup'], isNotNull);
            expect(m['verifyCommand'], isNotNull);
            expect(m['evaluate'], isNotNull);
          }
        });

        test('warmup .dart files exist', () {
          for (final id in const ['01-deps', '02-build', '03-smoke']) {
            final f = File(p.join(pkgRoot.path, '.gym', 'warmup', '$id.dart'));
            expect(f.existsSync(), isTrue, reason: 'missing warmup/$id.dart');
          }
        });

        test('exercise .dart file(s) exist', () {
          final exerciseDir = Directory(p.join(pkgRoot.path, '.gym'));
          final exercises = exerciseDir
              .listSync()
              .whereType<File>()
              .where((f) => p.basename(f.path).startsWith('exercise-'))
              .toList();
          expect(
            exercises,
            isNotEmpty,
            reason: 'at least one exercise-*.dart file must exist',
          );
        });
      });
    }
  });
}
