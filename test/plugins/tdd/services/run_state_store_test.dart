// Tests for RunStateStore (spec 049-tdd-run, U7-U11 / T006).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/run_state.dart';
import 'package:zuraffa/src/plugins/tdd/services/run_state_store.dart';

void main() {
  late Directory tmp;
  late String featureDir;
  late RunStateStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('run_state_store_');
    featureDir = p.join(tmp.path, 'specs', '090-fixture');
    await Directory(p.join(featureDir, 'tdd')).create(recursive: true);
    store = RunStateStore(featureDir);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  RunState sample() => RunState(
    feature: '090-fixture',
    behaviorStates: const {
      'B-001': BehaviorState.done,
      'B-002': BehaviorState.red,
    },
    inFlightBehaviorId: 'B-002',
    inFlightStep: 'make',
    inFlightOwnerPid: 4242,
  );

  test('U7: save -> load round-trips states and in-flight markers', () async {
    await store.save(sample());

    final loaded = await store.load();

    expect(loaded, isNotNull);
    expect(loaded!.feature, '090-fixture');
    expect(loaded.behaviorStates, {
      'B-001': BehaviorState.done,
      'B-002': BehaviorState.red,
    });
    expect(loaded.inFlightBehaviorId, 'B-002');
    expect(loaded.inFlightStep, 'make');
    expect(loaded.inFlightOwnerPid, 4242);
  });

  test('U7: load returns null when no state file exists', () async {
    expect(await store.load(), isNull);
    expect(await store.readDropped(), isEmpty);
  });

  test(
    'U8: saves are atomic — no tmp residue, previous intact on failure',
    () async {
      await store.save(sample());

      // Successful save leaves no temp file behind.
      expect(File('${store.path}.tmp').existsSync(), isFalse);
      final before = await File(store.path).readAsString();

      // A failed save (directory made read-only) leaves the previous content
      // intact — a crash mid-write cannot corrupt the previous state.
      Process.runSync('chmod', ['a-w', p.join(featureDir, 'tdd')]);
      try {
        await store.save(sample().advance('B-002', BehaviorState.green));
        fail('save should have failed against a read-only directory');
      } on FileSystemException {
        // expected
      } finally {
        Process.runSync('chmod', ['u+w', p.join(featureDir, 'tdd')]);
      }
      expect(await File(store.path).readAsString(), before);
    },
  );

  test(
    'U9: corrupted JSON stops with the corruption and recovery path',
    () async {
      await File(store.path).writeAsString('{"feature": "090-fixture", ');

      await expectLater(
        store.load(),
        throwsA(
          isA<RunStateCorruptException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('run-state.json'),
              contains('corrupt'),
              contains('delete'),
            ),
          ),
        ),
      );
    },
  );

  test('U9: shape violations are corruption, not crashes', () async {
    // spec 1468: an unknown state NAME is no longer corruption (it degrades
    // to pending — see the spec-1468 group below); only genuine shape
    // violations stay here.
    for (final raw in [
      '{"feature": "090-fixture", "behavior_states": []}',
      '{"feature": "other-feature", "behavior_states": {}}',
      '{"feature": "090-fixture", "behavior_states": {}, '
          '"in_flight_step": "dance"}',
    ]) {
      await File(store.path).writeAsString(raw);
      await expectLater(
        store.load(),
        throwsA(isA<RunStateCorruptException>()),
        reason: raw,
      );
    }
  });

  test('U10: a held in-flight marker refuses the second run', () async {
    // Live foreign owner: refused.
    final live = await Process.start('sleep', ['30']);
    addTearDown(live.kill);
    final held = RunState(
      feature: '090-fixture',
      behaviorStates: const {'B-001': BehaviorState.done},
      inFlightBehaviorId: 'B-001',
      inFlightStep: 'make',
      inFlightOwnerPid: live.pid,
    );
    expect(store.refusalReason(held), isNotNull);
    expect(store.refusalReason(held)!, contains('in flight'));

    // Dead owner (crashed run): resumable, no refusal.
    final deadProcess = await Process.start('sh', ['-c', 'exit 0']);
    await deadProcess.exitCode;
    final dead = RunState(
      feature: '090-fixture',
      behaviorStates: const {'B-001': BehaviorState.done},
      inFlightBehaviorId: 'B-001',
      inFlightStep: 'make',
      inFlightOwnerPid: deadProcess.pid,
    );
    expect(store.refusalReason(dead), isNull);

    // No in-flight marker at all.
    expect(store.refusalReason(null), isNull);
    expect(
      store.refusalReason(
        RunState(feature: '090-fixture', behaviorStates: const {}),
      ),
      isNull,
    );
  });

  test('U10: the live owner probe is injectable', () async {
    final probe = RunStateStore(featureDir, pidAlive: (pid) => pid == 4242);
    expect(probe.refusalReason(sample()), isNotNull);
    final otherPid = RunState(
      feature: '090-fixture',
      behaviorStates: const {},
      inFlightBehaviorId: 'B-001',
      inFlightStep: 'gen',
      inFlightOwnerPid: 9999,
    );
    expect(probe.refusalReason(otherPid), isNull);
  });

  test(
    'U11: behaviors removed from the test list are retained as dropped',
    () async {
      final state = sample().advance('B-002', BehaviorState.green);
      final withStale = state.advance('B-003', BehaviorState.done);

      await store.save(withStale, activeBehaviorIds: {'B-001', 'B-002'});

      final raw = jsonFileMap(store.path);
      expect(
        raw['behavior_states'],
        containsPair('B-003', 'done'),
        reason: 'the stale behavior is retained, never deleted',
      );
      expect(raw['dropped'], ['B-003']);
      expect(await store.readDropped(), ['B-003']);
      expect(store.computeDropped(withStale, {'B-001', 'B-002'}), ['B-003']);

      // A reload keeps the stale entry available for the audit trail.
      final reloaded = await store.load();
      expect(reloaded!.behaviorStates.containsKey('B-003'), isTrue);
    },
  );

  test('U11: saves without active ids record no dropped marker', () async {
    await store.save(sample());

    final raw = jsonFileMap(store.path);
    expect(raw.containsKey('dropped'), isFalse);
  });

  group('spec 1468: BehaviorState forward-compatibility', () {
    /// Writes [raw] as run-state.json and loads it with stderr captured
    /// (IOOverrides zone — the production warning goes through
    /// `stderr.writeln`). Returns the loaded state and the captured text.
    Future<(RunState?, String)> loadCapturingStderr(String raw) async {
      await File(store.path).writeAsString(raw);
      final capture = StringBuffer();
      final loaded = await IOOverrides.runZoned(
        () => store.load(),
        stderr: () => _StringSinkStderr(capture),
      );
      return (loaded, capture.toString());
    }

    test('U1: unknown state name degrades that entry to pending', () async {
      final (loaded, _) = await loadCapturingStderr(
        '{"feature": "090-fixture", '
        '"behavior_states": {"B-001": "shelved"}}',
      );

      expect(loaded, isNotNull, reason: 'SC-1: load succeeds, no throw');
      expect(loaded!.behaviorStates['B-001'], BehaviorState.pending);
    });

    test(
      'U2: the warning names the state, the behavior, and the fallback',
      () async {
        final (_, warning) = await loadCapturingStderr(
          '{"feature": "090-fixture", '
          '"behavior_states": {"B-001": "shelved"}}',
        );

        expect(
          warning,
          contains(
            '[run-state] unknown state "shelved" for behavior '
            '"B-001" → degraded to pending',
          ),
          reason: 'SC-2: the degrade receipt names state + behavior + fallback',
        );
      },
    );

    test(
      'U3: mixed map keeps known values, degrades only unknown ones',
      () async {
        final (loaded, warning) = await loadCapturingStderr(
          '{"feature": "090-fixture", "behavior_states": {'
          '"B-001": "done", "B-002": "archived", "B-003": "red"}}',
        );

        expect(loaded!.behaviorStates, {
          'B-001': BehaviorState.done,
          'B-002': BehaviorState.pending,
          'B-003': BehaviorState.red,
        }, reason: 'SC-3: downgraded binary resumes with known values intact');
        expect(
          warning,
          contains('unknown state "archived" for behavior "B-002"'),
        );
        expect(warning, isNot(contains('"done"')));
        expect(warning, isNot(contains('"red"')));
      },
    );

    test('U4: all-known state loads unchanged, no warning', () async {
      final (loaded, warning) = await loadCapturingStderr(
        '{"feature": "090-fixture", "behavior_states": {'
        '"B-001": "done", "B-002": "red", "B-003": "mocked"}}',
      );

      expect(loaded!.behaviorStates, {
        'B-001': BehaviorState.done,
        'B-002': BehaviorState.red,
        'B-003': BehaviorState.mocked,
      }, reason: 'SC-4: backwards compatible');
      expect(warning, isEmpty, reason: 'known states must not warn');
    });

    test('U5: non-string state value is still corruption', () async {
      await File(store.path).writeAsString(
        '{"feature": "090-fixture", "behavior_states": {"B-1": 7}}',
      );

      await expectLater(
        store.load(),
        throwsA(
          isA<RunStateCorruptException>().having(
            (e) => e.message,
            'message',
            contains('"behavior_states.B-1" is not a state name'),
          ),
        ),
        reason: 'SC-5: only unknown NAMES degrade, bad shapes stay corrupt',
      );
    });
  });
}

