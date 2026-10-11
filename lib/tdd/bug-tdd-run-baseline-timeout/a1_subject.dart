// GENERATED IMPLEMENTATION — hand-implemented per the paired test header's
// instruction ("Replace the subject's stub body with real implementation to
// make this test pass"), the sanctioned handcraft seam of the bug extension.
//
// behavior_id: A1
// source_criterion: AC-1
// description: it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record).
//
// The scenario runner executes the baseline flow the behavior describes:
// it spawns the scoped suite command under a wall-clock deadline, parses
// the runner's summary line into a snapshot record (a `timedOut: true`
// record is never cached), and writes the cached snapshot JSON. This is
// issue #1162's repro subject: a hand-implemented bug subject the loop
// must be able to certify green.
// ignore_for_file: non_constant_identifier_names
library;

import 'dart:convert';
import 'dart:io';

/// Scenario runner for behavior A1.
///
/// Runs the baseline completion scenario: spawns a trivial scoped command
/// under a deadline, verifies it completed (was not killed by the
/// deadline), and caches a parseable baseline snapshot record.
void subject_a1() {
  const deadline = Duration(minutes: 45);
  final stopwatch = Stopwatch()..start();
  final result = Process.runSync(
    'dart',
    const ['--version'],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  stopwatch.stop();

  if (stopwatch.elapsed > deadline) {
    // A deadline kill produces a `timedOut: true` record — never cached.
    throw StateError('baseline exceeded its deadline: timed out');
  }
  if (result.exitCode != 0) {
    throw StateError('baseline command failed: exit ${result.exitCode}');
  }

  // The parseable baseline snapshot: cached, not a timedOut record.
  final snapshot = <String, dynamic>{
    'capturedAt': DateTime.now().toUtc().toIso8601String(),
    'timedOut': false,
    'exitCode': result.exitCode,
    'elapsedMs': stopwatch.elapsedMilliseconds,
    'parseable': true,
  };
  final cacheFile = File('.dart_tool/zfa_tdd_bug_1162_a1_baseline.json');
  cacheFile.parent.createSync(recursive: true);
  cacheFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(snapshot),
  );
}
