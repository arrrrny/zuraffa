/// `MakeInterruptMarker` — the write-ahead crash marker for the TDD make
/// step (issue #1398: crash-safe make, spec 1398-crash-safe-make-interrupt).
///
/// Issue #1036's invariant — a make that does not complete leaves NO subject
/// mutation — only holds for graceful failures. A make killed mid-flight
/// (external timeout SIGKILL, OOM, process death) leaves the subject
/// mutated with no green evidence, and the resume could not distinguish the
/// driver's own half-made work from a dishonest hand-edit: both refused
/// `subject-drift` and the documented recovery dead-ended.
///
/// The marker closes the honesty gap the same way the run driver's
/// `TddTransaction` (bug #828) closes its evidence window — write-ahead,
/// fsync, atomic rename:
///
/// 1. **Write-ahead** — the make records its own in-flight state
///    (`behavior`, `pid`, `at`) in `specs/<feature>/tdd/make-interrupt.json`
///    BEFORE any work that can mutate the subject. Intent, never a claim of
///    success.
/// 2. **Read-before-overwrite** — a make that starts and finds a marker for
///    the SAME behavior knows the previous make died mid-flight: the drift
///    class is the honest crash class (the make command decides what that
///    legitimizes; the placeholder gate still refuses the vacuous class).
/// 3. **Commit** — every graceful exit removes the marker. A marker that
///    survives the run is a crash record — nothing else can leave one.
///
/// Fail closed: a missing, corrupt, foreign-behavior, or non-pending marker
/// reads as absent — a corrupt journal never blocks a make and never widens
/// the adoption. The recorded pid is auditability only: no liveness probing
/// (pid reuse makes it unsound); read-before-overwrite is the only
/// discrimination the marker needs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'tdd_transaction.dart' show fsyncFile;

/// The schema version of the marker document. Bump on any shape change;
/// readers reject unknown schemas as absent (fail closed).
const int kMakeInterruptMarkerSchema = 1;

class MakeInterruptMarker {
  const MakeInterruptMarker({required this.featureDir});

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// The marker file: `<featureDir>/tdd/make-interrupt.json`.
  String get path => p.join(featureDir, 'tdd', 'make-interrupt.json');

  /// Record this make's in-flight state — write-ahead, fsync'd, atomic
  /// (tmp + rename) BEFORE any subject-mutating work. Any surviving record
  /// after the process dies marks the interrupted make for the next resume.
  Future<void> begin({required String behavior}) async {
    final map = <String, Object?>{
      'schema': kMakeInterruptMarkerSchema,
      'feature': p.basename(featureDir),
      'behavior': behavior,
      'pid': pid,
      'at': DateTime.now().toUtc().toIso8601String(),
      'status': 'in-progress',
    };
    final file = File(path);
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
    await fsyncFile(tmp);
    await tmp.rename(file.path);
  }

  /// The in-progress marker left by a PREVIOUS make of [behavior], or null
  /// when the marker is missing, unparseable, names another behavior, or is
  /// not in progress — every non-marker shape behaves exactly like absence
  /// (fail closed: never blocks, never adopts).
  Future<Map<String, dynamic>?> pendingFor(String behavior) async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['schema'] != kMakeInterruptMarkerSchema) return null;
      if (decoded['status'] != 'in-progress') return null;
      if (decoded['behavior'] is! String) return null;
      if (decoded['behavior'] != behavior) return null;
      return decoded;
    } on FormatException {
      return null;
    }
  }

  /// Consume the marker: remove it after a graceful make exit reached the
  /// disk. Idempotent and best-effort — a marker clear must never fail a
  /// make; a missing marker is already the committed state.
  Future<void> clear() async {
    final file = File(path);
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Best-effort by contract: a locked or vanished file must not fail
      // the make that already finished its work.
    }
  }

  /// The synchronous form of [clear] — the make command's summary funnel
  /// (`_printSummary`) is a sync method every terminal path prints through
  /// (FR-010 of spec 047-tdd-make), so the marker clear must be sync too.
  /// Same idempotent best-effort contract.
  void clearSync() {
    final file = File(path);
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Best-effort by contract: never fail the make for a clear.
    }
  }
}
