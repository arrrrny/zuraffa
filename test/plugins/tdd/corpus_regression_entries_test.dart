// Bug #805 — generator differential testing (vision slice v0).
//
// Content pins for the SHIPPED regression corpus and the CI gate: one
// corpus entry per past behavioral incident (#744 gen hang, #751
// --suite-baseline flag mismatch, #752 cached-baseline make break) and
// a GitHub Actions workflow that runs the differential against the PR
// base on every generator-touching PR, inside the 20-minute budget.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/differential_corpus.dart';

/// Walks up from the CWD to the package root (dart test runs from the
/// package root, but the pin must not silently pass from elsewhere).
Directory packageRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      final text = File(p.join(dir.path, 'pubspec.yaml')).readAsStringSync();
      if (text.contains(RegExp(r'^name:\s*zuraffa\s*$', multiLine: true))) {
        return dir;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('zuraffa package root not found from CWD');
    }
    dir = parent;
  }
}

void main() {
  late Directory root;

  setUp(() => root = packageRoot());

  group('shipped regression corpus', () {
    test('exposes the three incident entries and nothing else', () async {
      final entries = await DifferentialCorpus.load(
        p.join(root.path, 'corpus'),
      );
      expect(entries.map((e) => e.name).toSet(), {
        'u2-flow',
        'make-suite-baseline-flag',
        'make-baseline-cache',
      });
    });

    test('each incident is named by its entry (744, 751, 752)', () async {
      final entries = await DifferentialCorpus.load(
        p.join(root.path, 'corpus'),
      );
      expect(
        {for (final e in entries) e.name: e.incident},
        {
          'u2-flow': 744,
          'make-suite-baseline-flag': 751,
          'make-baseline-cache': 752,
        },
      );
    });

    test(
      'u2-flow reproduces the #744 shape: two gen steps + a test step',
      () async {
        final entries = await DifferentialCorpus.load(
          p.join(root.path, 'corpus'),
        );
        final u2 = entries.firstWhere((e) => e.name == 'u2-flow');
        final labels = u2.steps.map((s) => s.label).toList();
        expect(labels, contains('gen U1'));
        expect(labels, contains('gen U2'));
        expect(
          labels.any((l) => l.startsWith('test')),
          isTrue,
          reason:
              'the pass/fail-count dimension of the vector needs a '
              'test step',
        );
      },
    );

    test(
      'the make entries drive the --suite-baseline call (#751/#752)',
      () async {
        final entries = await DifferentialCorpus.load(
          p.join(root.path, 'corpus'),
        );
        for (final name in [
          'make-suite-baseline-flag',
          'make-baseline-cache',
        ]) {
          final e = entries.firstWhere((x) => x.name == name);
          expect(
            e.steps.any((s) => s.argv.contains('--suite-baseline')),
            isTrue,
            reason: '$name must exercise the exact contract #751/#752 broke',
          );
        }
      },
    );

    test(
      'every entry ships a driven-project scaffold gen/make can run',
      () async {
        final entries = await DifferentialCorpus.load(
          p.join(root.path, 'corpus'),
        );
        for (final e in entries) {
          expect(
            File(p.join(e.projectDir, 'pubspec.yaml')).existsSync(),
            isTrue,
            reason: '${e.name}: project/pubspec.yaml missing',
          );
          expect(
            Directory(
              p.join(e.projectDir, 'specs', 'u2-flow', 'tdd'),
            ).existsSync(),
            isTrue,
            reason: '${e.name}: the feature tdd dir is missing',
          );
        }
      },
    );
  });

  group('generator differential CI gate', () {
    late File workflow;

    setUp(() {
      workflow = File(
        p.join(root.path, '.github', 'workflows', 'generator-differential.yml'),
      );
    });

    test('exists as a workflow file', () {
      expect(workflow.existsSync(), isTrue);
    });

    test('runs the corpus differential against the PR base', () {
      final text = workflow.readAsStringSync();
      expect(text, contains('corpus differential'));
      expect(text, contains('--from'));
      expect(text, contains('pull_request'));
    });

    test('stays inside the 20-minute gate budget', () {
      final text = workflow.readAsStringSync();
      expect(text, contains('timeout-minutes: 20'));
    });

    test('has full history so the base ref resolves', () {
      final text = workflow.readAsStringSync();
      expect(text, contains('fetch-depth: 0'));
    });
  });
}
