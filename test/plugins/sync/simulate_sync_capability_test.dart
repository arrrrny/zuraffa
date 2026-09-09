// Issue #1359 — `zfa sync simulate --scenario offline-flap`: the chaos
// driver for temporal sync features. Drives the REAL
// PushOnlySyncStrategy against a scripted failing remote (offline
// window → flaps → recovery) and proves eventual consistency with
// per-key verdicts + a landing ledger (no loss, no duplicates).
//
// Behaviors (test-list):
//   B1 — the offline-flap scenario runs GREEN: every seeded entity
//        lands exactly once after the recovery pass.
//   B2 — an unknown scenario refuses honestly naming the allowed list.
//   B3 — the summary line carries the chaos evidence (retries, verdict).
//   B4 — `zfa sync simulate --help` documents --scenario.

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  Future<(int, String)> runZfa(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing(args);
    return (exitCode, output);
  }

  test('B1: the offline-flap scenario drives the strategy to GREEN', () async {
    final (code, output) = await runZfa([
      'sync',
      'simulate',
      '--scenario',
      'offline-flap',
    ]);
    expect(code, 0, reason: output);
    expect(output, contains('verdict=GREEN'));
    expect(output, contains('landed=5/5'));
  });

  test('B2: an unknown scenario refuses naming the allowed list', () async {
    final (code, output) = await runZfa([
      'sync',
      'simulate',
      '--scenario',
      'gremlins',
    ]);
    // The parser layer rejects it first (the schema enum is the allowed
    // list); the capability keeps its own guard for direct invocation.
    expect(code, 2, reason: output);
    expect(output, contains('offline-flap'));
    expect(output, contains('not an allowed value'));
  });

  test(
    'B3: the summary carries the chaos evidence (retries + verdict)',
    () async {
      final (code, output) = await runZfa([
        'sync',
        'simulate',
        '--scenario',
        'offline-flap',
      ]);
      expect(code, 0, reason: output);
      expect(output, contains('retries>0'));
      expect(output, contains('sync-simulate: scenario=offline-flap'));
    },
  );

  test('B4: --help documents --scenario', () async {
    final (code, output) = await runZfa(['sync', 'simulate', '--help']);
    expect(code, 0, reason: output);
    expect(output, contains('scenario'));
    expect(output, contains('offline-flap'));
  });
}
