/// `RunBaselineCache` — persists the full-suite baseline snapshot a
/// `zfa tdd run` driver captures ONCE per run, so every `make` step in
/// that run reuses it instead of re-running the full suite per behavior
/// (issue #741).
///
/// The cache file lives at `specs/<feature>/tdd/run-baseline.json` and
/// holds the [SuiteSnapshot] fields verbatim (command, exitCode,
/// failedTests, capturedAt, parseable). It is:
///
/// - written by the run driver after its single per-run suite baseline
///   (only when the snapshot is parseable — an unusable suite disables
///   caching entirely);
/// - consumed by `zfa tdd make` through the `--suite-baseline <path>`
///   flag the driver passes to make steps;
/// - inert everywhere else: a standalone `make` never reads it without
///   the flag, so the flag-less contract (live baseline + live guard)
///   is unchanged.
///
/// Reading is fail-safe: a missing, corrupt, or malformed file yields
/// null and the caller falls back to the live suite run (safe failure —
/// never a silent pass, mirroring the SuiteGuard's U18 stance).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'suite_guard.dart';

class RunBaselineCache {
  const RunBaselineCache();

  /// The cache file name inside the feature's `tdd/` directory.
  static const fileName = 'run-baseline.json';

  /// The cache path for a feature directory.
  static String pathFor({required String featureDir}) =>
      p.join(featureDir, 'tdd', fileName);

  /// Persist [snapshot] for the feature and return the written path.
  Future<String> write({
    required String featureDir,
    required SuiteSnapshot snapshot,
  }) async {
    final file = File(pathFor(featureDir: featureDir));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'command': snapshot.command,
        'exitCode': snapshot.exitCode,
        'failedTests': snapshot.failedTests.toList(),
        'capturedAt': snapshot.capturedAt,
        'parseable': snapshot.parseable,
      }),
    );
    return file.path;
  }

  /// Load a cached snapshot. Returns null when the file is missing,
  /// unreadable, corrupt, or typed wrong — the caller then falls back
  /// to the live suite (safe failure, issue #741).
  Future<SuiteSnapshot?> read(String path) async {
    try {
      final raw = await File(path).readAsString();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final command = json['command'];
      final exitCode = json['exitCode'];
      final failed = json['failedTests'];
      final capturedAt = json['capturedAt'];
      final parseable = json['parseable'];
      if (command is! String ||
          exitCode is! int ||
          failed is! List ||
          capturedAt is! String ||
          parseable is! bool) {
        return null;
      }
      return SuiteSnapshot(
        command: command,
        exitCode: exitCode,
        failedTests: failed.whereType<String>().toSet(),
        capturedAt: capturedAt,
        parseable: parseable,
      );
    } catch (_) {
      return null;
    }
  }
}
