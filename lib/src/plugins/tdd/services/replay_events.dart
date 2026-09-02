/// `ReplayEvents` — the NDJSON event log for `zfa replay` (spec
/// 066-zfa-replay, FR-014), the streaming vocabulary #791 aligns on.
///
/// One JSON object per line, written on every outcome: `replay.start`, then
/// `step.start` / `step.end` per stage (with `paths` on drift,
/// `expected`/`actual` on a verify divergence, `entry` on an integrity
/// break, `reason` on skips/runner errors), terminated by `replay.end`
/// whose `exit` always equals the process exit code.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'replay_runner.dart';

class ReplayEvents {
  final IOSink _sink;

  ReplayEvents._(this._sink);

  /// Open the event log at [path] (parent directories created).
  static Future<ReplayEvents> start(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    return ReplayEvents._(sink);
  }

  void runStart({
    required String feature,
    required List<String> behaviors,
  }) {
    _emit({
      'event': 'replay.start',
      'feature': feature,
      'behaviors': behaviors,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  void stepStart({required String behavior, required ReplayStage step}) {
    _emit({
      'event': 'step.start',
      'behavior': behavior,
      'step': step.name,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  void stepEnd(ReplayStepResult result) {
    _emit({
      'event': 'step.end',
      'behavior': result.behavior,
      'step': result.stageName,
      'status': result.statusName,
      if (result.paths.isNotEmpty) 'paths': result.paths,
      if (result.stage == ReplayStage.verify &&
          result.status == ReplayStepStatus.diverged &&
          result.reason != null &&
          result.reason!.contains('verify-exit-mismatch')) ...{
        'expected': result.expected,
        'actual': result.actual,
      },
      if (result.entry != null) 'entry': result.entry,
      if (result.reason != null &&
          (result.status == ReplayStepStatus.skipped ||
              result.status == ReplayStepStatus.diverged))
        'reason': result.reason,
    });
  }

  Future<void> runEnd({
    required String result,
    required int replayed,
    required int skipped,
    required int diverged,
    required int exit,
  }) async {
    _emit({
      'event': 'replay.end',
      'result': result,
      'replayed': replayed,
      'skipped': skipped,
      'diverged': diverged,
      'exit': exit,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    await _sink.flush();
    await _sink.close();
  }

  /// Best-effort close for error paths where [runEnd] already ran or the
  /// sink must not leak.
  Future<void> discard() async {
    await _sink.flush();
    await _sink.close();
  }

  void _emit(Map<String, dynamic> event) {
    _sink.writeln(jsonEncode(event));
  }
}

/// Convenience: the default events file name is caller-chosen, but the
/// sibling name helpers keep the path stable relative to a project root.
String replayEventsPath(String directory, String fileName) =>
    p.join(directory, fileName);
