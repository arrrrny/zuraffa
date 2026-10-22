/// The owned-and-missing registry drift — ONE classifier shared by
/// `zfa tdd doctor` (the diagnosis) and `zfa tdd compose` (issue #1974).
///
/// A registry record that points at a file that is gone from disk is the
/// `owned-and-missing` drift (issue #1495). `doctor` reports it with a
/// `drift:` line and prescribes exactly ONE recovery command; `compose`
/// used to turn the very same state into a bare `runner-error` with no
/// reason and no recovery path, so an operator who hit it could not
/// discover the fix from the command that hit it (issue #1974).
///
/// Both commands classify the drift HERE, so the two can never disagree
/// about the same file: the `drift:` line and the `-->` fix line compose
/// prints are literally the ones doctor prints for that registry.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'artifact_registry.dart';
import 'feature_path_resolver.dart';
import '../models/artifact_record.dart';

/// One registry record whose recorded artifacts are missing from disk but
/// were found at a RELOCATED project-relative location (issue #1397): the
/// recorded FORM drifted, not the artifacts — `migrate-paths` repairs it,
/// never the reset.
class RelocatedArtifactRecord {
  const RelocatedArtifactRecord({
    required this.behaviorId,
    required this.testPath,
    required this.subjectPath,
  });

  final String behaviorId;
  final String testPath;
  final String subjectPath;
}

/// The classified owned-and-missing state of one feature's registry.
class MissingArtifactReport {
  const MissingArtifactReport({
    required this.drifts,
    required this.collectibleIds,
    required this.halfMissingIds,
    required this.relocated,
  });

  /// The `drift:` lines — `<behavior-id>: <path> is recorded but missing
  /// from disk`, one per missing half, in registry order.
  final List<String> drifts;

  /// Behavior ids whose BOTH recorded artifacts are gone: the record owns
  /// nothing on disk, so the surgical garbage-collect
  /// (`zfa tdd doctor <feature> --repair`) covers it.
  final Set<String> collectibleIds;

  /// Behavior ids that still own a SURVIVING half: collecting them would
  /// orphan the survivor, so the full reset remains their remedy.
  final Set<String> halfMissingIds;

  /// Records whose missing artifacts were found at a relocated path.
  final List<RelocatedArtifactRecord> relocated;

  /// Whether the registry owns any artifact that is missing from disk.
  bool get hasMissingArtifacts => drifts.isNotEmpty;
}

/// The one recovery a classified state prescribes: the `--> fix:` line's
/// command, the reason behind it, and the machine-readable class.
class MissingArtifactPrescription {
  const MissingArtifactPrescription({
    required this.fix,
    required this.why,
    required this.prescription,
  });

  /// The concrete command — never a template with a literal `<id>`
  /// placeholder.
  final String fix;

  /// Why this command is the remedy for THIS state.
  final String why;

  /// The machine-readable class: `repair` or `reset`.
  final String prescription;
}

/// The shared classifier + prescriber for the owned-and-missing drift.
abstract final class MissingArtifactDrift {
  /// Classify every record of a feature's registry against the disk.
  ///
  /// [projectRoot] is the project the records are resolved against: a
  /// machine-absolute recorded path is used as-is, a project-relative one
  /// is joined with the root. The drift lines name the path in the same
  /// portable project-relative display form doctor prints.
  static MissingArtifactReport classify({
    required List<ArtifactRecord> records,
    required String projectRoot,
  }) {
    final drifts = <String>[];
    final relocated = <RelocatedArtifactRecord>[];
    final collectibleIds = <String>{};
    final halfMissingIds = <String>{};
    for (final record in records) {
      final resolvedTest = _resolve(projectRoot, record.testPath);
      final resolvedSubject = _resolve(projectRoot, record.subjectPath);
      final missingTest = !File(resolvedTest).existsSync();
      final missingSubject = !File(resolvedSubject).existsSync();
      if (!missingTest && !missingSubject) continue;
      // A missing path that is found at a RELOCATED project-relative
      // location is path-FORM drift (issue #1397), not a missing artifact.
      final relocatedTest = missingTest
          ? probeRelocatedArtifact(projectRoot, record.testPath)
          : resolvedTest;
      final relocatedSubject = missingSubject
          ? probeRelocatedArtifact(projectRoot, record.subjectPath)
          : resolvedSubject;
      if (relocatedTest != null && relocatedSubject != null) {
        relocated.add(
          RelocatedArtifactRecord(
            behaviorId: record.behaviorId,
            testPath: _display(projectRoot, relocatedTest),
            subjectPath: _display(projectRoot, relocatedSubject),
          ),
        );
        continue;
      }
      if (missingTest) {
        drifts.add(
          '${record.behaviorId}: ${_display(projectRoot, resolvedTest)} is '
          'recorded but missing from disk',
        );
      }
      if (missingSubject) {
        drifts.add(
          '${record.behaviorId}: ${_display(projectRoot, resolvedSubject)} '
          'is recorded but missing from disk',
        );
      }
      // Issue #1495 GC classification: both halves genuinely gone -> the
      // record owns nothing on disk and is collectible; a surviving (or
      // relocatable) half keeps the record un-collectible.
      final testCollectible = missingTest && relocatedTest == null;
      final subjectCollectible = missingSubject && relocatedSubject == null;
      if (testCollectible && subjectCollectible) {
        collectibleIds.add(record.behaviorId);
      } else {
        halfMissingIds.add(record.behaviorId);
      }
    }
    return MissingArtifactReport(
      drifts: drifts,
      collectibleIds: collectibleIds,
      halfMissingIds: halfMissingIds,
      relocated: relocated,
    );
  }

