/// `CorpusBaselineCache` — the corpus-wide extension of the #741
/// baseline cache machinery (spec 069-corpus-economics, T004).
///
/// Issue #741 made the run driver cache the full-suite baseline ONCE
/// per `zfa tdd run`; but in the corpus lane every feature is a
/// separate driver spawn, so the suite was still re-captured once per
/// FEATURE. This cache lifts the snapshot ONE level up — the project
/// root (`.zfa/corpus/run-baseline.json`) — keyed by a DEPENDENCY
/// FINGERPRINT (sha256 over pubspec.yaml + pubspec.lock + the profile's
/// suite template):
///
/// - a fingerprint MATCH reuses the snapshot across features: the
///   driver materializes the feature-local
///   `specs/<f>/tdd/run-baseline.json` from the corpus cache and the
///   suite never re-runs (#741's make contract is unchanged — the
///   guard still comes from the scoped single-test run, so reuse
///   cannot hide a new failure);
/// - invalidation is correct, never stale: a dependency change flips
///   the fingerprint, the read misses, and the live suite re-runs
///   (issue #916's "correct invalidation on dependency changes");
/// - reading is fail-safe: a missing, corrupt, or mismatched file
///   yields null and the caller falls back to the live suite (the
///   #741 safe-failure stance, one level up — never a silent pass).
///
/// A project with neither pubspec.yaml nor pubspec.lock has NO
/// fingerprint (null) — no corpus reuse, always the honest live
/// baseline.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import 'suite_guard.dart';

class CorpusBaselineCache {
  const CorpusBaselineCache();

  /// The cache file name under the project's `.zfa/corpus/` directory.
  static const fileName = 'run-baseline.json';

  /// The cache path for a project root.
  static String pathFor({required String projectRoot}) =>
      p.join(projectRoot, '.zfa', 'corpus', fileName);

  /// The dependency fingerprint of the project: sha256 over
  /// pubspec.yaml + pubspec.lock + the suite template. Returns null
  /// when the project has neither pubspec file (nothing to key on).
  Future<String?> dependencyFingerprint(String projectRoot) async {
    final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
    final lock = File(p.join(projectRoot, 'pubspec.lock'));
    final hasPubspec = await pubspec.exists();
    final hasLock = await lock.exists();
    if (!hasPubspec && !hasLock) return null;
    final builder = BytesBuilder();
    if (hasPubspec) builder.add(await pubspec.readAsBytes());
    if (hasLock) builder.add(await lock.readAsBytes());
    // The suite COMMAND is part of the fingerprint: a changed runner
    // (a different suite template) changes what the snapshot means.
    final suiteTemplate = await _suiteTemplateFor(projectRoot);
    if (suiteTemplate != null) builder.add(utf8.encode(suiteTemplate));
    return crypto.sha256.convert(builder.toBytes()).toString();
  }

  /// Persist [snapshot] with [fingerprint] at the project level.
  Future<String> write({
    required String projectRoot,
    required SuiteSnapshot snapshot,
    required String fingerprint,
  }) async {
    final file = File(pathFor(projectRoot: projectRoot));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'command': snapshot.command,
        'exitCode': snapshot.exitCode,
        'failedTests': snapshot.failedTests.toList(),
        'capturedAt': snapshot.capturedAt,
        'parseable': snapshot.parseable,
        'dependency_fingerprint': fingerprint,
      }),
    );
    return file.path;
  }

  /// Load the corpus cache when the fingerprint MATCHES [fingerprint].
  /// Returns null when the file is missing, unreadable, corrupt, typed
  /// wrong, or keyed to a different fingerprint — the caller falls
  /// back to the live suite (safe failure, issue #741's stance).
  Future<SuiteSnapshot?> read({
    required String projectRoot,
    required String fingerprint,
  }) async {
    try {
      final raw = await File(pathFor(projectRoot: projectRoot)).readAsString();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final recorded = json['dependency_fingerprint'];
      if (recorded is! String || recorded != fingerprint) return null;
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

  /// The suite template from the project's TDD profile (null when the
  /// profile or the key is absent — the driver misfire-stops on that
  /// before reaching the cache anyway).
  Future<String?> _suiteTemplateFor(String projectRoot) async {
    try {
      final profile = File(
        p.join(projectRoot, '.specify', 'memory', 'tdd-profile.md'),
      );
      if (!await profile.exists()) return null;
      final raw = await profile.readAsString();
      final keysBlock = RegExp(
        r'##\s*Keys \(machine-readable\)\s*\n+```ya?ml\n(.*?)```',
        dotAll: true,
      ).firstMatch(raw);
      if (keysBlock == null) return null;
      final m = RegExp(
        r'''^\s*suite:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))\s*$''',
        multiLine: true,
      ).firstMatch(keysBlock.group(1)!);
      if (m == null) return null;
      for (var i = 1; i <= m.groupCount; i++) {
        final g = m.group(i);
        if (g != null && g.isNotEmpty) return g;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
