// RED tests for spec 1193 B-006/B-009 — the ladder journal: the
// per-behavior MOCKED → REAL → DONE advance in tdd/run-state.json, the
// simulation-binding retirement, the unified cycle-log journal entry,
// and BehaviorState.real's integration with the run machinery.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/run_state.dart';
import 'package:zuraffa/src/plugins/tdd/services/ladder_journal.dart';
import 'package:zuraffa/src/plugins/tdd/services/lane_receipts.dart'
    show laneCounts;
import 'package:zuraffa/src/plugins/tdd/services/run_state_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart'
    show BehaviorRow;

void main() {
  late Directory root;
  late String featureDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ladder_test_');
    featureDir = p.join(root.path, 'specs', '090-tdd-fixture');
    await Directory(
      p.join(featureDir, 'tdd', 'fixtures'),
    ).create(recursive: true);
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  Future<void> seedRunState(Map<String, BehaviorState> states) async {
    final store = RunStateStore(featureDir);
    await store.save(
      RunState(feature: '090-tdd-fixture', behaviorStates: states),
    );
  }

  Future<Map<String, dynamic>> readRunState() async =>
      jsonDecode(
            await File(
              p.join(featureDir, 'tdd', 'run-state.json'),
            ).readAsString(),
          )
          as Map<String, dynamic>;

  test('B-006: advanceToRealThenDone walks the ladder for the entity '
      'behaviors and leaves unrelated behaviors alone', () async {
    await seedRunState({
      'B-001': BehaviorState.mocked,
      'B-002': BehaviorState.green,
      'B-003': BehaviorState.pending,
    });

    final journal = LadderJournal(
      featureDir: featureDir,
      projectRoot: root.path,
    );
    final advance = await journal.advanceToRealThenDone(
      behaviorIds: {'B-001'},
      evidence: {'contract': 'green', 'differential': 'pass'},
    );

    // B-001 (the realized entity's behavior) crossed the full ladder.
    expect(advance.transitions, hasLength(1));
    expect(advance.transitions.first.behavior, 'B-001');
    expect(advance.transitions.first.ladder, ['MOCKED', 'REAL', 'DONE']);
    // B-002 (a green behavior of another tier) and B-003 (pending) were
    // never touched — realize never lies about tiers it did not swap.
    final states = await readRunState();
    expect(states['behavior_states']['B-001'], 'done');
    expect(states['behavior_states']['B-002'], 'green');
    expect(states['behavior_states']['B-003'], 'pending');
  });

  test('B-006: a green behavior of the realized entity advances '
      'GREEN → DONE', () async {
    await seedRunState({'B-009': BehaviorState.green});

    final advance = await LadderJournal(
      featureDir: featureDir,
      projectRoot: root.path,
    ).advanceToRealThenDone(behaviorIds: {'B-009'}, evidence: {});

    expect(advance.transitions.first.ladder, ['GREEN', 'DONE']);
    final states = await readRunState();
    expect(states['behavior_states']['B-009'], 'done');
  });

  test(
    'B-006: a partially-realized behavior (REAL) completes to DONE',
    () async {
      await seedRunState({'B-001': BehaviorState.real});

      final advance = await LadderJournal(
        featureDir: featureDir,
        projectRoot: root.path,
      ).advanceToRealThenDone(behaviorIds: {'B-001'}, evidence: {});

      expect(advance.transitions.first.ladder, ['REAL', 'DONE']);
      final states = await readRunState();
      expect(states['behavior_states']['B-001'], 'done');
    },
  );

  test('B-006: no prior run-state file creates one with the terminal '
      'states only', () async {
    final advance = await LadderJournal(
      featureDir: featureDir,
      projectRoot: root.path,
    ).advanceToRealThenDone(behaviorIds: {'B-001'}, evidence: {});

    expect(advance.transitions, hasLength(1));
    final states = await readRunState();
    expect(states['feature'], '090-tdd-fixture');
    expect(states['behavior_states'], {'B-001': 'done'});
  });

  test('B-006: the simulation binding (fixtures manifest) is retired '
      'with its digest recorded', () async {
    final manifest = File(
      p.join(featureDir, 'tdd', 'fixtures', 'manifest.json'),
    );
    final manifestBytes = utf8.encode('{"digest": "abc", "families": []}');
    await manifest.writeAsBytes(manifestBytes);
    // The mock-era fixture JSON stays (differential evidence).
    await File(
      p.join(featureDir, 'tdd', 'fixtures', 'get_by_id.json'),
    ).writeAsString('{}');

    final advance = await LadderJournal(
      featureDir: featureDir,
      projectRoot: root.path,
    ).advanceToRealThenDone(behaviorIds: {'B-001'}, evidence: {});

    expect(advance.manifestRetired, isTrue);
    expect(advance.manifestDigest, isNotNull);
    // sha256 of the retired bytes.
    expect(advance.manifestDigest, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(await manifest.exists(), isFalse);
    expect(
      await File(
        p.join(featureDir, 'tdd', 'fixtures', 'get_by_id.json'),
      ).exists(),
      isTrue,
      reason: 'the fixtures stay as differential evidence',
    );
  });

  test(
    'B-006: a missing manifest is a no-op retirement (idempotent)',
    () async {
      final advance = await LadderJournal(
        featureDir: featureDir,
        projectRoot: root.path,
      ).advanceToRealThenDone(behaviorIds: {'B-001'}, evidence: {});

      expect(advance.manifestRetired, isFalse);
      expect(advance.manifestDigest, isNull);
    },
  );

  test('B-006: appendRealizationEntry writes the unified journal entry '
      'the evidence parsers read past (no behavior field)', () async {
    final journal = LadderJournal(
      featureDir: featureDir,
      projectRoot: root.path,
    );
    await journal.appendRealizationEntry(
      feature: '090-tdd-fixture',
      adapter: 'firestore',
      entities: const ['User'],
      contract: 'green',
      differential: 'pass',
      receipt: '.zfa/receipts/realize.090-tdd-fixture.firestore.receipt.json',
      ladder: 'MOCKED->REAL->DONE',
    );

    final log = await File(
      p.join(featureDir, 'tdd', 'cycle-log.md'),
    ).readAsString();
    expect(log, contains('## Realization: 090-tdd-fixture'));
    expect(log, contains('- adapter: firestore'));
    expect(log, contains('- contract: green'));
    expect(log, contains('- differential: pass'));
    expect(log, contains('- ladder: MOCKED->REAL->DONE'));
    expect(
      log,
      isNot(contains('- behavior:')),
      reason: 'the unified entry must not look like per-behavior evidence',
    );
  });

  group('B-009: BehaviorState.real integrates with the run machinery', () {
    test('run-state round-trips the real tier through the store', () async {
      await seedRunState({'B-001': BehaviorState.real});
      final loaded = await RunStateStore(featureDir).load();
      expect(loaded, isNotNull);
      expect(loaded!.behaviorStates['B-001'], BehaviorState.real);
    });

    test('run-state validation accepts the raw "real" state name', () async {
      await File(p.join(featureDir, 'tdd', 'run-state.json')).writeAsString(
        jsonEncode({
          'feature': '090-tdd-fixture',
          'behavior_states': {'B-001': 'real'},
        }),
      );
      final loaded = await RunStateStore(featureDir).load();
      expect(loaded!.behaviorStates['B-001'], BehaviorState.real);
    });

    test('laneCounts counts a real behavior in the green tier', () {
      BehaviorRow row(String id) => BehaviorRow(
        id: id,
        description: 'd',
        traces: 'FR',
        state: BehaviorState.pending,
        kind: BehaviorKind.unit,
        target: 'subject_x',
      );
      final counts = laneCounts(
        [row('B-001'), row('B-002'), row('B-003')],
        {
          'B-001': BehaviorState.real,
          'B-002': BehaviorState.mocked,
          'B-003': BehaviorState.pending,
        },
      );
      expect(counts['green'], 2);
      expect(counts['pending'], 1);
      expect(counts['done'], 0);
    });

    test('RunState.advance walks pending → real → done', () {
      final s0 = RunState(feature: 'f', behaviorStates: const {});
      final s1 = s0.advance('B-001', BehaviorState.real);
      expect(s1.behaviorStates['B-001'], BehaviorState.real);
      final s2 = s1.advance('B-001', BehaviorState.done);
      expect(s2.behaviorStates['B-001'], BehaviorState.done);
    });
  });
}
