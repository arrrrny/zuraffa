/// The registry drift diagnosis — ONE ordered verdict shared by
/// `zfa tdd doctor` (the diagnosis) and `zfa tdd compose` (issue #1974).
///
/// The doctor walks the drift states in a fixed order and prescribes
/// exactly ONE recovery for the first state it finds:
///
///   1. a generated-shape file ANOTHER feature's registry owns
///      (bug #874) — migrate the OWNING feature, never adopt;
///   2. a generated-shape file NO registry owns (bug #840) — adopt it;
///   3. a record whose artifacts are missing from disk (issue #1495) —
///      the surgical repair, or the full reset;
///   4. a record whose recorded paths name a foreign project root
///      (issue #1397) — rewrite the recorded forms, never reset.
///
/// `zfa tdd compose` reaches the SAME registry, so it must prescribe in
/// the SAME order: a compose that prescribed the reset where the doctor
/// prescribes the adoption would send the operator down the destructive
/// road, and a compose that reported success where the doctor reports a
/// drift would break the very invariant the shared classifier exists to
/// establish.
///
/// The `drift:` lines and the `-->` fix line are BUILT HERE, so the two
/// commands print byte-identical text for the same file.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'cross_feature_ownership.dart';
import 'feature_path_resolver.dart';
import 'generated_shape.dart';
import 'missing_artifact_drift.dart';
import '../models/artifact_record.dart';

/// Which drift state the diagnosis found.
enum RegistryDriftKind {
  /// The registry agrees with the disk — no drift.
  none,

  /// A generated-shape file ANOTHER feature's registry owns (bug #874).
  foreignOwned,

  /// A generated-shape file NO registry owns (bug #840).
  unowned,

  /// A record whose artifacts are missing from disk (issue #1495).
  missingArtifact,

  /// A record whose recorded paths name a foreign project root
  /// (issue #1397).
  relocated,
}

/// The ordered diagnosis of one feature's registry: the `drift:` lines and
/// the ONE recovery the state prescribes.
class RegistryDriftDiagnosis {
  const RegistryDriftDiagnosis({
    required this.kind,
    required this.drifts,
    required this.prescription,
    required this.report,
    this.ownedBy = const {},
  });

  /// The "no drift" verdict — the empty registry state.
  const RegistryDriftDiagnosis.none()
    : kind = RegistryDriftKind.none,
      drifts = const [],
      prescription = const MissingArtifactPrescription(
        fix: '',
        why: '',
        prescription: 'none',
      ),
      report = const MissingArtifactReport(
        drifts: [],
        collectibleIds: {},
        halfMissingIds: {},
        relocated: [],
      ),
      ownedBy = const {};

  /// Which state the diagnosis found.
  final RegistryDriftKind kind;

  /// The `drift:` lines, in the order the doctor prints them.
  final List<String> drifts;

  /// The ONE recovery: the fix command, the reason behind it and the
  /// machine-readable class.
  final MissingArtifactPrescription prescription;

  /// The classified owned-and-missing state (empty for the
  /// legacy-layout kinds).
  final MissingArtifactReport report;

  /// The owning feature of every foreign-owned file, keyed by the file's
  /// display path (the foreign-owned verdict's ownership map).
  final Map<String, String> ownedBy;

  /// Whether the diagnosis found a drift at all.
  bool get hasDrift => kind != RegistryDriftKind.none;
}

