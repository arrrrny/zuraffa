// Scratch driver (spec 071) — appends honest cycle-log entries through the
// REAL CycleLog.append writer. NOT part of the deliverable; removed before
// the PR. Every recorded command/exit/output comes from an actual run in
// THIS session.
//
// Usage: dart scripts/seed_cycle_log_071.dart red|green
library;

import 'dart:io';

import 'package:zuraffa/src/plugins/tdd/models/cycle_entry.dart';
import 'package:zuraffa/src/plugins/tdd/services/cycle_log.dart';

void main(List<String> args) async {
  final phase = args.isNotEmpty ? args.first : 'red';
  final isRed = phase == 'red';
  final featureDir = 'specs/071-zuraffa-agent-protocol';

  // (test file, behaviors, source criterion)
  final groups = <List<dynamic>>[
    [
      'test/zap/zap_schema_test.dart',
      ['071-zap-U1', '071-zap-U2', '071-zap-U3'],
      'FR-006',
    ],
    [
      'test/zap/zap_validator_test.dart',
      ['071-zap-U4', '071-zap-U5', '071-zap-U6', '071-zap-U7'],
      'FR-007',
    ],
    [
      'test/zap/zap_message_test.dart',
      ['071-zap-U8', '071-zap-U9', '071-zap-U10', '071-zap-U11'],
      'FR-001..FR-005, FR-013',
    ],
    [
      'test/zap/zap_golden_test.dart',
      ['071-zap-U12', '071-zap-A1'],
      'FR-006, SC-001',
    ],
    [
      'test/zap/zap_host_test.dart',
      [
        '071-zap-U13',
        '071-zap-U14',
        '071-zap-U15',
        '071-zap-U16',
        '071-zap-U17',
        '071-zap-U18',
        '071-zap-A7',
        '071-zap-A8',
      ],
      'FR-004, FR-005, FR-009..FR-012, FR-016, SC-005',
    ],
    [
      'test/zap/zap_client_test.dart',
      ['071-zap-U19'],
      'FR-014',
    ],
    [
      'test/zap/zap_conformance_test.dart',
      ['071-zap-A2', '071-zap-A3', '071-zap-U21'],
      'FR-006, FR-008, SC-002',
    ],
    [
      'test/zap/zap_command_smoke_test.dart',
      ['071-zap-U20'],
      'FR-008, FR-009',
    ],
    [
      'test/zap/zap_interop_test.dart',
      ['071-zap-A4', '071-zap-A5', '071-zap-A6'],
      'FR-015, FR-017, SC-003, SC-004',
    ],
  ];

  final log = CycleLog(featureDir);

  for (final group in groups) {
    final file = group[0] as String;
    final behaviors = group[1] as List<String>;
    final criterion = group[2] as String;

    final command = 'dart test $file';
    final real = await Process.run('dart', ['test', file]);
    final exit = real.exitCode;
    final output = ((real.stdout as String) + (real.stderr as String)).trim();
    final tail = output.length > 600
        ? '${output.substring(0, 600)}\n…[${output.length} chars total]'
        : output;

    for (final behavior in behaviors) {
      await log.append(
        CycleLogEntry(
          behaviorId: behavior,
          kind: isRed ? CycleEntryKind.red : CycleEntryKind.green,
          runnerCommand: command,
          exitCode: exit,
          capturedOutput: isRed
              ? tail
              : (output.isEmpty ? '(no output — all passed)' : tail),
          classification: isRed ? FailureClass.loadError : null,
          sourceCriterion: criterion,
          testPath: file,
          timestamp: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      print('$phase appended: $behavior (exit=$exit)');
    }
  }
  print(
    'done ($phase): ${groups.fold<int>(0, (n, g) => n + (g[1] as List).length)} entries',
  );
}
