/// `TddTransaction` — the write-ahead journal for the TDD run driver
/// (bug #828: cycle-log evidence integrity).
///
/// The driver's per-step commit spans two processes: the spawned step
/// child appends its evidence to `tdd/cycle-log.md`, and the driver
/// advances `tdd/run-state.json` after the child exits. A crash inside
/// that window leaves the stores independent — exactly the disagreement
/// the bug reports. The transaction closes the window:
///
/// 1. **Write-ahead** — before a step is spawned, [begin] records the
///    intended transition (`behavior`, `step`, `pid`, `at`) in
///    `tdd/transaction.json` and fsyncs it. The transaction is intent,
///    never a claim of success.
/// 2. **Apply** — the child appends its evidence (fsync'd), the driver
///    saves the advanced run-state (fsync'd).
/// 3. **Commit** — [clear] removes the transaction. A transaction file
///    that survives the run is a crash marker.
///
/// On resume, [pending] exposes the interrupted transition: when the
/// step's evidence landed, the driver replays the state advance without
/// re-spawning the step (the transaction completes); when it did not, the
/// transaction is discarded and the in-flight marker re-drives the step
/// honestly. Either way the stores converge with the evidence — the
/// agent never hand-edits run-state to recover.
///
/// Spec 1113 (issue #1113) renamed this file from `tdd/journal.json` to
/// `tdd/transaction.json`: the write-ahead crash marker is a TRANSACTION
/// record, and `tdd/journal.json` is now the unified TDD journal
/// (`JournalWriter`/`JournalReader`) every cycle appends to — the name
/// collision clobbered unified entries on every `clear()`. A surviving
/// pre-1113 `journal.json` carrying the transaction shape is read as an
/// EMPTY unified journal (`JournalReader`'s legacy tolerance), never a
/// corrupt one.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Flush [file]'s contents to stable storage (fsync) before returning.
/// `RandomAccessFile.flush()` performs the fsync on POSIX targets.
Future<void> fsyncFile(File file) async {
  final raf = await file.open(mode: FileMode.append);
  try {
    await raf.flush();
  } finally {
    await raf.close();
  }
}

class TddTransaction {
  const TddTransaction(this.featureDir);

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// The write-ahead transaction file: `<featureDir>/tdd/transaction.json`
  /// (renamed from `tdd/journal.json` by spec 1113 — see the library doc).
  String get path => p.join(featureDir, 'tdd', 'transaction.json');

  /// Record the intent to run [step] for [behavior] — write-ahead, fsync'd
  /// before the step spawns. Any surviving record marks an interrupted
  /// transaction for the next resume to replay or discard.
  Future<void> begin({required String behavior, required String step}) async {
    final map = <String, Object?>{
      'schema': 1,
      'feature': p.basename(featureDir),
      'behavior': behavior,
      'step': step,
      'pid': pid,
      'at': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
    };
    final file = File(path);
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
    await fsyncFile(tmp);
    await tmp.rename(file.path);
  }

  /// The pending transaction record, or `null` when no journal exists or
  /// it cannot be parsed as a pending record (a corrupt journal never
  /// blocks a run — its absence of proof is an intent to re-drive).
  Future<Map<String, dynamic>?> pending() async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['status'] != 'pending') return null;
      return decoded;
    } on FormatException {
      return null;
    }
  }

  /// Complete the transaction: remove the transaction file after the
  /// state advance reached the disk.
  Future<void> clear() async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