/// The one ordered diagnosis every command shares.
abstract final class RegistryDrift {
  /// Diagnose a feature's registry against the disk.
  ///
  /// [records] are the registry's RAW stored forms (never the
  /// re-anchored view): the path FORM is itself drift (issue #1397), and
  /// the re-anchored view silently heals it.
  ///
  /// [featureName] is the feature's canonical name (the `reset` and
  /// `doctor --repair` commands name it); [featureRef] is the RESOLVED
  /// reference (the `--feature` flag form `migrate-paths` and `gen
  /// --adopt` parse — issue #1573: a bare name would migrate a DIFFERENT
  /// registry than the one just diagnosed).
  ///
  /// [prefixDrifts] are drift lines the caller already collected; they
  /// are printed ahead of this diagnosis's own lines, so the doctor's
  /// transcript keeps its shape.
  static Future<RegistryDriftDiagnosis> diagnose({
    required String projectRoot,
    required String featureName,
    required String featureRef,
    required List<ArtifactRecord> records,
    bool repairMode = false,
    List<String> prefixDrifts = const [],
  }) async {
    // ---- 1. Legacy-layout scan (bugs #840, #874) -------------------
    final legacy = await _scanLegacyLayout(
      projectRoot: projectRoot,
      featureName: featureName,
      records: records,
    );
    if (legacy.foreignOwned.isNotEmpty) {
      return RegistryDriftDiagnosis(
        kind: RegistryDriftKind.foreignOwned,
        drifts: [
          ...prefixDrifts,
          for (final entry in legacy.foreignOwned.entries)
            'foreign-owned generated file(s) for "${entry.key}" '
                '(owned by ${_ownersOf(legacy, entry.value, projectRoot).join(', ')}): '
                '${entry.value.map((path_) => _display(projectRoot, path_)).join(', ')}',
        ],
        prescription: MissingArtifactPrescription(
          fix: legacy.owners.length == 1
              ? 'zfa tdd migrate-paths --feature ${legacy.owners.first}'
              : 'zfa tdd migrate-paths',
          why:
              'move the owning feature\'s legacy flat artifacts into its '
              'namespaced layout (adopting another feature\'s files would '
              'corrupt ownership)',
          prescription: 'migrate',
        ),
        report: const MissingArtifactReport(
          drifts: [],
          collectibleIds: {},
          halfMissingIds: {},
          relocated: [],
        ),
        ownedBy: legacy.ownedBy,
      );
    }
    if (legacy.unowned.isNotEmpty) {
      final ids = legacy.unowned.keys.toList()..sort();
      return RegistryDriftDiagnosis(
        kind: RegistryDriftKind.unowned,
        drifts: [
          ...prefixDrifts,
          for (final entry in legacy.unowned.entries)
            'unowned generated file(s) for "${entry.key}": '
                '${entry.value.map((path_) => p.relative(path_, from: projectRoot)).join(', ')}',
        ],
        prescription: MissingArtifactPrescription(
          fix: ids
              .map((id) => 'zfa tdd gen $id --adopt --feature $featureRef')
              .join(' && '),
          why:
              'verify the generated shape, register ownership, audit-log '
              'the adoption',
          prescription: 'adopt',
        ),
        report: const MissingArtifactReport(
          drifts: [],
          collectibleIds: {},
          halfMissingIds: {},
          relocated: [],
        ),
      );
    }
    // ---- 2. Owned-and-missing + relocated (issues #1495, #1397) ----
    final report = MissingArtifactDrift.classify(
      records: records,
      projectRoot: projectRoot,
    );
    if (report.hasMissingArtifacts) {
      return RegistryDriftDiagnosis(
        kind: RegistryDriftKind.missingArtifact,
        drifts: [...prefixDrifts, ...report.drifts],
        prescription: MissingArtifactDrift.prescribe(
          feature: featureName,
          report: report,
          repairMode: repairMode,
        ),
        report: report,
      );
    }
    if (report.relocated.isNotEmpty) {
      return RegistryDriftDiagnosis(
        kind: RegistryDriftKind.relocated,
        drifts: [
          ...prefixDrifts,
          ...MissingArtifactDrift.relocatedDrifts(report),
        ],
        prescription: MissingArtifactDrift.relocatedPrescription(
          featureRef: featureRef,
        ),
        report: report,
      );
    }
    return const RegistryDriftDiagnosis.none();
  }

