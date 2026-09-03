/// `zfa tdd corpus run` — drive every `ready` feature in the corpus
/// manifest through `zfa tdd run` then `zfa tdd verify`, in manifest
/// order (spec 051-corpus-harness, FR-001..FR-004).
///
/// The loop (mirroring `zfa tdd run`'s honesty rules one level up):
/// - Corpus progress persists after every feature; a run interrupted for
///   minutes or weeks resumes from the first non-done/waived feature and
///   never re-drives completed features.
/// - STOP-ON-ROADBLOCK (FR-002): any feature-level stop (run failure or
///   a non-passing verify gate without an exact-match waiver) halts the
///   whole run non-zero, appends a gap-ledger entry with the six FR-007
///   fields, and no later feature starts.
/// - A feature counts as corpus-done ONLY on a passing gate or an
///   explicit recorded waiver (reason + actor + timestamp) — never a
///   silent absorption (FR-004).
/// - Not-ready features are skipped and reported, never spawned
///   (FR-003); they block completion (reported, not driven).
/// - The runner writes only progress + ledger: never specs/, lib/,
///   test/, the manifest, waivers, or the carve-out.
///
/// Machine contract (FR-009/FR-010): every feature prints
/// `[corpus] <feature> <step> -> <outcome>`, and every invocation ends
/// with the final summary line
/// `corpus: features=<n> done=<n> waived=<n> stopped=<n> not_ready=<n>
/// pending=<n> dropped=<n> gaps=<n> result=<r>` plus ` stopped_at=<f>`
/// when stopped. Exit codes: 0 complete (every manifest feature done or
/// waived), 1 stopped/incomplete, 2 runner-error incl. no-manifest,
/// 3 corrupt-state, 4 concurrent-run.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../tdd_plugin.dart';
import '../models/corpus_ledger.dart';
import '../models/corpus_manifest.dart';
import '../models/corpus_plan.dart';
import '../models/corpus_progress.dart';
import '../services/budget_telemetry.dart';
import '../services/corpus_manifest_store.dart';
import '../services/corpus_progress_store.dart';
import '../services/corpus_sharder.dart';
import '../services/corpus_step_runner.dart';
import '../services/gap_ledger_store.dart';
import '../services/test_list_reader.dart';
import '../services/tdd_timeout.dart';
import '../../../core/project/project_root.dart';

