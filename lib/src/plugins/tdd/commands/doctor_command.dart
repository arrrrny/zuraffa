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
///    to the namespaced layout (`zfa tdd migrate-paths --feature <owner>`)
///    — never adopted, which would corrupt ownership.
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
///    (`zfa tdd migrate-paths --feature <feature>` — the resolved
///    reference, since a bare name can re-resolve to a same-named
///    `specs/` directory instead).
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
/// 5a. **hash-chain** — a schema-1 cycle-log entry's recomputed chain
///    digest no longer matches its recorded `- hash:` link, its
///    `- prev-hash:` link does not chain to the previous recorded hash,
///    or a chain-claiming section carries no well-formed `- hash:` line
///    (bug #828 — the walk restored by #1585 after the #840 rework
///    dropped it): the certified facts were edited after certification,
///    so every claim the log backs is untrusted. There is no automatic
///    remedy — restore the cycle-log from a trusted source, then re-run
///    `zfa tdd run <feature>` to re-certify. Legacy hash-less entries
///    stay valid and unverifiable, and are never failed; sections from
///    the certifier writers (`fixtures`, `mock-cert`, `world-*`,
///    `realize*`) are verified when their hash recomputes and otherwise
///    tolerated — the canonical payload cannot rebuild a legacy foreign
///    scheme (review #1612; see `evidence_chain.dart`).
/// 6. **none** — the stores agree; the feature is healthy.
///
/// Issue #1978 adds one more class the store-vs-store comparisons cannot
/// see: **receipt drift** — a receipted artifact whose recorded digest no
/// longer matches the bytes on disk, or that is gone altogether. It is the
/// very check `zfa tdd verify` runs in its receipt preflight (spec 0996)
/// before the mutation audit, so without it the two commands disagreed
/// about the same state: doctor reported a healthy feature while the
/// verify gate refused it. The drift lines name the file, the recorded and
/// the current digest, and the transition that re-binds the receipt to the
/// current bytes (`zfa tdd verify-red <id> --re-certify` / `zfa tdd make
/// contract:<id> --born-green`); the destructive generator re-drive (issue
/// #1375) is never prescribed, and a generator receipt's transition is
/// picked by the artifact's kind (a test is re-certified red, a subject is
/// born green).
///
/// The check covers the receipt-vs-disk classes the preflight refuses a
/// feature for — a digest mismatch and a receipted artifact that is gone.
/// The preflight's remaining classes (`stale_spec`, `stale_usecase`,
/// `manifest_drift`, `world_drift`) are outside its scope, so the doctor
/// never claims to agree with `zfa tdd verify` about them.
///
/// The same state always produces the same prescription (deterministic:
/// pure priority order over store contents, no clocks, no randomness).
/// The machine-readable JSON verdict is the final stdout line; the exit
/// protocol is 0 for healthy and 1 for drift/refusal.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../../core/proof/proof_checker.dart';
import '../../../core/project/receipt_store.dart';
import '../../../core/project/test_receipt.dart';
import '../services/artifact_registry.dart';
import '../services/cycle_evidence.dart';
import '../services/evidence_chain.dart';
import '../services/feature_path_resolver.dart';
import '../services/journal.dart';
import '../services/import_resolution.dart';
import '../services/import_resolution_checker.dart';
import '../services/registry_drift.dart';
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

    RunState? state;
    var stateCorrupt = false;
    try {
      state = await RunStateStore(featureDir).load();
    } on RunStateCorruptException catch (e) {
      stateCorrupt = true;
      drifts.add('run-state.json is corrupted: ${e.message}');
    }

    // Read-only, multi-read flow: the cached view serves every check from
    // one disk read + parse (review #1612, finding 5). The doctor never
    // writes the cycle log, so the cache cannot go stale mid-run.
    final evidence = CycleEvidence.cached(featureDir);
    final red = await evidence.redEvidence();
    final green = await evidence.greenEvidence();
    // Review #1785 (minor): marker-only (loose) born-green set, matching
    // the run driver's reconcile path (intentionally looser than the
    // subject-bound set the #1592 refactor shortcut uses) — see
    // run_driver_core.dart.
    final bornGreenIds = (await evidence.bornGreenCertifiedEntries()).keys
        .toSet();

    // ---- 1. Registry drift diagnosis ---------------------------------
    // The drift states and the ONE recovery each of them prescribes live
    // in the shared `RegistryDrift` service, in the doctor's own order:
    //
    //   1. a generated-shape file ANOTHER feature's registry owns
    //      (bug #874) — migrate the OWNING feature, never adopt;
    //   2. a generated-shape file NO registry owns (bug #840) — adopt;
    //   3. a record whose artifacts are missing from disk (issue #1495)
    //      — the surgical repair, or the full reset;
    //   4. a record whose recorded paths name a foreign project root
    //      (issue #1397) — rewrite the recorded forms, never reset.
    //
    // Issue #1974: `zfa tdd compose` diagnoses the SAME registry through
    // the SAME service, so the two commands print the same `drift:` line
    // and the same `-->` fix line for the same file — they can never
    // disagree about it.
    final repairMode = argResults?['repair'] as bool? ?? false;
    final diagnosis = await RegistryDrift.diagnose(
      projectRoot: cwd,
      featureName: feature,
      featureRef: resolved.ref,
      records: records,
      repairMode: repairMode,
      prefixDrifts: drifts,
    );
    if (diagnosis.hasDrift) {
      if (diagnosis.kind == RegistryDriftKind.missingArtifact &&
          repairMode &&
          diagnosis.report.halfMissingIds.isEmpty) {
        // Issue #1495: the surgical repair — drop EVERY gone-file record,
        // keep every healthy record, touch no file on disk, audit-log.
        final dropped = await registry.dropRecords(
          diagnosis.report.collectibleIds,
        );
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
          // Issue #1495 review: a concrete command, not a template with a
          // literal `<id>` placeholder — the run driver re-drives the
          // collected behaviors honestly.
          fix: 'zfa tdd run ${resolved.ref}',
          drifts: diagnosis.drifts,
        );
        exitCode = 0;
        return;
      }
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
      for (final drift in diagnosis.drifts) {
        print('  drift: $drift');
      }
      print(
        '   --> fix: ${diagnosis.prescription.fix} — '
        '${diagnosis.prescription.why}',
      );
      _printVerdict(
        feature: feature,
        // The foreign-owned state is its own verdict class; every other
        // drift state reports the shared 'drift'.
        verdict: diagnosis.kind == RegistryDriftKind.foreignOwned
            ? 'foreign-owned'
            : 'drift',
        // Issue #1495 review: match the prescription to its fix line —
        // on a half-missing record the fix is the reset command, so the
        // flag alone must not flip the machine-readable field (the same
        // state diagnosed without the flag reports 'reset').
        prescription: diagnosis.prescription.prescription,
        fix: diagnosis.prescription.fix,
        drifts: diagnosis.drifts,
        ownedBy: diagnosis.ownedBy,
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
      // Issue #1573: the drift line prints the RAW recorded value — the
      // exact string the registry carries. The old rendering piped it
      // through display normalization, so the line claimed "machine-absolute"
      // while showing a relative path the registry does not contain.
      if (p.isAbsolute(record.testPath)) {
        formDrifts.add(
          '${record.behaviorId}: the recorded test path is '
          'machine-absolute (${record.testPath}) '
          '— records must be project-relative to stay portable',
        );
      }
      if (p.isAbsolute(record.subjectPath)) {
        formDrifts.add(
          '${record.behaviorId}: the recorded subject path is '
          'machine-absolute '
          '(${record.subjectPath}) '
          '— records must be project-relative to stay portable',
        );
      }
    }
    if (formDrifts.isNotEmpty) {
      drifts.addAll(formDrifts);
      // Issue #1573: prescribe the flag form migrate-paths parses, naming
      // the RESOLVED REFERENCE rather than the bare name. Re-resolving a
      // bare name through `resolveWithPin` keeps `specs/<name>` whenever
      // that directory exists, so a plain name would migrate a DIFFERENT
      // registry than the one just diagnosed (doctor on
      // `.specify/bugs/<slug>` with a same-named `specs/<slug>` present).
      // The reference is what issue #1471 hands to child steps for exactly
      // this reason: resolving it yields this same directory.
      final fix = 'zfa tdd migrate-paths --feature ${resolved.ref}';
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
      // Issue #1573: prescribe the flag form migrate-paths parses, naming
      // the RESOLVED REFERENCE rather than the bare name. Re-resolving a
      // bare name through `resolveWithPin` keeps `specs/<name>` whenever
      // that directory exists, so a plain name would migrate a DIFFERENT
      // registry than the one just diagnosed (doctor on
      // `.specify/bugs/<slug>` with a same-named `specs/<slug>` present).
      // The reference is what issue #1471 hands to child steps for exactly
      // this reason: resolving it yields this same directory.
      final fix = 'zfa tdd migrate-paths --feature ${resolved.ref}';
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
            backed = (hasRed || bornGreenIds.contains(entry.key)) && hasGreen;
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

    // ---- 3b. Hand-delta proof drift -> RE-CERTIFY / RESUME (1423) ----
    // The proof-layer class the store-vs-store comparisons cannot see:
    // a registry-recorded test/subject path whose disk digest differs
    // from its latest receipt digest — the certified hand-delta state
    // the run driver's `<id>:hand` stop prescribes (issue #1308). Every
    // store "agrees" (the claims are evidence-backed) while `zfa tdd
    // verify`'s proof preflight refuses the feature on the drifted
    // digest: doctor must NOT report "stores agree" here (SC-4). The
    // sanctioned completion re-receipts the hand-edited pair at the
    // certification transitions (`verify-red --re-certify`, make's skip
    // — spec 1423); re-driving the generator over a hand-delta would
    // DESTROY the certified work (the #1375 destructive remedy) and is
    // never the prescription. Which transition is prescribed derives
    // from the behavior's last certification — see
    // `_handDeltaProofDrifts`.
    final handDelta = await _handDeltaProofDrifts(
      cwd,
      feature,
      records,
      evidence,
    );
    if (handDelta.lines.isNotEmpty) {
      drifts.addAll(handDelta.lines);
      final fix = handDelta.fix;
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print('   --> fix: $fix — ${handDelta.note}');
      _printVerdict(
        feature: feature,
        verdict: 'drift',
        prescription: handDelta.prescription,
        fix: fix,
        drifts: drifts,
      );
      exitCode = 1;
      return;
    }

    // ---- 3c. Evidence hash-chain integrity -> RESTORE + RE-CERTIFY ----
    // Bug #828 (restored by #1585): schema-1 cycle-log entries carry a
    // tamper-evident hash chain (`- prev-hash:` / `- hash:`), and this
    // command is the reader that verifies it — without the walk, a
    // hand-edited entry reads as "stores agree" while the certified
    // facts no longer match their evidence. The walk is shared with the
    // replay reader (`verifyEvidenceChain`, review #1612 finding 3):
    // every `prev-hash` must link the previous recorded hash, every
    // canonical `hash` must equal the recomputed payload digest
    // (`CycleLog.payloadFromFields`), and a chain-claiming section with
    // no well-formed `- hash:` line is drift — the tail bypass where
    // deleting the line hid the entry from the walk (finding 2).
    // Certifier-written sections (`fixtures`, `mock-cert`, `world-*`,
    // `realize*`) whose legacy `- hash:` predates the canonical chain are
    // unverifiable, never failed (finding 1); entries written through
    // `CycleLog.chainHashFromFields` verify cleanly.
    final chainWalk = verifyEvidenceChain(await evidence.entries());
    if (chainWalk.drifts.isNotEmpty) {
      drifts.addAll(chainWalk.drifts.map((drift) => drift.message));
      final fix =
          'restore the cycle-log from a trusted source, then re-run '
          '`zfa tdd run $feature` to re-certify';
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print(
        '   --> fix: $fix — the entry was edited or reordered after it was '
        'certified, so every claim it backs is untrusted; there is no '
        'automatic remedy, and re-certification re-proves the behaviors '
        'through the runner',
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

    // ---- 3d. Receipt drift -> RE-CERTIFY (issue #1978) ---------------
    // The receipt preflight `zfa tdd verify` runs before its mutation
    // audit (spec 0996): every receipted artifact's recorded digest must
    // still match the bytes on disk. The store-vs-store comparisons above
    // cannot see that class — a feature whose receipts drifted reads
    // "stores agree" while the verify gate refuses it, and the two
    // commands disagree about the same state (issue #1978). This check
    // runs the SAME check (the shared `ProofChecker` behind the
    // preflight) and reports the receipt-vs-disk classes it finds — a
    // digest mismatch AND a receipted artifact that is gone — so the
    // doctor names the same artifacts the verify gate refuses the feature
    // for. The preflight's other classes (stale spec, stale usecase,
    // manifest/world drift) are outside this check's scope and are not
    // claimed here.
    final receiptDrift = await _receiptDigestDrifts(cwd, feature);
    if (receiptDrift.lines.isNotEmpty) {
      drifts.addAll(receiptDrift.lines);
      final fix = receiptDrift.fix;
      print('zfa tdd doctor: feature $feature ($featureLabel/tdd)');
      for (final drift in drifts) {
        print('  drift: $drift');
      }
      print('   --> fix: $fix — ${receiptDrift.note}');
      _printVerdict(
        feature: feature,
        verdict: 'drift',
        prescription: receiptDrift.prescription,
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

  /// The hand-delta proof-drift scan (spec 1423, SC-4): for every
  /// registry-recorded test/subject path, compare the disk digest against
  /// the LATEST receipt digest covering it through the shared
  /// [ReceiptStore.latestForPath] resolution (the same one `ProofChecker`
  /// applies). A mismatch is the certified hand-delta state the stores
  /// cannot see: state claims and cycle-log evidence agree while
  /// `zfa tdd verify`'s proof preflight refuses.
  ///
  /// Fail-open surfaces: an unreadable receipts tree, a feature with no
  /// receipts, an unreceipted artifact path (the preflight's
  /// missing-receipt gate owns that class), and a missing file (check 2
  /// already reported it) all produce no hand-delta findings — never a
  /// fabricated mismatch.
  ///
  /// The prescription derives from the FIRST drifted behavior's last
  /// recorded certification, never from the mere presence of red
  /// evidence — which the designed `<id>:hand` stop always leaves behind
  /// (`zfa tdd run` certifies the honest red before the hand step).
  /// `verify-red <id> --re-certify` fires ONLY on the unexpected-green
  /// classification (`verify_red_command.dart:396`), so a behavior whose
  /// last certification is red (an interrupted hand-delta) resumes
  /// through the run loop, while a behavior last certified green (or
  /// refactor) takes the direct transition. Both commands stay named so
  /// a drifted-but-green pair is never pushed at the re-certify no-op.
  /// The destructive generator re-drive (#1375) is never prescribed.
  Future<({List<String> lines, String fix, String prescription, String note})>
  _handDeltaProofDrifts(
    String cwd,
    String feature,
    List<ArtifactRecord> records,
    CycleEvidence evidence,
  ) async {
    const none = (lines: <String>[], fix: '', prescription: 'none', note: '');
    final List<ReceiptRecord> receipts;
    try {
      receipts = await ReceiptStore(projectRoot: cwd).loadAll();
    } catch (_) {
      // Unreadable receipts tree — fail open here; the verify proof
      // preflight still gates the audit on whatever it can read.
      return none;
    }
    if (receipts.isEmpty || records.isEmpty) {
      return none;
    }

    final lines = <String>[];
    String? firstDrifted;
    for (final record in records) {
      for (final recorded in [record.testPath, record.subjectPath]) {
        // Both recorded forms resolve to the project-relative POSIX shape
        // the receipt store records (issue #1397 compat).
        final relative = canonicalArtifactPath(cwd, recorded);
        final recordedDigest = ReceiptStore.latestForPath(
          receipts,
          relative,
        )?.entry.sha256;
        if (recordedDigest == null) continue; // unreceipted: not this class
        final file = File(p.join(cwd, relative));
        if (!file.existsSync()) continue; // check 2 reported the deletion
        final String diskDigest;
        try {
          diskDigest = crypto.sha256.convert(file.readAsBytesSync()).toString();
        } on FileSystemException {
          continue;
        }
        if (diskDigest == recordedDigest) continue; // no drift
        var driftLine =
            '${record.behaviorId}: hand-delta drift — $relative matches no '
            'receipt digest (receipt ${_shortDigest(recordedDigest)}, disk '
            '${_shortDigest(diskDigest)}) — the certified hand-delta is not '
            'receipted (issue #1423)';
        // Issue #1778: when the recorded runnable_test_name is absent from
        // the test file, the drift is (also) a test-title mismatch that
        // `--re-certify` can now rebind — name it so the operator sees
        // the real cause instead of only the digest mismatch.
        if (recorded == record.testPath) {
          final testFile = File(p.join(cwd, relative));
          if (testFile.existsSync()) {
            String testContent = '';
            try {
              testContent = testFile.readAsStringSync();
            } catch (_) {}
            final recordedName = record.plainTestName;
            // Issue #1778 (review): check the test TITLES, not the whole
            // file — a changed title with an unchanged `// description:`
            // header would otherwise still contain the old name and skip
            // the annotation. Fall back to a whole-file contains only when
            // no titles could be extracted (tolerant parse failure).
            final titles = _extractTestTitles(testContent);
            final present = titles.isEmpty
                ? testContent.contains(recordedName)
                : titles.any((t) => t.contains(recordedName));
            if (recordedName.isNotEmpty && !present) {
              driftLine +=
                  ' (test-name mismatch: recorded runnable_test_name '
                  '"${record.runnableTestName}" is absent from $relative)';
            }
          }
        }
        lines.add(driftLine);
        firstDrifted ??= record.behaviorId;
      }
    }
    if (lines.isEmpty) return none;

    // Green-backed: the behavior's last recorded certification is a green
    // (or refactor) one — the state the direct re-certify transition can
    // close. A later red entry (a re-drive, an interrupted cycle)
    // supersedes it: the pair must pass the loop again first.
    final behaviorId = firstDrifted!;
    final entries = await evidence.entries();
    var lastRed = -1;
    var lastGreen = -1;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.behaviorId != behaviorId) continue;
      if (entry.kind == 'red') lastRed = i;
      if (entry.kind == 'green') lastGreen = i;
    }
    final tail =
        're-run `zfa tdd doctor $feature` afterwards. Never re-drive the '
        'generator over a hand-delta — it regenerates the guard test and '
        'destroys the certified work (issue #1375).';
    if (lastGreen > lastRed) {
      return (
        lines: lines,
        fix: 'zfa tdd verify-red $behaviorId --re-certify',
        prescription: 're-certify',
        note:
            'the re-certify transition re-receipts the hand-edited '
            'test/subject pair with the current digest (spec 1423); if the '
            'pair no longer passes, resume with `zfa tdd run $feature`. '
            '$tail',
      );
    }
    return (
      lines: lines,
      fix:
          'zfa tdd run $feature (then `zfa tdd verify-red $behaviorId --re-certify`)',
      prescription: 'resume',
      note:
          "the behavior's last certification is not green, so the "
          're-certify transition cannot fire yet (it needs the pair to '
          'pass) — resume the loop; the sanctioned transitions re-receipt '
          'the hand-delta once it is green (spec 1423). If the drifted '
          "behavior's test already passes, "
          '`zfa tdd verify-red $behaviorId --re-certify` closes it '
          'directly. $tail',
    );
  }

  /// The receipt drift scan (issue #1978): the same check `zfa tdd verify`'s
  /// receipt preflight runs — every receipted artifact against the bytes on
  /// disk — reported per file with the transition that re-binds the drifted
  /// receipt to the current bytes.
  ///
  /// The classes covered are the RECEIPT-VS-DISK ones the preflight refuses
  /// the feature for: `modified` (the recorded digest no longer matches the
  /// bytes on disk) and `deleted` (the receipted artifact is gone). The
  /// preflight's other classes (`stale_spec`, `stale_usecase`,
  /// `manifest_drift`, `world_drift`) are outside this check's scope — the
  /// issue asked for the digest class — so the wording here never claims
  /// more than the check delivers.
  ///
  /// The receipts are the PROJECT's receipts, exactly the set the preflight
  /// validates: the two commands must not disagree about one state, and the
  /// preflight audits the whole project (a drifted artifact of any feature
  /// refuses the audit of the feature being verified).
  ///
  /// Fail-open surfaces: an unreadable receipts tree, a project that ships
  /// no proof.v1 receipt (the preflight's vacuous gate) and an unreadable
  /// artifact produce no finding — never a fabricated mismatch.
  ///
  /// The destructive generator re-drive (issue #1375) is never prescribed:
  /// a generator receipt's own repro is id-less (`zfa tdd compose`) and
  /// re-running the generator over certified work destroys it, so the
  /// sanctioned re-certification transition is named instead.
  Future<({List<String> lines, String fix, String prescription, String note})>
  _receiptDigestDrifts(String cwd, String feature) async {
    const none = (lines: <String>[], fix: '', prescription: 'none', note: '');
    final List<ReceiptRecord> receipts;
    final List<TestReceipt> testReceipts;
    try {
      receipts = await ReceiptStore(projectRoot: cwd).loadAll();
      // The test plugin's receipts (`test-*.json`, schema test.v1) are a
      // SEPARATE document kind that `ReceiptStore.loadAll` deliberately
      // skips — but the shared checker audits them, so the doctor must
      // resolve them too. Otherwise a test.v1 drift is reported with the
      // digests it does NOT have (`receipt says unknown`) and its own
      // regeneration command is lost (issue #1978 review).
      testReceipts = await TestReceiptStore(projectRoot: cwd).loadAll();
    } catch (_) {
      // Unreadable receipts tree — fail open here; the verify receipt
      // preflight still gates the audit on whatever it can read.
      return none;
    }
    // The preflight's vacuous gate: a project that ships no proof.v1
    // receipt has nothing to prove — the doctor stays quiet, exactly
    // like `zfa tdd verify`.
    if (receipts.isEmpty) return none;
    final ProofReport proof;
    try {
      proof = await ProofChecker(projectRoot: cwd).check();
    } catch (_) {
      return none;
    }
    final drifted = proof.findings
        .where(
          (finding) =>
              finding.kind == ProofFinding.kindModified ||
              finding.kind == ProofFinding.kindDeleted,
        )
        .toList();
    if (drifted.isEmpty) return none;

    final byFileName = <String, ReceiptRecord>{
      for (final record in receipts) record.fileName: record,
    };
    final testByFileName = <String, TestReceipt>{
      for (final receipt in testReceipts)
        TestReceiptStore.fileNameFor(receipt.entity): receipt,
    };
    final lines = <String>[];
    final fixes = <String>[];
    for (final finding in drifted) {
      final record = byFileName[finding.receipt];
      final testReceipt = testByFileName[finding.receipt];
      final prescription = testReceipt != null
          ? _testReceiptPrescription(testReceipt)
          : _receiptDriftPrescription(record, finding.path);
      lines.add(
        _receiptDriftLine(
          finding,
          owner: _receiptFeature(record),
          prescription: prescription,
        ),
      );
      if (prescription.isNotEmpty && !fixes.contains(prescription)) {
        fixes.add(prescription);
      }
    }
    if (lines.isEmpty) return none;
    return (
      lines: lines,
      fix: fixes.isEmpty ? 'zfa tdd run $feature' : fixes.join(' && '),
      prescription: 're-certify',
      note:
          're-bind the drifted receipts to the current bytes — the same '
          'gate `zfa tdd verify`\'s receipt preflight runs; a feature '
          'whose receipts drifted (or whose receipted artifact is gone) '
          'is not healthy (issue #1978). Never re-drive the generator '
          'over certified work (issue #1375)',
    );
  }

  /// One drift line for a receipted artifact the bytes on disk no longer
  /// match — or that is gone altogether.
  ///
  /// The digests are the CHECKER's: it read and hashed every receipted
  /// file already, so the finding carries both sides of the comparison and
  /// the doctor never re-reads the file to say what the receipt said
  /// (issue #1978 review).
  static String _receiptDriftLine(
    ProofFinding finding, {
    required String owner,
    required String prescription,
  }) {
    final recorded = _shortDigest(finding.recordedDigest ?? 'unknown');
    final buffer = StringBuffer();
    if (finding.kind == ProofFinding.kindDeleted) {
      buffer.write(
        'receipt artifact missing — ${finding.path}: the receipt recorded '
        '$recorded but the file is gone',
      );
    } else {
      buffer.write(
        'receipt digest drift — ${finding.path}: receipt says $recorded, '
        'disk has ${_shortDigest(finding.actualDigest ?? 'unknown')}',
      );
    }
    final action = finding.action;
    if (action != null && action.isNotEmpty) buffer.write(' (action: $action)');
    if (owner.isNotEmpty) buffer.write(' (feature $owner)');
    if (prescription.isNotEmpty) buffer.write(' — re-bind with: $prescription');
    return buffer.toString();
  }

  /// The feature a receipt belongs to — its own `feature` input, else the
  /// empty string (a receipt that names no feature).
  static String _receiptFeature(ReceiptRecord? record) {
    final owner = record?.receipt.input['feature'];
    return owner is String ? owner : '';
  }

  /// The prescription for a drifted TEST receipt (the test plugin's
  /// `test.v1` family): the receipt's own command — the regeneration that
  /// re-binds the receipt to the current bytes.
  static String _testReceiptPrescription(TestReceipt receipt) =>
      receipt.command.trim();

  /// The transition that re-binds a drifted receipt to the current bytes.
  ///
  /// A hand-delta receipt's own repro IS the prescription: it is the
  /// command that produced the drifted artifact (`zfa tdd verify-red U1
  /// --re-certify`, `zfa tdd make contract:A10 --born-green`) and it
  /// carries the behavior id, so it can be pasted as-is.
  ///
  /// A GENERATOR receipt is the exception on both counts: the TDD
  /// generation verbs stamp an id-less repro (`zfa tdd compose`) that
  /// cannot be pasted as-is, and re-running a generator over certified
  /// work destroys it (issue #1375). The behavior's own re-certification
  /// transition is named instead — the red re-certification for a TEST
  /// artifact, the born-green hand transition for a SUBJECT (a generator
  /// receipt owns both sides of a behavior).
  static String _receiptDriftPrescription(ReceiptRecord? record, String path) {
    if (record == null) return '';
    final behaviorId = _receiptBehaviorId(record);
    final feature = _receiptFeature(record);
    final command = record.receipt.command.trim();
    final repro = record.receipt.repro.trim();

    // A feature-scoped receipt (a plan/run receipt) names the feature,
    // not a behavior — the verb is re-run with the feature it was run
    // for.
    if (behaviorId.isEmpty) {
      if (feature.isEmpty) return '';
      if (command == 'tdd plan') return 'zfa tdd plan $feature';
      return 'zfa tdd run $feature';
    }

    // A hand-delta repro carries the behavior id (`zfa tdd verify-red U1
    // --re-certify`) and is the transition that re-binds the evidence —
    // but only when it really carries it: the generation verbs stamp an
    // id-less repro, and a generator re-drive is destructive anyway.
    if (!_isGeneratorCommand(command) &&
        !_isGeneratorRepro(repro) &&
        repro.contains(behaviorId)) {
      return repro;
    }

    return _isTestArtifact(path)
        ? 'zfa tdd verify-red $behaviorId --re-certify'
        : 'zfa tdd make $behaviorId --born-green';
  }

  /// The behavior a receipt belongs to — the receipt's own `behavior` input,
  /// else its target. A FEATURE-scoped receipt (a plan/run receipt) names
  /// the feature, not a behavior, and yields no behavior id.
  static String _receiptBehaviorId(ReceiptRecord record) {
    final behavior = record.receipt.input['behavior'];
    if (behavior is String && behavior.trim().isNotEmpty) {
      return behavior.trim();
    }
    final target = record.receipt.target.trim();
    if (target.isEmpty) return '';
    // A feature slug (`001-purchase-store`) is never a behavior id.
    if (RegExp(r'^\d+[-_]').hasMatch(target)) return '';
    return target;
  }

  /// True for a TEST artifact — the red side of a behavior. A subject (the
  /// green side) is anything else, and the two are re-bound by different
  /// transitions.
  static bool _isTestArtifact(String path) =>
      path.endsWith('_test.dart') ||
      path.contains('/test/') ||
      path.startsWith('test/');

  /// True for a reproduction command that re-drives the generator — the
  /// destructive remedy (issue #1375), never a prescription.
  static bool _isGeneratorRepro(String repro) =>
      RegExp(r'tdd gen(?![\w-])').hasMatch(repro);

  /// The TDD verbs that GENERATE an artifact. Their receipt's own repro is
  /// id-less (`zfa tdd compose`) — it cannot be pasted as-is — and
  /// re-running one over certified work destroys it (issue #1375), so a
  /// generator receipt's drift is re-bound by the behavior's own
  /// re-certification transition instead.
  static const Set<String> _generatorVerbs = {
    'tdd gen',
    'tdd compose',
    'tdd wire',
    'tdd func',
    'tdd view',
    'tdd plan',
  };

  /// True for a receipt whose command is a GENERATION verb.
  static bool _isGeneratorCommand(String command) {
    final trimmed = command.trim();
    for (final verb in _generatorVerbs) {
      if (trimmed == verb || trimmed.startsWith('$verb ')) return true;
    }
    return false;
  }

  /// Extract outer test titles (issue #1778): the strings passed to
  /// `test(...)` / `testWidgets(...)`, tolerant of escaped quotes.
  static List<String> _extractTestTitles(String content) {
    final titles = <String>[];
    final re = RegExp(
      r'''\btest(?:Widgets)?\s*\(\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")''',
    );
    for (final m in re.allMatches(content)) {
      var t = m.group(1) ?? m.group(2);
      if (t == null || t.isEmpty) continue;
      t = t
          .replaceAll(r"\'", "'")
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', r'\');
      // Note: unescape backslash-last ordering matches verify_red_command.
      if (!titles.contains(t)) titles.add(t);
    }
    return titles;
  }

  static String _shortDigest(String digest) =>
      digest.length <= 12 ? digest : digest.substring(0, 12);

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
    List<ArtifactRecord> droppedRecords,
  ) async {
    final auditFile = File(p.join(featureDir, 'tdd', 'audit.log'));
    await auditFile.parent.create(recursive: true);
    final line = jsonEncode({
      'at': DateTime.now().toUtc().toIso8601String(),
      'action': 'repair',
      'feature': featureName,
      'command': 'doctor',
      'dropped': droppedRecords.map((r) => r.behaviorId).toList(),
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
        // Issue #1495 review: `repaired` is a SUCCESS verdict — the GC
        // path exits 0, so the envelope must not gate it as fail.
        ..outcome = (verdict == 'healthy' || verdict == 'repaired')
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
