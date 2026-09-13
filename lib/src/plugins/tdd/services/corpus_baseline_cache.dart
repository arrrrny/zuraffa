/// `CorpusBaselineCache` — the corpus-wide extension of the #741
/// baseline cache machinery (spec 069-corpus-economics, T004).
///
/// Issue #741 made the run driver cache the full-suite baseline ONCE
/// per `zfa tdd run`; but in the corpus lane every feature is a
/// separate driver spawn, so the suite was still re-captured once per
/// FEATURE. This cache lifts the snapshot ONE level up — the project
/// root (`.zfa/corpus/run-baseline.json`) — keyed by a DEPENDENCY
/// FINGERPRINT (sha256 over pubspec.yaml + pubspec.lock + the profile's
/// suite template + the `test/` and `lib/` tree contents + the run-
/// stable `.zfa/` memory/manifest state — issue #1505):
///
/// - a fingerprint MATCH reuses the snapshot across features: the
///   driver materializes the feature-local
///   `specs/<f>/tdd/run-baseline.json` from the corpus cache and the
///   suite never re-runs (#741's make contract is unchanged — the
///   guard still comes from the scoped single-test run, so reuse
///   cannot hide a new failure);
/// - invalidation is correct, never stale: a dependency change, a
///   test-file fix, a lib/ source edit, or a declared-state change
///   flips the fingerprint, the read misses, and the live suite re-runs
///   (issue #916's "correct invalidation on dependency changes"; issue
///   #1505's "invalidate when anything that can change test outcomes
///   changes");
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

import '../../../core/project/project_paths.dart';

import 'suite_guard.dart';

class CorpusBaselineCache {
  const CorpusBaselineCache();

  /// The cache file name under the project's `.zfa/corpus/` directory.
  static const fileName = 'run-baseline.json';

  /// The cache path for a project root.
  static String pathFor({required String projectRoot}) =>
      p.join(projectRoot, '.zfa', 'corpus', fileName);

  /// The dependency fingerprint of the project: sha256 over
  /// pubspec.yaml + pubspec.lock + the suite template + the CONTENT of
  /// the `test/` and `lib/` trees + the run-stable `.zfa/` memory/
  /// manifest state (`.zfa/manifests/**`, `.zfa/context.json`,
  /// `.zfa/AGENT_CONTRACT.md` — issue #1505). Returns null when the
  /// project has neither pubspec file (nothing to key on).
  ///
  /// Everything that can change test outcomes is keyed: a test-file fix
  /// or a lib/ source edit invalidates the cached baseline exactly like
  /// a dependency change. Everything a NORMAL RUN mutates
  /// (`.zfa/corpus/**`, `.zfa/runs/**`, `.zfa/receipts/**`,
  /// `.zfa/plans/**`, `.zfa/blueprints/**`, `.zfa/decisions/**`,
  /// `.zfa/provenance/**`, mtimes) is deliberately NOT keyed: keying it
  /// would force a suite re-run after every feature and destroy the
  /// spec 069 corpus economics. Content is hashed, never metadata — a
  /// pure mtime touch keeps the fingerprint stable.
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
    // Issue #1505: the test and lib trees ARE the suite's inputs — a
    // fix to the files that produced the baseline's failures must
    // invalidate it, exactly like a dependency change does.
    await _addTreeDigest(
      builder,
      Directory(p.join(projectRoot, 'test')),
      label: 'test',
    );
    await _addTreeDigest(
      builder,
      Directory(p.join(projectRoot, 'lib')),
      label: 'lib',
    );
    await _addZfaStateDigest(builder, projectRoot);
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

