/// `CorpusBaselineCache` — the corpus-wide extension of the issue #741
/// run-baseline cache (spec 069-corpus-economics, issue #916):
/// ONE full-suite baseline snapshot shared by EVERY feature of the
/// corpus lane, instead of one capture per feature.
///
/// The cache lives at `.zfa/corpus/run-baseline.json` and wraps the
/// exact #741 payload (`command`, `exitCode`, `failedTests`,
/// `capturedAt`, `parseable`) plus the DEPENDENCY FINGERPRINT the
/// corpus-wide reuse hinges on:
///
/// - `dependency_fingerprint` — sha256 over `pubspec.yaml` +
///   `pubspec.lock` + `.dart_tool/package_config.json`: the inputs
///   that decide whether yesterday's green baseline still means
///   anything today. A dependency change (an added package, a version
///   bump, a changed source path) invalidates the cache: the reader
///   reports a MISS and the caller captures a fresh baseline — a stale
///   baseline can never let a compile-level break slide through as
///   "pre-existing".
/// - `suite_fingerprint` — sha256 of the suite command itself: a
///   changed `tdd-profile.md` suite template is a different suite.
///
/// Reading is fail-safe (the #741 house stance): a missing, corrupt,
/// malformed, or fingerprint-mismatched cache yields null and the
/// caller falls back to a LIVE baseline capture — never a silent
/// pass.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import 'suite_guard.dart';

/// The corpus-wide baseline cache (spec 069, extends #741).
class CorpusBaselineCache {
  const CorpusBaselineCache();

  /// The cache file name under `.zfa/corpus/`.
  static const fileName = 'run-baseline.json';

  /// The cache path for a project root.
  static String pathFor({required String projectRoot}) =>
      p.join(projectRoot, '.zfa', 'corpus', fileName);

  /// The dependency fingerprint of [projectRoot]: sha256 over
  /// `pubspec.yaml`, `pubspec.lock`, and
  /// `.dart_tool/package_config.json` (whichever exist), in that fixed
  /// order. A missing file hashes as absent — the fingerprint tracks
  /// what the project's resolution actually depends on, and adding a
  /// lock file IS a dependency change (the resolved set changed).
  static String dependencyFingerprint(String projectRoot) {
    final inputs = [
      p.join(projectRoot, 'pubspec.yaml'),
      p.join(projectRoot, 'pubspec.lock'),
      p.join(projectRoot, '.dart_tool', 'package_config.json'),
    ];
    final bytes = <int>[];
    for (final path in inputs) {
      final file = File(path);
      if (!file.existsSync()) {
        bytes.addAll(utf8.encode('absent:$path\n'));
        continue;
      }
      bytes.addAll(utf8.encode('sha256:$path:'));
      bytes.addAll(crypto.sha256.convert(file.readAsBytesSync()).bytes);
      bytes.addAll(utf8.encode('\n'));
    }
    return crypto.sha256.convert(bytes).toString();
  }

  /// Write the corpus-wide cache: the #741 snapshot payload plus the
  /// fingerprints the reuse decision checks. Returns the written path.
  Future<String> write({
    required String projectRoot,
    required SuiteSnapshot snapshot,
    required String suiteCommand,
  }) async {
    final file = File(pathFor(projectRoot: projectRoot));
    await file.parent.create(recursive: true);
    // Atomic temp+rename (the #828 house pattern).
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'command': snapshot.command,
        'exitCode': snapshot.exitCode,
        'failedTests': snapshot.failedTests.toList(),
        'capturedAt': snapshot.capturedAt,
        'parseable': snapshot.parseable,
        'dependency_fingerprint': dependencyFingerprint(projectRoot),
        'suite_fingerprint': _fingerprintText(suiteCommand),
      }),
    );
    await tmp.rename(file.path);
    return file.path;
  }

  /// Load the cached snapshot when it is USABLE for [projectRoot]:
  /// present, well-formed, parseable, and both fingerprints matching
  /// the project RIGHT NOW. Any miss (missing, corrupt, dependency
  /// change, suite change) yields null — the caller captures a live
  /// baseline (safe failure, never a silent pass).
  Future<SuiteSnapshot?> read({
    required String projectRoot,
    required String suiteCommand,
  }) async {
    final file = File(pathFor(projectRoot: projectRoot));
    if (!await file.exists()) return null;
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      json = decoded;
    } catch (_) {
      return null;
    }
    // The #741 payload contract.
    final command = json['command'];
    final exitCode = json['exitCode'];
    final failed = json['failedTests'];
    final capturedAt = json['capturedAt'];
    final parseable = json['parseable'];
    if (command is! String ||
        exitCode is! int ||
        failed is! List ||
        capturedAt is! String ||
        parseable is! bool ||
        !parseable) {
      return null;
    }
    // The corpus-wide reuse guards (spec 069 T004).
    final dependency = json['dependency_fingerprint'];
    if (dependency is! String ||
        dependency != dependencyFingerprint(projectRoot)) {
      return null;
    }
    final suite = json['suite_fingerprint'];
    if (suite is! String || suite != _fingerprintText(suiteCommand)) {
      return null;
    }
    return SuiteSnapshot(
      command: command,
      exitCode: exitCode,
      failedTests: failed.whereType<String>().toSet(),
      capturedAt: capturedAt,
      parseable: parseable,
    );
  }

  static String _fingerprintText(String command) =>
      crypto.sha256.convert(utf8.encode(command)).toString();
}
