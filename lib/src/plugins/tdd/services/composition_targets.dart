/// `CompositionTargets` — resolves the feature's composable unit
/// subjects for the acceptance composition surface (spec
/// 052-acceptance-make-composition; issue #642; FR-003, FR-007; issue
/// #923).
///
/// A **composable anchor** is a unit-kind row in the feature's
/// `tdd/test-list.md` (the shared `TestListReader` contract — the kind
/// source of truth) whose subject artifact exists on disk and either
/// carries green cycle-log evidence in `tdd/cycle-log.md` OR carries the
/// `zfa tdd wire` implementation anchor (`wiredEntityAnchor`, bug #610 —
/// issue #923: an entity-wired unit subject is a valid anchor even while
/// its behavior is still a stub, so an acceptance scenario is never
/// stuck at `unexpressible` when the units are entity-wired). Green
/// cycle-log evidence remains the source of truth for "already-green" —
/// the same evidence the run driver's reconciliation consumes — so
/// discovery stays independent of `tdd/run-state.json` (the driver owns
/// run state; the make pipeline owns the cycle log). Issue #1550: a
/// green claim the REGISTRY contradicts (the record is absent — the
/// artifacts were dropped, e.g. by a reset) is the `stale-evidence`
/// refusal, never an anchor and never a silent skip.
///
/// The TARGET (the behavior being made) may be acceptance-kind or
/// widget-kind (issue #939): both compose against the feature's green
/// unit subjects. Every other kind fails closed with the row's ACTUAL
/// kind named — never a hardcoded guess.
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

/// One anchor a composition may wire against: a green, entity-wired, or
/// (bug features, issue #1162) stub-only unit subject.
///
/// Issue #923: an anchor no longer requires green cycle-log evidence —
/// a unit subject the `zfa tdd wire` step implemented against its entity
/// (the `wiredEntityAnchor` implementation-anchor marker, bug #610) is a
/// valid composition anchor even while the unit behavior is still a stub
/// (`return 0`). The acceptance scenario composes against the wired
/// subject and defers the real green transition to when the unit
/// subjects are filled with business logic; [entityWired] records which
/// anchors carry only that wiring so the audit trail stays honest.
///
/// Issue #1162: [stubOnly] anchors go one honest step further for BUG
/// features — a unit subject that exists on disk (gen wrote it) but is
/// neither green nor wired is still a composable anchor, because compose
/// REFERENCES anchor subjects without calling them: the composed
/// scenario runner does not throw, the paired test's scenario assertions
/// genuinely execute, and the composed skeleton's real green lands when
/// the unit subjects are filled in later cycles. The audit trail labels
/// these `[stub]` everywhere (discovery print, compose output, and the
/// composed file header).
class ComposableUnitSubject {
  final String behaviorId;

  /// The subject artifact's absolute path (normalized against the project
  /// root the discovery was run with).
  final String subjectPath;

  /// The subject function the anchor's behavior targets — the symbol gen
  /// emitted in the subject file (the test-list row's target, defaulting
  /// to `subject_<snake-id>`).
  final String symbol;

  /// Whether the subject file carries the `zfa tdd wire` implementation
  /// anchor (`wiredEntityAnchor`, bug #610) — true for anchors composed
  /// against wiring alone (no green cycle-log evidence yet, issue #923).
  final bool entityWired;

  /// Issue #1162: true for anchors that are neither green nor wired —
  /// the stub-only composition lane for bug features. The composed
  /// scenario references the stub subject as an implementation anchor;
  /// the audit trail labels it `[stub]` so the accounting stays honest.
  final bool stubOnly;

  const ComposableUnitSubject({
    required this.behaviorId,
    required this.subjectPath,
    required this.symbol,
    this.entityWired = false,
    this.stubOnly = false,
  });

  @override
  String toString() =>
      'ComposableUnitSubject($behaviorId: $subjectPath#$symbol'
      '${entityWired ? ', entity-wired' : ''}${stubOnly ? ', stub' : ''})';
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
  /// `stale-evidence`, `target-not-acceptance`, `no-test-list`,
  /// `malformed-test-list`.
  ///
  /// `stale-evidence` (issue #1550) is the green-PREMISE contradiction:
  /// the unit row carries green cycle-log evidence while its registry
  /// record is ABSENT — the evidence survives the append-only cycle-log
  /// but the artifacts it certified were dropped (canonically by a
  /// `tdd reset`, which also invalidates the journal evidence the
  /// discovery does not consult). A refusal, never a partial anchor
  /// set: the caller re-derives the dropped artifacts
  /// (`zfa tdd gen <id>` + re-drive) before composing.
  final String code;