  /// Contribute a deterministic CONTENT digest of [dir]'s regular files
  /// to [builder] (issue #1505). Sorted project-relative POSIX paths +
  /// length-prefixed per-file `sha256(content)` make the digest
  /// filesystem-order- and platform-independent while bounding peak
  /// memory to the largest single file instead of the whole tree: the
  /// tree payload is never accumulated (review F4 — a large binary
  /// fixture can no longer grow the buffer without bound). Only CONTENT
  /// is hashed — a pure mtime touch never flips the digest. Symlinks are
  /// skipped (no cycles, no platform drift). An unreadable file
  /// contributes its path with an `unreadable` marker instead of failing
  /// the whole fingerprint (the #741 fail-safe stance: the worst case is
  /// a rare extra miss, never a crash and never a wrong hit).
  ///
  /// An ABSENT directory and an EMPTY one hash identically: neither
  /// carries content. That matters because a tool can materialise an
  /// empty directory mid-lane — `ProjectContextStore.save()` creates the
  /// empty `.zfa/manifests/` at the tail of every `zfa make` — and a
  /// present-but-empty marker would flip the key for zero content change
  /// (review F1/F3; the same absent≡empty reasoning the `.zfa` state
  /// digest already applies one level up). A real content change — a
  /// file added, edited, or deleted — still flips it.
  Future<void> _addTreeDigest(
    BytesBuilder builder,
    Directory dir, {
    required String label,
  }) async {
    builder.add(utf8.encode('\x00tree:$label'));
    if (!await dir.exists()) {
      builder.add(utf8.encode(':absent\n'));
      return;
    }
    final entries = <({String relPath, File file})>[];
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        entries.add((
          relPath: p
              .relative(entity.path, from: dir.path)
              .replaceAll(r'\', '/'),
          file: entity,
        ));
      }
    } catch (_) {
      builder.add(utf8.encode(':unreadable-dir\n'));
      return;
    }
    if (entries.isEmpty) {
      // An empty directory is an absent one: zero content either way.
      builder.add(utf8.encode(':absent\n'));
      return;
    }
    entries.sort((a, b) => a.relPath.compareTo(b.relPath));
    for (final entry in entries) {
      builder.add(utf8.encode('${entry.relPath}\n'));
      try {
        final bytes = await entry.file.readAsBytes();
        builder.add(_lengthPrefix(bytes.length));
        // Digest the file into the hash instead of buffering it whole:
        // still content-based and mtime-blind, but the tree payload
        // never accumulates (review F4).
        builder.add(crypto.sha256.convert(bytes).bytes);
      } catch (_) {
        builder.add(utf8.encode('unreadable\n'));
      }
    }
  }

  /// Contribute the run-STABLE `.zfa/` memory/manifest state to [builder]
  /// (issue #1505's declared-state invalidation). This is a closed
  /// allow-list — `.zfa/manifests/**` (read-only harness inputs) plus the
  /// agent memory/contract files — and deliberately NOT a blanket
  /// `.zfa/**` walk: `.zfa/corpus/**` (progress, run lock, and this cache
  /// file itself), `.zfa/runs/**`, `.zfa/receipts/**`, `.zfa/plans/**`,
  /// `.zfa/blueprints/**`, `.zfa/decisions/**`, and `.zfa/provenance/**`
  /// are mutated by every normal run; keying them would flip the
  /// fingerprint between features and force a live suite re-run each
  /// time, destroying the spec 069 economics (SC-3).
  ///
  /// The `.zfa/` layout comes from [ProjectPaths] rather than being
  /// re-derived here (review F5): one source of truth for the directory
  /// shape. Note `.zfa/AGENT_CONTRACT.md` has no writer anywhere in the
  /// repo today (only the [ProjectPaths] declaration and a spec-007
  /// aspiration) — keying it is inert but forward-looking, and a real
  /// change to it still invalidates.
  Future<void> _addZfaStateDigest(
    BytesBuilder builder,
    String projectRoot,
  ) async {
    builder.add(utf8.encode('\x00zfa-state'));
    // NOTE: there is deliberately NO `.zfa`-directory existence marker
    // here, and none on the sub-digests either. The cache write itself
    // creates `.zfa/corpus/`, and `ProjectContextStore.save()` creates an
    // empty `.zfa/manifests/` plus `.zfa/context.json` at the tail of
    // every `zfa make` — absent→present transitions between the very
    // features the cache must serve, while carrying ZERO declared-state
    // change. Absent and empty therefore hash the same (review F1); the
    // state IS the sub-digests' real content.
    final paths = ProjectPaths(projectRoot);
    await _addTreeDigest(
      builder,
      Directory(paths.manifestsDirectory),
      label: 'manifests',
    );
    await _addLooseFile(
      builder,
      File(paths.contextFilePath),
      label: 'context.json',
    );
    await _addLooseFile(
      builder,
      File(paths.agentContractFilePath),
      label: 'AGENT_CONTRACT.md',
    );
  }

  /// Contribute a single run-stable file to [builder]: length-prefixed
  /// content when it carries any, NOTHING when it is absent or empty, or
  /// an `unreadable` marker on a read failure (fail-safe, never fatal).
  ///
  /// Absent ≡ empty here for the same reason as in [_addTreeDigest]: a
  /// tool-written file (`.zfa/context.json`) that appears empty mid-lane
  /// carries no state change and must not flip the key (review F1).
  Future<void> _addLooseFile(
    BytesBuilder builder,
    File file, {
    required String label,
  }) async {
    if (!await file.exists()) return;
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      builder.add(utf8.encode('\x00file:$label\nunreadable\n'));
      return;
    }
    if (bytes.isEmpty) return;
    builder.add(utf8.encode('\x00file:$label\n'));
    builder.add(_lengthPrefix(bytes.length));
    builder.add(bytes);
  }

  /// An 8-byte big-endian content length: it removes any
  /// path/content-boundary ambiguity between concatenated entries.
  /// Byte-wise (not ByteData.setUint64) so the code stays compilable on
  /// web targets where 64-bit accessors are unsupported.
  Uint8List _lengthPrefix(int length) {
    final out = Uint8List(8);
    out[0] = (length >> 56) & 0xff;
    out[1] = (length >> 48) & 0xff;
    out[2] = (length >> 40) & 0xff;
    out[3] = (length >> 32) & 0xff;
    out[4] = (length >> 24) & 0xff;
    out[5] = (length >> 16) & 0xff;
    out[6] = (length >> 8) & 0xff;
    out[7] = length & 0xff;
    return out;
  }
}
