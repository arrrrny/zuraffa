/// `CorpusProgressStore` — atomic persistence for the corpus-level
/// progress file `.zfa/corpus/progress.json` (spec 051-corpus-harness,
/// FR-001/FR-010): temp-file + rename saves, a load corruption gate, the
/// pid in-flight refusal (concurrent corpus runs), and dropped marks for
/// features removed from the manifest mid-stream.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/corpus_progress.dart';

class CorpusProgressStore {
  CorpusProgressStore(this.projectRoot, {bool Function(int pid)? pidAlive})
    : _pidAlive = pidAlive ?? _processIsAlive;

  /// The driven app's project root.
  final String projectRoot;

  /// Injectable pid-liveness probe (tests). Defaults to a signal-0 probe.
  final bool Function(int pid) _pidAlive;

  String get path => p.join(projectRoot, '.zfa', 'corpus', 'progress.json');

  /// Load the persisted progress, or `null` when no file exists.
  /// Corruption stops with [CorpusCorruptException] naming the file and
  /// the recovery path.
  Future<CorpusProgress?> load() async {
    final file = File(path);
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    try {
      return CorpusProgress.fromJson(jsonDecode(raw));
    } on FormatException catch (e) {
      throw CorpusCorruptException(
        'corrupted $path (${e.message}). Recovery: delete the file to '
        'restart the corpus from PENDING (per-feature loop state under '
        'specs/<feature>/tdd/ is unaffected), or repair it to valid '
        'corpus progress JSON.',
      );
    }
  }

  /// Atomically persist [progress] (temp + rename). When
  /// [manifestFeatureNames] is given, progress features absent from it
  /// are recorded under `dropped` (append-only audit trail).
  Future<void> save(
    CorpusProgress progress, {
    Set<String>? manifestFeatureNames,
  }) async {
    if (manifestFeatureNames != null) {
      progress.dropped = computeDropped(progress, manifestFeatureNames);
    }
    await Directory(p.dirname(path)).create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(progress.toJson()),
    );
    await tmp.rename(path);
  }

  /// The progress features absent from [manifestFeatureNames]: features
  /// removed from the manifest mid-stream, retained as dropped (U10).
  List<String> computeDropped(
    CorpusProgress progress,
    Set<String> manifestFeatureNames,
  ) {
    return progress.features.keys
        .where((name) => !manifestFeatureNames.contains(name))
        .where((name) => !progress.dropped.contains(name))
        .toList()
      ..addAll(progress.dropped)
      ..sort();
  }

  /// Non-null when a live foreign process holds the in-flight marker —
  /// the caller must refuse to start a second concurrent corpus run
  /// (FR-010).
  String? refusalReason(
    CorpusProgress? progress, {
    bool Function(int pid)? pidAlive,
  }) {
    final probe = pidAlive ?? _pidAlive;
    final feature = progress?.inFlight?.feature;
    if (feature == null) return null;
    final owner = progress!.inFlight!.ownerPid;
    // The owner is this process: no positive evidence of a concurrent
    // run — resumable.
    if (owner == pid) return null;
    if (!probe(owner)) return null;
    return 'a corpus run is already in flight for feature "$feature" '
        '(pid $owner); refusing to start a second concurrent run. The '
        'progress file was left untouched. If pid $owner is stale, wait '
        'for it to exit or delete $path to restart.';
  }

  static bool _processIsAlive(int pid) {
    try {
      final result = Process.runSync('kill', ['-0', pid.toString()]);
      return result.exitCode == 0;
    } on Object {
      return true;
    }
  }
}
