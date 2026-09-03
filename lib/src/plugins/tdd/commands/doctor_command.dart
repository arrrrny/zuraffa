/// `zfa tdd doctor <feature>` — deterministic recovery diagnosis (bug
/// #840).
///
/// The command reads the three TDD stores (`tdd/run-state.json`,
/// `tdd/artifacts.json`, `tdd/cycle-log.md`) plus the generated-artifact
/// layout on disk, and prescribes EXACTLY ONE recovery action as a
/// `--> fix:` line, in this deterministic priority order:
///
/// 1. **migrate** — generated-shape files exist at the legacy flat layout
///    that ANOTHER feature's registry owns (the pre-#827 multi-feature
///    project, bug #874): the owning feature's artifacts must be migrated
///    to the namespaced layout (`zfa tdd migrate-paths <owner>`) — never
///    adopted, which would corrupt ownership.
/// 2. **adopt** — generated-shape files exist on disk that NO feature's
///    registry owns (the post-crash/post-merge state): ownership must be
///    registered before anything else can run (`zfa tdd gen <id>
///    --adopt`).
/// 3. **reset** — the registry records artifacts that are MISSING from
///    disk: every later step would die at the ownership preflight, and
///    the state cannot be reconciled without dropping the stale records
///    (`zfa tdd reset <feature>`).
/// 4. **resume** — the stores disagree on progress (an in-flight marker,
///    or claims whose matching cycle-log evidence is missing): the run
///    driver re-drives the incomplete steps honestly (`zfa tdd run
///    <feature>`).
/// 5. **none** — the stores agree; the feature is healthy.
///
/// The same state always produces the same prescription (deterministic:
/// pure priority order over store contents, no clocks, no randomness).
/// The machine-readable JSON verdict is the final stdout line; the exit
/// protocol is 0 for healthy and 1 for drift/refusal.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/artifact_registry.dart';
import '../services/cross_feature_ownership.dart';
import '../services/cycle_evidence.dart';
import '../services/generated_shape.dart';
import '../services/import_resolution.dart';
import '../services/run_state_store.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class DoctorCommand extends Command<void> {
  DoctorCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and lib/. When omitted, '
          'the current working directory is used.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Diagnose a feature\'s TDD stores and prescribe exactly one recovery '
      'action — migrate (another feature owns the legacy-layout files), '
      'adopt (register unowned generated files), reset (drop stale '
      'registry records), or resume (re-run the loop) — as a '
      '--> fix: line with a JSON verdict (bugs #840, #874).';

  @override
  String get invocation => 'zfa tdd doctor <feature> [--project <path>]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      usageException('Feature name is required: zfa tdd doctor <feature>');
    }
    final feature = rest.first;
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final featureDir = p.join(cwd, 'specs', feature);

    if (!await Directory(featureDir).exists()) {
      print('zfa tdd doctor: no feature directory at specs/$feature');
      _printVerdict(
        feature: feature,
        verdict: 'refused',
        prescription: 'none',
        drifts: ['no feature directory at specs/$feature'],
      );
      exitCode = 1;
      return;
    }

    final drifts = <String>[];

    // ---- Store loads -------------------------------------------------
    final registry = ArtifactRegistry(featureDir: featureDir);
    final records = await registry.loadAll();
    // Bug #874: registries may record absolute (gen's default) or
    // project-relative paths — ownership comparisons normalize both sides
    // so a recorded file is never misread as unowned by path form.
    final ownedTestPaths = records
        .map((r) => normalizeArtifactPath(cwd, r.testPath))
        .toSet();
    final ownedSubjectPaths = records
        .map((r) => normalizeArtifactPath(cwd, r.subjectPath))
        .toSet();

    RunState? state;
    var stateCorrupt = false;
    try {
      state = await RunStateStore(featureDir).load();
    } on RunStateCorruptException catch (e) {
      stateCorrupt = true;
      drifts.add('run-state.json is corrupted: ${e.message}');
    }

    final evidence = CycleEvidence(featureDir);
    final red = await evidence.redEvidence();
    final green = await evidence.greenEvidence();

    // ---- 1. Legacy-layout scan ---------------------------------------
    // Scan the gen default layout; classify every generated-shape file
    // the queried feature does not own (bug #874): another feature's
    // registry owning the path makes it FOREIGN-OWNED (migrate the
    // owning feature, never adopt); nobody owning it makes it unowned
    // (the #840 adopt state).
    final ownersByPath = await ownershipByPathAcrossFeatures(cwd);
    final unowned = <String, List<String>>{};
    final foreignByBehavior = <String, List<String>>{};
    final ownedBy = <String, String>{};
    for (final entry in _scanGeneratedLayout(cwd)) {
      final normalized = normalizeArtifactPath(cwd, entry.path);
      final isOwned =
          ownedTestPaths.contains(normalized) ||
          ownedSubjectPaths.contains(normalized);
      if (isOwned) continue;
      final owner = ownersByPath[normalized];
      if (owner != null && owner != feature) {
        foreignByBehavior
            .putIfAbsent(entry.behaviorId, () => [])
            .add(entry.path);
        ownedBy[_displayPath(cwd, entry.path)] = owner;
        continue;
      }
      unowned.putIfAbsent(entry.behaviorId, () => []).add(entry.path);
    }

    // ---- 1a. Foreign-owned files -> MIGRATE (never adopt, bug #874) --
    if (foreignByBehavior.isNotEmpty) {
      final ownersInvolved = ownedBy.values.toSet().toList()..sort();
      for (final entry in foreignByBehavior.entries) {
        final ownersForBehavior =
            entry.value
                .map((path_) => ownedBy[_displayPath(cwd, path_)] ?? '')
                .where((owner_) => owner_.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        drifts.add(
          'foreign-owned generated file(s) for "${entry.key}" '
          '(owned by ${ownersForBehavior.join(', ')}): '
          '${entry.value.map((path_) => _displayPath(cwd, path_)).join(', ')}',
        );
      }
      final fix = ownersInvolved.length == 1
          ? 'zfa tdd migrate-paths ${ownersInvolved.first}'
          : 'zfa tdd migrate-paths';
      print('zfa tdd doctor: feature $feature (specs/$feature/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print(
        '   --> fix: $fix — move the owning feature\'s legacy flat '
        'artifacts into its namespaced layout (adopting another '
        'feature\'s files would corrupt ownership)',
      );
      _printVerdict(
        feature: feature,
        verdict: 'foreign-owned',
        prescription: 'migrate',
        fix: fix,
        drifts: drifts,
        ownedBy: ownedBy,
      );
      exitCode = 1;
      return;
    }

    // ---- 1b. Unowned generated files -> ADOPT ------------------------
    if (unowned.isNotEmpty) {
      for (final entry in unowned.entries) {
        drifts.add(
          'unowned generated file(s) for "${entry.key}": '
          '${entry.value.map((path_) => p.relative(path_, from: cwd)).join(', ')}',
        );
      }
      final ids = unowned.keys.toList()..sort();
      final fix = ids
          .map((id) => 'zfa tdd gen $id --adopt --feature $feature')
          .join(' && ');
      print('zfa tdd doctor: feature $feature (specs/$feature/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print(
        '   --> fix: $fix — verify the generated shape, register '
        'ownership, audit-log the adoption',
      );
      _printVerdict(
        feature: feature,
        verdict: 'drift',
        prescription: 'adopt',
        fix: fix,
        drifts: drifts,
      );
      exitCode = 1;
      return;
    }

    // ---- 2. Registry records with missing files -> RESET -------------
    final missingFiles = <String>[];
    for (final record in records) {
      for (final path in [record.testPath, record.subjectPath]) {
        // Records may be absolute (gen's default) or project-relative —
        // resolve both against the project root (issue #912: the raw
        // relative form resolved against the process CWD, flagging
        // healthy files as missing when doctor ran from elsewhere).
        final resolved = p.isAbsolute(path)
            ? p.normalize(path)
            : p.normalize(p.join(cwd, path));
        if (!File(resolved).existsSync()) {
          missingFiles.add(
            '${record.behaviorId}: ${_displayPath(cwd, resolved)} is '
            'recorded but missing from disk',
          );
        }
      }
    }
    if (missingFiles.isNotEmpty) {
      drifts.addAll(missingFiles);
      final fix = 'zfa tdd reset $feature';
      print('zfa tdd doctor: feature $feature (specs/$feature/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print(
        '   --> fix: $fix — drop the stale registry records and owned '
        'artifacts, then re-drive from gen (resume cannot pass the '
        'ownership preflight while records point at missing files)',
      );
      _printVerdict(
        feature: feature,
        verdict: 'drift',
        prescription: 'reset',
        fix: fix,
        drifts: drifts,
      );
      exitCode = 1;
      return;
    }

    // ---- 2b. Import-resolution drift -> MIGRATE (issue #912) ---------
    // A recorded test whose relative or self-package imports dangle is
    // UNLOADABLE — the suite cannot run no matter what the stores claim.
    // The migration repair (`zfa tdd migrate-paths`) rewrites stale flat
    // references to the namespaced layout; doctor prescribes it.
    final pkg = hostPackageName(cwd);
    final importDrifts = <String>[];
    for (final record in records) {
      final testFile = File(
        p.isAbsolute(record.testPath)
            ? p.normalize(record.testPath)
            : p.normalize(p.join(cwd, record.testPath)),
      );
      if (!testFile.existsSync()) continue; // check 2 reported it
      String source;
      try {
        source = testFile.readAsStringSync();
      } on FileSystemException {
        continue;
      }
      for (final issue in unresolvedImports(
        source: source,
        filePath: testFile.path,
        projectRoot: cwd,
        packageName: pkg,
      )) {
        importDrifts.add(
          '${record.behaviorId}: '
          '${_displayPath(cwd, testFile.path)} imports '
          "'${issue.uri}' which does not resolve (${issue.reason})",
        );
      }
    }
    if (importDrifts.isNotEmpty) {
      drifts.addAll(importDrifts);
      final fix = 'zfa tdd migrate-paths $feature';
      print('zfa tdd doctor: feature $feature (specs/$feature/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print(
        '   --> fix: $fix — rewrite stale subject references to the '
        'namespaced layout and self-check the imports (issue #912 '
        'defect 4: an unloadable recorded suite must not read healthy)',
      );
      _printVerdict(
        feature: feature,
        verdict: 'drift',
        prescription: 'migrate',
        fix: fix,
        drifts: drifts,
      );
      exitCode = 1;
      return;
    }

    // ---- 3. State-vs-evidence drift -> RESUME ------------------------
    if (stateCorrupt) {
      // A corrupt state file cannot be trusted for claims; reset is the
      // honest recovery for the state half.
      final fix = 'zfa tdd reset $feature';
      print('zfa tdd doctor: feature $feature (specs/$feature/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print('   --> fix: $fix — delete the corrupted state and start clean');
      _printVerdict(
        feature: feature,
        verdict: 'drift',
        prescription: 'reset',
        fix: fix,
        drifts: drifts,
      );
      exitCode = 1;
      return;
    }
    if (state != null) {
      if (state.inFlightBehaviorId != null) {
        drifts.add(
          'an in-flight marker survives for "${state.inFlightBehaviorId}" '
          '(step ${state.inFlightStep}) — a run was interrupted',
        );
      }
      for (final entry in state.behaviorStates.entries) {
        final hasRed = red.contains(entry.key);
        final hasGreen = green.contains(entry.key);
        final claim = entry.value;
        var backed = true;
        switch (claim) {
          case BehaviorState.done:
            backed = hasRed && hasGreen;
          case BehaviorState.green:
            backed = hasGreen;
          case BehaviorState.red:
            backed = hasRed;
          case BehaviorState.pending:
            backed = true;
        }
        if (!backed) {
          drifts.add(
            'run-state claims ${claim.name} for "${entry.key}" but the '
            'cycle-log evidence is incomplete (red: $hasRed, '
            'green: $hasGreen)',
          );
        }
      }
    }
    if (drifts.isNotEmpty) {
      final fix = 'zfa tdd run $feature';
      print('zfa tdd doctor: feature $feature (specs/$feature/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print(
        '   --> fix: $fix — resume reconciliation re-drives the earliest '
        'incomplete step for every claim the evidence does not back',
      );
      _printVerdict(
        feature: feature,
        verdict: 'drift',
        prescription: 'resume',
        fix: fix,
        drifts: drifts,
      );
      exitCode = 1;
      return;
    }

    // ---- 4. Healthy --------------------------------------------------
    print('zfa tdd doctor: feature $feature (specs/$feature/tdd)');
    print('  stores agree — no drift detected');
    _printVerdict(feature: feature, verdict: 'healthy', prescription: 'none');
    exitCode = 0;
  }

  /// Scan the gen default layout (`test/tdd/*.dart`, `lib/tdd/*.dart`)
  /// and return the generated-shape files found there with the behavior
  /// id their provenance header names. Files without the header are
  /// foreign — never adopted, never prescribed.
  List<({String path, String behaviorId})> _scanGeneratedLayout(String cwd) {
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

  /// The path relative to the project root, POSIX separators (the display
  /// and verdict form for scanned artifacts).
  String _displayPath(String cwd, String absolute) =>
      p.relative(absolute, from: cwd).replaceAll(r'\', '/');

  /// The machine-readable JSON verdict (bug #840) — the LAST stdout line.
  void _printVerdict({
    required String feature,
    required String verdict,
    required String prescription,
    String? fix,
    List<String> drifts = const [],
    Map<String, String>? ownedBy,
  }) {
    print(
      jsonEncode({
        'command': 'doctor',
        'feature': feature,
        'verdict': verdict,
        'prescription': prescription,
        'fix': ?fix,
        'drifts': drifts,
        'owned_by': ?((ownedBy != null && ownedBy.isNotEmpty) ? ownedBy : null),
      }),
    );
  }
}