  /// Human-readable message naming the artifact / file at fault.
  final String message;

  const CompositionTargetFailure({required this.code, required this.message});

  @override
  String toString() => '$code: $message';
}

class CompositionTargets {
  const CompositionTargets();

  /// The `zfa tdd wire` implementation-anchor marker (bug #610), matched
  /// in executable code only (line comments stripped first — a mention
  /// inside a doc comment is documentation, not wiring). Issue #923: a
  /// subject carrying this marker is a composable anchor even when its
  /// behavior has no green cycle-log evidence yet.
  static final RegExp _wiredEntityAnchor = RegExp(
    r'^\s*final\s+Type\s+wiredEntityAnchor\s*=',
  );

  /// Whether [raw] declares the wire command's `wiredEntityAnchor`
  /// implementation anchor outside a line comment.
  static bool carriesWiredEntityAnchor(String raw) {
    for (final line in raw.split('\n')) {
      final commentIdx = line.indexOf('//');
      final code = commentIdx >= 0 ? line.substring(0, commentIdx) : line;
      if (_wiredEntityAnchor.hasMatch(code)) return true;
    }
    return false;
  }

  /// Whether [featureDir] is a BUG feature (issue #1162): the bug
  /// extension's TDD lane drives features rooted at `.specify/bugs/<slug>`
  /// (the bug.fix contract), bridged into the specs/ scan as a
  /// `bug-<slug>` symlink. Both shapes detect: the bridge keeps the
  /// `bug-` prefix in the directory's basename, and an unbridged
  /// `feature_directory` pin resolves to the real `.specify/bugs/` path.
  static bool isBugFeatureDir(String featureDir) {
    if (p.basename(featureDir).startsWith('bug-')) return true;
    final dir = Directory(featureDir);
    final real = dir.existsSync() ? dir.resolveSymbolicLinksSync() : featureDir;
    final segments = real.split(Platform.pathSeparator);
    return segments.contains('.specify') && segments.contains('bugs');
  }

