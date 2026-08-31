/// Corpus progress store (spec 051-corpus-harness, FR-001/FR-010).
///
/// Atomic persistence for `.zfa/corpus/progress.json` — mirrors the
/// RunStateStore pattern.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/corpus_feature_progress.dart';

class CorpusProgressCorruptException implements Exception {
  const CorpusProgressCorruptException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CorpusProgressStore {
  CorpusProgressStore(this.projectRoot, {bool Function(int pid)? pidAlive})
      : _pidAlive = pidAlive ?? _processIsAlive;

  final String projectRoot;
  final bool Function(int pid) _pidAlive;

  String get _path =>
      p.join(projectRoot, '.zfa', 'corpus', 'progress.json');

  /// Load progress, or null if absent.
  Future<CorpusProgress?> load() async {
    final file = File(_path);
    if (!await file.exists()) return null;
    String raw;
    try {
      raw = await file.readAsString();
    } on FileSystemException catch (e) {
      throw CorpusProgressCorruptException(
        'cannot read $_path: ${e.message}. Recovery: delete the file to '
        'restart from PENDING, or repair it to valid JSON.',
      );
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return CorpusProgress.fromJson(decoded);
    } on FormatException catch (e) {
      throw CorpusProgressCorruptException(
        'invalid JSON in $_path: ${e.message}. Recovery: delete the file.',
      );
    }
  }

  /// Save progress atomically via temp+rename.
  Future<void> save(CorpusProgress progress) async {
    await Directory(p.dirname(_path)).create(recursive: true);
    final tmp = File('$_path.tmp');
    await tmp.writeAsString(progress.toJsonString());
    await tmp.rename(_path);
  }

  /// Non-null when a live foreign process holds the in-flight marker.
  String? refusalReason(CorpusProgress? progress) {
    if (progress == null || !progress.inFlight) return null;
    final owner = progress.ownerPid;
    if (owner == null || owner == pid) return null;
    if (!_pidAlive(owner)) return null;
    return 'a corpus run is already in flight (pid $owner); refusing to '
        'start a second concurrent run. If pid $owner is stale, wait '
        'for it to exit or delete $_path to restart.';
  }

  /// Compute the resume point: first feature not in done/not-ready/dropped.
  String? resumePoint(
    List<String> manifestFeatures,
    Map<String, CorpusFeatureProgress> features,
  ) {
    for (final name in manifestFeatures) {
      final progress = features[name];
      if (progress == null) return name; // not yet started
      switch (progress.state) {
        case CorpusFeatureState.done:
        case CorpusFeatureState.notReady:
        case CorpusFeatureState.dropped:
          continue;
        default:
          return name;
      }
    }
    return null; // all done
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
