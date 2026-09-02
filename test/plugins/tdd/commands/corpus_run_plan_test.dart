// Bug #836 RED tests — `zfa tdd corpus run --plan`: topological ordering
// of the manifest by declared dependency edges, honest plan errors, the
// spec-hash provenance binding (drift = exit 3), and the plan-gap ledger
// (which FRs/ACs lack behaviors — the completeness proof).
//
// The command runs in-process through CliRunner.runCapturing; the
// per-feature `tdd run` / `tdd verify` are the fixture's scripted fake
// zfa binary (the corpus_run_command_test.dart pattern).
//
// NOT tagged `slow`: the only subprocesses are the fixture's scripted
// fake zfa (no pub get / build_runner), so this suite IS the scaled-down
// full-corpus smoke that CI runs on every push (issue #836 remediation 5).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_progress.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_progress_store.dart';

import '../helpers/corpus_fixture.dart';

void main() {
  late CorpusFixture fx;

  Future<String> drive({String? plan}) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'corpus',
      'run',
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeBin,
      if (plan != null) ...['--plan', plan],
    ]);
  }

  setUp(() async {
    fx = await CorpusFixture.create();
    await fx.writeFakeZfa();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('U25 — --plan drives in topological dependency order', () {
    test(
      'dependent features are driven after their dependencies (markdown plan)',
      () async {
        // Manifest order is deliberately REVERSED relative to the
        // dependency chain f1-base <- f2-mid <- f3-dep (F002→F001 style
        // edges): the plan must override manifest order.
        await fx.writeManifest([
          (name: 'f3-dep', ready: true, reason: ''),
          (name: 'f2-mid', ready: true, reason: ''),
          (name: 'f1-base', ready: true, reason: ''),
        ]);
        final plan = await fx.writePlan(
          '# Rewrite plan\n'
          '## Dependencies\n'
          '- f2-mid -> f1-base\n'
          '- f3-dep → f2-mid\n',
        );
        final out = await drive(plan: plan);
        expect(exitCode, 0, reason: out);
        expect(await fx.readCalls(), [
          'tdd run f1-base --project ${fx.root.path}',
          'tdd verify --feature f1-base --project ${fx.root.path}',
          'tdd run f2-mid --project ${fx.root.path}',
          'tdd verify --feature f2-mid --project ${fx.root.path}',
          'tdd run f3-dep --project ${fx.root.path}',
          'tdd verify --feature f3-dep --project ${fx.root.path}',
        ], reason: out);
      },
    );

    test(
      'independent features keep manifest order (stable topological sort)',
      () async {
        await fx.writeManifest([
          (name: 'a-first', ready: true, reason: ''),
          (name: 'b-second', ready: true, reason: ''),
        ]);
        final plan = await fx.writePlan('# Plan — no dependencies\n');
        final out = await drive(plan: plan);
        expect(exitCode, 0, reason: out);
        final calls = await fx.readCalls();
        expect(
          calls.indexOf(calls.firstWhere((c) => c.contains('a-first'))),
          lessThan(
            calls.indexOf(calls.firstWhere((c) => c.contains('b-second'))),
          ),
          reason: out,
        );
      },
    );

    test('a TUPEC inventory.json plan orders by its dependencies', () async {
      await fx.writeManifest([
        (name: 'f2-mid', ready: true, reason: ''),
        (name: 'f1-base', ready: true, reason: ''),
      ]);
      final plan = await fx.writePlan(
        '{"features": ['
        '{"id": "F001", "name": "f1-base", "dependencies": []},'
        '{"id": "F002", "name": "f2-mid", "dependencies": ["F001"]}'
        ']}',
        name: 'inventory.json',
      );
      final out = await drive(plan: plan);
      expect(exitCode, 0, reason: out);
      expect(await fx.readCalls(), [
        'tdd run f1-base --project ${fx.root.path}',
        'tdd verify --feature f1-base --project ${fx.root.path}',
        'tdd run f2-mid --project ${fx.root.path}',
        'tdd verify --feature f2-mid --project ${fx.root.path}',
      ], reason: out);
    });

    test('a plan edge naming an unknown feature stops honestly (exit 2), '
        'nothing driven', () async {
      await fx.writeManifest([(name: 'f1-base', ready: true, reason: '')]);
      final plan = await fx.writePlan('- f1-base -> f9-ghost\n');
      final out = await drive(plan: plan);
      expect(exitCode, 2, reason: out);
      expect(out, contains('f9-ghost'), reason: out);
      expect(await fx.readCalls(), isEmpty, reason: out);
    });

    test(
      'a dependency cycle stops honestly (exit 2), nothing driven',
      () async {
        await fx.writeManifest([
          (name: 'c1', ready: true, reason: ''),
          (name: 'c2', ready: true, reason: ''),
        ]);
        final plan = await fx.writePlan('- c1 -> c2\n- c2 -> c1\n');
        final out = await drive(plan: plan);
        expect(exitCode, 2, reason: out);
        expect(out, contains('c1'), reason: out);
        expect(await fx.readCalls(), isEmpty, reason: out);
      },
    );

    test(
      'a missing plan file stops honestly (exit 2), nothing driven',
      () async {
        await fx.writeManifest([(name: 'f1-base', ready: true, reason: '')]);
        final out = await drive(plan: '${fx.root.path}/no-such-plan.md');
        expect(exitCode, 2, reason: out);
        expect(await fx.readCalls(), isEmpty, reason: out);
      },
    );

    test(
      'the machine summary carries order=topological when --plan is given',
      () async {
        await fx.writeManifest([(name: 'f1-base', ready: true, reason: '')]);
        final plan = await fx.writePlan('# plan\n');
        final out = await drive(plan: plan);
        final lastLine = out.trim().split('\n').last;
        expect(
          lastLine,
          startsWith(
            'corpus: features=1 done=1 waived=0 stopped=0 '
            'not_ready=0 pending=0 dropped=0 gaps=0 result=complete',
          ),
          reason: out,
        );
        expect(lastLine, contains('order=topological'), reason: out);
      },
    );
  });

  group('U26 — resume with a plan (the resume token stays honest)', () {
    test('done features are not re-driven; the remaining order stays '
        'topological', () async {
      await fx.writeManifest([
        (name: 'f3-dep', ready: true, reason: ''),
        (name: 'f2-gap', ready: true, reason: ''),
        (name: 'f1-base', ready: true, reason: ''),
      ]);
      final plan = await fx.writePlan(
        '- f2-gap -> f1-base\n- f3-dep -> f2-gap\n',
      );
      await fx.writeFakeZfa(
        outcomes: {
          'run:f2-gap': (
            exit: 1,
            stdout: [
              'zfa tdd run: step failed — behavior=B-002 step=make outcome=unexpressible',
              'run: feature=f2-gap result=stopped pending=0 red=1 green=0 '
                  'done=0 stopped_at=B-002:make',
            ],
          ),
        },
      );
      final first = await drive(plan: plan);
      expect(exitCode, 1, reason: first); // stopped at f2-gap

      // "Fix the gap" and re-run with the same plan.
      await fx.rewriteFakeZfa(const {});
      final second = await drive(plan: plan);
      expect(exitCode, 0, reason: second);
      final calls = await fx.readCalls();
      // f1-base was driven exactly once across BOTH runs (resume).
      expect(
        calls.where((c) => c.contains('tdd run f1-base')),
        hasLength(1),
        reason: calls.join('\n'),
      );
      // f3-dep came after f2-gap on the resume run.
      final f2Run = calls.lastIndexOf(
        'tdd run f2-gap --project ${fx.root.path}',
      );
      final f3Run = calls.lastIndexOf(
        'tdd run f3-dep --project ${fx.root.path}',
      );
      expect(f2Run, lessThan(f3Run), reason: calls.join('\n'));
    });
  });

  group('U27 — provenance: green runs bind to the spec hash', () {
    test('a done feature records the sha256 of its spec.md', () async {
      await fx.writeManifest([(name: 'f1-base', ready: true, reason: '')]);
      await fx.writeSpec('f1-base', '# intent v1\n');
      final out = await drive();
      expect(exitCode, 0, reason: out);
      final progress = await fx.readProgress();
      final hash = progress!['features']['f1-base']['spec_hash'] as String?;
      expect(hash, isNotNull, reason: out);
      expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')), reason: out);
    });

    test('spec drift on a done feature stops the next run with exit 3 '
        'before driving anything', () async {
      await fx.writeManifest([
        (name: 'f1-base', ready: true, reason: ''),
        (name: 'f2-next', ready: true, reason: ''),
      ]);
      await fx.writeSpec('f1-base', '# intent v1\n');
      final first = await drive();
      expect(exitCode, 0, reason: first);
      final baseline = await fx.readCalls();

      // The intent changed under a completed green run.
      await fx.writeSpec('f1-base', '# intent v2 — CHANGED\n');
      final second = await drive();
      expect(exitCode, 3, reason: second);
      expect(second, contains('f1-base'), reason: second);
      expect(second, contains('drift'), reason: second);
      // Nothing new was driven: the call log is unchanged from run 1.
      final calls = await fx.readCalls();
      expect(calls, equals(baseline), reason: calls.join('\n'));
    });

    test('features driven before the hash record exists are not false-positive '
        'drift', () async {
      await fx.writeManifest([
        (name: 'f1-base', ready: true, reason: ''),
        (name: 'f2-next', ready: true, reason: ''),
      ]);
      // Hand-written legacy progress: done, no spec_hash recorded.
      final store = CorpusProgressStore(fx.root.path);
      final legacy = CorpusProgress();
      legacy.updateFeature(
        'f1-base',
        FeatureProgress(state: FeatureCorpusState.done, gate: 'pass'),
      );
      await store.save(legacy, manifestFeatureNames: {'f1-base', 'f2-next'});
      final out = await drive();
      expect(exitCode, 0, reason: out);
      final calls = await fx.readCalls();
      expect(
        calls.where((c) => c.contains('f1-base')),
        isEmpty,
        reason: calls.join('\n'),
      );
      expect(
        calls.where((c) => c.contains('tdd run f2-next')),
        hasLength(1),
        reason: calls.join('\n'),
      );
    });
  });

  group('U28 — the plan-gap ledger (the completeness proof)', () {
    test(
      'a declared criterion with no behavior lands in the gap ledger',
      () async {
        await fx.writeManifest([(name: 'f1-base', ready: true, reason: '')]);
        await fx.writeTestList('f1-base', [(id: 'B-001', traces: 'FR-1')]);
        final plan = await fx.writePlan(
          '# Plan\n## Criteria\n'
          '- f1-base: FR-1, FR-2\n',
        );
        final out = await drive(plan: plan);
        expect(exitCode, 0, reason: out); // gaps do not stop the run
        final ledger = await fx.readLedger();
        final planGaps = ledger
            .whereType<Map<String, dynamic>>()
            .where((e) => e['step'] == 'plan')
            .toList();
        expect(planGaps, hasLength(1), reason: '$ledger\n$out');
        expect(planGaps.first['feature'], 'f1-base');
        expect(planGaps.first['behavior'], 'FR-2');
        expect(planGaps.first['outcome'], 'missing_behavior');
      },
    );

    test('a covered criterion is never ledgered', () async {
      await fx.writeManifest([(name: 'f1-base', ready: true, reason: '')]);
      await fx.writeTestList('f1-base', [
        (id: 'B-001', traces: 'FR-1'),
        (id: 'B-002', traces: 'FR-2'),
      ]);
      final plan = await fx.writePlan(
        '# Plan\n## Criteria\n- f1-base: FR-1, FR-2\n',
      );
      final out = await drive(plan: plan);
      expect(exitCode, 0, reason: out);
      final ledger = await fx.readLedger();
      expect(
        ledger.whereType<Map<String, dynamic>>().where(
          (e) => e['step'] == 'plan',
        ),
        isEmpty,
        reason: '$ledger\n$out',
      );
    });

    test('plan gaps do not duplicate across resume runs', () async {
      await fx.writeManifest([(name: 'f1-base', ready: true, reason: '')]);
      await fx.writeTestList('f1-base', [(id: 'B-001', traces: 'FR-1')]);
      final plan = await fx.writePlan(
        '# Plan\n## Criteria\n- f1-base: FR-1, FR-2\n',
      );
      await drive(plan: plan);
      final second = await drive(plan: plan);
      expect(exitCode, 0, reason: second);
      final ledger = await fx.readLedger();
      final planGaps = ledger
          .whereType<Map<String, dynamic>>()
          .where((e) => e['step'] == 'plan')
          .toList();
      expect(planGaps, hasLength(1), reason: '$ledger\n$second');
    });

    test('a criterion becoming covered resolves the open plan gap (a NEW '
        'resolution entry, never an edit)', () async {
      await fx.writeManifest([(name: 'f1-base', ready: true, reason: '')]);
      await fx.writeTestList('f1-base', [(id: 'B-001', traces: 'FR-1')]);
      final plan = await fx.writePlan(
        '# Plan\n## Criteria\n- f1-base: FR-1, FR-2\n',
      );
      await drive(plan: plan);
      // The missing behavior now exists.
      await fx.writeTestList('f1-base', [
        (id: 'B-001', traces: 'FR-1'),
        (id: 'B-002', traces: 'FR-2'),
      ]);
      final second = await drive(plan: plan);
      expect(exitCode, 0, reason: second);
      final ledger = await fx.readLedger();
      final kinds = ledger.whereType<Map<String, dynamic>>().map(
        (e) => e['kind'],
      );
      expect(kinds, contains('resolution'), reason: '$ledger\n$second');
    });

    test('the machine summary counts plan gaps in gaps=', () async {
      await fx.writeManifest([(name: 'f1-base', ready: true, reason: '')]);
      await fx.writeTestList('f1-base', [(id: 'B-001', traces: 'FR-1')]);
      final plan = await fx.writePlan(
        '# Plan\n## Criteria\n- f1-base: FR-1, FR-2\n',
      );
      final out = await drive(plan: plan);
      final lastLine = out.trim().split('\n').last;
      expect(lastLine, contains('gaps=1'), reason: out);
    });
  });

  group('U29 — cross-feature composition ordering', () {
    test('a feature composing another feature\'s subject never drives before '
        'its composed dependency', () async {
      // The manifest lists the ACCEPTANCE (composing) feature first;
      // the plan declares it depends on the unit feature. #827
      // namespaced artifacts make the composition referenceable.
      await fx.writeManifest([
        (name: 'acc-composes', ready: true, reason: ''),
        (name: 'unit-base', ready: true, reason: ''),
      ]);
      final plan = await fx.writePlan('- acc-composes -> unit-base\n');
      final out = await drive(plan: plan);
      expect(exitCode, 0, reason: out);
      final calls = await fx.readCalls();
      final unitRun = calls.indexOf(
        'tdd run unit-base --project ${fx.root.path}',
      );
      final accRun = calls.indexOf(
        'tdd run acc-composes --project ${fx.root.path}',
      );
      expect(unitRun, lessThan(accRun), reason: calls.join('\n'));
    });
  });

  group('U30 — no --plan: the FR-001 manifest-order contract is unchanged', () {
    test('without --plan the manifest order drives verbatim', () async {
      await fx.writeManifest([
        (name: 'z-second', ready: true, reason: ''),
        (name: 'a-first', ready: true, reason: ''),
      ]);
      final out = await drive();
      expect(exitCode, 0, reason: out);
      expect(await fx.readCalls(), [
        'tdd run z-second --project ${fx.root.path}',
        'tdd verify --feature z-second --project ${fx.root.path}',
        'tdd run a-first --project ${fx.root.path}',
        'tdd verify --feature a-first --project ${fx.root.path}',
      ], reason: out);
      final lastLine = out.trim().split('\n').last;
      expect(lastLine, isNot(contains('order=')), reason: out);
    });
  });
}
