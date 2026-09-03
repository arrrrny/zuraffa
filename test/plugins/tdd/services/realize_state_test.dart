// Fast unit tests for `RealizeStateStore` — the MOCKED→REAL era record at
// specs/<feature>/tdd/realize-state.json (spec 913, T001: U1-U3).
//
//   U1: an absent state file is era MOCKED — mock-first is the default
//       path, never an exception.
//   U2: transitionToReal persists realize-state.json with era REAL and an
//       append-only transition history carrying gate evidence.
//   U3: a second realize of the same adapter is idempotent — no duplicate
//       transition, era stays REAL.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/realize_state.dart';

void main() {
  late Directory temp;
  late String featureDir;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('realize_state_');
    featureDir = p.join(temp.path, 'specs', '090-tdd-fixture');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  RealizeStateStore store() => RealizeStateStore(featureDir);

  test('U1: absent state file means era MOCKED (mock-first default)', () async {
    final state = await store().loadOrDefault(
      feature: '090-tdd-fixture',
      entity: 'User',
    );

    expect(state.era, RealizeEra.mocked);
    expect(state.feature, '090-tdd-fixture');
    expect(state.entity, 'User');
    expect(state.transitions, isEmpty);
    // No file was created merely by reading the default.
    expect(File(store().path).existsSync(), isFalse);
  });

  test('U2: transitionToReal persists era REAL with gate evidence', () async {
    final s = store();
    final initial = await s.loadOrDefault(
      feature: '090-tdd-fixture',
      entity: 'User',
    );
    final next = await s.transitionToReal(
      state: initial,
      adapter: 'UserRealAdapter',
      evidence: {
        'contract': 'green',
        'differential': 'pass',
        'drift': 0.0,
        'handDeltas': 1,
      },
    );
    await s.save(next);

    final file = File(s.path);
    expect(file.existsSync(), isTrue, reason: 'state file must persist');
    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(raw['schema'], 'realize.v1');
    expect(raw['era'], 'REAL');
    expect(raw['entity'], 'User');
    expect(raw['adapter'], 'UserRealAdapter');
    final transitions = raw['transitions'] as List;
    expect(transitions, hasLength(1));
    expect(transitions.first['from'], 'MOCKED');
    expect(transitions.first['to'], 'REAL');
    expect(transitions.first['adapter'], 'UserRealAdapter');
    expect(transitions.first['evidence']['contract'], 'green');
    expect(transitions.first['at'], isNotEmpty);

    // Round-trip: loadOrDefault returns the persisted REAL state.
    final reloaded = await s.loadOrDefault(
      feature: '090-tdd-fixture',
      entity: 'User',
    );
    expect(reloaded.era, RealizeEra.real);
    expect(reloaded.transitions, hasLength(1));
  });

  test('U3: re-realizing the same adapter is idempotent', () async {
    final s = store();
    final initial = await s.loadOrDefault(
      feature: '090-tdd-fixture',
      entity: 'User',
    );
    final once = await s.transitionToReal(
      state: initial,
      adapter: 'UserRealAdapter',
      evidence: const {},
    );
    await s.save(once);
    final twice = await s.transitionToReal(
      state: once,
      adapter: 'UserRealAdapter',
      evidence: const {},
    );
    await s.save(twice);

    expect(twice.era, RealizeEra.real);
    expect(twice.transitions, hasLength(1),
        reason: 'same-adapter re-realize must not append a transition');
  });
}
