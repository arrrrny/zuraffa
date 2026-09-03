// Spec 071 (issue #809) — ZAP reference client.
//
// U19 from specs/071-zuraffa-agent-protocol/tdd/test-list.md: ZapClient
// submits missions, collects evidence, checkpoints, recomputes the chain,
// and verifies receipts (FR-014) — in-process against a ZapHost wired
// through injectable streams (the same seam `zfa zap serve` uses).
library;

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/zap/zap_client.dart';
import 'package:zuraffa/src/zap/zap_executor.dart';
import 'package:zuraffa/src/zap/zap_host.dart';
import 'package:zuraffa/src/zap/zap_message.dart';

class _Scripted extends ZapStepExecutor {
  _Scripted(this.exitByStep);

  final Map<String, int> exitByStep;

  @override
  Future<ZapStepRun> run(
    MissionStep step, {
    required String workingDirectory,
    required Duration timeout,
  }) async {
    final exit = exitByStep[step.id] ?? 0;
    final output = 'scripted ${step.id}';
    return ZapStepRun(
      stepId: step.id,
      phase: step.phase,
      command: step.command,
      exit: exit,
      digest: ZapStepRun.digestOf(utf8.encode(output)),
      at: DateTime.now().toUtc().toIso8601String(),
      durationMs: 1,
      output: output,
    );
  }
}

MissionEnvelope _mission(String missionId, List<MissionStep> steps) =>
    MissionEnvelope(
      id: 'm-$missionId',
      ts: '2026-09-03T10:00:00Z',
      missionId: missionId,
      agent: 'reference-test',
      goal: 'drive a full session',
      maxSteps: 8,
      riskTier: 'standard',
      toolAllowlist: const ['dart'],
      steps: steps,
    );

MissionStep _step(String id, String phase) =>
    MissionStep(id: id, command: 'dart tdd_loop.dart $id', phase: phase);

void main() {
  test(
    'U19: the reference client submits, checkpoints, and verifies receipts',
    () async {
      final host = ZapHost(executor: _Scripted({'s1': 1, 's2': 0, 's3': 0}));

      // The transport seam: two in-memory wires, pumped sequentially —
      // exactly the topology `zfa zap serve` uses with stdin/stdout.
      final toHost = StreamController<String>();
      final toClient = StreamController<String>();
      addTearDown(toHost.close);
      addTearDown(toClient.close);

      final pump = () async {
        await for (final line in toHost.stream) {
          await host.handleLine(line, emit: toClient.add);
        }
      }();
      // Ignore the pump's completion (ends when the test tears the wires
      // down); a failure inside it surfaces via the client's timeouts.
      pump.ignore;

      final client = ZapClient(
        inbound: () => toClient.stream,
        send: toHost.add,
      );
      client.start();

      // Mission 1: red + green.
      final receipt1 = await client.submit(
        _mission('m1', [_step('s1', 'red'), _step('s2', 'green')]),
      );
      expect(receipt1.verdict, 'pass');
      expect(receipt1.exit, 0);

      // Checkpoint save + restore round-trip.
      final saved = await client.saveCheckpoint('m1');
      expect(saved.kind, 'saved');
      expect(saved.stateId, isNotNull);
      final restored = await client.restoreCheckpoint('m1', saved.stateId!);
      expect(restored.kind, 'restored');
      expect(restored.stateId, saved.stateId);

      // Mission 2: verify — the session continues.
      final receipt2 = await client.submit(
        _mission('m1', [_step('s3', 'verify')]),
      );
      expect(receipt2.verdict, 'pass');

      // Evidence collected: all three packets.
      expect(client.evidenceFor('m1').length, 3);

      // Receipt verification: the recomputed chain equals the host's digest.
      expect(client.recomputeChainDigest('m1'), receipt2.chainDigest);
      expect(client.verifyReceipt(receipt2), isTrue);

      // A tampered receipt digest is caught by the client's verification.
      final tampered = ZapReceipt(
        id: receipt2.id,
        ts: receipt2.ts,
        missionId: receipt2.missionId,
        verdict: receipt2.verdict,
        exit: receipt2.exit,
        chainDigest: '0' * 64,
        stepsExecuted: receipt2.stepsExecuted,
        stepsTotal: receipt2.stepsTotal,
        checks: receipt2.checks,
        at: receipt2.at,
      );
      expect(client.verifyReceipt(tampered), isFalse);
    },
  );
}