  /// The legacy-layout scan: the generated-shape files under the gen
  /// default layout that this feature's registry does not own, split by
  /// WHO owns them (bug #874's foreign state, bug #840's adopt state).
  static Future<_LegacyLayout> _scanLegacyLayout({
    required String projectRoot,
    required String featureName,
    required List<ArtifactRecord> records,
  }) async {
    // Bug #874: registries may record absolute (gen's default) or
    // project-relative paths — ownership comparisons normalize both
    // sides so a recorded file is never misread as unowned by path form.
    final ownedPaths = <String>{
      for (final record in records)
        normalizeArtifactPath(projectRoot, record.testPath),
      for (final record in records)
        normalizeArtifactPath(projectRoot, record.subjectPath),
    };
    final ownersByPath = await ownershipByPathAcrossFeatures(projectRoot);
    final unowned = <String, List<String>>{};
    final foreignOwned = <String, List<String>>{};
    final ownedBy = <String, String>{};
    for (final entry in scanGeneratedLayout(projectRoot)) {
      final normalized = normalizeArtifactPath(projectRoot, entry.path);
      if (ownedPaths.contains(normalized)) continue;
      final owner = ownersByPath[normalized];
      if (owner != null && owner != featureName) {
        foreignOwned.putIfAbsent(entry.behaviorId, () => []).add(entry.path);
        ownedBy[_display(projectRoot, entry.path)] = owner;
        continue;
      }
      unowned.putIfAbsent(entry.behaviorId, () => []).add(entry.path);
    }
    return _LegacyLayout(
      unowned: unowned,
      foreignOwned: foreignOwned,
      ownedBy: ownedBy,
      owners: ownedBy.values.toSet().toList()..sort(),
    );
  }

  /// The owning features of [paths], sorted — the per-behavior owner
  /// list the foreign-owned drift line names.
  static List<String> _ownersOf(
    _LegacyLayout legacy,
    List<String> paths,
    String projectRoot,
  ) =>
      paths
          .map((path_) => legacy.ownedBy[_display(projectRoot, path_)] ?? '')
          .where((owner_) => owner_.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  /// The portable project-relative display form of an absolute path.
  static String _display(String projectRoot, String absolute) =>
      TddFeaturePaths.displayDir(cwd: projectRoot, dir: absolute);
}

/// The legacy-layout scan's verdict for one feature.
class _LegacyLayout {
  const _LegacyLayout({
    required this.unowned,
    required this.foreignOwned,
    required this.ownedBy,
    required this.owners,
  });

  /// Generated-shape files NO registry owns, keyed by behavior id.
  final Map<String, List<String>> unowned;

  /// Generated-shape files ANOTHER feature's registry owns, keyed by
  /// behavior id.
  final Map<String, List<String>> foreignOwned;

  /// The owning feature of every foreign file, keyed by the file's
  /// display path.
  final Map<String, String> ownedBy;

  /// The distinct owning features, sorted.
  final List<String> owners;
}

/// Scan the gen default layout (`test/tdd/*.dart`, `lib/tdd/*.dart`) and
/// return the generated-shape files found there with the behavior id their
/// provenance header names. Files without the header are foreign — never
/// adopted, never prescribed.
List<({String path, String behaviorId})> scanGeneratedLayout(String cwd) {
  final found = <({String path, String behaviorId})>[];
  for (final dir in [p.join(cwd, 'test', 'tdd'), p.join(cwd, 'lib', 'tdd')]) {
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    for (final entity in d.listSync().whereType<File>()) {
      if (!entity.path.endsWith('.dart')) continue;
      String content;
      try {
        content = entity.readAsStringSync();
      } on FileSystemException {
        continue;
      }
      final id = behaviorIdFromContent(content);
      if (id == null) continue;
      final shaped =
          content.contains(generatedTestMarker) ||
          content.contains(generatedSubjectMarker);
      if (!shaped) continue;
      found.add((path: entity.path, behaviorId: id));
    }
  }
  return found;
}
