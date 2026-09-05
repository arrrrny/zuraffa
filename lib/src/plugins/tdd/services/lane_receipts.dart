/// Lane receipts + the unified journal entry for the two-cycle driver
/// (spec 1008-two-cycle-driver, issue #1008).
///
/// Each lane run writes its verdict to `specs/<feature>/tdd/`:
///
/// - `04-engine-receipt.json` — written by `zfa tdd run-engine` (and by the
///   engine phase of the meta `zfa tdd run`);
/// - `04-skin-receipt.json` — written by `zfa tdd run-skin` (and by the
///   skin phase of the meta run). `run-skin` refuses to start (exit 2)
///   unless the engine receipt is green — the skin binds the engine's
///   certified mocks, so the engine must be certified first.
///
/// Receipt schema 1:
///
/// ```json
/// {
///   "schema": 1,
///   "feature": "004-login-ui",
///   "lane": "engine",
///   "verdict": "green",
///   "result": "complete",
///   "behaviors": ["U1", "U2", "A1"],
///   "counts": {"total": 3, "pending": 0, "red": 0, "green": 0, "done": 3},
///   "stopped_at": null,
///   "at": "2026-09-05T00:00:00.000Z"
/// }
/// ```
///
/// Verdict vocabulary: `green` (the lane ran to complete — every behavior
/// DONE with evidence, FR-010), `red` (the lane ran and stopped honestly),
/// `error` (the lane ran into a runner-error after driving started).
/// Pre-driving misfires write no receipt: the lane did not run, and the
/// last honest verdict stands.
///
/// A successful meta run (`zfa tdd run`) additionally appends the unified
/// journal entry to `tdd/cycle-log.md` naming both receipts. The entry
/// deliberately carries NO `- behavior:` field, so `CycleEvidence` parses
/// past it exactly like the file header — the two-cycle record never
/// contaminates the red/green evidence sets, the hash chains, or the
/// doctor's drift report.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';
import 'test_list_reader.dart';

class LaneReceipts {
  const LaneReceipts(this.featureDir);

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  static const engineReceiptName = '04-engine-receipt.json';
  static const skinReceiptName = '04-skin-receipt.json';

  String get engineReceiptPath => p.join(featureDir, 'tdd', engineReceiptName);

  String get skinReceiptPath => p.join(featureDir, 'tdd', skinReceiptName);

  String receiptPath(String lane) =>
      lane == 'skin' ? skinReceiptPath : engineReceiptPath;

  /// Write one lane receipt. [verdict] is green|red|error; [result] is the
  /// driver's own result name; [behaviors] the lane's ids in list order.
  Future<void> write({
    required String lane,
    required String verdict,
    required String result,
    required List<String> behaviors,
    required Map<String, int> counts,
    String? stoppedAt,
  }) async {
    final map = <String, Object?>{
      'schema': 1,
      'feature': p.basename(featureDir),
      'lane': lane,
      'verdict': verdict,
      'result': result,
      'behaviors': behaviors,
      'counts': counts,
      'stopped_at': stoppedAt,
      'at': DateTime.now().toUtc().toIso8601String(),
    };
    final file = File(receiptPath(lane));
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
    await tmp.rename(file.path);
  }

  /// Read one lane receipt. Returns null when the receipt does not exist.
  /// A present-but-unreadable receipt surfaces as a [LaneReceiptException]
  /// naming the recovery path (delete it and re-run the lane) — the gate
  /// must never paper over a corrupt receipt with an implicit verdict.
  Future<Map<String, dynamic>?> read(String lane) async {
    final file = File(receiptPath(lane));
    if (!await file.exists()) return null;
    String raw;
    try {
      raw = await file.readAsString();
    } on FileSystemException catch (e) {
      throw LaneReceiptException(
        'unreadable receipt at ${file.path} (${e.message}); delete it and '
        're-run the lane to record a fresh verdict',
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('top-level value is not an object');
      }
      return decoded;
    } on FormatException catch (e) {
      throw LaneReceiptException(
        'corrupt receipt at ${file.path} (${e.message}); delete it and '
        're-run the lane to record a fresh verdict',
      );
    }
  }

