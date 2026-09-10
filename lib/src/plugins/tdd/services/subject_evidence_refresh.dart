/// Issue #1430 — the refactor pass's certified-subject evidence refresh.
///
/// The fixed pass registry (`zfa build` → `dart format lib/` →
/// `dart fix --apply lib/`) rewrites files under `lib/`, including
/// certified subjects — and a certified green evidence entry stamps the
/// subject's sha256 at certification time, so a sanctioned rewrite strands
/// the evidence: the next make's #1036 guard compares the stale certified
/// hash against the reformatted file and refuses `subject-drift
/// (stale-artifacts)` — the loop dead-ends on the very state it
/// manufactured (the issue's "cannot resume through the loop").
///
/// The reconciliation mirrors `RefactorReceiptRefresh` (#1311, the same
/// pass-rewrites-certified-state class): the pass's re-proof already
/// proved the suite green over the new shapes, so appending a `refresh`
/// cycle-log entry per touched certified behavior re-binds the certified
/// shape to the post-rewrite subject without re-running make's pipeline.
/// A refresh entry is deliberately NOT `green` (the #1329 precedent):
/// certification contracts key on red+green and must never observe it.
/// The make guard consults the behavior's LAST refresh entry before
/// refusing — hash match against the CURRENT subject plus ISO-8601
/// freshness over the certified basis, failing closed — so an out-of-band
/// post-certification edit still refuses exactly as before.
library;

import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../models/artifact_record.dart';
import '../models/cycle_entry.dart';
import '../services/cycle_evidence.dart';
import '../services/cycle_log.dart';

/// One certified subject the pass rewrote whose green evidence no longer
/// matches disk — a candidate a GREEN re-proof may reconcile.
class SubjectRefreshCandidate {
  final String behaviorId;

  /// Absolute path of the subject file.
  final String subjectPath;

  /// The sha256 the certified green evidence recorded.
  final String certifiedHash;

  /// The post-rewrite sha256 (what the refreshed evidence will carry).
  final String currentHash;

  /// The record's criterion, carried onto the refresh entry.
  final String sourceCriterion;

  const SubjectRefreshCandidate({
    required this.behaviorId,
    required this.subjectPath,
    required this.certifiedHash,
    required this.currentHash,
    required this.sourceCriterion,
  });
}

class SubjectEvidenceRefresh {
  /// The certified subjects among [changedPaths] whose green evidence no
  /// longer matches disk. Only CERTIFIED subjects qualify (a pending or
  /// red-only behavior's subject has nothing to reconcile — the next
  /// certify stamps the then-current hash naturally), and only when the
  /// recorded hash genuinely differs (equal → nothing to reconcile).
  static Future<List<SubjectRefreshCandidate>> candidates({
    required String projectRoot,
    required String featureName,
    required Iterable<String> changedPaths,
    required List<ArtifactRecord> artifacts,
  }) async {
    if (changedPaths.isEmpty) return const [];
    final changed = changedPaths
        .map((path) => _absolute(projectRoot, path))
        .toSet();
    final evidence = CycleEvidence(p.join(projectRoot, 'specs', featureName));
    final candidates = <SubjectRefreshCandidate>[];
    for (final record in artifacts) {
      final subjectPath = _absolute(projectRoot, record.subjectPath);
      if (!changed.contains(subjectPath)) continue;
      // Only certified green evidence reconciles — the #1036 guard's
      // authoritative basis (green first, then red) is what the rewrite
      // strands.
      final green = await evidence.lastEntryFor(
        record.behaviorId,
        kind: 'green',
      );
      final certifiedHash = green?.subjectHash;
      if (certifiedHash == null) continue;
      final file = File(subjectPath);
      if (!await file.exists()) continue;
      final currentHash = crypto.sha256
          .convert(await file.readAsBytes())
          .toString();
      if (currentHash == certifiedHash) continue;
      candidates.add(
        SubjectRefreshCandidate(
          behaviorId: record.behaviorId,
          subjectPath: subjectPath,
          certifiedHash: certifiedHash,
          currentHash: currentHash,
          sourceCriterion: record.sourceCriterion,
        ),
      );
    }
    return candidates;
  }

  /// Append one `refresh` cycle-log entry per candidate. The caller gates
  /// on a GREEN re-proof whose scope covered every candidate's test (the
  /// scoped covering-test mapping sends each changed registered subject to
  /// its own paired test; every other green path is the full suite) — a
  /// failed re-proof must never reach here. Each entry's hash is
  /// re-derived from disk at append time so the evidence is
  /// self-consistent by construction; a candidate whose subject vanished
  /// or whose hash no longer differs from the certified one is skipped.
  /// Returns the appended count.
  static Future<int> reconcile({
    required String projectRoot,
    required String featureName,
    required List<SubjectRefreshCandidate> candidates,
    required String reproofCommand,
    required int reproofExit,
  }) async {
    final log = CycleLog(p.join(projectRoot, 'specs', featureName));
    var appended = 0;
    for (final candidate in candidates) {
      final file = File(candidate.subjectPath);
      if (!await file.exists()) continue;
      final currentHash = crypto.sha256
          .convert(await file.readAsBytes())
          .toString();
      if (currentHash == candidate.certifiedHash) continue;
      await log.append(
        CycleLogEntry(
          behaviorId: candidate.behaviorId,
          kind: CycleEntryKind.refresh,
          runnerCommand: reproofCommand,
          exitCode: reproofExit,
          capturedOutput:
              'refresh (issue #1430): the pass rewrote '
              '${candidate.subjectPath} (hash '
              '${candidate.certifiedHash.substring(0, 8)}… → '
              '${currentHash.substring(0, 8)}…); the re-proof '
              'above proved the suite green over the new shape — the '
              'certified evidence re-binds to it.',
          sourceCriterion: candidate.sourceCriterion,
          testPath: 'test/',
          timestamp: DateTime.now().toUtc().toIso8601String(),
          subjectHash: currentHash,
        ),
      );
      appended++;
    }
    return appended;
  }

  static String _absolute(String projectRoot, String path) =>
      p.normalize(p.isAbsolute(path) ? path : p.join(projectRoot, path));
}
