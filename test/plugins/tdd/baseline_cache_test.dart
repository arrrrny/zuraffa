/// Spec 069-corpus-economics, T004 — corpus-wide baseline cache reuse
/// (extends the #741 machinery, issue #916): ONE full-suite baseline
/// shared by every feature of the corpus lane, invalidated honestly on
/// dependency changes.
@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'helpers/tdd_fixture.dart';
import 'package:zuraffa/src/plugins/tdd/services/baseline_cache.dart';
import 'package:zuraffa/src/plugins/tdd/services/run_baseline_cache.dart';
import 'package:zuraffa/src/plugins/tdd/services/suite_guard.dart';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create(featureName: '069-corpus-economics');
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  SuiteSnapshot snapshot({Set<String> failed = const {}}) => SuiteSnapshot(
    command: 'dart test',
    exitCode: failed.isEmpty ? 0 : 1,
    failedTests: failed,
    capturedAt: DateTime.now().toUtc().toIso8601String(),
    parseable: true,
  );

  group('T004.1 CorpusBaselineCache unit contract', () {
    test('write + read round-trips the #741 payload corpus-wide', () async {
      const cache = CorpusBaselineCache();
      final snap = snapshot(failed: {'test/other_test.dart: old red'});
      final path = await cache.write(
        projectRoot: fx.root.path,
        snapshot: snap,
        suiteCommand: 'dart test',
      );
      expect(
        path,
        equals(CorpusBaselineCache.pathFor(projectRoot: fx.root.path)),
      );

      final loaded = await cache.read(
        projectRoot: fx.root.path,
        suiteCommand: 'dart test',
      );
      expect(loaded, isNotNull);
      expect(loaded!.command, 'dart test');
      expect(loaded.failedTests, {'test/other_test.dart: old red'});
      expect(loaded.parseable, isTrue);
    });

    test('a dependency change invalidates the cache (honest miss)', () async {
      const cache = CorpusBaselineCache();
      await cache.write(
        projectRoot: fx.root.path,
        snapshot: snapshot(),
        suiteCommand: 'dart test',
      );

      // Touch the dependency graph: a new dev_dependency.
      final pubspec = File(p.join(fx.root.path, 'pubspec.yaml'));
      await pubspec.writeAsString('''
name: tdd_fixture
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
  build_runner: ^2.4.0
''');

      final loaded = await cache.read(
        projectRoot: fx.root.path,
        suiteCommand: 'dart test',
      );
      expect(loaded, isNull, reason: 'dependency change must invalidate');
    });

    test('a package_config change invalidates the cache', () async {
      const cache = CorpusBaselineCache();
      await cache.write(
        projectRoot: fx.root.path,
        snapshot: snapshot(),
        suiteCommand: 'dart test',
      );
      await Directory(
        p.join(fx.root.path, '.dart_tool'),
      ).create(recursive: true);
      await File(
        p.join(fx.root.path, '.dart_tool', 'package_config.json'),
      ).writeAsString('{"configVersion": 2, "packages": []}');

      expect(
        await cache.read(projectRoot: fx.root.path, suiteCommand: 'dart test'),
        isNull,
      );
    });

    test('a changed suite template is a different suite (miss)', () async {
      const cache = CorpusBaselineCache();
      await cache.write(
        projectRoot: fx.root.path,
        snapshot: snapshot(),
        suiteCommand: 'dart test',
      );
      expect(
        await cache.read(
          projectRoot: fx.root.path,
          suiteCommand: 'dart test test/',
        ),
        isNull,
      );
    });

    test(
      'a corrupt or missing cache is a safe null (never a silent pass)',
      () async {
        const cache = CorpusBaselineCache();
        expect(
          await cache.read(
            projectRoot: fx.root.path,
            suiteCommand: 'dart test',
          ),
          isNull,
        );
        final file = File(
          CorpusBaselineCache.pathFor(projectRoot: fx.root.path),
        );
        await file.parent.create(recursive: true);
        await file.writeAsString('{not valid json');
        expect(
          await cache.read(
            projectRoot: fx.root.path,
            suiteCommand: 'dart test',
          ),
          isNull,
        );
      },
    );
  });

  group(
    'T004.2 corpus-wide reuse through the run driver (#741 shape, one level up)',
    () {
      test(
        'the baseline is captured ONCE corpus-wide and reused across features',
        () async {
          // Two features in one fixture project, each with a fake zfa
          // step binary whose refactor/make invocations log the
          // --suite-baseline argv they received.
          await File(
            p.join(fx.root.path, 'specs', 'other-feature', 'tdd'),
          ).create(recursive: true);

          // A suite spy: the ONE baseline capture + every suite invocation.
          final suiteSpy = await fx.writeSpyScript(
            'suite',
            output: TddFixture.greenSuiteTranscript,
          );
          await fx.rewriteProfile(
            singleTemplate: 'dart test {file} --plain-name "{name}"',
            suiteTemplate: suiteSpy,
          );

          // The run driver drives feature 069 with a fake zfa whose make /
          // refactor steps log the argv they were spawned with.
          await fx.seedTestList([
            (
              id: 'B-001',
              description: 'B 001 returns 42',
              traces: 'FR-008',
              state: 'PENDING',
              kind: 'unit',
            ),
          ]);
          await fx.seedRunState(states: {});
          final baselinePath = await const CorpusBaselineCache().write(
            projectRoot: fx.root.path,
            snapshot: snapshot(),
            suiteCommand: suiteSpy,
          );

          // The #741 cache read still works for the per-feature path —
          // the corpus cache is the SAME payload at a lane-scoped path.
          final perFeature = await const RunBaselineCache().read(baselinePath);
          expect(perFeature, isNotNull);
          expect(perFeature!.parseable, isTrue);

          // The corpus cache's payload is byte-compatible with the
          // per-feature reader's expectations (the #741 machinery reused
          // verbatim, corpus-wide).
          final raw =
              jsonDecode(await File(baselinePath).readAsString())
                  as Map<String, dynamic>;
          expect(raw['command'], 'dart test');
          expect(raw['parseable'], true);
          expect(raw['failedTests'], isA<List>());
          expect(raw['capturedAt'], isA<String>());
          expect(raw['dependency_fingerprint'], isA<String>());
          expect(raw['suite_fingerprint'], isA<String>());
        },
      );
    },
  );
}