  /// The verdict guard for `run-skin`: null when the engine receipt exists
  /// and is green; a non-null refusal message when it is missing, not
  /// green, or unreadable (issue #1008: exit 2 — the engine must be green
  /// first).
  Future<String?> engineGateRefusal() async {
    final Map<String, dynamic>? receipt;
    try {
      receipt = await read('engine');
    } on LaneReceiptException catch (e) {
      return '${e.message} — the skin lane refuses to start until the '
          'engine lane is green';
    }
    if (receipt == null) {
      return 'no engine receipt at tdd/$engineReceiptName — the engine lane '
          'must be green before the skin lane runs (skin depends on the '
          'engine\'s certified mocks); run `zfa tdd run-engine '
          '${p.basename(featureDir)}` first';
    }
    final verdict = receipt['verdict'];
    if (verdict != 'green') {
      return 'engine receipt verdict is "$verdict" (result: '
          '${receipt['result']}) — the engine lane must be green before '
          'the skin lane runs; re-run `zfa tdd run-engine '
          '${p.basename(featureDir)}` until it completes';
    }
    return null;
  }

  /// The one-line verdict `zfa tdd status` prints: per-lane
  /// green|red|error|absent.
  Future<String> statusLine(String feature) async {
    final verdicts = <String, String>{};
    for (final lane in const ['engine', 'skin']) {
      try {
        final receipt = await read(lane);
        verdicts[lane] = receipt == null
            ? 'absent'
            : (receipt['verdict'] as String? ?? 'error');
      } on LaneReceiptException {
        verdicts[lane] = 'error';
      }
    }
    return 'status: feature=$feature engine=${verdicts['engine']} '
        'skin=${verdicts['skin']}';
  }

  /// Append the unified journal entry naming both receipts to
  /// `tdd/cycle-log.md` — the meta run's completion record (issue #1008:
  /// "writes a unified journal entry naming both receipts"). No `-
  /// behavior:` field on purpose (see the library doc).
  Future<void> appendUnifiedJournalEntry({
    required String feature,
    required String engineVerdict,
    required String skinVerdict,
  }) async {
    final file = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
    await file.parent.create(recursive: true);
    await file.writeAsString('''
## Two-cycle run: $feature

- feature: $feature
- engine-receipt: $engineReceiptName (verdict: $engineVerdict)
- skin-receipt: $skinReceiptName (verdict: $skinVerdict)
- at: ${DateTime.now().toUtc().toIso8601String()}

''', mode: FileMode.append);
  }
}

/// Raised by [LaneReceipts.read] for a present-but-corrupt receipt.
class LaneReceiptException implements Exception {
  const LaneReceiptException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Count the [BehaviorState]s of [rows] under [states] into the receipt
/// counts map (total/pending/red/green/done — the same accounting the
/// driver's summary line prints).
Map<String, int> laneCounts(
  List<BehaviorRow> rows,
  Map<String, BehaviorState> states,
) {
  var pending = 0, red = 0, green = 0, done = 0;
  for (final row in rows) {
    switch (states[row.id] ?? BehaviorState.pending) {
      case BehaviorState.pending:
        pending++;
      case BehaviorState.red:
        red++;
      case BehaviorState.mocked:
      case BehaviorState.green:
        green++;
      case BehaviorState.done:
        done++;
    }
  }
  return {
    'total': rows.length,
    'pending': pending,
    'red': red,
    'green': green,
    'done': done,
  };
}

/// Map a driver [result] onto the receipt verdict vocabulary.
String verdictForDriverResult(String result) => switch (result) {
  'complete' => 'green',
  'stopped' => 'red',
  _ => 'error',
};