  /// The ONE recovery the classified state prescribes.
  ///
  /// [repairMode] is the caller's `doctor --repair` flag: with the flag,
  /// a half-missing record is still collected-refused (the surviving half
  /// would be orphaned), so the prescription stays the full reset.
  static MissingArtifactPrescription prescribe({
    required String feature,
    required MissingArtifactReport report,
    bool repairMode = false,
  }) {
    final collectibleOnly =
        report.collectibleIds.isNotEmpty && report.halfMissingIds.isEmpty;
    final fix = repairMode && report.halfMissingIds.isNotEmpty
        ? 'zfa tdd reset $feature'
        : collectibleOnly
        ? 'zfa tdd doctor $feature --repair'
        : 'zfa tdd reset $feature';
    final why = repairMode
        ? 'a half-missing record still owns a file on disk — collecting it '
              'would orphan the survivor (issue #1495); the full reset '
              'reconciles records AND owned artifacts'
        : collectibleOnly
        ? 'drop the stale registry records only — the surgical '
              'garbage-collect keeps every healthy record and touches no '
              'file (issue #1495); `zfa tdd reset` remains the heavier '
              'alternative'
        : 'drop the stale registry records and owned artifacts, then '
              're-drive from gen (resume cannot pass the ownership '
              'preflight while records point at missing files)';
    return MissingArtifactPrescription(
      fix: fix,
      why: why,
      // Issue #1495 review: match the prescription to its fix line — on a
      // half-missing record the fix is the reset command, so the flag
      // alone must not flip the machine-readable field (the same state
      // diagnosed without the flag reports 'reset').
      prescription: fix.contains('--repair') ? 'repair' : 'reset',
    );
  }

  /// The `drift:` lines of the RELOCATED records — the path-FORM drift
  /// of issue #1397, whose remedy is the path rewrite, never the reset.
  ///
  /// Shared with `zfa tdd compose` so the two commands name the SAME
  /// drift for the SAME file (issue #1974).
  static List<String> relocatedDrifts(MissingArtifactReport report) => [
    for (final relocated in report.relocated)
      '${relocated.behaviorId}: the recorded machine-absolute path '
          'names a project root that is not on this machine, but the '
          'artifacts sit at ${relocated.testPath} / '
          '${relocated.subjectPath} under the current root — a relocated '
          'registry (the recorded form, not the artifacts, has drifted)',
  ];

  /// The ONE recovery a RELOCATED registry prescribes.
  ///
  /// [featureRef] is the RESOLVED reference (issue #1573): `migrate-paths`
  /// takes a `--feature` flag, and re-resolving a bare name through
  /// `resolveWithPin` keeps `specs/<name>` whenever that directory
  /// exists — so a plain name would migrate a DIFFERENT registry than the
  /// one just diagnosed.
  static MissingArtifactPrescription relocatedPrescription({
    required String featureRef,
  }) => MissingArtifactPrescription(
    fix: 'zfa tdd migrate-paths --feature $featureRef',
    why:
        'rewrite the recorded forms to the portable project-relative '
        'POSIX form (the files stay where they are; reset would drop the '
        'certified behaviors)',
    prescription: 'migrate',
  );

  /// A recorded path resolved against the project root: a machine-absolute
  /// form is used as-is, a project-relative one is joined with the root.
  static String _resolve(String projectRoot, String recorded) =>
      p.isAbsolute(recorded)
      ? p.normalize(recorded)
      : p.normalize(p.join(projectRoot, recorded));

  /// The portable project-relative display form of an absolute path.
  static String _display(String projectRoot, String absolute) =>
      TddFeaturePaths.displayDir(cwd: projectRoot, dir: absolute);
}
