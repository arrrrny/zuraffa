// Command-level tests for `zfa corpus run` (the corpus WALK with a
// configurable failure budget) — epic #1017 CORPUS-WALK, child issue
// "#1016 zfa corpus run --target=zik_zak with configurable failure
// budget".
//
// The walk drives every cataloged feature through the loop runtime's
// per-feature steps (`zfa tdd run` + `zfa tdd verify`, spawned through
// the same machine contract `zfa tdd corpus run` uses), classifying each
// feature green / partial / blocked — and unlike STOP-ON-ROADBLOCK it
// keeps walking, because the budget (partial + blocked <= budget) is the
// gate, not the first failure.
//
// Fast tier: the CLI runs in-process through CliRunner.runCapturing; the
// per-feature steps are the fixture's scripted fake zfa binary spawned as
// lightweight real sub-processes (the repo's canonical fake-zfa pattern).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/corpus_walk_fixture.dart';

void main() {
  late CorpusWalkFixture fx;

  /// Writes the manifest, specs, and catalog for [features], driving the
  /// REAL catalog command (the walk's input contract is the catalog the
  /// maintainer commits).
  Future<void> setupCatalog(List<String> names) async {
    await fx.writeManifest([
      for (final n in names) (name: n, ready: true, reason: ''),
    ]);
    for (final n in names) {
      await fx.writeSpec(n, CorpusWalkFixture.coreSpec(n));
    }
    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing([
      'corpus',
      'catalog',
      '--target',
      CorpusWalkFixture.target,
      '--project',
      fx.root.path,
    ]);
  }

  Future<String> walk({
    String? budget,
    Map<String, WalkOutcome> outcomes = const {},
  }) async {
    await fx.writeFakeZfa(outcomes: outcomes);
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'corpus',
      'run',
      '--target',
      CorpusWalkFixture.target,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeBin,
      if (budget != null) ...['--budget', budget],
    ]);
  }

  setUp(() async {
    fx = await CorpusWalkFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('A1 — registration and arg surface', () {
    test('the corpus family lists run', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['corpus']);
      expect(out, contains('run'));
    });

    test('run exposes --target, --budget, --project, --zfa-bin', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['corpus', 'run', '--help']);
      expect(out, contains('--target'));
      expect(out, contains('--budget'));
      expect(out, contains('--project'));
      expect(out, contains('--zfa-bin'));
    });

    test('run without --target is a usage error (exit 2)', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'corpus',
        'run',
        '--project',
        fx.root.path,
      ]);
      expect(out, contains('target'));
      expect(exitCode, 2);
    });

    test(
      'run without a catalog stops with catalog guidance (exit 2)',
      () async {
        await fx.writeFakeZfa();
        final out = await walk();
        expect(out, contains('catalog'));
        expect(out, contains('--> fix'));
        expect(exitCode, 2);
      },
    );

    test(
      'an invalid --budget value stops with a parse error (exit 2)',
      () async {
        await setupCatalog(['f1-good']);
        final out = await walk(budget: 'lots');
        expect(out, contains('budget'));
        expect(exitCode, 2);
      },
    );
  });

  group('A2 — the walk drives every feature', () {
    test('every feature gets run-then-verify, in catalog order', () async {
      await setupCatalog(['f1-good', 'f2-good']);
      final out = await walk();
      expect(await fx.readCalls(), [
        'tdd run f1-good --project ${fx.root.path}',
        'tdd verify --feature f1-good --project ${fx.root.path}',
        'tdd run f2-good --project ${fx.root.path}',
        'tdd verify --feature f2-good --project ${fx.root.path}',
      ], reason: out);
    });

    test(
      'the walk continues past a failing feature (no stop-on-roadblock)',
      () async {
        await setupCatalog(['f1-bad', 'f2-good']);
        final out = await walk(
          outcomes: {
            'run:f1-bad': (
              exit: 1,
              stdout: ['run: feature=f1-bad result=stopped stopped_at=b1:gen'],
            ),
          },
        );
        // f2 is STILL driven after f1's failure — the budget is the gate.
        expect(
          await fx.readCalls(),
          contains('tdd run f2-good --project ${fx.root.path}'),
          reason: out,
        );
      },
    );
  });

  group('A3 — verdict mapping', () {
    test('a completing run + passing gate is green', () async {
      await setupCatalog(['f1-good']);
      final out = await walk();
      expect(out, contains('[corpus-walk] f1-good -> green (gate=pass)'));
    });

    test('a completing run + failing gate is partial (gate named)', () async {
      await setupCatalog(['f1-gap']);
      final out = await walk(
        outcomes: {
          'verify:f1-gap': (
            exit: 1,
            stdout: [
              'mutation: gate=fail_survived killed=0 survived=1 '
                  'timed_out=0 mutation_was_run=true',
            ],
          ),
        },
      );
      expect(
        out,
        contains('[corpus-walk] f1-gap -> partial (gate=fail_survived)'),
      );
    });

    test('a failed run is blocked (outcome named)', () async {
      await setupCatalog(['f1-bad']);
      final out = await walk(
        outcomes: {
          'run:f1-bad': (
            exit: 1,
            stdout: ['run: feature=f1-bad result=stopped stopped_at=b1:gen'],
          ),
        },
      );
      expect(
        out,
        contains('[corpus-walk] f1-bad -> blocked (stopped'),
        reason: out,
      );
    });

    test('a not-ready feature is blocked without being spawned', () async {
      await fx.writeManifest([
        (name: 'f1-ready', ready: true, reason: ''),
        (name: 'f0-notready', ready: false, reason: 'no acceptance scenarios'),
      ]);
      await fx.writeSpec('f1-ready', CorpusWalkFixture.coreSpec('f1'));
      await fx.writeSpec('f0-notready', '# f0\nprose only, no scenarios');
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'corpus',
        'catalog',
        '--target',
        CorpusWalkFixture.target,
        '--project',
        fx.root.path,
      ]);
      final out = await walk();
      expect(
        out,
        contains(
          '[corpus-walk] f0-notready -> blocked (not-ready: no '
          'acceptance scenarios)',
        ),
      );
      expect(
        await fx.readCalls(),
        isNot(contains('tdd run f0-notready --project ${fx.root.path}')),
        reason: 'not-ready features are never spawned',
      );
    });
  });

  group('A4 — the failure budget', () {
    test('within budget (M+K <= budget) exits 0 with result=ok', () async {
      await setupCatalog(['f1-good', 'f2-gap', 'f3-bad']);
      final out = await walk(
        budget: '2',
        outcomes: {
          'verify:f2-gap': (
            exit: 1,
            stdout: ['mutation: gate=fail_survived killed=0 survived=1'],
          ),
          'run:f3-bad': (
            exit: 1,
            stdout: ['run: feature=f3-bad result=stopped stopped_at=b1:gen'],
          ),
        },
      );
      expect(exitCode, 0, reason: out);
      final lastLine = out.trim().split('\n').last;
      expect(
        lastLine,
        startsWith(
          'corpus run: target=zik_zak features=3 green=1 partial=1 '
          'blocked=1 budget=2 used=2 result=ok',
        ),
        reason: out,
      );
    });

    test(
      'over budget (M+K > budget) exits 1 with result=over-budget',
      () async {
        await setupCatalog(['f1-gap', 'f2-bad']);
        final out = await walk(
          budget: '1',
          outcomes: {
            'verify:f1-gap': (
              exit: 1,
              stdout: ['mutation: gate=fail_survived killed=0 survived=1'],
            ),
            'run:f2-bad': (
              exit: 1,
              stdout: ['run: feature=f2-bad result=stopped stopped_at=b1:gen'],
            ),
          },
        );
        expect(exitCode, 1, reason: out);
        expect(out, contains('result=over-budget'));
        expect(out, contains('over budget'), reason: 'names the breach');
      },
    );

    test('the default budget is 5 (epic exit criterion: M+K <= 5)', () async {
      await setupCatalog(['f1-good', 'f2-gap']);
      final out = await walk(
        outcomes: {
          'verify:f2-gap': (
            exit: 1,
            stdout: ['mutation: gate=fail_survived killed=0 survived=1'],
          ),
        },
      );
      expect(exitCode, 0, reason: '1 partial <= default budget 5');
      expect(out, contains('budget=5'), reason: out);
    });
  });

  group('A5 — persisted walk results', () {
    test('the walk results land in .zfa/corpus/walks/<target>.json', () async {
      await setupCatalog(['f1-good', 'f2-gap']);
      await walk(
        outcomes: {
          'verify:f2-gap': (
            exit: 1,
            stdout: ['mutation: gate=fail_survived killed=0 survived=1'],
          ),
        },
      );
      final json = fx.readJsonMap(fx.walkPath);
      expect(json['target'], CorpusWalkFixture.target);
      final features = json['features'] as Map<String, dynamic>;
      expect(features['f1-good']['verdict'], 'green');
      expect(features['f2-gap']['verdict'], 'partial');
      expect(
        features['f1-good']['spec_sha256'],
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
    });
  });

  group('A6 — a walk of nothing is a misfire', () {
    test('an empty catalog stops with exit 2', () async {
      await setupCatalog([]);
      final out = await walk();
      expect(exitCode, 2, reason: out);
      expect(out, contains('no features'));
    });
  });
}
