// Spec 071 (issue #809) — ZAP cross-implementation interop.
//
// A4, A5, A6 from specs/071-zuraffa-agent-protocol/tdd/test-list.md:
// the reference ZapClient and the independent foreign client (pure SDK,
// zero zuraffa imports) both complete verified sessions against the SAME
// unmodified host entry point — `dart bin/zfa.dart zap serve` (FR-015,
// FR-017, SC-003, SC-004).
//
// Spawns real JIT `dart bin/zfa.dart` host subprocesses (multi-minute) —
// tagged out of the default fast tier; run with
// `dart test --preset=integration test/zap/zap_interop_test.dart`.
@Tags(['integration', 'slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/zap/zap_client.dart';
import 'package:zuraffa/src/zap/zap_message.dart';

import '../helpers/project_root.dart';

/// The ONE host command every client drives — asserted literally so the
/// "no code changes on either side" claim is mechanical, not narrative.
const hostCommand = ['bin/zfa.dart', 'zap', 'serve'];

Future<String> _repoRoot() => findProjectRoot();

Future<Process> _spawnHost(String root) =>
    Process.start('dart', hostCommand, workingDirectory: root);

void main() {
  late String root;

  setUpAll(() async {
    root = await _repoRoot();
  });

  test(
    'A4: reference client drives the real zfa zap serve subprocess',
    () async {
      final host = await _spawnHost(root);
      addTearDown(() => host.kill());

      final client = ZapClient.overProcess(host);
      client.start();

      final mission = MissionEnvelope(
        id: 'm-ref-1',
        ts: DateTime.now().toUtc().toIso8601String(),
        missionId: 'ref-session',
        agent: 'reference-client',
        goal: 'Drive a full TDD loop through the real serve command',
        feature: '071-zuraffa-agent-protocol',
        maxSteps: 8,
        riskTier: 'standard',
        toolAllowlist: const ['dart'],
        steps: [
          MissionStep(
            id: 's1',
            command: 'dart examples/zap_demo/tdd_loop.dart red',
            phase: 'red',
            description: 'witness the failing check',
          ),
          MissionStep(
            id: 's2',
            command: 'dart examples/zap_demo/tdd_loop.dart green',
            phase: 'green',
            description: 'the fixed check passes',
          ),
        ],
      );

      final receipt = await client.submit(mission);
      expect(receipt.verdict, 'pass', reason: 'receipt: ${receipt.toJson()}');
      expect(receipt.exit, 0);

      // Checkpoint round-trip through the real process boundary.
      final saved = await client.saveCheckpoint('ref-session');
      expect(saved.kind, 'saved');
      expect(saved.stateId, isNotNull);
      final restored = await client.restoreCheckpoint(
        'ref-session',
        saved.stateId!,
      );
      expect(restored.kind, 'restored');

      // ...and the session continues after restore.
      final receipt2 = await client.submit(
        MissionEnvelope(
          id: 'm-ref-2',
          ts: DateTime.now().toUtc().toIso8601String(),
          missionId: 'ref-session',
          agent: 'reference-client',
          goal: 'complete the loop',
          maxSteps: 8,
          riskTier: 'standard',
          toolAllowlist: const ['dart'],
          steps: [
            MissionStep(
              id: 's3',
              command: 'dart examples/zap_demo/tdd_loop.dart verify',
              phase: 'verify',
              description: 'the suite passes',
            ),
          ],
        ),
      );
      expect(receipt2.verdict, 'pass');

      // Client-side receipt verification over the real wire.
      expect(client.evidenceFor('ref-session').length, 3);
      expect(client.recomputeChainDigest('ref-session'), receipt2.chainDigest);
      expect(client.verifyReceipt(receipt2), isTrue);

      // Close the host's stdin: the serve loop exits 0 at EOF.
      host.stdin.close();
      final exit = await host.exitCode;
      expect(exit, 0, reason: 'zfa zap serve exits 0 at stdin EOF');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('A5: foreign client drives a full TDD loop end-to-end', () async {
    // The foreign client is a pure-SDK subprocess with ZERO zuraffa
    // imports — it spawns the host itself and prints its final verdict as
    // the last stdout line.
    final result = await Process.run('dart', [
      'examples/zap_demo/foreign_client.dart',
      '--repo-root',
      root,
    ], workingDirectory: root);

    expect(
      result.exitCode,
      0,
      reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );

    final lines = (result.stdout as String).trim().split('\n');
    final last = lines.last;
    expect(
      last.startsWith('{'),
      isTrue,
      reason: 'the last line must be the verdict JSON: $last',
    );
    final verdict = jsonDecode(last) as Map<String, dynamic>;

    expect(
      verdict['chainVerified'],
      isTrue,
      reason: 'the foreign client must verify the receipt digest',
    );
    expect(
      verdict['hostCommand'],
      'dart ${hostCommand.join(' ')}',
      reason: 'the foreign client drives the SAME host entry point',
    );

    final receipt = verdict['receipt'] as Map<String, dynamic>;
    expect(receipt['type'], 'receipt');
    expect(receipt['verdict'], 'pass');
    expect(receipt['exit'], 0);
    final checks = (receipt['checks'] as List).cast<Map<String, dynamic>>();
    final discipline = checks.firstWhere((c) => c['name'] == 'tdd-discipline');
    expect(
      discipline['ok'],
      isTrue,
      reason: 'the full TDD loop was certified: red failed, green passed',
    );
    expect(
      receipt['stepsExecuted'],
      3,
      reason: 'red + green + verify all executed',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('A6: two independent clients, same unmodified host', () async {
    // Client A: the reference client (imports package:zuraffa).
    // Client B: the foreign client (pure SDK, zero zuraffa imports).
    // Both must drive the IDENTICAL host command — asserted literally.
    final refSession = await () async {
      final host = await _spawnHost(root);
      addTearDown(() => host.kill());
      final client = ZapClient.overProcess(host);
      client.start();
      final mission = MissionEnvelope(
        id: 'm-both-1',
        ts: DateTime.now().toUtc().toIso8601String(),
        missionId: 'both-ref',
        agent: 'reference-client',
        goal: 'interop session A',
        maxSteps: 4,
        riskTier: 'standard',
        toolAllowlist: const ['dart'],
        steps: [
          MissionStep(
            id: 's1',
            command: 'dart examples/zap_demo/tdd_loop.dart red',
            phase: 'red',
          ),
          MissionStep(
            id: 's2',
            command: 'dart examples/zap_demo/tdd_loop.dart green',
            phase: 'green',
          ),
        ],
      );
      final receipt = await client.submit(mission);
      host.stdin.close();
      await host.exitCode;
      return receipt;
    }();

    expect(refSession.verdict, 'pass');
    expect(refSession.exit, 0);

    // Client B: same host command, no code changes on either side.
    final foreign = await Process.run('dart', [
      'examples/zap_demo/foreign_client.dart',
      '--repo-root',
      root,
    ], workingDirectory: root);
    expect(
      foreign.exitCode,
      0,
      reason: 'stdout: ${foreign.stdout}\nstderr: ${foreign.stderr}',
    );
    final verdict =
        jsonDecode((foreign.stdout as String).trim().split('\n').last)
            as Map<String, dynamic>;
    expect(verdict['hostCommand'], 'dart ${hostCommand.join(' ')}');
    expect(verdict['chainVerified'], isTrue);

    // BOTH implementations interop with the one contract — the receipts
    // agree on the protocol's verdict vocabulary.
    final foreignReceipt = verdict['receipt'] as Map<String, dynamic>;
    expect(foreignReceipt['verdict'], refSession.verdict);
    expect(foreignReceipt['exit'], refSession.exit);
    for (final r in [refSession.toJson(), foreignReceipt]) {
      final names = ((r['checks'] as List).cast<Map<String, dynamic>>())
          .map((c) => c['name'])
          .toSet();
      expect(
        names,
        containsAll([
          'mission-schema',
          'budget',
          'policy',
          'steps-executed',
          'tdd-discipline',
          'evidence-chain',
        ]),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
