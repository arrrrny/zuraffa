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
///    disk with no relocated match (issue #1397): every later step would
///    die at the ownership preflight, and the state cannot be reconciled
///    without dropping the stale records (`zfa tdd reset <feature>`).
/// 3a. **migrate (path-form)** — the registry records machine-absolute
///    test/subject paths (issue #1397): either resolving on this machine
///    (the mixed-form registry, the state where the gen ownership gate
///    misfires while every store "agrees") or naming a project root that
///    is not on this machine while the artifacts sit at the same
///    project-relative locations under the current root (a relocated
///    registry, which `reset` would wrongly answer by dropping certified
///    behaviors). The migration rewrites the recorded forms to the
///    portable project-relative POSIX form without moving any file
///    (`zfa tdd migrate-paths <feature>`).
/// 4. **resume** — the stores disagree on progress (an in-flight marker,
///    or claims whose matching cycle-log evidence is missing), or green
///    evidence has no backing artifact on disk (issue #1264's
///    `evidence-without-artifact`: the post-reset phantom done-state):
///    the run driver re-drives the incomplete steps honestly (`zfa tdd
///    run <feature>`).
/// 5. **stale-artifacts** — the #1324 contradiction: green cycle-log
///    evidence for a behavior was certified BEFORE the registry's
///    current artifact generation for the same behavior id (gen re-ran
///    over the certified pair without a re-certification). Every store
///    reads self-consistent, but the next run either wedges (verify-red
///    unexpected-green → make subject-drift) or fake-completes on the
///    stale certification — the same recovery the run driver's stop
///    prescribes (`zfa tdd reset <feature>`).
/// 6. **none** — the stores agree; the feature is healthy.
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
import '../services/feature_path_resolver.dart';
import '../services/generated_shape.dart';
import '../services/journal.dart';
import '../services/import_resolution.dart';
import '../services/import_resolution_checker.dart';
import '../services/run_state_store.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class DoctorCommand extends Command<void> {
  DoctorCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #969).',
      negatable: false,
    );
    argParser.addFlag(
      'repair',
      help:
          'Repair mode (issue #1495): garbage-collect every registry '
          'record whose test AND subject files are gone from disk (no '
          'relocation match). Surgical — healthy records stay, no file on '
          'disk is touched (owned-and-absent has nothing to clobber), '
          'audit-logged (action "repair"). A record that still owns a '
          'surviving half is never collected — reset remains its remedy.',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and lib/. When omitted, '
          'the current working directory is used.',
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit (the
  /// legacy raw-JSON verdict line folds into it under --json).
  final VerdictContext _verdict = VerdictContext();

  bool get _jsonMode => argResults?['json'] as bool? ?? false;

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
  String get invocation =>
      'zfa tdd doctor <feature> [--repair] [--project <path>]';

  @override
  Future<void> run() =>
      runWithVerdictEnvelope(this, _verdict, _run, featureFromRest: true);

  Future<void> _run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      usageException('Feature name is required: zfa tdd doctor <feature>');
    }
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    // Issue #1471: resolve the reference once — the bug extension's
    // `.specify/feature.json` pin included — so a bug feature is diagnosed
    // in `.specify/bugs/<slug>`, never a fabricated `specs/<slug>`. The
    // display label names the directory the command actually used.
    final resolved = TddFeaturePaths.resolveWithPin(
      projectRoot: cwd,
      featureRef: rest.first,
    );
    final feature = resolved.name;
    final featureDir = resolved.dir;
    final featureLabel = p
        .relative(featureDir, from: cwd)
        .replaceAll(r'\', '/');

    if (!await Directory(featureDir).exists()) {
      print('zfa tdd doctor: no feature directory at $featureLabel');
      _printVerdict(
        feature: feature,
        verdict: 'refused',
        prescription: 'none',
        drifts: ['no feature directory at $featureLabel'],
      );
      exitCode = 1;
      return;
    }

    final drifts = <String>[];

    // ---- Store loads -------------------------------------------------
    final registry = ArtifactRegistry(featureDir: featureDir);
    // Raw load (issue #1397 x #1357): doctor owns path-FORM drift
    // detection — the reanchored view would silently heal relocated
    // records and mask the stored non-portable forms this command must
    // flag and prescribe `migrate-paths` for.
    final records = await registry.loadAll(reanchor: false);
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
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
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
          .map((id) => 'zfa tdd gen $id --adopt --feature ${resolved.ref}')
          .join(' && ');
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
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
    // Issue #1397: a record whose recorded path is machine-absolute may
    // name a project root that does not exist on this machine (a checkout
    // relocated between machines) while the artifact sits at the same
    // project-relative location under the current root. That is path-form
    // drift the migration repairs — NOT a missing artifact, which `reset`
    // would answer by dropping certified behaviors. The relocation probe
    // separates the two: a record whose missing paths all relocate is
    // routed to migrate-paths below; a record with a genuinely missing
    // artifact (probe finds nothing) still resets.
    //
    // Issue #1495: a record whose BOTH files are gone (no relocation
    // match) owns NOTHING on disk — `zfa tdd doctor <feature> --repair`
    // garbage-collects exactly those records (surgical, audit-logged);
    // a record that still owns a surviving half is never collected (GC
    // would orphan the survivor — reset remains its remedy).
    final missingFiles = <String>[];
    final relocatedRecords = <_RelocatedRecord>[];
    // Issue #1495: per-record GC classification — a record is collectible
    // only when BOTH recorded paths are genuinely missing (no relocation
    // probe match, nothing on disk it owns).
    final collectibleIds = <String>{};
    final halfMissingIds = <String>{};
    for (final record in records) {
      // Records may be absolute (gen's default) or project-relative —
      // resolve both against the project root (issue #912: the raw
      // relative form resolved against the process CWD, flagging
      // healthy files as missing when doctor ran from elsewhere).
      final resolvedTest = p.isAbsolute(record.testPath)
          ? p.normalize(record.testPath)
          : p.normalize(p.join(cwd, record.testPath));
      final resolvedSubject = p.isAbsolute(record.subjectPath)
          ? p.normalize(record.subjectPath)
          : p.normalize(p.join(cwd, record.subjectPath));
      final missingTest = !File(resolvedTest).existsSync();
      final missingSubject = !File(resolvedSubject).existsSync();
      if (!missingTest && !missingSubject) continue;
      final relocatedTest = missingTest
          ? probeRelocatedArtifact(cwd, record.testPath)
          : resolvedTest;
      final relocatedSubject = missingSubject
          ? probeRelocatedArtifact(cwd, record.subjectPath)
          : resolvedSubject;
      if (relocatedTest != null && relocatedSubject != null) {
        relocatedRecords.add(
          _RelocatedRecord(
            behaviorId: record.behaviorId,
            testPath: _displayPath(cwd, relocatedTest),
            subjectPath: _displayPath(cwd, relocatedSubject),
          ),
        );
        continue;
      }
      if (missingTest) {
        missingFiles.add(
          '${record.behaviorId}: ${_displayPath(cwd, resolvedTest)} is '
          'recorded but missing from disk',
        );
      }
      if (missingSubject) {
        missingFiles.add(
          '${record.behaviorId}: ${_displayPath(cwd, resolvedSubject)} is '
          'recorded but missing from disk',
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
    if (missingFiles.isNotEmpty) {
      drifts.addAll(missingFiles);
      final repairMode = argResults?['repair'] as bool? ?? false;
      if (repairMode && halfMissingIds.isEmpty) {
        // Issue #1495: the surgical repair — drop EVERY gone-file record,
        // keep every healthy record, touch no file on disk, audit-log.
        final dropped = await registry.dropRecords(collectibleIds);
        await _auditRepair(featureDir, feature, dropped);
        final droppedIds = dropped.map((r) => r.behaviorId).toList()..sort();
        print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
        print(
          '  repaired: dropped ${droppedIds.length} gone-file registry '
          'record(s): ${droppedIds.join(', ')} — no file on disk was '
          'touched (owned-and-absent has nothing to clobber; issue '
          '#1495)',
        );
        print(
          '   --> next: re-drive the collected behaviors from gen '
          '(`zfa tdd gen <id> --feature ${resolved.ref}` or '
          '`zfa tdd run ${resolved.ref}`)',
        );
        _printVerdict(
          feature: feature,
          verdict: 'repaired',
          prescription: 'repair',
          fix: 'zfa tdd gen <id> --feature ${resolved.ref}',
          drifts: drifts,
        );
        exitCode = 0;
        return;
      }
      final fix = repairMode && halfMissingIds.isNotEmpty
          ? 'zfa tdd reset $feature'
          : collectibleIds.isNotEmpty && halfMissingIds.isEmpty
          ? 'zfa tdd doctor $feature --repair'
          : 'zfa tdd reset $feature';
      final why = repairMode
          ? 'a half-missing record still owns a file on disk — collecting '
                'it would orphan the survivor (issue #1495); the full reset '
                'reconciles records AND owned artifacts'
          : collectibleIds.isNotEmpty && halfMissingIds.isEmpty
          ? 'drop the stale registry records only — the surgical '
                'garbage-collect keeps every healthy record and touches no '
                'file (issue #1495); `zfa tdd reset` remains the heavier '
                'alternative'
          : 'drop the stale registry records and owned artifacts, then '
                're-drive from gen (resume cannot pass the ownership '
                'preflight while records point at missing files)';
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print('   --> fix: $fix — $why');
      _printVerdict(
        feature: feature,
        verdict: 'drift',
        prescription: repairMode || fix.contains('--repair')
            ? 'repair'
            : 'reset',
        fix: fix,
        drifts: drifts,
      );
      exitCode = 1;
      return;
    }
    // ---- 2c. Relocated registry -> MIGRATE (issue #1397) -------------
    // Every missing path of these records was found at its project-relative
    // location under the current root: the registry was committed with
    // machine-absolute forms from another checkout. The migration rewrites
    // the recorded forms in place; `reset` would drop certified behaviors
    // over a path form.
    if (relocatedRecords.isNotEmpty) {
      for (final relocated in relocatedRecords) {
        drifts.add(
          '${relocated.behaviorId}: the recorded machine-absolute path '
          'names a project root that is not on this machine, but the '
          'artifacts sit at ${relocated.testPath} / '
          '${relocated.subjectPath} under the current root — a relocated '
          'registry (the recorded form, not the artifacts, has drifted)',
        );
      }
      final fix = 'zfa tdd migrate-paths $feature';
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print(
        '   --> fix: $fix — rewrite the recorded forms to the portable '
        'project-relative POSIX form (the files stay where they are; '
        'reset would drop the certified behaviors)',
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

    // ---- 2d. Evidence without artifact -> RESUME (issue #1264) -------
    // The store-to-tree check the store-to-store comparisons miss: green
    // evidence in the append-only cycle-log can survive the deletion of
    // the artifacts it certified (`zfa tdd reset` drops the owned files
    // but never the evidence). A behavior whose last green entry names a
    // test file missing from disk is the phantom done-state: run skips
    // it as "already done" and status reports green on a nonexistent
    // test. Exactly one recovery: re-drive the behaviors (`zfa tdd run`).
    // Issue #1331: the prescription names the mechanics the run ACTUALLY
    // performs — run reconciles the tombstoned behaviors to pending and
    // re-enters at gen, and make ADOPTS each re-driven subject whose
    // certification the reset invalidated (the `adopted` outcome)
    // instead of dead-ending at subject-drift. The old text promised a
    // path that stopped at `<id>:make` every time. Issue #1345: the
    // prescription also names the placeholder re-entry — a re-driven
    // ACCEPTANCE placeholder (the compose pipeline's own born-green
    // product) re-enters compose/make phase-2 (the
    // `adopted-placeholder` outcome) instead of refusing, so the
    // documented recovery loop completes for acceptance-lane behaviors
    // too.
    final orphaned = await evidence.orphanedGreenEvidence(projectRoot: cwd);
    if (orphaned.isNotEmpty) {
      final ids = orphaned.toList()..sort();
      for (final id in ids) {
        final lastGreen = await evidence.lastEntryFor(id, kind: 'green');
        final testPath = lastGreen?.test ?? '(unknown)';
        drifts.add(
          'evidence-without-artifact: "$id" has green evidence naming '
          '${_displayPath(cwd, p.isAbsolute(testPath) ? p.normalize(testPath) : p.normalize(p.join(cwd, testPath)))} '
          'but the file is missing from disk',
        );
      }
      final fix = 'zfa tdd run $feature';
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print(
        '   --> fix: $fix — re-drive every behavior whose evidence has no '
        'backing artifact (run reconciles them to pending and re-enters '
        'at gen; make adopts each re-driven subject whose certification '
        'the reset invalidated — the adopted outcome, issue #1331 — and '
        're-enters the acceptance pipeline at compose/make phase-2 for '
        'every re-driven acceptance placeholder — the adopted-placeholder '
        'outcome, issue #1345 — instead of dead-ending at subject-drift; '
        'the append-only evidence history is preserved)',
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

    // ---- 2e. Recorded path-form drift -> MIGRATE (issue #1397) -------
    // A record whose test/subject path is machine-absolute is not
    // portable: another checkout reads it as a different file, and the
    // mixed-form registry is exactly the state where the ownership gate
    // misfires on re-gen while every store "agrees". The gate itself now
    // compares resolved paths; the remaining hazard is the recorded form,
    // and the migration rewrites it to the portable project-relative
    // POSIX form without moving any file.
    final formDrifts = <String>[];
    for (final record in records) {
      if (p.isAbsolute(record.testPath)) {
        formDrifts.add(
          '${record.behaviorId}: the recorded test path is '
          'machine-absolute (${_displayPath(cwd, p.normalize(record.testPath))}) '
          '— records must be project-relative to stay portable',
        );
      }
      if (p.isAbsolute(record.subjectPath)) {
        formDrifts.add(
          '${record.behaviorId}: the recorded subject path is '
          'machine-absolute '
          '(${_displayPath(cwd, p.normalize(record.subjectPath))}) '
          '— records must be project-relative to stay portable',
        );
      }
    }
    if (formDrifts.isNotEmpty) {
      drifts.addAll(formDrifts);
      final fix = 'zfa tdd migrate-paths $feature';
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print(
        '   --> fix: $fix — rewrite the recorded path forms to the '
        'portable project-relative POSIX form (files stay where they '
        'are; only the recorded strings change)',
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

    // ---- 2f. Stale-artifacts contradiction -> RESET (issue #1324) ----
    // The wedge doctor called healthy: a behavior's cycle-log carries
    // green evidence certified at T1, but the feature's registry recorded
    // its artifact generation for the same behavior id at T2 > T1 — gen
    // re-ran over the certified pair without a re-certification. Every
    // store looks self-consistent (records own existing files, claims
    // are evidence-backed), yet the next run either wedges (verify-red
    // unexpected-green → make subject-drift) or fake-completes on the
    // stale certification. The prescription matches the run driver's
    // stale-artifacts stop: reset. Legacy entries without a parseable
    // `- at:` fail open (never failed what cannot be read).
    final staleArtifacts = <String>[];
    final lastGreenEntries = <String, ParsedCycleEntry>{};
    for (final entry in await evidence.entries()) {
      if (entry.kind != 'green') continue;
      lastGreenEntries[entry.behaviorId] = entry;
    }
    // Consult the reset tombstone so a behavior whose last green entry
    // predates the tombstone is skipped — the re-drive is the sanctioned
    // recovery, not a contradiction (mirrors the run driver's
    // tombstone-filtered greenEvidence gate).
    final tombstone = await JournalReader.lastResetTombstone(featureDir);
    final tombstoneAt = tombstone.at;
    for (final record in records) {
      final greenEntry = lastGreenEntries[record.behaviorId];
      if (greenEntry == null) continue;
      final certifiedAt = DateTime.tryParse(greenEntry.at ?? '');
      final createdAt = DateTime.tryParse(record.createdAt);
      if (certifiedAt == null || createdAt == null) continue;
      // Skip behaviors whose last green entry predates the last reset
      // tombstone — the certification is already invalidated; the
      // re-drive's registry record (T2 > tombstone) is the sanctioned
      // recovery state, not a stale-artifacts contradiction.
      if (tombstoneAt != null &&
          tombstone.behaviors.contains(record.behaviorId)) {
        if (certifiedAt.isBefore(tombstoneAt)) continue;
      }
      if (createdAt.isAfter(certifiedAt)) {
        staleArtifacts.add(record.behaviorId);
        drifts.add(
          'stale-artifacts: "${record.behaviorId}" has green evidence '
          'certified at ${greenEntry.at} but the registry re-generated its '
          'artifacts at ${record.createdAt} — the certification predates '
          'the current artifact generation (issue #1324)',
        );
      }
    }
    if (staleArtifacts.isNotEmpty) {
      staleArtifacts.sort();
      final fix = 'zfa tdd reset $feature';
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print(
        '   --> fix: $fix — drop the stale registry records and owned '
        'artifacts, then re-run `zfa tdd run $feature` (re-driving gen '
        'over the certified pair wedges the feature: a fresh guard-only '
        'test against the implemented subject dies at verify-red '
        'unexpected-green then make subject-drift, issue #1324)',
      );
      _printVerdict(
        feature: feature,
        verdict: 'stale-artifacts',
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
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
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

    // ---- 2c. Unexported runtime symbols drift -> UPGRADE-RUNTIME (#911) --
    const importChecker = ImportResolutionChecker();
    final runtimeDrifts = <String>[];
    for (final record in records) {
      // Anchor the recorded path the same way check 2b does: post-#1397
      // records carry the canonical project-relative form, which must
      // resolve against the project root — never the process CWD.
      final resolvedTestPath = p.isAbsolute(record.testPath)
          ? p.normalize(record.testPath)
          : p.normalize(p.join(cwd, record.testPath));
      final testDrifts = importChecker.checkTestFile(
        resolvedTestPath,
        projectRoot: cwd,
      );
      for (final td in testDrifts) {
        runtimeDrifts.add(
          '${_displayPath(cwd, record.testPath)} references $td',
        );
      }
    }
    if (runtimeDrifts.isNotEmpty) {
      drifts.addAll(runtimeDrifts);
      const fix = 'dart pub upgrade zuraffa';
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print(
        '   --> fix: $fix — upgrade zuraffa to resolve unexported symbols '
        'referenced by generated tests',
      );
      _printVerdict(
        feature: feature,
        verdict: 'drift',
        prescription: 'upgrade-runtime',
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
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
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
          case BehaviorState.mocked:
          case BehaviorState.green:
            backed = hasGreen;
          case BehaviorState.red:
            backed = hasRed;
          case BehaviorState.pending:
            backed = true;
          // Issue #1007: a BLOCKED contract-lane claim is backed by the
          // blocked receipt (.zfa/receipts/contract-blocked.<id>.json),
          // never by red evidence — the doctor only checks the cycle-log
          // here, so the claim stands (the receipt's existence is the
          // verify-red command's own contract).
          case BehaviorState.blocked:
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
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
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
    print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
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
  /// and verdict form for scanned artifacts) — the shared
  /// [TddFeaturePaths.displayDir] idiom, so every command renders one way.
  String _displayPath(String cwd, String absolute) =>
      TddFeaturePaths.displayDir(cwd: cwd, dir: absolute);

  /// Append the garbage-collect audit record (issue #1495): one JSONL line
  /// per repair run in `specs/<feature>/tdd/audit.log` — the same
  /// discipline as the #840 adoption line. Records which behavior ids
  /// were collected; no file on disk is touched.
  Future<void> _auditRepair(
    String featureDir,
    String featureName,
    List<dynamic> droppedRecords,
  ) async {
    final auditFile = File(p.join(featureDir, 'tdd', 'audit.log'));
    await auditFile.parent.create(recursive: true);
    final line = jsonEncode({
      'at': DateTime.now().toUtc().toIso8601String(),
      'action': 'repair',
      'feature': featureName,
      'command': 'doctor',
      'dropped': droppedRecords.map((r) => r.behaviorId as String).toList(),
    });
    final sink = auditFile.openWrite(mode: FileMode.append);
    sink.writeln(line);
    await sink.flush();
    await sink.close();
  }

  /// The machine-readable JSON verdict (bug #840) — the LAST stdout line.
  void _printVerdict({
    required String feature,
    required String verdict,
    required String prescription,
    String? fix,
    List<String> drifts = const [],
    Map<String, String>? ownedBy,
  }) {
    if (_jsonMode) {
      // Issue #969: fold the verdict into the versioned envelope — the
      // wrapper emits ONE machine line; the raw object disappears.
      _verdict
        ..feature = feature
        ..exitClass = verdict
        ..outcome = verdict == 'healthy'
            ? VerdictOutcome.pass
            : VerdictOutcome.fail
        ..fix = fix
        ..drifts.addAll(drifts)
        ..details['prescription'] = prescription;
      if (ownedBy != null && ownedBy.isNotEmpty) {
        _verdict.details['owned_by'] = ownedBy;
      }
      return;
    }
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

/// One registry record whose every missing recorded path relocated (issue
/// #1397): the machine-absolute form names a foreign project root, the
/// artifacts sit at the same project-relative locations under the current
/// root, so the record is form drift for `migrate-paths` — not a missing
/// artifact for `reset`.
class _RelocatedRecord {
  const _RelocatedRecord({
    required this.behaviorId,
    required this.testPath,
    required this.subjectPath,
  });

  final String behaviorId;
  final String testPath;
  final String subjectPath;
}