class CorpusRunCommand extends Command<void> {
  CorpusRunCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root of the driven app (containing .zfa/, specs/, lib/). '
          'When omitted, the current working directory is used. The runner '
          'never mutates the process-global working directory.',
    );
    argParser.addOption(
      'zfa-bin',
      help:
          'Path to the zfa CLI entrypoint used to spawn the per-feature '
          '`tdd run` / `tdd verify` commands (defaults to this package\'s '
          'bin/zfa.dart). Point this at a scripted fake to drive the corpus '
          'against stubbed features.',
    );
    argParser.addOption(
      'timeout',
      valueHelp: 'minutes',
      help:
          'Hard deadline in minutes for each spawned per-feature command '
          '(bug #742; default 10). Fractions are allowed. On timeout the '
          'child is killed and the corpus stops with a runner-error.',
    );
    argParser.addOption(
      'shard',
      valueHelp: '<i>/<k>',
      help:
          'Shard the corpus lane (spec 069-corpus-economics, issue #916): '
          'drive ONLY the features of shard <i> of <k> (1-based, the CI '
          'matrix form). The assignment is deterministic round-robin over '
          'the manifest/plan order, so the k parallel lanes of a CI '
          'matrix cover every feature exactly once — the per-PR corpus '
          'lane stays ≤ 10 minutes. The verdict JSON records the shard.',
    );
    argParser.addOption(
      'concurrency',
      valueHelp: 'lanes',
      defaultsTo: '1',
      help:
          'Concurrent feature lanes INSIDE this invocation (spec 069): '
          'drive up to N features in parallel through a bounded worker '
          'pool. The default 1 is the strictly-sequential corpus '
          'contract (order preserved, STOP-ON-ROADBLOCK semantics '
          'unchanged — on a roadblock no NEW feature starts; in-flight '
          'features drain to completion and are recorded honestly).',
    );
    argParser.addOption(
      'plan',
      valueHelp: 'file',
      help:
          'Rewrite plan (bug #836): a markdown file whose `A -> B` / '
          '`A→B` lines declare dependency edges and whose '
          '`F001: FR-1, AC-2` lines declare per-feature criteria — or a '
          'TUPEC inventory.json (features[].id/name/dependencies/'
          'criteria). The manifest is topologically ordered by the '
          'declared edges before anything is driven; declared criteria '
          'without behaviors land in the gap ledger (the completeness '
          'proof). Plan errors (missing file, unknown feature, cycle) '
          'stop honestly with exit 2 and nothing driven.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'run';

  @override
  String get description =>
      'Drive every ready manifest feature through run then verify in '
      'manifest order, stopping on the first roadblock (spec 051, '
      'FR-001..FR-004).';

  @override
  String get invocation =>
      'zfa tdd corpus run [--project <dir>] [--zfa-bin <path>] '
      '[--plan <file>]';

  static const _exitComplete = 0;
  static const _exitStopped = 1;
  static const _exitRunnerError = 2;
  static const _exitCorruptState = 3;
  static const _exitConcurrentRun = 4;

  @override
  Future<void> run() async {
    final argResults = this.argResults;
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final zfaBin = argResults?['zfa-bin'] as String?;
    final planFlag = argResults?['plan'] as String?;

    // Spec 069: the shard spec (`--shard <i>/<k>`). A malformed value
    // stops honestly BEFORE anything is driven — a mistyped shard spec
    // would silently drive the WRONG lane.
    final (int, int)? shardSpec;
    try {
      shardSpec = CorpusSharder.parseShardSpec(argResults?['shard'] as String?);
    } on FormatException catch (e) {
      print('zfa tdd corpus run: ${e.message}');
      _printSummary(features: 0, result: 'runner-error');
      exitCode = _exitRunnerError;
      return;
    }

    // Spec 069: the in-process lane concurrency (`--concurrency n`).
    final concurrencyRaw = argResults?['concurrency'] as String?;
    var concurrency = 1;
    if (concurrencyRaw != null && concurrencyRaw.isNotEmpty) {
      final parsed = int.tryParse(concurrencyRaw);
      if (parsed == null || parsed < 1) {
        print(
          'zfa tdd corpus run: invalid --concurrency "$concurrencyRaw" — '
          'expected an integer >= 1.',
        );
        _printSummary(features: 0, result: 'runner-error');
        exitCode = _exitRunnerError;
        return;
      }
      concurrency = parsed;
    }

    // Bug #742: the --timeout override for each spawned per-feature command.
    final Duration? timeoutOverride;
    try {
      timeoutOverride = parseTddTimeoutMinutes(
        argResults?['timeout'] as String?,
      );
    } on TddTimeoutFormatException catch (e) {
      print('zfa tdd corpus run: ${e.message}');
      _printSummary(features: 0, result: 'runner-error');
      exitCode = _exitRunnerError;
      return;
    }

    final manifestStore = CorpusManifestStore(projectRoot);
    final progressStore = CorpusProgressStore(projectRoot);
    final ledgerStore = GapLedgerStore(projectRoot);

    // -----------------------------------------------------------------
    // 1. The manifest (no-manifest is the distinct runner-error class).
    // -----------------------------------------------------------------
    final CorpusManifest manifest;
    final List<CorpusWaiver> waivers;
    try {
      manifest = await manifestStore.readManifest();
      waivers = await manifestStore.readWaivers();
    } on CorpusManifestMissingException catch (e) {
      print('zfa tdd corpus run: ${e.message}');
      _printSummary(features: 0, result: 'no-manifest');
      exitCode = _exitRunnerError;
      return;
    } on CorpusCorruptException catch (e) {
      print('zfa tdd corpus run: ${e.message}');
      _printSummary(features: 0, result: 'corrupt-state');
      exitCode = _exitCorruptState;
      return;
    } on CorpusManifestException catch (e) {
      print('zfa tdd corpus run: ${e.message}');
      _printSummary(features: 0, result: 'corrupt-state');
      exitCode = _exitCorruptState;
      return;
    }

    // -----------------------------------------------------------------
    // 1b. The plan (--plan, bug #836): parse + topologically order the
    //     manifest BEFORE any state is touched. A plan error is the
    //     honest runner-error outcome (exit 2) with nothing driven.
    // -----------------------------------------------------------------
    CorpusPlan? plan;
    List<CorpusFeature> driveOrder = manifest.features;
    if (planFlag != null && planFlag.isNotEmpty) {
      final planFile = File(planFlag);
      if (!await planFile.exists()) {
        print(
          'zfa tdd corpus run: no corpus plan at $planFlag — pass the '
          'rewrite-plan.md (or TUPEC inventory.json) path via --plan.',
        );
        _printSummary(
          features: manifest.features.length,
          result: 'runner-error',
        );
        exitCode = _exitRunnerError;
        return;
      }
      try {
        plan = CorpusPlan.parse(await planFile.readAsString(), path: planFlag);
        driveOrder = CorpusPlan.orderManifest(manifest, plan);
        if (plan.features.isEmpty) {
          print(
            '[corpus] plan: no dependency edges declared — manifest '
            'order preserved',
          );
        } else {
          print(
            '[corpus] plan: ${plan.features.length} feature(s), '
            'order: ${driveOrder.map((f) => f.name).join(' -> ')}',
          );
        }
      } on CorpusPlanException catch (e) {
        print('zfa tdd corpus run: $e');
        _printSummary(
          features: manifest.features.length,
          result: 'runner-error',
        );
        exitCode = _exitRunnerError;
        return;
      }
    }

    // -----------------------------------------------------------------
    // 2. Acquire atomic ownership before inspecting the persisted
    //    marker. This closes the check-then-write race between two runs.
    // -----------------------------------------------------------------
    final CorpusOwnership? ownership;
    try {
      ownership = await progressStore.tryAcquireOwnership();
    } on IOException catch (e) {
      print('zfa tdd corpus run: cannot acquire corpus ownership: $e');
      _printSummary(features: manifest.features.length, result: 'runner-error');
      exitCode = _exitRunnerError;
      return;
    }
    if (ownership == null) {
      print('zfa tdd corpus run: another process owns this corpus run');
      _printSummary(
        features: manifest.features.length,
        result: 'concurrent-run',
      );
      exitCode = _exitConcurrentRun;
      return;
    }

    try {
      // Progress + ledger corruption stops before any feature is driven.
      final progress = await progressStore.load() ?? CorpusProgress();
      final refusal = progressStore.refusalReason(progress);
      if (refusal != null) {
        print('zfa tdd corpus run: $refusal');
        _printSummary(
          features: manifest.features.length,
          result: 'concurrent-run',
          progress: progress,
          manifest: manifest,
        );
        exitCode = _exitConcurrentRun;
        return;
      }
      await ledgerStore.load();

      // -----------------------------------------------------------------
      // 2b. Provenance drift gate (bug #836 remediation 2): a recorded
      //     spec hash that no longer matches specs/<f>/spec.md means the
      //     green evidence no longer binds to intent — stop with exit 3
      //     BEFORE anything is driven. Rows without a recorded hash
      //     (pre-#836 progress) never false-positive.
      // -----------------------------------------------------------------
      final drifted = await _driftedFeatures(projectRoot, progress);
      if (drifted.isNotEmpty) {
        for (final name in drifted) {
          final recorded = progress.features[name]?.specHash;
          final current = await _specHashFor(projectRoot, name);
          print(
            'zfa tdd corpus run: evidence drift on $name: '
            'specs/$name/spec.md changed after its green run '
            '(recorded ${_shortHash(recorded)}, now ${_shortHash(current)}) '
            '— the corpus evidence no longer binds to intent.',
          );
        }
        print(
          'zfa tdd corpus run: ${drifted.length} drifted feature(s); '
          'recovery: re-drive them (reset their corpus progress) or '
          'restore the spec — the run stopped before driving anything.',
        );
        _printSummary(
          features: manifest.features.length,
          result: 'corrupt-state',
          progress: progress,
          manifest: manifest,
        );
        exitCode = _exitCorruptState;
        return;
      }

      // -----------------------------------------------------------------
      // 2c. Plan-gap reconciliation (bug #836 remediation 3, plan mode):
      //     every declared criterion without a behavior lands in the
      //     ledger (append-only, deduped across resumes); a criterion
      //     that became covered resolves its open gap (a NEW entry).
      //     The ledger IS the completeness proof.
      // -----------------------------------------------------------------
      if (plan != null) {
        await _reconcilePlanGaps(
          plan: plan,
          projectRoot: projectRoot,
          ledgerStore: ledgerStore,
        );
      }

      final manifestNames = manifest.features.map((f) => f.name).toSet();
      print(
        'zfa tdd corpus run: ${manifest.features.length} feature(s) '
        '(${manifest.features.where((f) => !f.ready).length} not-ready)',
      );

      // -----------------------------------------------------------------
      // 3. Drive in plan/topological order when --plan is given (bug
      //    #836), else manifest order (FR-001); STOP-ON-ROADBLOCK
      //    (FR-002). Spec 069: the order may be scoped to ONE shard
      //    lane (--shard i/k, deterministic round-robin) and driven
      //    through a bounded worker pool (--concurrency n, default 1 =
      //    the strictly-sequential contract).
      // -----------------------------------------------------------------
      var laneOrder = driveOrder;
      if (shardSpec != null) {
        final (lane, lanes) = shardSpec;
        final names = driveOrder.map((f) => f.name).toList();
        final laneNames = const CorpusSharder().shardLane(
          features: names,
          shardCount: lanes,
          shardIndex: lane - 1,
        );
        final laneSet = laneNames.toSet();
        laneOrder = driveOrder.where((f) => laneSet.contains(f.name)).toList();
        print(
          '[corpus] shard $lane/$lanes: ${laneOrder.length} of '
          '${driveOrder.length} feature(s) in this lane [069]',
        );
      }
      if (concurrency > 1) {
        print(
          '[corpus] concurrency: $concurrency feature lane(s) in '
          'process [069]',
        );
      }
      final runner = CorpusStepRunner(zfaBin: zfaBin, timeout: timeoutOverride);
      String? stoppedAtFeature;

      // Spec 069 budget telemetry: wall-clock per step kind, suite
      // seconds, mutant count — MEASURED around the real spawns and
      // written into the lane's verdict JSON.
      final telemetry = BudgetTelemetry();
      // The ledger store is load->append->persist: concurrent roadblock
      // bookkeeping is serialized through this lock so no gap entry is
      // lost (append-only contract).
      var ledgerLock = Future<void>.value();
      Future<void> serializedStop(void Function() stop) async {
        final pending = ledgerLock.then((_) => stop());
        ledgerLock = pending.catchError((_) {});
        await pending;
      }

      // The progress store's temp+rename save uses ONE fixed tmp path:
      // concurrent saves from parallel lanes would race the rename (a
      // PathNotFoundException aborting the lane). Serialized through
      // this lock every save stays atomic AND every mutation order is
      // preserved (the shared progress object is only mutated between
      // awaits, so each serialized save carries all applied mutations).
      var persistLock = Future<void>.value();
      Future<void> persist() {
        final pending = persistLock.then(
          (_) =>
              progressStore.save(progress, manifestFeatureNames: manifestNames),
        );
        persistLock = pending.catchError((_) {});
        return pending;
      }

      Future<void> driveOne(CorpusFeature feature) async {
        final name = feature.name;
        final existing = progress.features[name];

        // Resume: done/waived features are never re-driven (US1.AC2).
        if (existing?.state == FeatureCorpusState.done ||
            existing?.state == FeatureCorpusState.waived) {
          return;
        }

        // Not-ready: skipped and reported, never spawned (FR-003).
        if (!feature.ready) {
          print(
            '[corpus] $name not-ready (${feature.reason.isEmpty ? 'no reason recorded' : feature.reason}) '
            '-- skipped, never driven',
          );
          return;
        }

        // mark -> save -> spawn -> advance -> save: an interruption loses
        // at most the in-flight feature (the 049 contract, one level up).
        progress.updateFeature(
          name,
          FeatureProgress(state: FeatureCorpusState.driving),
        );
        progress.inFlight = CorpusInFlight(feature: name, ownerPid: pid);
        await persist();

        // --- zfa tdd run <feature> ---
        final runWatch = Stopwatch()..start();
        final runResult = await runner.runFeature(
          feature: name,
          projectRoot: projectRoot,
        );
        runWatch.stop();
        telemetry.wallClock.addDuration('run', runWatch.elapsed);
        telemetry.addSuiteSeconds(runWatch.elapsed.inMilliseconds / 1000);
        print('[corpus] $name run -> ${runResult.outcome}');
        if (!runResult.success) {
          final stoppedAtParts = runResult.stoppedAt?.split(':');
          await serializedStop(
            () => _stopAtFeature(
              feature: name,
              step: stoppedAtParts != null && stoppedAtParts.length > 1
                  ? stoppedAtParts[1]
                  : 'run',
              outcome: runResult.outcome,
              expectedResult: 'complete',
              stoppedAt: runResult.stoppedAt,
              gate: null,
              failingCommand: _runCommand(name, projectRoot),
              output: runResult.output,
              progress: progress,
              ledgerStore: ledgerStore,
              persist: persist,
            ),
          );
          stoppedAtFeature ??= name;
          return;
        }

        // --- zfa tdd verify --feature <feature> ---
        final verifyWatch = Stopwatch()..start();
        final verifyResult = await runner.verifyFeature(
          feature: name,
          projectRoot: projectRoot,
        );
        verifyWatch.stop();
        telemetry.wallClock.addDuration('verify', verifyWatch.elapsed);
        telemetry.addSuiteSeconds(verifyWatch.elapsed.inMilliseconds / 1000);
        final mutants = _mutantsOf(verifyResult);
        if (mutants != null) telemetry.addMutants(mutants);
        print('[corpus] $name verify -> ${verifyResult.outcome}');

        if (verifyResult.success) {
          progress.updateFeature(
            name,
            FeatureProgress(
              state: FeatureCorpusState.done,
              gate: 'pass',
              specHash: await _specHashFor(projectRoot, name),
            ),
          );
          print('[corpus] $name -> done (gate: pass)');
          // A previously-gapped feature passing records the resolution as
          // NEW ledger entries — history is never edited (US4.AC2).
          await serializedStop(
            () => _appendResolutionsIfGapped(
              feature: name,
              ledgerStore: ledgerStore,
            ),
          );
        } else {
          // Exact-match waiver only (FR-004): a waiver for a different
          // gate outcome never absorbs this failure.
          final waiver = waivers
              .where((w) => w.feature == name && w.gate == verifyResult.outcome)
              .firstOrNull;
          if (waiver != null) {
            progress.updateFeature(
              name,
              FeatureProgress(
                state: FeatureCorpusState.waived,
                gate: verifyResult.outcome,
                waiver: waiver,
                specHash: await _specHashFor(projectRoot, name),
              ),
            );
            print(
              '[corpus] $name -> waived (gate: ${verifyResult.outcome}; '
              'reason: ${waiver.reason}; by ${waiver.actor} at ${waiver.at})',
            );
          } else {
            await serializedStop(
              () => _stopAtFeature(
                feature: name,
                step: 'verify',
                outcome: verifyResult.outcome,
                expectedResult: 'pass',
                stoppedAt: 'gate:${verifyResult.outcome}',
                gate: verifyResult.outcome,
                failingCommand: _verifyCommand(name, projectRoot),
                output: verifyResult.output,
                progress: progress,
                ledgerStore: ledgerStore,
                persist: persist,
              ),
            );
            stoppedAtFeature ??= name;
            return;
          }
        }
        progress.inFlight = null;
        await persist();
      }

      // The bounded worker pool: worker() claims the next feature until
      // the queue drains or a roadblock stops new lanes (in-flight
      // features drain to completion). With concurrency 1 this is
      // EXACTLY the sequential contract (order preserved).
      var next = 0;
      var noNewLanes = false;
      Future<void> worker() async {
        while (true) {
          if (noNewLanes || next >= laneOrder.length) return;
          final feature = laneOrder[next++];
          await driveOne(feature);
          if (stoppedAtFeature != null) noNewLanes = true;
        }
      }

      final workerCount = concurrency > laneOrder.length || laneOrder.isEmpty
          ? concurrency.clamp(0, laneOrder.isEmpty ? 1 : laneOrder.length)
          : concurrency;
      final workers = List.generate(
        workerCount == 0 ? 1 : workerCount,
        (_) => worker(),
        growable: false,
      );
      await Future.wait(workers);
      // Let a failed worker's stop bookkeeping settle before reporting.
      await ledgerLock;

      // -----------------------------------------------------------------
      // 4. Final report + the machine summary line (FR-008/FR-009).
      // -----------------------------------------------------------------
      final ledger = await _loadLedger(ledgerStore);
      final doneFeatures = progress.features.entries
          .where(
            (e) =>
                e.value.state == FeatureCorpusState.done ||
                e.value.state == FeatureCorpusState.waived,
          )
          .map((e) => e.key)
          .toSet();
      final totals = GapLedgerTotals.fromEntries(
        ledger,
        doneFeatures: doneFeatures,
      );

      _printReport(manifest: manifest, progress: progress, totals: totals);
      // Spec 069: a sharded lane's completeness is LANE-scoped — every
      // ready feature of THIS lane done/waived. The other lanes are
      // other CI jobs' business; a lane reporting `complete` means its
      // own slice is proven, and the matrix union is the full corpus.
      final completionScope = shardSpec != null ? laneOrder : manifest.features;
      final scopeComplete = _scopeComplete(completionScope, progress);
      final openGapRefusal = totals.open.isNotEmpty;
      final result = stoppedAtFeature != null
          ? 'stopped'
          : scopeComplete && !openGapRefusal
          ? 'complete'
          : 'incomplete';
      if (scopeComplete && openGapRefusal) {
        // Bug #846: every feature done/waived is NOT enough — the corpus
        // refuses a `complete` verdict while open gaps exist in the
        // ledger (a done feature's gap is reported, never absorbed).
        print(
          '   open gaps: ${totals.open.length} — corpus refuses '
          '`complete` while gaps are open:',
        );
        for (final gap in totals.open) {
          print(
            '   open gap: ${gap.id} ${gap.feature} ${gap.step} '
            '${gap.outcome}',
          );
        }
      }
      // Spec 069: the budget-telemetry verdict JSON — where the lane's
      // minutes went (wall-clock per step, suite seconds, mutants),
      // machine-readable for CI budget dashboards. Written BEFORE the
      // machine summary line so the summary stays the FINAL stdout
      // line (FR-009).
      final verdictPath = p.join(projectRoot, '.zfa', 'corpus', 'verdict.json');
      try {
        final verdictFile = File(verdictPath);
        await verdictFile.parent.create(recursive: true);
        final tmp = File('${verdictFile.path}.tmp');
        await tmp.writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'result': result,
            'shard': shardSpec != null
                ? '${shardSpec.$1}/${shardSpec.$2}'
                : null,
            'concurrency': concurrency,
            'features': {
              'manifest': manifest.features.length,
              'lane': laneOrder.length,
              'done': progress.features.values
                  .where((f) => f.state == FeatureCorpusState.done)
                  .length,
              'waived': progress.features.values
                  .where((f) => f.state == FeatureCorpusState.waived)
                  .length,
            },
            'stopped_at': stoppedAtFeature,
            'gaps': totals.found,
            'budget': telemetry.toJson(),
          }),
        );
        await tmp.rename(verdictFile.path);
        print(
          '   verdict: $verdictPath (budget telemetry [069]: '
          'wall_clock_ms=${telemetry.wallClock.millisOf('run') + telemetry.wallClock.millisOf('verify')} '
          'suite_seconds=${telemetry.suiteSeconds} '
          'mutants=${telemetry.mutantCount})',
        );
      } on IOException catch (e) {
        // The verdict is telemetry, never a gate: an unwritable verdict
        // file must not fail an otherwise-proven lane.
        print('   verdict: could not write $verdictPath ($e) [069]');
      }

      _printSummary(
        features: manifest.features.length,
        result: result,
        progress: progress,
        manifest: manifest,
        gaps: totals.found,
        stoppedAt: stoppedAtFeature,
        order: plan != null ? 'topological' : null,
        shard: shardSpec != null ? '${shardSpec.$1}/${shardSpec.$2}' : null,
      );

      exitCode = result == 'complete' ? _exitComplete : _exitStopped;
    } on CorpusCorruptException catch (e) {
      print('zfa tdd corpus run: ${e.message}');
      _printSummary(
        features: manifest.features.length,
        result: 'corrupt-state',
      );
      exitCode = _exitCorruptState;
    } finally {
      await ownership.release();
    }
  }

  /// Every feature in [scope] is done or waived (not-ready features
  /// block completion — they are reported, never silently absorbed).
  /// The scope is the whole manifest (unsharded) or ONE shard's lane
  /// (spec 069: lane-scoped completeness). The open ledger gap refusal
  /// (bug #846) is applied by the caller on top of this check.
  static bool _scopeComplete(
    List<CorpusFeature> scope,
    CorpusProgress progress,
  ) {
    for (final feature in scope) {
      if (!feature.ready) return false;
      final state = progress.features[feature.name]?.state;
      if (state != FeatureCorpusState.done &&
          state != FeatureCorpusState.waived) {
        return false;
      }
    }
    return true;
  }

  /// The assessed mutant count of a verify step's mutation summary
  /// (`killed` + `survived` + `timed_out`), or null when the step
  /// produced no parseable mutation counters (spec 069 budget
  /// telemetry — the verdict's `mutant_count`).
  static int? _mutantsOf(CorpusStepResult result) {
    final fields = result.summaryFields;
    int? parse(String key) {
      if (!fields.containsKey(key)) return null;
      return int.tryParse(fields[key]!);
    }

    final killed = parse('killed');
    final survived = parse('survived');
    final timedOut = parse('timed_out');
    if (killed == null && survived == null && timedOut == null) return null;
    return (killed ?? 0) + (survived ?? 0) + (timedOut ?? 0);
  }

  /// STOP-ON-ROADBLOCK bookkeeping (FR-002 + FR-007): ledger entry,
  /// stopped progress state, in-flight cleared, persist.
  Future<void> _stopAtFeature({
    required String feature,
    required String step,
    required String outcome,
    required String expectedResult,
    required String? stoppedAt,
    required String? gate,
    required String failingCommand,
    required String output,
    required CorpusProgress progress,
    required GapLedgerStore ledgerStore,
    required Future<void> Function() persist,
  }) async {
    final behavior = stoppedAt?.contains(':') == true
        ? stoppedAt!.split(':').first
        : null;
    await ledgerStore.appendGap(
      feature: feature,
      behavior: behavior,
      step: step,
      outcome: outcome,
      expectedResult: expectedResult,
      failingCommand: failingCommand,
    );
    progress.updateFeature(
      feature,
      FeatureProgress(
        state: FeatureCorpusState.stopped,
        gate: gate,
        stoppedAt: stoppedAt,
      ),
    );
    progress.inFlight = null;
    await persist();
    print('zfa tdd corpus run: stopped at $feature ($step: $outcome)');
    print('   ${_firstLines(output, 3)}');
    print('   resume: fix the roadblock, then re-run `zfa tdd corpus run`');
  }

  /// Resolution entries for a previously-gapped feature that just passed
  /// (US4.AC2): one NEW entry per unresolved gap, never an edit. Plan-gap
  /// entries (step=plan, bug #836) are excluded: they resolve by the
  /// criterion becoming covered (reconciliation at 2c), not by the
  /// feature completing — a done feature with a still-missing behavior
  /// stays honestly gapped.
  Future<void> _appendResolutionsIfGapped({
    required String feature,
    required GapLedgerStore ledgerStore,
  }) async {
    final ledger = await _loadLedger(ledgerStore);
    final resolvedIds = ledger
        .where((e) => e.kind == GapLedgerKind.resolution)
        .map((e) => e.resolves)
        .whereType<String>()
        .toSet();
    for (final gap in ledger) {
      if (gap.kind != GapLedgerKind.gap) continue;
      if (gap.feature != feature) continue;
      if (gap.step == 'plan') continue;
      if (gap.status == 'resolved' || gap.status == 'merged') continue;
      if (resolvedIds.contains(gap.id)) continue;
      await ledgerStore.appendResolution(feature: feature, resolves: gap.id);
      print('[corpus] $feature gap ${gap.id} resolved (new ledger entry)');
    }
  }

  /// The done/waived features whose recorded spec hash no longer matches
  /// the current `specs/<f>/spec.md` (bug #836 remediation 2). Features
  /// without a recorded hash (pre-#836 progress) are never drift.
  static Future<List<String>> _driftedFeatures(
    String projectRoot,
    CorpusProgress progress,
  ) async {
    final drifted = <String>[];
    for (final entry in progress.features.entries) {
      final state = entry.value.state;
      if (state != FeatureCorpusState.done &&
          state != FeatureCorpusState.waived) {
        continue;
      }
      final recorded = entry.value.specHash;
      if (recorded == null) continue;
      final current = await _specHashFor(projectRoot, entry.key);
      if (current != null && current != recorded) {
        drifted.add(entry.key);
      }
    }
    return drifted;
  }

  /// The sha256 of `specs/<feature>/spec.md` (the intent the green run
  /// binds to), null when the feature has no spec file.
  static Future<String?> _specHashFor(
    String projectRoot,
    String feature,
  ) async {
    final file = File(p.join(projectRoot, 'specs', feature, 'spec.md'));
    if (!await file.exists()) return null;
    return crypto.sha256.convert(await file.readAsBytes()).toString();
  }

  static String _shortHash(String? hash) {
    if (hash == null || hash.length < 8) return hash ?? '(none)';
    return '${hash.substring(0, 8)}…';
  }

  /// Plan-gap reconciliation (bug #836 remediation 3): for every plan
  /// criterion, compare against the trace tokens of the feature's
  /// `tdd/test-list.md` rows (the TestListReader single format contract).
  /// Uncovered + no open entry → append a gap entry
  /// (`step=plan`, `outcome=missing_behavior`, `expected_result=behavior`).
  /// Covered + open entry → append a resolution (never an edit). Covered
  /// + no entry and uncovered + open entry are no-ops (dedupe keeps the
  /// append-only ledger stable across resume runs).
  Future<void> _reconcilePlanGaps({
    required CorpusPlan plan,
    required String projectRoot,
    required GapLedgerStore ledgerStore,
  }) async {
    final ledger = await _loadLedger(ledgerStore);
    final openPlanGaps = <String, GapLedgerEntry>{};
    for (final entry in ledger) {
      if (entry.kind != GapLedgerKind.gap) continue;
      if (entry.step != 'plan') continue;
      if (entry.status == 'resolved' || entry.status == 'merged') continue;
      openPlanGaps['${entry.feature}|${entry.behavior}'] = entry;
    }
    final resolvedIds = ledger
        .where((e) => e.kind == GapLedgerKind.resolution)
        .map((e) => e.resolves)
        .whereType<String>()
        .toSet();

    for (final row in plan.features) {
      if (row.criteria.isEmpty) continue;
      final covered = await _coveredCriteria(projectRoot, row.name);
      for (final criterion in row.criteria) {
        final key = '${row.name}|$criterion';
        final open = openPlanGaps[key];
        if (covered.contains(criterion)) {
          if (open != null && !resolvedIds.contains(open.id)) {
            await ledgerStore.appendResolution(
              feature: row.name,
              resolves: open.id,
            );
            print(
              '[corpus] plan-gap ${open.id} resolved: $key has a behavior '
              '(new ledger entry)',
            );
          }
        } else if (open == null) {
          final entry = await ledgerStore.appendGap(
            feature: row.name,
            behavior: criterion,
            step: 'plan',
            outcome: 'missing_behavior',
            expectedResult: 'behavior',
          );
          print(
            '[corpus] plan-gap ${entry.id}: $key declares $criterion but '
            'no behavior traces to it (gap ledger)',
          );
        }
      }
    }
  }

  /// The trace tokens of [feature]'s test-list rows (uppercase, split on
  /// commas/whitespace); empty when the feature has no (readable) test
  /// list — every declared criterion is then honestly uncovered.
  static Future<Set<String>> _coveredCriteria(
    String projectRoot,
    String feature,
  ) async {
    final reader = TestListReader(p.join(projectRoot, 'specs', feature));
    final List<BehaviorRow> rows;
    try {
      rows = await reader.read();
    } on TestListReadException {
      return const {};
    }
    final tokens = <String>{};
    for (final row in rows) {
      for (final token in row.traces.split(RegExp(r'[,\s]+'))) {
        final normalized = token.trim().toUpperCase();
        if (normalized.isNotEmpty) tokens.add(normalized);
      }
    }
    return tokens;
  }

  static Future<List<GapLedgerEntry>> _loadLedger(GapLedgerStore store) =>
      store.load();

  static String _runCommand(String feature, String projectRoot) =>
      'zfa tdd run $feature --project $projectRoot';

  static String _verifyCommand(String feature, String projectRoot) =>
      'zfa tdd verify --feature $feature --project $projectRoot';

  static String _firstLines(String output, int count) {
    final lines = output
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .take(count);
    return lines.isEmpty ? '(no output)' : lines.join(' | ');
  }

  /// The human report above the summary line (US4.AC3, FR-008).
  void _printReport({
    required CorpusManifest manifest,
    required CorpusProgress progress,
    required GapLedgerTotals totals,
  }) {
    final done = <String>[];
    final waived = <String>[];
    final stopped = <String>[];
    final pending = <String>[];
    final notReady = <String>[];
    for (final feature in manifest.features) {
      final state = progress.features[feature.name]?.state;
      switch (state) {
        case FeatureCorpusState.done:
          done.add(feature.name);
        case FeatureCorpusState.waived:
          waived.add(feature.name);
        case FeatureCorpusState.stopped:
          stopped.add(feature.name);
        case null:
        case FeatureCorpusState.pending:
        case FeatureCorpusState.driving:
          if (!feature.ready) {
            notReady.add('${feature.name} (${feature.reason})');
          } else {
            pending.add(feature.name);
          }
      }
    }
    print('--- corpus report ---');
    if (done.isNotEmpty) print('   done (${done.length}): ${done.join(', ')}');
    if (waived.isNotEmpty) {
      print('   waived (${waived.length}):');
      for (final name in waived) {
        final w = progress.features[name]?.waiver;
        print(
          '      $name — ${w?.gate ?? '?'}: ${w?.reason ?? '?'} '
          '(by ${w?.actor ?? '?'}, at ${w?.at ?? '?'})',
        );
      }
    }
    if (stopped.isNotEmpty) {
      print('   stopped (${stopped.length}): ${stopped.join(', ')}');
    }
    if (notReady.isNotEmpty) {
      print('   not-ready (${notReady.length}): ${notReady.join(', ')}');
    }
    if (pending.isNotEmpty) {
      print('   pending (${pending.length}): ${pending.join(', ')}');
    }
    if (progress.dropped.isNotEmpty) {
      print(
        '   dropped (${progress.dropped.length}): ${progress.dropped.join(', ')}',
      );
    }
    print(
      '   ledger: found=${totals.found} filed=${totals.filed} '
      'merged=${totals.merged} blocking=${totals.blocking.length}',
    );
    for (final gap in totals.blocking) {
      print(
        '   blocking: ${gap.id} ${gap.feature} ${gap.step} ${gap.outcome}'
        '${gap.behavior != null ? ' (${gap.behavior})' : ''}',
      );
    }
  }

  void _printSummary({
    required int features,
    required String result,
    CorpusProgress? progress,
    CorpusManifest? manifest,
    int gaps = 0,
    String? stoppedAt,
    String? order,
    String? shard,
  }) {
    var done = 0;
    var waived = 0;
    var stopped = 0;
    var notReady = 0;
    var pending = 0;
    if (manifest != null) {
      for (final feature in manifest.features) {
        final state = progress?.features[feature.name]?.state;
        if (!feature.ready) {
          notReady++;
        } else {
          switch (state) {
            case FeatureCorpusState.done:
              done++;
            case FeatureCorpusState.waived:
              waived++;
            case FeatureCorpusState.stopped:
              stopped++;
            case null:
            case FeatureCorpusState.pending:
            case FeatureCorpusState.driving:
              pending++;
          }
        }
      }
    }
    final dropped = progress?.dropped.length ?? 0;
    print(
      'corpus: features=$features done=$done waived=$waived stopped=$stopped '
      'not_ready=$notReady pending=$pending dropped=$dropped gaps=$gaps '
      'result=$result'
      '${stoppedAt != null ? ' stopped_at=$stoppedAt' : ''}'
      '${order != null ? ' order=$order' : ''}'
      '${shard != null ? ' shard=$shard' : ''}',
    );
  }
}
