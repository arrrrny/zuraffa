/// `CompositionTargets` — resolves the feature's composable green unit
/// subjects for the acceptance composition surface (spec
/// 052-acceptance-make-composition; issue #642; FR-003, FR-007).
///
/// A **composable anchor** is a unit-kind row in the feature's
/// `tdd/test-list.md` (the shared `TestListReader` contract — the kind
/// source of truth) whose behavior id carries green evidence in
/// `tdd/cycle-log.md` and whose registry `subject_path` artifact exists on
/// disk. Green cycle-log evidence is the source of truth for
/// "already-green" — the same evidence the run driver's reconciliation
/// consumes — so discovery stays independent of `tdd/run-state.json` (the
/// driver owns run state; the make pipeline owns the cycle log).
///
/// Discovery is the ONLY new filesystem-reading surface the composition
/// feature adds. It is fail-closed: every anomaly (no/ malformed test
/// list, non-acceptance target, missing anchor record or file, zero
/// anchors) yields a typed [CompositionTargetFailure] — never a partial
/// anchor set, never a silent skip — so the make fallback and the compose
/// command can refuse honestly instead of composing against a lie.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';
import 'artifact_registry.dart';
import 'cycle_evidence.dart';
import 'test_list_reader.dart';

/// One anchor a composition may wire against: a green unit subject.
class ComposableUnitSubject {
  final String behaviorId;

  /// The subject artifact's absolute path (normalized against the project
  /// root the discovery was run with).
  final String subjectPath;

  /// The subject function the anchor's behavior targets — the symbol gen
  /// emitted in the subject file (the test-list row's target, defaulting
  /// to `subject_<snake-id>`).
  final String symbol;

  const ComposableUnitSubject({
    required this.behaviorId,
    required this.subjectPath,
    required this.symbol,
  });

  @override
  String toString() =>
      'ComposableUnitSubject($behaviorId: $subjectPath#$symbol)';
}

/// The result of a discovery run: either resolved anchors or a typed,
/// fail-closed failure — never both, never a partial set.
sealed class CompositionTargetResult {
  const CompositionTargetResult();
}

class CompositionTargetResolved extends CompositionTargetResult {
  final List<ComposableUnitSubject> anchors;

  const CompositionTargetResolved(this.anchors);
}

class CompositionTargetFailure extends CompositionTargetResult {
  /// Machine token: `no-green-units`, `missing-anchor-subject`,
  /// `target-not-acceptance`, `no-test-list`, `malformed-test-list`.
  final String code;

  /// Human-readable message naming the artifact / file at fault.
  final String message;

  const CompositionTargetFailure({required this.code, required this.message});

  @override
  String toString() => '$code: $message';
}

class CompositionTargets {
  const CompositionTargets();

  /// Discover the composable anchors for composing [behaviorId]'s subject
  /// in [featureDir] (a `specs/<feature>` path under [projectRoot]).
  Future<CompositionTargetResult> discover({
    required String projectRoot,
    required String featureDir,
    required String behaviorId,
  }) async {
    // 1. The feature's test list — the kind source of truth. A missing or
    //    malformed list fails closed (the fallback must not guess kinds).
    List<BehaviorRow> rows;
    try {
      rows = await TestListReader(featureDir).read();
    } on TestListReadException catch (e) {
      final missing = e.message.contains('no test list at');
      return CompositionTargetFailure(
        code: missing ? 'no-test-list' : 'malformed-test-list',
        message: e.message,
      );
    }

    // 2. Kind gate: composition is the acceptance-subject surface only
    //    (spec Out of Scope). A unit-kind or unknown target fails closed.
    BehaviorRow? targetRow;
    for (final row in rows) {
      if (row.id == behaviorId) {
        targetRow = row;
        break;
      }
    }
    if (targetRow == null) {
      return CompositionTargetFailure(
        code: 'target-not-acceptance',
        message:
            'behavior "$behaviorId" has no row in '
            '${p.join(featureDir, 'tdd', 'test-list.md')}: compose composes '
            'acceptance subjects only (spec 052).',
      );
    }
    if (targetRow.kind != BehaviorKind.acceptance) {
      return CompositionTargetFailure(
        code: 'target-not-acceptance',
        message:
            'behavior "$behaviorId" is unit-kind: compose composes '
            'acceptance subjects against the feature\'s green unit subjects, '
            'and a unit subject implements its own logic (spec 052 Out of '
            'Scope).',
      );
    }

    // 3. Green evidence + the registry's subject artifacts.
    final green = await CycleEvidence(featureDir).greenEvidence();
    final records = await ArtifactRegistry(featureDir: featureDir).loadAll();
    final subjectPathById = {
      for (final record in records) record.behaviorId: record.subjectPath,
    };

    // 4. Anchors in test-list order: every green unit row must resolve to
    //    an existing subject artifact — a partial anchor set is a misfire,
    //    never a silent skip (US2.AC4).
    final anchors = <ComposableUnitSubject>[];
    for (final row in rows) {
      if (row.kind != BehaviorKind.unit) continue;
      if (row.id == behaviorId) continue; // never anchor against itself
      if (!green.contains(row.id)) continue;
      final recorded = subjectPathById[row.id];
      if (recorded == null) {
        return CompositionTargetFailure(
          code: 'missing-anchor-subject',
          message:
              'green unit subject "${row.id}" has no registry record with a '
              'subject_path in ${p.join(featureDir, 'tdd', 'artifacts.json')}. '
              'Run `zfa tdd gen ${row.id}` to restore its artifacts.',
        );
      }
      final normalized = p.normalize(
        p.isAbsolute(recorded) ? recorded : p.join(projectRoot, recorded),
      );
      if (!File(normalized).existsSync()) {
        return CompositionTargetFailure(
          code: 'missing-anchor-subject',
          message:
              'green unit subject "${row.id}" has no subject artifact on '
              'disk at "$recorded". Run `zfa tdd gen ${row.id}` to restore '
              'its artifacts.',
        );
      }
      anchors.add(
        ComposableUnitSubject(
          behaviorId: row.id,
          subjectPath: normalized,
          symbol: row.target,
        ),
      );
    }

    if (anchors.isEmpty) {
      return CompositionTargetFailure(
        code: 'no-green-units',
        message:
            'no green unit subjects to compose against: behavior '
            '"$behaviorId" needs at least one unit-kind behavior with green '
            'cycle-log evidence and an existing subject artifact (the units '
            'must go green before an acceptance subject can compose against '
            'them — the 049 phase-1 deferral).',
      );
    }
    return CompositionTargetResolved(anchors);
  }
}
