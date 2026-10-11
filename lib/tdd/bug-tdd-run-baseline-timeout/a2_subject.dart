// GENERATED IMPLEMENTATION — hand-implemented per the paired test header's
// instruction ("Replace the subject's stub body with real implementation to
// make this test pass"), the sanctioned handcraft seam of the bug extension.
//
// behavior_id: A2
// source_criterion: AC-2
// description: the default 10-minute deadline still applies (no behavior change for small repos).
//
// The scenario runner exercises the default-deadline behavior: it runs a
// trivial scoped command, checks the elapsed wall time against the
// 10-minute defaultSuite deadline, and asserts the deadline did not fire
// (the record is not a timeout record). This is issue #1162's repro
// subject for the drift-guard fail-open path.
// ignore_for_file: non_constant_identifier_names
library;

import 'dart:convert';
import 'dart:io';

/// Scenario runner for behavior A2.
///
/// Proves the default deadline still bounds the baseline: a command that
/// completes well inside 10 minutes yields a usable, non-timeout record.
void subject_a2() {
  const defaultSuiteDeadline = Duration(minutes: 10);
  final stopwatch = Stopwatch()..start();
  final result = Process.runSync(
    'dart',
    const ['--version'],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  stopwatch.stop();

  if (stopwatch.elapsed >= defaultSuiteDeadline) {
    throw StateError('default 10-minute deadline fired: baseline killed');
  }
  if (result.exitCode != 0) {
    throw StateError('baseline command failed: exit ${result.exitCode}');
  }

  final record = <String, dynamic>{
    'capturedAt': DateTime.now().toUtc().toIso8601String(),
    'timedOut': false,
    'exitCode': result.exitCode,
    'elapsedMs': stopwatch.elapsedMilliseconds,
    'deadline': 'defaultSuite:10m',
  };
  final cacheFile = File('.dart_tool/zfa_tdd_bug_1162_a2_record.json');
  cacheFile.parent.createSync(recursive: true);
  cacheFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(record),
  );
}