/// Minimal [Stdout] adapter so the spec-1468 degrade warning (written
/// through `stderr.writeln`) can be captured without spawning a process.
class _StringSinkStderr implements Stdout {
  _StringSinkStderr(this._target);
  final StringBuffer _target;

  @override
  void write(Object? obj) => _target.write(obj);

  @override
  void writeln([Object? obj = '']) => _target.writeln(obj);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _target.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _target.writeCharCode(charCode);

  @override
  bool get hasTerminal => false;

  @override
  IOSink get nonBlocking => throw UnsupportedError('nonBlocking');

  @override
  void add(List<int> data) => _target.write(utf8.decode(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      throw UnsupportedError('addError');

  @override
  Future addStream(Stream<List<int>> stream) =>
      throw UnsupportedError('addStream');

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  Future close() async {}

  @override
  Future get done => Future.value();

  @override
  Future flush() async {}

  @override
  bool get supportsAnsiEscapes => false;

  @override
  String get lineTerminator => '\n';

  @override
  set lineTerminator(String lineTerminator) {}

  @override
  int get terminalColumns => throw UnsupportedError('terminalColumns');

  @override
  int get terminalLines => throw UnsupportedError('terminalLines');
}

Map<String, dynamic> jsonFileMap(String path) {
  final content = File(path).readAsStringSync();
  return jsonDecode(content) as Map<String, dynamic>;
}
