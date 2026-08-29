/// SourceRestorer — captures the sha256 of every in-scope subject BEFORE
/// the mutation audit, and restores every temporarily mutated subject
/// AFTER the audit (success, failure, timeout, or interrupt). Restoration
/// is verified by sha256 comparison before the command returns
/// (spec 044-test-tdd-generation, FR-021).
///
/// The restorer NEVER touches test files (FR-022: the audit never edits
/// a test to fake a pass). The restorer's scope is exactly the subject
/// paths from the registry.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';

/// The result of a [SourceRestorer.restoreAndVerify] call.
class RestorationResult {
  RestorationResult({
    required this.restorationVerified,
    required this.restorationFailed,
    this.failedPaths = const [],
  });

  /// True iff every captured subject's post-audit sha256 matches its
  /// pre-audit sha256 (after restoration).
  final bool restorationVerified;

  /// True iff restoration failed (e.g. a file was deleted by the audit
  /// and we couldn't restore it from the captured hash alone).
  final bool restorationFailed;

  /// Paths that failed restoration (empty when [restorationFailed] is false).
  final List<String> failedPaths;
}

/// Captures and restores subjects for a mutation audit.
class SourceRestorer {
  SourceRestorer({required this.paths});

  /// Paths to capture (subject files only; never test files — FR-022).
  final List<String> paths;

  /// Map of path -> pre-audit bytes (for restoration).
  final Map<String, List<int>> _preAuditBytes = {};

  /// Map of path -> pre-audit sha256 hex string.
  final Map<String, String> _preAuditHashes = {};

  /// True after [capture] has been called.
  bool _captured = false;

  /// The list of paths that have been captured.
  List<String> get capturedPaths => _preAuditBytes.keys.toList();

  /// The pre-audit sha256 hex string for a path, or null if not captured.
  String? hashOf(String path) => _preAuditHashes[path];

  /// True iff the current file's sha256 matches the captured one.
  bool hashMatches(String path) {
    final captured = _preAuditHashes[path];
    if (captured == null) return false;
    final file = File(path);
    if (!file.existsSync()) return false;
    final bytes = file.readAsBytesSync();
    final currentHash = sha256.convert(bytes).toString();
    return currentHash == captured;
  }

  /// Capture the pre-audit bytes + sha256 of every in-scope subject.
  Future<void> capture() async {
    _preAuditBytes.clear();
    _preAuditHashes.clear();
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) {
        // The subject doesn't exist pre-audit; nothing to capture (the
        // audit can mutate it to create it, but restoration can only
        // delete it).
        continue;
      }
      final bytes = await file.readAsBytes();
      _preAuditBytes[path] = bytes;
      _preAuditHashes[path] = sha256.convert(bytes).toString();
    }
    _captured = true;
  }

  /// Restore every captured subject and verify sha256 matches.
  ///
  /// This is safe to call after the audit regardless of whether the audit
  /// ended in success, failure, timeout, or interrupt — it restores every
  /// captured file to its pre-audit bytes and verifies the post-restore
  /// sha256 matches the pre-audit one.
  Future<RestorationResult> restoreAndVerify() async {
    if (!_captured) {
      return RestorationResult(
        restorationVerified: false,
        restorationFailed: true,
        failedPaths: const ['<not captured>'],
      );
    }
    final failedPaths = <String>[];
    for (final entry in _preAuditBytes.entries) {
      final path = entry.key;
      final bytes = entry.value;
      final file = File(path);
      try {
        await file.writeAsBytes(bytes);
      } catch (_) {
        failedPaths.add(path);
        continue;
      }
      // Verify sha256.
      final currentBytes = await file.readAsBytes();
      final currentHash = sha256.convert(currentBytes).toString();
      if (currentHash != _preAuditHashes[path]) {
        failedPaths.add(path);
      }
    }
    return RestorationResult(
      restorationVerified: failedPaths.isEmpty,
      restorationFailed: failedPaths.isNotEmpty,
      failedPaths: failedPaths,
    );
  }
}