  /// Discover the composable anchors for composing [behaviorId]'s subject
  /// in [featureDir] (a `specs/<feature>` path under [projectRoot]).
  ///
  /// Issue #1162: [allowStubAnchors] (bug features only — gate the flag
  /// with [isBugFeatureDir] at the call site) extends the anchor search
  /// with STUB-only unit subjects: unit-kind rows whose subject artifact
  /// exists on disk (registry-recorded) but carries neither green
  /// evidence nor the wire anchor. Such anchors are labeled [stubOnly]
  /// so every audit surface stays honest about what the composition
  /// rests on. Non-bug features keep the strict gate: their
  /// `no-green-units` stop is unchanged.
  Future<CompositionTargetResult> discover({
    required String projectRoot,
    required String featureDir,
    required String behaviorId,
    bool allowStubAnchors = false,
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

    // 2. Kind gate: composition is the acceptance+widget subject surface
    //    (spec 052 Out of Scope as amended by issue #939: a widget-kind
    //    row composes like acceptance — against the feature's green unit
    //    subjects — instead of being refused with a WRONG kind label).
    //    Every other kind fails closed, NAMING THE ACTUAL KIND: the
    //    pre-#939 message hardcoded "is unit-kind" for every
    //    non-acceptance kind, so a widget row's disengage said unit-kind
    //    — wrong on its face — and hid the widget lane's real shape
    //    (issue #939 defect 2).
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
    if (targetRow.kind != BehaviorKind.acceptance &&
        targetRow.kind != BehaviorKind.widget) {
      final kindName = targetRow.kind.name;
      return CompositionTargetFailure(
        code: 'target-not-acceptance',
        message:
            'behavior "$behaviorId" is $kindName-kind: compose composes '
            'acceptance and widget subjects against the feature\'s green '
            'unit subjects, and a $kindName subject implements its own '
            'logic (spec 052 Out of Scope; issue #939).',
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
    //    never a silent skip (US2.AC4). Issue #923: a unit row WITHOUT
    //    green evidence is still an anchor when its subject artifact
    //    exists on disk and carries the `zfa tdd wire` implementation
    //    anchor (`wiredEntityAnchor`, bug #610) — the acceptance scenario
    //    composes against the entity-wired subject even while the unit is
    //    a stub, deferring the real green transition to when the unit
    //    subjects are filled with business logic.
    //
    //    Issue #1550: the green-unit premise is verified against the
    //    REGISTRY first. A green row whose registry record is ABSENT is
    //    the stale-evidence refusal — the cycle-log's green claim
    //    survives (append-only) while the artifacts it certified were
    //    dropped (canonically by a reset; the #1264 tombstone that
    //    invalidates the claim lives in the journal, which discovery
    //    does not consult). Classifying it `stale-evidence` (not the
    //    legacy `missing-anchor-subject` → `runner-error`) names the
    //    actual inconsistency: the premise is stale, re-derive the
    //    artifacts. A record PRESENT but file missing stays
    //    `missing-anchor-subject` — the registry premise is intact,
    //    the tree drifted.
    final anchors = <ComposableUnitSubject>[];
    for (final row in rows) {
      if (row.kind != BehaviorKind.unit) continue;
      if (row.id == behaviorId) continue; // never anchor against itself
      final recorded = subjectPathById[row.id];
      if (green.contains(row.id)) {
        if (recorded == null) {
          return CompositionTargetFailure(
            code: 'stale-evidence',
            message:
                'green unit subject "${row.id}" has no registry record in '
                '${p.join(featureDir, 'tdd', 'artifacts.json')} — the green '
                'evidence in tdd/cycle-log.md is STALE (its artifacts were '
                'dropped, e.g. by a `zfa tdd reset`; the tombstone that '
                'invalidates the evidence lives in tdd/journal.json). '
                'Re-derive the artifacts: run `zfa tdd gen ${row.id}` and '
                're-drive the behavior before composing.',
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
            entityWired: carriesWiredEntityAnchor(
              File(normalized).readAsStringSync(),
            ),
          ),
        );
        continue;
      }
      // Issue #923: no green evidence — the entity-wiring probe decides.
      // A missing record or file just means the unit was never gen'd/wired
      // (a normal not-done state, not an anomaly): it is not an anchor,
      // and discovery keeps scanning the remaining rows.
      if (recorded == null) continue;
      final normalized = p.normalize(
        p.isAbsolute(recorded) ? recorded : p.join(projectRoot, recorded),
      );
      final subjectFile = File(normalized);
      if (!subjectFile.existsSync()) continue;
      String raw;
      try {
        raw = subjectFile.readAsStringSync();
      } on FileSystemException {
        continue; // unreadable subject — not a trustworthy anchor
      }
      if (!carriesWiredEntityAnchor(raw)) continue;
      anchors.add(
        ComposableUnitSubject(
          behaviorId: row.id,
          subjectPath: normalized,
          symbol: row.target,
          entityWired: true,
        ),
      );
    }

    // Issue #1162: the bug-feature stub-only lane. Still no anchors after
    // the green/wired scan, and the caller allowed stubs: unit rows whose
    // subject artifact exists on disk become [stub] anchors (compose
    // references anchors without calling them, so the composed scenario
    // is non-throwing and the paired test's assertions genuinely run).
    if (anchors.isEmpty && allowStubAnchors) {
      for (final row in rows) {
        if (row.kind != BehaviorKind.unit) continue;
        if (row.id == behaviorId) continue; // never anchor against itself
        final recorded = subjectPathById[row.id];
        if (recorded == null) continue; // never gen'd — not on disk
        final normalized = p.normalize(
          p.isAbsolute(recorded) ? recorded : p.join(projectRoot, recorded),
        );
        if (!File(normalized).existsSync()) continue;
        anchors.add(
          ComposableUnitSubject(
            behaviorId: row.id,
            subjectPath: normalized,
            symbol: row.target,
            stubOnly: true,
          ),
        );
      }
    }

    if (anchors.isEmpty) {
      return CompositionTargetFailure(
        code: 'no-green-units',
        message:
            'no green unit subjects to compose against: behavior '
            '"$behaviorId" needs at least one unit-kind behavior with green '
            'cycle-log evidence or an entity-wired subject artifact (the '
            '`wiredEntityAnchor` implementation anchor `zfa tdd wire` emits '
            '— issue #923: a wired unit subject is a valid composition '
            'anchor even while its behavior is still a stub). Wire a unit '
            'subject with `zfa tdd wire <id> --entity <Name>` or take a '
            'unit behavior green before composing against it.',
      );
    }
    return CompositionTargetResolved(anchors);
  }
}
