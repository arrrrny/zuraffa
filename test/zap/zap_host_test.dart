// Spec 071 (issue #809) — ZAP host session semantics (in-process).
//
// U13–U18 + A7 + A8 from specs/071-zuraffa-agent-protocol/tdd/test-list.md:
// evidence + verified receipts, budget/policy gates BEFORE execution,
// checkpoint save/restore/persistence, direction/version/garbage lines
// never kill the host, timeouts + capping, and the TDD discipline rules
// (FR-004, FR-005, FR-009..FR-012, FR-016, SC-005).
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/zap/zap_chain.dart';
import 'package:zuraffa/src/zap/zap_executor.dart';
import 'package:zuraffa/src/zap/zap_golden.dart';
import 'package:zuraffa/src/zap/zap_host.dart';
import 'package:zuraffa/src/zap/zap_message.dart';

Map<String, Object?> _mission({
  required String missionId,
  required List<Map<String, Object?>> steps,
  int maxSteps = 8,
  List<String> allowlist = const ['dart'],
  String? id,
}) => {
  'zap': '0.1',
  'type': 'mission',
  'id': id ?? 'm-$missionId',
  'ts': '2026-09-03T10:00:00Z',
  'missionId': missionId,
  'agent': 'reference-test',
  'goal': 'test session',
  'budget': {'maxSteps': maxSteps},
  'policy': {'riskTier': 'standard', 'toolAllowlist': allowlist},
  'steps': steps,
};

Map<String, Object?> _step(String id, String command, String phase) => {
  'id': id,
  'command': command,
  'phase': phase,
};

Map<String, Object?> _checkpoint(
  String missionId,
  String kind, {
  String? stateId,
  String? id,
}) => {
  'zap': '0.1',
  'type': 'checkpoint',
  'id': id ?? 'c-$missionId',
  'ts': '2026-09-03T10:00:00Z',
  'missionId': missionId,
  'kind': kind,
  'stateId': ?stateId,
};

/// Drives one message through the host and returns the decoded replies
/// (in order).
Future<List<Map<String, Object?>>> _drive(
  ZapHost host,
  Map<String, Object?> message,
) async {
  final lines = <String>[];
  await host.handleLine(jsonEncode(message), emit: lines.add);
  return [
    for (final line in lines) (jsonDecode(line) as Map).cast<String, Object?>(),
  ];
}

Future<List<Map<String, Object?>>> _driveRaw(ZapHost host, String line) async {
  final lines = <String>[];
  await host.handleLine(line, emit: lines.add);
  return [
    for (final l in lines) (jsonDecode(l) as Map).cast<String, Object?>(),
  ];
}

/// A scripted executor: deterministic results keyed by step id, recording
/// every invocation so gates can prove "never invoked".
class _RecordingScripted extends ZapStepExecutor {
  _RecordingScripted(this.exitByStep);

  final Map<String, int> exitByStep;
  final List<String> invoked = [];

  @override
  Future<ZapStepRun> run(
    MissionStep step, {
    required String workingDirectory,
    required Duration timeout,
  }) async {
    invoked.add(step.id);
    return ZapStepRun(
      stepId: step.id,
      phase: step.phase,
      command: step.command,
      exit: exitByStep[step.id] ?? 0,
      digest: _digestFor(exitByStep[step.id] ?? 0),
      at: DateTime.now().toUtc().toIso8601String(),
      durationMs: 1,
      output: 'scripted output for ${step.id}',
    );
  }
}

String _digestFor(int exit) => 'f' * 63 + (exit == 0 ? '0' : '1');

