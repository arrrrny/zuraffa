/// HostBaseline (feature 074, issue #962): the pre-merge safety net —
/// a content-addressed byte snapshot of every host file the merge will
/// touch, restorable byte-identically, plus the suite baseline diff
/// (pre-existing reds are never blamed; new reds always are).
///
/// Pure and synchronous: bytes in, bytes back. No git dependence —
/// rollback is a file copy verified by re-hashing.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// One snapshotted host file: relative path + exact bytes + hash.
class BaselineEntry {
  final String relativePath;
  final List<int> bytes;
  final String hash;

  const BaselineEntry(this.relativePath, this.bytes, this.hash);
}

/// The pre-merge snapshot of the host tree subset.
class HostSnapshot {
  final List<BaselineEntry> entries;

  const HostSnapshot(this.entries);

  /// True when the host tree still matches the snapshot (used after a
  /// rollback to prove the restore was byte-identical).
  bool matchesHost(String projectRoot) =>
      restore(projectRoot).isEmpty;

  /// Restores every snapshotted file into [projectRoot]; returns the
  /// relative paths that were restored. Files that did not exist at
  /// capture time are DELETED (merge-created files do not survive a
  /// rollback).
  List<String> restore(String projectRoot) {
    final restored = <String>[];
    for (final entry in entries) {
      final target = File(p.join(projectRoot, entry.relativePath));
      if (entry.hash.isEmpty) {
        if (target.existsSync()) {
          target.deleteSync();
          restored.add(entry.relativePath);
        }
        continue;
      }
      final currentExists = target.existsSync();
      final currentHash = currentExists
          ? sha256.convert(target.readAsBytesSync()).toString()
          : null;
      if (currentHash != entry.hash) {
        target.parent.createSync(recursive: true);
        target.writeAsBytesSync(entry.bytes);
        restored.add(entry.relativePath);
      }
    }
    return restored..sort();
  }
}

/// Captures and diffs host baselines.
abstract final class HostBaseline {
  /// Snapshot the given host files (relative paths; missing files are
  /// recorded as absent so a rollback can delete what merge created).
  static HostSnapshot capture({
    required String projectRoot,
    required List<String> relativePaths,
  }) {
    final entries = <BaselineEntry>[];
    final sorted = List<String>.from(relativePaths)..sort();
    for (final rel in sorted) {
      final file = File(p.join(projectRoot, rel));
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        entries.add(
          BaselineEntry(rel, bytes, sha256.convert(bytes).toString()),
        );
      } else {
        entries.add(BaselineEntry(rel, const [], ''));
      }
    }
    return HostSnapshot(entries);
  }

  /// A fingerprint of a whole directory's file contents — the cheap
  /// "did anything drift" check used by the rollback proof.
  static String fingerprint(String projectRoot, {String? subPath}) {
    final root = subPath == null
        ? Directory(projectRoot)
        : Directory(p.join(projectRoot, subPath));
    if (!root.existsSync()) return '';
    final files =
        root
            .listSync(recursive: true)
            .whereType<File>()
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return sha256.convert([
      for (final file in files) ...[
        ...file.path.codeUnits,
        ..._safeBytes(file),
      ],
    ]).toString();
  }

  static List<int> _safeBytes(File file) {
    try {
      return file.readAsBytesSync();
    } on FileSystemException {
      return const [];
    }
  }

  /// The suite-baseline diff: given the pre-merge failure set and the
  /// post-merge failure set, returns ONLY the new failures — a merge
  /// is never blamed for reds the host already had.
  static List<String> newFailures({
    required List<String> baseline,
    required List<String> current,
  }) {
    final prior = baseline.toSet();
    return current.where((f) => !prior.contains(f)).toList()..sort();
  }
}
