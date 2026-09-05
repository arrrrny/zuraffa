// Command-level tests for `zfa corpus ledger` — epic #1017 CORPUS-WALK,
// child issue "#1017 zfa corpus ledger --target=zik_zak — ledger as merge
// gate".
//
// The ledger is the merge gate: the walk's per-feature verdicts land in
// the COMMITTED ledger file `corpus/ledgers/<target>.json` (committed to
// the repo, so it persists across runs). The first ledger run writes the
// baseline; every subsequent run is a DIFF against the committed ledger —
// and a diff that shows an existing green contract regressing (green ->
// partial/blocked, or a green feature vanishing) is a CI failure (exit 1).
//
// Fast tier: the CLI runs in-process through CliRunner.runCapturing; the
// per-feature steps are the fixture's scripted fake zfa binary (the
// repo's canonical fake-zfa pattern).
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/corpus_walk_fixture.dart';

void main() {
  late CorpusWalkFixture fx;

  /// Writes manifest + specs + catalog (the real catalog command).
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

  Future<String> ledger({Map<String, WalkOutcome> outcomes = const {}}) async {
    await fx.writeFakeZfa(outcomes: outcomes);
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'corpus',
      'ledger',
      '--target',
      CorpusWalkFixture.target,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeBin,
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
    test('the corpus family lists ledger', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['corpus']);
      expect(out, contains('ledger'));
    });

    test('ledger exposes --target, --project, --zfa-bin', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['corpus', 'ledger', '--help']);
      expect(out, contains('--target'));
      expect(out, contains('--project'));
      expect(out, contains('--zfa-bin'));
    });

    test('ledger without --target is a usage error (exit 2)', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'corpus',
        'ledger',
        '--project',
        fx.root.path,
      ]);
      expect(out, contains('target'));
      expect(exitCode, 2);
    });

    test(
      'ledger without a catalog stops with catalog guidance (exit 2)',
      () async {
        final out = await ledger();
        expect(out, contains('catalog'));
        expect(out, contains('--> fix'));
        expect(exitCode, 2);
      },
    );
  });

  group('A2 — baseline: the first ledger run', () {
    test(
      'writes corpus/ledgers/<target>.json and exits 0 (result=baseline)',
      () async {
        await setupCatalog(['f1-good', 'f2-gap']);
        final out = await ledger(
          outcomes: {
            'verify:f2-gap': (
              exit: 1,
              stdout: ['mutation: gate=fail_survived killed=0 survived=1'],
            ),
          },
        );
        expect(exitCode, 0, reason: out);
        expect(out, contains('result=baseline'));

        final json = fx.readJsonMap(fx.ledgerPath);
        expect(json['target'], CorpusWalkFixture.target);
        final features = json['features'] as Map<String, dynamic>;
        expect(features['f1-good']['verdict'], 'green');
        expect(features['f2-gap']['verdict'], 'partial');
        expect(
          features['f1-good']['spec_sha256'],
          matches(RegExp(r'^[0-9a-f]{64}$')),
        );
        expect(features['f1-good']['classification'], 'CORE');
      },
    );
  });

  group('A3 — subsequent runs are diffs', () {
    test('an unchanged walk diffs clean (exit 0, result=clean)', () async {
      await setupCatalog(['f1-good']);
      await ledger(); // baseline
      final out = await ledger(); // same state again
      expect(exitCode, 0, reason: out);
      expect(out, contains('result=clean'));
      final lastLine = out.trim().split('\n').last;
      expect(
        lastLine,
        startsWith(
          'corpus ledger: target=zik_zak features=1 green=1 partial=0 '
          'blocked=0 regressions=0 added=0 removed=0 result=clean',
        ),
        reason: out,
      );
    });

    test('a spec change that stays green renews the hash (exit 0)', () async {
      await setupCatalog(['f1-good']);
      await ledger();
      // The spec evolves; the feature stays green.
      await fx.writeSpec('f1-good', CorpusWalkFixture.coreSpec('f1-v2'));
      final out = await ledger();
      expect(exitCode, 0, reason: out);
      expect(out, contains('renewed'), reason: 'renewal is reported');
      final json = fx.readJsonMap(fx.ledgerPath);
      final feature = json['features']['f1-good'] as Map<String, dynamic>;
      expect(feature['verdict'], 'green');
    });
  });

  group('A4 — regressions are CI failures (the merge gate)', () {
    test('a green contract regressing to partial is a contract-break '
        '(exit 1)', () async {
      await setupCatalog(['f1-good']);
      await ledger(); // baseline: f1 green
      final out = await ledger(
        outcomes: {
          'verify:f1-good': (
            exit: 1,
            stdout: ['mutation: gate=fail_survived killed=0 survived=1'],
          ),
        },
      );
      expect(exitCode, 1, reason: out);
      expect(out, contains('result=contract-break'));
      expect(
        out,
        contains('[ledger] f1-good: green -> partial (REGRESSION)'),
        reason: out,
      );
    });

    test('a green contract regressing to blocked is a contract-break '
        '(exit 1)', () async {
      await setupCatalog(['f1-good']);
      await ledger(); // baseline: f1 green
      final out = await ledger(
        outcomes: {
          'run:f1-good': (
            exit: 1,
            stdout: ['run: feature=f1-good result=stopped stopped_at=b1:gen'],
          ),
        },
      );
      expect(exitCode, 1, reason: out);
      expect(out, contains('result=contract-break'));
    });

    test('a removed green feature is a contract-break (exit 1)', () async {
      await setupCatalog(['f1-good', 'f2-good']);
      await ledger(); // baseline: both green

      // The feature leaves the walk (spec + catalog row removed).
      final catalogJson = fx.readJsonMap(fx.catalogPath);
      catalogJson['features'] = (catalogJson['features'] as List)
          .where((f) => (f as Map)['name'] != 'f2-good')
          .toList();
      File(fx.catalogPath).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(catalogJson),
      );

      final out = await ledger();
      expect(exitCode, 1, reason: out);
      expect(out, contains('removed'));
      expect(out, contains('f2-good'));
      expect(out, contains('result=contract-break'));
    });

    test('a new feature breaking an existing contract fails CI: the new '
        'feature lands, a previously-green one regresses (exit 1)', () async {
      await setupCatalog(['f1-good']);
      await ledger(); // baseline: f1 green

      // A new feature lands in the walk AND f1 (existing contract) breaks.
      await setupCatalog(['f1-good', 'f2-new']);
      final out = await ledger(
        outcomes: {
          'verify:f1-good': (
            exit: 1,
            stdout: ['mutation: gate=fail_survived killed=0 survived=1'],
          ),
        },
      );
      expect(exitCode, 1, reason: out);
      expect(out, contains('[ledger] f1-good: green -> partial (REGRESSION)'));
      expect(out, contains('added'), reason: 'the new feature is reported');
    });
  });

  group('A5 — additions are reported, not failures', () {
    test('a new green feature is an addition (exit 0, recorded)', () async {
      await setupCatalog(['f1-good']);
      await ledger(); // baseline: f1

      await setupCatalog(['f1-good', 'f2-new']);
      final out = await ledger();
      expect(exitCode, 0, reason: out);
      expect(out, contains('[ledger] added: f2-new (green)'));
      final json = fx.readJsonMap(fx.ledgerPath);
      expect((json['features'] as Map).containsKey('f2-new'), isTrue);
    });

    test('a new non-green feature is an addition against the budget — '
        'reported, ledger records it (exit 0)', () async {
      await setupCatalog(['f1-good']);
      await ledger();
      await setupCatalog(['f1-good', 'f2-gap']);
      final out = await ledger(
        outcomes: {
          'verify:f2-gap': (
            exit: 1,
            stdout: ['mutation: gate=fail_survived killed=0 survived=1'],
          ),
        },
      );
      expect(exitCode, 0, reason: 'additions are not regressions');
      expect(out, contains('[ledger] added: f2-gap (partial)'));
    });
  });

  group('A6 — corrupt state stops honestly', () {
    test(
      'a corrupt ledger JSON stops with recovery guidance (exit 2)',
      () async {
        await setupCatalog(['f1-good']);
        await ledger();
        File(fx.ledgerPath).writeAsStringSync('{ not json');
        final out = await ledger();
        expect(exitCode, 2, reason: out);
        expect(out, contains('--> fix'));
      },
    );
  });
}