void main() {
  group('ZapHost — happy path (U13)', () {
    test(
      'U13: a clean mission produces evidence and a verified receipt',
      () async {
        final executor = _RecordingScripted({'s1': 1, 's2': 0});
        final host = ZapHost(executor: executor);

        final replies = await _drive(
          host,
          _mission(
            missionId: 'm1',
            steps: [
              _step('s1', 'dart tdd_loop.dart red', 'red'),
              _step('s2', 'dart tdd_loop.dart green', 'green'),
            ],
          ),
        );

        // One evidence per step, then one receipt.
        expect(replies.length, 3);
        expect(replies[0]['type'], 'evidence');
        expect(replies[0]['stepId'], 's1');
        expect(replies[0]['phase'], 'red');
        expect(replies[0]['exit'], 1);
        expect(replies[0]['command'], 'dart tdd_loop.dart red');
        expect(replies[1]['type'], 'evidence');
        expect(replies[1]['exit'], 0);

        final receipt = replies[2];
        expect(receipt['type'], 'receipt');
        expect(receipt['verdict'], 'pass');
        expect(receipt['exit'], 0);
        expect(receipt['stepsExecuted'], 2);
        expect(receipt['stepsTotal'], 2);
        final checks = (receipt['checks'] as List).cast<Map<String, Object?>>();
        expect(checks.map((c) => c['name']).toSet(), {
          'mission-schema',
          'budget',
          'policy',
          'steps-executed',
          'tdd-discipline',
          'evidence-chain',
        });
        expect(checks.every((c) => c['ok'] == true), isTrue);

        // Receipt verification: recompute the chain over the received
        // evidence — it must equal the receipt's chainDigest.
        final evidenceFacts = replies
            .take(2)
            .map((r) => r.map((k, v) => MapEntry(k, v)))
            .toList();
        expect(zapEvidenceChain(evidenceFacts), receipt['chainDigest']);

        // The executor ran both steps in order.
        expect(executor.invoked, ['s1', 's2']);
      },
    );

    test(
      'U13: later missions continue the session (cumulative chain)',
      () async {
        final executor = _RecordingScripted({'s1': 1, 's2': 0, 's3': 0});
        final host = ZapHost(executor: executor);

        final mission = _mission(
          missionId: 'm1',
          steps: [
            _step('s1', 'dart tdd_loop.dart red', 'red'),
            _step('s2', 'dart tdd_loop.dart green', 'green'),
          ],
        );
        final first = await _drive(host, mission);
        expect(first.last['verdict'], 'pass');

        final second = await _drive(
          host,
          _mission(
            missionId: 'm1',
            steps: [_step('s3', 'dart tdd_loop.dart verify', 'verify')],
          ),
        );
        expect(second.length, 2); // one evidence + one receipt
        expect(second.last['stepsExecuted'], 3, reason: 'cumulative');
        expect(second.last['stepsTotal'], 3);

        // Cumulative chain covers all three evidence packets.
        final allEvidence = [...first.take(2), ...second.take(1)];
        expect(zapEvidenceChain(allEvidence), second.last['chainDigest']);
      },
    );
  });

  group('ZapHost — gates reject BEFORE execution (U14)', () {
    test('U14: a mission whose steps exceed the budget is rejected', () async {
      final executor = _RecordingScripted({});
      final host = ZapHost(executor: executor);

      final replies = await _drive(
        host,
        _mission(
          missionId: 'm1',
          maxSteps: 1,
          steps: [_step('s1', 'dart a', 'red'), _step('s2', 'dart b', 'green')],
        ),
      );

      expect(replies.length, 1);
      expect(replies[0]['type'], 'error');
      expect(replies[0]['code'], 'budget');
      expect(replies[0]['inReplyTo'], 'm-m1');
      expect(executor.invoked, isEmpty, reason: 'nothing may execute');
    });

    test('U14: cumulative budget exhaustion across missions', () async {
      final executor = _RecordingScripted({'s1': 1, 's2': 0, 's3': 0});
      final host = ZapHost(executor: executor);

      // Budget 2; mission 1 spends it exactly.
      await _drive(
        host,
        _mission(
          missionId: 'm1',
          maxSteps: 2,
          steps: [_step('s1', 'dart a', 'red'), _step('s2', 'dart b', 'green')],
        ),
      );
      expect(executor.invoked, ['s1', 's2']);

      // Mission 2 would exceed the cumulative budget.
      final replies = await _drive(
        host,
        _mission(
          missionId: 'm1',
          maxSteps: 2,
          steps: [_step('s3', 'dart c', 'verify')],
        ),
      );
      expect(replies.single['type'], 'error');
      expect(replies.single['code'], 'budget');
      expect(executor.invoked, ['s1', 's2'], reason: 's3 never ran');
    });

    test('U14: a later mission cannot ESCALATE the budget', () async {
      final executor = _RecordingScripted({'s1': 1});
      final host = ZapHost(executor: executor);

      await _drive(
        host,
        _mission(
          missionId: 'm1',
          maxSteps: 4,
          steps: [_step('s1', 'dart a', 'red')],
        ),
      );

      final replies = await _drive(
        host,
        _mission(
          missionId: 'm1',
          maxSteps: 99,
          steps: [_step('s2', 'dart b', 'green')],
        ),
      );
      expect(replies.single['type'], 'error');
      expect(replies.single['code'], 'budget');
      expect(executor.invoked, ['s1']);
    });

    test('U14: a command outside the allowlist is rejected', () async {
      final executor = _RecordingScripted({});
      final host = ZapHost(executor: executor);

      final replies = await _drive(
        host,
        _mission(
          missionId: 'm1',
          allowlist: ['dart'],
          steps: [_step('s1', 'rm -rf /tmp/everything', 'red')],
        ),
      );

      expect(replies.single['type'], 'error');
      expect(replies.single['code'], 'policy');
      expect(
        (replies.single['message'] as String).contains('rm'),
        isTrue,
        reason: 'the refusal must name the forbidden executable',
      );
      expect(executor.invoked, isEmpty);
    });

    test('U14: a later mission cannot DRIFT the policy', () async {
      final executor = _RecordingScripted({'s1': 1, 's2': 0});
      final host = ZapHost(executor: executor);

      await _drive(
        host,
        _mission(
          missionId: 'm1',
          allowlist: ['dart'],
          steps: [_step('s1', 'dart a', 'red')],
        ),
      );

      final replies = await _drive(
        host,
        _mission(
          missionId: 'm1',
          allowlist: ['dart', 'git'],
          steps: [_step('s2', 'git status', 'green')],
        ),
      );
      expect(replies.single['type'], 'error');
      expect(replies.single['code'], 'policy');
      expect(executor.invoked, ['s1']);
    });
  });

  group('ZapHost — checkpoints (U15)', () {
    test(
      'U15: save -> saved with stateId/digest; restore -> restored',
      () async {
        final executor = _RecordingScripted({'s1': 1, 's2': 0});
        final host = ZapHost(executor: executor);

        await _drive(
          host,
          _mission(
            missionId: 'm1',
            steps: [
              _step('s1', 'dart a', 'red'),
              _step('s2', 'dart b', 'green'),
            ],
          ),
        );

        final saved = await _drive(host, _checkpoint('m1', 'save'));
        expect(saved.single['type'], 'checkpoint');
        expect(saved.single['kind'], 'saved');
        expect(saved.single['stateId'], isA<String>());
        expect(saved.single['digest'], matches(RegExp('^[a-f0-9]{64}\$')));
        expect(saved.single['steps'], 2);
        final stateId = saved.single['stateId'] as String;

        final restored = await _drive(
          host,
          _checkpoint('m1', 'restore', stateId: stateId),
        );
        expect(restored.single['kind'], 'restored');
        expect(restored.single['stateId'], stateId);
        expect(restored.single['steps'], 2);
      },
    );

    test('U15: restoring an unknown stateId fails named', () async {
      final executor = _RecordingScripted({'s1': 1});
      final host = ZapHost(executor: executor);
      await _drive(
        host,
        _mission(missionId: 'm1', steps: [_step('s1', 'dart a', 'red')]),
      );

      final replies = await _drive(
        host,
        _checkpoint('m1', 'restore', stateId: 'cp-doesnotexist'),
      );
      expect(replies.single['type'], 'error');
      expect(replies.single['code'], 'bad-checkpoint');
    });

    test('U15: checkpointing an unknown mission fails named', () async {
      final host = ZapHost(executor: _RecordingScripted({}));

      final replies = await _drive(host, _checkpoint('ghost', 'save'));
      expect(replies.single['type'], 'error');
      expect(replies.single['code'], 'unknown-mission');
    });

    test('U15: snapshots persist and restore across host instances', () async {
      final dir = Directory.systemTemp.createTempSync('zap_cp');
      addTearDown(() => dir.deleteSync(recursive: true));

      final evidence = <Map<String, Object?>>[];
      final executor1 = _RecordingScripted({'s1': 1, 's2': 0});
      final host1 = ZapHost(executor: executor1, checkpointDir: dir.path);
      evidence.addAll(
        (await _drive(
          host1,
          _mission(
            missionId: 'm1',
            steps: [
              _step('s1', 'dart a', 'red'),
              _step('s2', 'dart b', 'green'),
            ],
          ),
        )).take(2),
      );

      final saved = await _drive(host1, _checkpoint('m1', 'save'));
      final stateId = saved.single['stateId'] as String;

      // A NEW host (fresh process semantics) with the same checkpoint dir.
      final executor2 = _RecordingScripted({'s3': 0});
      final host2 = ZapHost(executor: executor2, checkpointDir: dir.path);
      final restored = await _drive(
        host2,
        _checkpoint('m1', 'restore', stateId: stateId),
      );
      expect(restored.single['kind'], 'restored');
      expect(restored.single['steps'], 2);

      // The continued mission chains from the restored state.
      final second = await _drive(
        host2,
        _mission(missionId: 'm1', steps: [_step('s3', 'dart c', 'verify')]),
      );
      evidence.addAll(second.take(1));
      expect(second.last['verdict'], 'pass');
      expect(
        zapEvidenceChain(evidence),
        second.last['chainDigest'],
        reason: 'the chain must continue from the restored state',
      );
    });

    test(
      'U15: a tampered checkpoint file is rejected with bad-checkpoint',
      () async {
        final dir = Directory.systemTemp.createTempSync('zap_cp_tamper');
        addTearDown(() => dir.deleteSync(recursive: true));

        final host1 = ZapHost(
          executor: _RecordingScripted({'s1': 1}),
          checkpointDir: dir.path,
        );
        await _drive(
          host1,
          _mission(missionId: 'm1', steps: [_step('s1', 'dart a', 'red')]),
        );
        final saved = await _drive(host1, _checkpoint('m1', 'save'));
        final stateId = saved.single['stateId'] as String;

        // Tamper with the persisted record on disk: rewrite the red
        // evidence as a PASSING step — a fabricated session history.
        final file = File('${dir.path}/$stateId.json');
        final record = (jsonDecode(file.readAsStringSync()) as Map)
            .cast<String, Object?>();
        final snap = (record['snapshot'] as Map).cast<String, Object?>();
        final evidence0 = (snap['evidence'] as List).first as Map;
        evidence0['exit'] = 0;
        file.writeAsStringSync(jsonEncode(record));

        // A NEW host restoring from the tampered file gets the named
        // rejection — never a restored session.
        final host2 = ZapHost(
          executor: _RecordingScripted({}),
          checkpointDir: dir.path,
        );
        final replies = await _drive(
          host2,
          _checkpoint('m1', 'restore', stateId: stateId),
        );
        expect(replies.single['type'], 'error');
        expect(replies.single['code'], 'bad-checkpoint');
        expect(
          (replies.single['message'] as String).contains('digest'),
          isTrue,
          reason: 'the refusal must name the digest check',
        );
        // ...and the session was NOT restored: a save now finds no session
        // (a wrongly-restored session would answer `saved`).
        final saveReplies = await _drive(host2, _checkpoint('m1', 'save'));
        expect(saveReplies.single['type'], 'error');
        expect(saveReplies.single['code'], 'unknown-mission');
      },
    );
  });

  group('ZapHost — direction, version, garbage (U16 / A7)', () {
    test('A7: the host rejects malformed input with precise codes and '
        'keeps serving', () async {
      final executor = _RecordingScripted({'s1': 1});
      final host = ZapHost(executor: executor);

      // Garbage line -> schema error, host alive.
      final garbage = await _driveRaw(host, 'this is not json at all');
      expect(garbage.single['type'], 'error');
      expect(garbage.single['code'], 'schema');

      // Wrong version -> version error.
      final versioned = _mission(
        missionId: 'm1',
        steps: [_step('s1', 'dart a', 'red')],
      );
      versioned['zap'] = '2.0';
      final versionReply = await _drive(host, versioned);
      expect(versionReply.single['code'], 'version');

      // Host-only type sent inbound -> direction error.
      final evidenceInbound = ZapGoldens.example('evidence');
      final directionReply = await _drive(host, evidenceInbound);
      expect(directionReply.single['code'], 'direction');

      // Schema violation -> schema error with path details.
      final broken = _mission(
        missionId: 'm1',
        steps: [_step('s1', 'dart a', 'red')],
      );
      (broken['steps'] as List)[0]['phase'] = 'vibes';
      final schemaReply = await _drive(host, broken);
      expect(schemaReply.single['code'], 'schema');
      expect(
        (schemaReply.single['details'] as List).join(' '),
        contains('steps[0].phase'),
      );

      // ...and the host STILL serves a valid mission afterwards.
      final ok = await _drive(
        host,
        _mission(missionId: 'm1', steps: [_step('s1', 'dart a', 'red')]),
      );
      expect(ok.last['type'], 'receipt');
      expect(ok.last['verdict'], 'pass');
      expect(executor.invoked, ['s1']);
    });

    test('U16: host-only kinds sent inbound are direction errors', () async {
      final host = ZapHost(executor: _RecordingScripted({}));
      for (final kind in ['saved', 'restored']) {
        final replies = await _drive(host, _checkpoint('m1', kind));
        expect(replies.single['code'], 'direction', reason: 'kind=$kind');
      }
      final errorInbound = <String, Object?>{
        'zap': '0.1',
        'type': 'error',
        'id': 'x1',
        'ts': '2026-09-03T10:00:00Z',
        'code': 'schema',
        'message': 'boo',
      };
      final replies = await _drive(host, errorInbound);
      expect(replies.single['code'], 'direction');
    });
  });

  group('ZapHost — timeouts and capping (U17)', () {
    test(
      'U17: a timed-out step reports exit 124 and fails the receipt',
      () async {
        // A real subprocess executor running `sleep 5` with a 1s timeout.
        final host = ZapHost(
          executor: SubprocessZapStepExecutor(),
          defaultStepTimeout: const Duration(seconds: 1),
        );

        final replies = await _drive(
          host,
          _mission(
            missionId: 'm1',
            allowlist: ['sleep'],
            steps: [_step('s1', 'sleep 5', 'red')],
          ),
        );

        expect(replies[0]['type'], 'evidence');
        expect(replies[0]['exit'], 124, reason: 'the timeout convention');
        expect((replies[0]['output'] as String).contains('timed out'), isTrue);

        final receipt = replies.last;
        expect(receipt['verdict'], 'fail');
        expect(receipt['exit'], 1);
        final checks = (receipt['checks'] as List).cast<Map<String, Object?>>();
        final executed = checks.firstWhere(
          (c) => c['name'] == 'steps-executed',
        );
        expect(executed['ok'], isFalse);
        expect((executed['detail'] as String).contains('s1'), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test('U17: evidence output is capped at 2000 chars', () async {
      final longOutput = 'x' * 50000;
      final host = ZapHost(executor: _ScriptedOutput('s1', 0, longOutput));

      final replies = await _drive(
        host,
        _mission(missionId: 'm1', steps: [_step('s1', 'dart a', 'green')]),
      );

      final evidence = replies[0];
      expect((evidence['output'] as String).length, lessThanOrEqualTo(2000));
      // The digest still covers the FULL output (capping is a preview, not
      // a truncation of the certified fact).
      final full = ZapMessage.fromJson(evidence) as EvidencePacket;
      expect(full.digest, evidence['digest']);
    });
  });

  group('ZapHost — TDD discipline rules (U18 / A8)', () {
    test('A8: discipline violations flip the receipt verdict', () async {
      // A red step that PASSES (exit 0) — a test that never failed.
      final executor = _RecordingScripted({'s1': 0, 's2': 0});
      final host = ZapHost(executor: executor);

      final replies = await _drive(
        host,
        _mission(
          missionId: 'm1',
          steps: [
            _step('s1', 'dart tdd_loop.dart red', 'red'),
            _step('s2', 'dart tdd_loop.dart green', 'green'),
          ],
        ),
      );

      // Execution proceeds — both steps ran, evidence is honest.
      expect(replies.length, 3);
      expect(executor.invoked, ['s1', 's2']);

      // ...but the receipt FAILS with the discipline check naming the rule.
      final receipt = replies.last;
      expect(receipt['verdict'], 'fail');
      expect(receipt['exit'], 1);
      final checks = (receipt['checks'] as List).cast<Map<String, Object?>>();
      final discipline = checks.firstWhere(
        (c) => c['name'] == 'tdd-discipline',
      );
      expect(discipline['ok'], isFalse);
      expect((discipline['detail'] as String).contains('red'), isTrue);
    });

    test('U18: a failing green step fails the receipt (green rule)', () async {
      final executor = _RecordingScripted({'s1': 1, 's2': 1});
      final host = ZapHost(executor: executor);

      final replies = await _drive(
        host,
        _mission(
          missionId: 'm1',
          steps: [_step('s1', 'dart a', 'red'), _step('s2', 'dart b', 'green')],
        ),
      );
      final discipline = ((replies.last['checks'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((c) => c['name'] == 'tdd-discipline'));
      expect(replies.last['verdict'], 'fail');
      expect(discipline['ok'], isFalse);
      expect((discipline['detail'] as String).contains('green'), isTrue);
    });

    test('U18: green with no red ever witnessed fails (order rule)', () async {
      final executor = _RecordingScripted({'s1': 0});
      final host = ZapHost(executor: executor);

      final replies = await _drive(
        host,
        _mission(missionId: 'm1', steps: [_step('s1', 'dart a', 'green')]),
      );
      final discipline = ((replies.last['checks'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((c) => c['name'] == 'tdd-discipline'));
      expect(replies.last['verdict'], 'fail');
      expect(
        (discipline['detail'] as String).contains('witnessed'),
        isTrue,
        reason: 'the order rule must say no red was witnessed',
      );
    });

    test('U18: a green certified BEFORE any red fails (order rule)', () async {
      final executor = _RecordingScripted({'s1': 0, 's2': 1});
      final host = ZapHost(executor: executor);

      final replies = await _drive(
        host,
        _mission(
          missionId: 'm1',
          steps: [_step('s1', 'dart a', 'green'), _step('s2', 'dart b', 'red')],
        ),
      );
      final discipline = ((replies.last['checks'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((c) => c['name'] == 'tdd-discipline'));
      expect(replies.last['verdict'], 'fail');
      expect(discipline['ok'], isFalse);
      expect(
        (discipline['detail'] as String).contains('before any red'),
        isTrue,
        reason:
            'a red AFTER the first green does not satisfy the order '
            'rule: ${discipline['detail']}',
      );
    });

    test(
      'U18: red failing before green passing is certified honestly',
      () async {
        final executor = _RecordingScripted({'s1': 1, 's2': 0});
        final host = ZapHost(executor: executor);

        final replies = await _drive(
          host,
          _mission(
            missionId: 'm1',
            steps: [
              _step('s1', 'dart a', 'red'),
              _step('s2', 'dart b', 'green'),
            ],
          ),
        );
        final discipline = ((replies.last['checks'] as List)
            .cast<Map<String, Object?>>()
            .firstWhere((c) => c['name'] == 'tdd-discipline'));
        expect(replies.last['verdict'], 'pass');
        expect(discipline['ok'], isTrue);
        expect(
          (discipline['detail'] as String).contains(
            'red failed before green passed',
          ),
          isTrue,
          reason: 'the success detail may only claim the order held',
        );
      },
    );

    test('U18: a refactor step that stays green is neutral', () async {
      final executor = _RecordingScripted({'s1': 1, 's2': 0, 's3': 0});
      final host = ZapHost(executor: executor);

      final replies = await _drive(
        host,
        _mission(
          missionId: 'm1',
          steps: [
            _step('s1', 'dart a', 'red'),
            _step('s2', 'dart b', 'green'),
            _step('s3', 'dart c', 'refactor'),
          ],
        ),
      );
      expect(
        replies.last['verdict'],
        'pass',
        reason: 'refactor exit 0 keeps discipline green',
      );
    });
  });
}

/// Executor with a fixed output string (for the capping test).
class _ScriptedOutput extends ZapStepExecutor {
  _ScriptedOutput(this.stepId, this.exit, this.output);

  final String stepId;
  final int exit;
  final String output;

  @override
  Future<ZapStepRun> run(
    MissionStep step, {
    required String workingDirectory,
    required Duration timeout,
  }) async {
    final bytes = utf8.encode(output);
    final digest = ZapStepRun.digestOf(bytes);
    return ZapStepRun(
      stepId: step.id,
      phase: step.phase,
      command: step.command,
      exit: exit,
      digest: digest,
      at: DateTime.now().toUtc().toIso8601String(),
      durationMs: 1,
      output: output,
    );
  }
}
