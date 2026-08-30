/// `SuiteGuard` — runs the full suite and surfaces only NEW failures
/// (spec 047-tdd-make T007; FR-007; data-model.md).
///
/// Responsibilities:
///   1. Parse failing test identifiers from a `dart test` transcript
///      into a [SuiteSnapshot] (FR-007 / U14). The grammar matches
///      package:test's default reporter: lines like
///      `00:01 +1 -1: test/path_test.dart: group name test name [E]`
///      and the trailing failure block.
///   2. Diff a guard snapshot against a baseline snapshot to surface
///      only NEW failures by name (FR-007 / U15). Failures present in
///      BOTH snapshots are tolerated (U16 — pre-existing breakage
///      doesn't fail a `make` run).
///   3. Treat unparseable guard output as a safe failure (U18):
///      better to misfire-stop than silently pass.
library;

import '../services/runner.dart';

/// Snapshot of the failing-test set captured at one point in time
/// (data-model.md `SuiteSnapshot`).
class SuiteSnapshot {
  /// The suite command that produced this snapshot.
  final String command;

  /// The exit code of the suite run.
  final int exitCode;

  /// Set of failing test identifiers (e.g. `"test/foo_test.dart: group name test name"`).
  final Set<String> failedTests;

  /// ISO-8601 UTC timestamp of the snapshot.
  final String capturedAt;

  /// Whether the parser could find any progress or summary line at
  /// all (false → unparseable, U18).
  final bool parseable;

  const SuiteSnapshot({
    required this.command,
    required this.exitCode,
    required this.failedTests,
    required this.capturedAt,
    required this.parseable,
  });

  @override
  String toString() =>
      'SuiteSnapshot(cmd: $command, exit: $exitCode, failed: '
      '${failedTests.length}, parseable: $parseable)';
}

/// The NEW failures (guard − baseline), surfaced as a list so the
/// command can name them in its stderr report (FR-007).
class GuardDiff {
  final SuiteSnapshot baseline;
  final SuiteSnapshot guard;
  final List<String> newFailures;

  const GuardDiff({
    required this.baseline,
    required this.guard,
    required this.newFailures,
  });

  bool get hasNewFailures => newFailures.isNotEmpty;

  @override
  String toString() =>
      'GuardDiff(baseline=${baseline.failedTests.length} failed, '
      'guard=${guard.failedTests.length} failed, '
      'new=${newFailures.length})';
}

class SuiteGuard {
  const SuiteGuard();

  /// Parse a `dart test` transcript into a snapshot. Misfire-stop
  /// (U18): when the transcript shows no recognizable progress or
  /// summary markers, returns `parseable: false` so the caller can
  /// misfire-stop the command rather than silently passing.
  SuiteSnapshot parse({
    required String command,
    required int exitCode,
    required String output,
    required String capturedAt,
  }) {
    final failed = <String>{};

    // package:test default reporter emits one progress line per test:
    //   00:01 +1 -1: test/foo_test.dart: group name test name [E]
    //   00:01 +5: test/bar_test.dart: another test
    // Failures carry BOTH a non-zero `-N` segment AND an `[E]` marker.
    // Passes carry no `-N` segment (or `-0`) and no `[E]`. We capture
    // the test identifier (everything between `: ` and ` [E]`) only
    // when both failure markers are present, so the parser never
    // treats `All tests passed!` as a failing test.
    final progressFailure = RegExp(
      r'^\d\d:\d\d \+\d+ -\d+(?: ~\d+)?: (.+?) \[E\]$',
      multiLine: true,
    );
    for (final m in progressFailure.allMatches(output)) {
      final id = m.group(1)!.trim();
      if (id.isNotEmpty) {
        failed.add(id);
      }
    }

    // Some failures appear only in the trailing block:
    //   Some tests failed:
    //   - test/foo_test.dart: group name test name
    final block = RegExp(
      r'(?:Some tests failed|Failed tests|Failed:)[^\n]*\n((?:\s*-\s+.+\n?)+)',
    );
    for (final m in block.allMatches(output)) {
      for (final line in m.group(1)!.split('\n')) {
        final trimmed = line.trimLeft();
        if (!trimmed.startsWith('-')) continue;
        final id = trimmed.substring(1).trim();
        if (id.isNotEmpty) {
          failed.add(id);
        }
      }
    }

    // Parseability: any progress line (pass or fail), summary block,
    // or the exact success summary proves the transcript is real. A
    // non-zero run with no named failures is unusable: it may be a runner
    // or compiler failure rather than a trustworthy suite snapshot.
    final anyProgress = RegExp(r'^\d\d:\d\d [+\-~\d ]+:', multiLine: true);
    final hasTranscriptMarker =
        anyProgress.hasMatch(output) ||
        block.hasMatch(output) ||
        output.contains('All tests passed!');
    final parseable =
        hasTranscriptMarker && (exitCode == 0 || failed.isNotEmpty);

    return SuiteSnapshot(
      command: command,
      exitCode: exitCode,
      failedTests: failed,
      capturedAt: capturedAt,
      parseable: parseable,
    );
  }

  /// Build a snapshot from a [SuiteRunRecord] at a point in time.
  SuiteSnapshot fromRunRecord({
    required SuiteRunRecord record,
    required String capturedAt,
  }) {
    return parse(
      command: record.command,
      exitCode: record.exitCode,
      output: record.output,
      capturedAt: capturedAt,
    );
  }

  /// Diff guard against baseline, returning only NEW failures by name
  /// (FR-007 / U15). A failure present in both snapshots is tolerated
  /// (U16). A fix in the baseline that breaks again in the guard is a
  /// NEW failure (U17 — fix+break nets a named failure).
  GuardDiff diff({
    required SuiteSnapshot baseline,
    required SuiteSnapshot guard,
  }) {
    final baselineSet = baseline.failedTests;
    final newFailures =
        guard.failedTests.where((id) => !baselineSet.contains(id)).toList()
          ..sort();
    return GuardDiff(
      baseline: baseline,
      guard: guard,
      newFailures: newFailures,
    );
  }
}
