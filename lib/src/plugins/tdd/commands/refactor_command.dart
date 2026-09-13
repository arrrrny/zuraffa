/// `zfa tdd refactor` — green-only refactoring step of the TDD loop
/// (spec 048-tdd-refactor, FR-001..010; 041 Phase 9, T066-T069).
///
/// The command:
///   1. Resolves the project root from `--project` (else cwd) and the
///      feature from `--feature` (else scans `specs/`).
///   2. Loads the `suite` command template from
///      `.specify/memory/tdd-profile.md` (FR-001) and runs the full suite
///      as the absolute preflight — refusing on any red (FR-001), with no
///      `--skip-preflight` option (FR-002).
///   3. Captures a before snapshot of `test/` and `lib/` for the
///      post-pass immutability and attribution checks.
///   4. Runs the fixed pass registry (the resolved zfa build, `dart format
///      lib/`, `dart fix --apply lib/`) via [RefactorPasses]. Each pass is
///      recorded with its exact command, exit code, and filesChanged
///      (FR-003, FR-005). Misfire-stop on any failing pass (FR-010).
///   5. After all passes, asserts `test/` is byte-identical (FR-004) and
///      every changed `lib/` path is attributable to a recorded action
///      (FR-005). Either violation is a hard failure.
///   6. Re-runs the suite; on regression exits non-zero naming the
///      regressed tests (FR-006). On green, appends a refactor-evidence
///      entry to `tdd/cycle-log.md` (FR-007) — or a clean no-op entry
///      when no pass changed anything (FR-008).
///   7. Prints the machine-readable summary line
///      `refactor: feature=<f> outcome=<o> applied=<n>` as the final stdout
///      line on every code path (FR-009); exit code 0 means exactly
///      "green before and after".
///
/// Spec 1520 — per-run scratch TMPDIR. The command acquires ONE scratch dir
/// per invocation and hands it to the preflight/re-proof suite runs and the
/// pass registry, so every `dart test`/`dart` child of the cycle writes its
/// kernel and dill temp files inside the run's own scratch instead of the
/// shared user TMPDIR; the scratch is deleted recursively in a `finally`
/// (the #1507 leak fixed by construction, in the command whose loops ran
/// longest). Best-effort: a scratchless run always beats a failed one.
///
/// Issue #922 — pre-existing red and the run's done gate. When the driving
/// `zfa tdd run` hands its cached full-suite baseline
/// (`--suite-baseline run-baseline.json`, the issue #741 cache) to a
/// spawned refactor, the preflight and re-proof verdicts exclude the
/// baseline's pre-existing failures: only NEW failures refuse or classify
/// as a regression. A suite that is red ONLY from failures the baseline
/// already recorded (unrelated files that cannot even load, tolerated
/// U16-style the way make treats them) no longer blocks the run's done
/// transition, and the evidence entry names the tolerated red honestly.
/// The flag-less standalone command keeps the absolute-green contract
/// (FR-001) unchanged, and a missing/corrupt cache falls back to it
/// safely — the exclusion can never turn an unparseable red into a pass.
///
/// Issue #1333 — transient runner failures are NOT regressions. A re-proof
/// that fails through the dart test runner's own infrastructure (the
/// incremental kernel-cache race: exit 255, "Cannot retrieve length of
/// file ... dart_test.kernel...", ENOENT) is classified INFRA, retried up
/// to two times with the kernel cache cleared, and — when the retries are
/// exhausted — reported as `runner-error`, never `regression`: a crashed
/// runner cannot certify a regression any more than it can certify a
/// pass. Every re-proof verdict (green, tolerated, regression,
/// infra-exhausted, timeout) appends its verdict line (verdict + exit
/// code), the retry count, and a truncated transcript tail to the
/// feature's `tdd/cycle-log.md`, so a false regression is auditable
/// instead of silent.
///
/// Issue #1588 — batch economics and the parked-behavior exemption. The
/// driving run's phase-2 refactor pass hands this command two driver-only
/// flags. `--pass-batch` opts the invocation into the feature pass-batch
/// ledger (`tdd/pass-batch.json`, [PassBatchLedger]): a later invocation
/// of the SAME batch on a byte-identical lib/ + test/ tree under the same
/// suite configuration (the repo-root `dart_test.yaml`/`pubspec.lock` the
/// ledger also keys on) inherits the gate a previous invocation proved —
/// no preflight, no pass registry, no re-proof — so N green behaviors
/// cost ONE pipeline instead of N (the #741 economics, finally extended
/// to the refactor pass). `--full-reproof` never inherits: an explicit
/// request for the strongest proof is always answered by running it. A
/// flag-less standalone refactor never reads or writes the ledger: the
/// absolute-green contract (spec 048 FR-001) stands. `--exempt-behaviors
/// <ids>` excludes the named behaviors' registered tests from the
/// preflight/re-proof failing sets — the lane's parked BLOCKED contracts
/// (issue #1007/#1544) whose red tests are the designed park state, not
/// this feature's doing, and which the #922 baseline cannot know (gen
/// created their tests after the baseline capture). When the feature has
/// a run state, the ids are cross-checked against its blocked entries —
/// the designed park is the exemption's whole justification — while a
/// missing or unreadable state keeps the ids as handed (fail-open: the
/// flag is driver-only). Every non-exempt failure still refuses; an id
/// with no registered artifact is ignored (fail-open); the exclusion is
/// named in the output and the evidence entry instead of silently
/// claiming green.
///
/// Rejections and misfires are signaled through dart:io `exitCode` (which
/// [CliRunner] honors) rather than by throwing, so the summary line stays
/// the final stdout line.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/artifact_registry.dart';
import '../services/cycle_log.dart';
import '../services/feature_path_resolver.dart';
import '../services/kernel_cache.dart';
import '../services/pass_batch_ledger.dart';
import '../services/pass_registry_tracker.dart';
import '../services/refactor_passes.dart';
import '../services/refactor_receipt_refresh.dart';
import '../services/reproof_failure_classifier.dart';
import '../services/run_baseline_cache.dart';
import '../services/run_state_store.dart';
import '../services/runner.dart';
import '../services/scratch_tmpdir.dart';
import '../services/subject_evidence_refresh.dart';
import '../services/suite_guard.dart';
import '../services/tdd_profile_keys.dart';
import '../services/tdd_timeout.dart';
import '../services/tree_snapshot.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class RefactorCommand extends Command<void> {
  RefactorCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 048-tdd-refactor). Selects the cycle-log under '
          'specs/<feature>/tdd/. When omitted, the command infers the '
          'feature from the unique specs/ directory that has a tdd/ '
          'subdirectory, or falls back to "default" when none exists.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, lib/, and .specify/ (the '
          'fixture or target project). When omitted, the current working '
          'directory is used. Tests pass the temp fixture root here instead '
          'of mutating Directory.current, which is process-global and '
          'unsafe under concurrent test execution.',
    );
    argParser.addOption(
      'zfa-bin',
      help:
          'Path to the zfa entrypoint the build pass invokes (bug #689). '
          'When omitted, the entrypoint resolves the same way make/gen/verify '
          'resolve it: the running CLI from source, then the system zfa on '
          'PATH, then the dart+script fallback — never a hardcoded '
          'bin/zfa.dart, which zfa setup does not create.',
    );
    argParser.addOption(
      'suite-baseline',
      valueHelp: 'path',
      help:
          'Path to a cached full-suite baseline snapshot (run-baseline.json) '
          'from the driving `zfa tdd run` (issue #922). When given AND the '
          'cache is usable, the preflight and re-proof exclude the '
          "baseline's pre-existing failures from their green verdicts — "
          'only NEW failures refuse — so pre-existing red in unrelated '
          'files cannot block the run\'s done transition. Without it the '
          'absolute-green contract applies (spec 048 FR-001). A missing or '
          'corrupt cache falls back to the absolute-green contract safely.',
    );
    argParser.addMultiOption(
      'parked-seam',
      valueHelp: 'path',
      help:
          'A parked contract\'s seam test file (project-relative) whose '
          'suite failure the preflight and re-proof tolerate (issue #1589). '
          'The driving run hands the seams it knows are parked — the BLOCKED '
          'verdict\'s failing contract test is a KNOWN red for the whole '
          'pass (pre-existing-failure economics, the same discipline issue '
          '#922 gave the baseline), so it cannot refuse or regress the '
          'phase-2 refactors of the behaviors that ARE green. Repeatable. '
          'A NEW failure in any other file still refuses, an unparseable '
          'transcript still fails closed, and without the flag the '
          'absolute-green contract applies (spec 048 FR-001).',
    );
    argParser.addOption(
      'timeout',
      valueHelp: 'minutes',
      help:
          'Hard deadline in minutes for the preflight/re-proof suite and each '
          'pass process (bug #742; default 10). Fractions are allowed. On '
          'timeout the child is killed and the command stops non-zero as '
          'runner-error.',
    );
    argParser.addFlag(
      'full-reproof',
      help:
          'Force the FULL-suite re-proof even when the pass-registry-'
          'changed files map to covering tests (spec 069 T001: the '
          'feature-completion / nightly full gate; the default re-proof '
          'is scoped to the covering tests of the changed files).',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addFlag(
      'pass-batch',
      help:
          'Driver-only opt-in to the feature pass-batch ledger (issue '
          '#1588). When the driving `zfa tdd run`\'s phase-2 refactor pass '
          'hands this flag, the command records the gate it proved '
          '(suite template, baseline content, suite configuration, '
          'exempt set, lib/ + test/ tree digests) in '
          'specs/<feature>/tdd/pass-batch.json, and a later invocation '
          'of the SAME batch on a byte-identical tree under the same '
          'configuration inherits it — no preflight, no pass registry, no '
          're-proof. A --full-reproof invocation never inherits: an '
          'explicit request for the strongest proof always runs the full '
          'pipeline. A flag-less standalone refactor never reads or '
          'writes the ledger: the absolute-green contract (spec 048 '
          'FR-001) stands.',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addOption(
      'exempt-behaviors',
      valueHelp: 'ids',
      help:
          'Comma-separated behavior ids whose registered tests are EXEMPT '
          'from the gate (issue #1588). The driving run hands the lane\'s '
          'parked BLOCKED contracts here: their red tests on disk are the '
          'designed park state (#1007/#1544), not this feature\'s doing, '
          'and must not poison every refactor preflight — the baseline '
          'cannot know them (gen created their tests after the #741 '
          'baseline capture). The exemption removes only the registered '
          'tests of the named behaviors from the preflight/re-proof '
          'failing sets; every other failure still refuses, and an id '
          'with no registered artifact is ignored (fail-open). When the '
          'feature has a run state, an id it does not record as blocked '
          'is ignored too (no state → the ids stand as handed). Without '
          'the flag the gate is unchanged.',
    );
    // Note (FR-002): there is INTENTIONALLY no --skip-preflight option.
    // The preflight is the entire discipline of the refactor step; skipping
    // it would destroy the signal that makes refactoring safe. The
    // --pass-batch ledger narrows nothing: it only lets a LATER invocation
    // of the same proven batch skip a redundant re-proof of a
    // byte-identical tree (issue #1588), and the full gate still runs at
    // feature completion + nightly (spec 069 T001).
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  /// Issue #1333: how many times an infra-failed re-proof is retried
  /// (with a cleared kernel cache) before the verdict stands. Two retries
  /// ride out the observed kernel-cache race without masking genuine
  /// regressions (which are never retried at all).
  static const int _maxReproofRetries = 2;

  @override
  String get name => 'refactor';

  @override
  String get description =>
      'Refactor on a green suite only; never edit tests. Applies the fixed '
      'pass registry (resolved zfa build, dart format lib/, '
      'dart fix --apply lib/), '
      're-proves the suite green, and appends refactor evidence to '
      'cycle-log.md.';

  @override
  String get invocation =>
      'zfa tdd refactor [--feature <name>] [--project <path>] [--zfa-bin <path>]';

  @override
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _runOnce);

  Future<void> _runOnce() async {
    final featureFlag = argResults?['feature'] as String?;
    if (featureFlag != null && featureFlag.isNotEmpty) {
      _validateFeatureSegment(featureFlag);
    }
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final zfaBinFlag = argResults?['zfa-bin'] as String?;

    // Bug #742: the --timeout override for the suite runs and every pass.
    Duration? timeoutOverride;
    try {
      timeoutOverride = parseTddTimeoutMinutes(
        argResults?['timeout'] as String?,
      );
    } on TddTimeoutFormatException catch (e) {
      print('zfa tdd refactor: ${e.message}');
      _printSummary(
        feature: featureFlag ?? 'unknown',
        outcome: RefactorOutcome.runnerError,
        applied: 0,
      );
      exitCode = 1;
      return;
    }

    // Spec 1520: ONE scratch dir per invocation. Every child of a refactor
    // cycle — the preflight/re-proof suite runs AND the pass registry's
    // spawns (build/format/fix) — inherits the scratch as its TMPDIR, so
    // their `dart test`/`dart` grandchild kernel dirs land inside the run's
    // own scratch instead of the shared user TMPDIR; the finally below
    // deletes it recursively at run end (the #1507 leak fixed by
    // construction). Best-effort: a scratchless run always beats a crashed
    // command.
    final scratch = await ScratchTmpDir.acquire(
      label: (featureFlag != null && featureFlag.isNotEmpty)
          ? featureFlag
          : 'refactor',
      projectRoot: cwd,
    );
    try {
      await _run(
        cwd: cwd,
        featureFlag: featureFlag,
        zfaBin: zfaBinFlag,
        timeout: timeoutOverride,
        fullReproof: argResults?['full-reproof'] as bool? ?? false,
        suiteBaselinePath: argResults?['suite-baseline'] as String?,
        parkedSeams: (argResults?['parked-seam'] as List<String>? ?? const [])
            .where((s) => s.trim().isNotEmpty)
            .map((s) => p.normalize(s.trim()).replaceAll(r'\', '/'))
            .toSet(),
        scratchEnv: scratch?.childEnvironment(),
        passBatch: argResults?['pass-batch'] as bool? ?? false,
        exemptBehaviorIds: _parseExemptBehaviors(
          argResults?['exempt-behaviors'] as String?,
        ),
      );
    } finally {
      await scratch?.dispose();
    }
  }

  /// Issue #1588: the comma-separated `--exempt-behaviors` value, split
  /// into trimmed, de-duplicated, sorted ids. An empty value yields an
  /// empty set (the gate is unchanged when the driver hands no ids).
  static List<String> _parseExemptBehaviors(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /// Issue #1588: normalize a registered test path to the project-
  /// relative, forward-slashed form the dart test reporter prints
  /// (absolute recorded paths become relative to [projectRoot]; already-
  /// relative paths pass through) — the same comparison contract
  /// PassRegistryTracker.coveringTestsFor uses.
  static String _normalizeGatePath(String path, String projectRoot) {
    var normalized = p.normalize(path);
    if (p.isAbsolute(normalized)) {
      normalized = p.relative(normalized, from: p.normalize(projectRoot));
    }
    return p.posix.normalize(normalized);
  }

  /// The body of the command, extracted so it can return a typed outcome
  /// for testing. The [injectablePasses] parameter is used by tests to
  /// drive the pass registry without real subprocesses.
  Future<void> _run({
    required String cwd,
    String? featureFlag,
    String? zfaBin,
    Duration? timeout,
    bool fullReproof = false,
    String? suiteBaselinePath,
    Set<String> parkedSeams = const {},
    Map<String, String>? scratchEnv,
    bool passBatch = false,
    List<String> exemptBehaviorIds = const [],
  }) async {
    RefactorOutcome outcome;
    int applied = 0;
    String featureName = featureFlag ?? 'unknown';
    // Issue #1471: every artifact path uses the RESOLVED feature directory
    // (a bug directory lives outside `specs/`); [featureName] stays the
    // canonical plain basename for labels, cycle-log behavior ids and
    // receipts.
    String featureDir = p.join(cwd, 'specs', featureName);
    final commandStartedAt = DateTime.now();
    // Issue #922: how many failures each suite verdict tolerated as
    // pre-existing (recorded in the run baseline) — 0 when the verdict
    // was absolutely green or no usable baseline was handed in. The
    // evidence entry records them honestly instead of claiming green.
    var preflightTolerated = 0;
    var reproofTolerated = 0;
    // Issue #1588: how many failures each verdict excluded as
    // parked-exempt behavior tests — 0 when the verdict involved no
    // exemption. The evidence entry records them honestly.
    var preflightExempted = 0;
    var reproofExempted = 0;

    try {
      // Issue #1507: the kernel sweep is a start-of-cycle obligation, not
      // an infra-retry afterthought — a healthy cycle leaks one
      // `$TMPDIR/dart_test.kernel.*` directory per dart test invocation
      // just the same (51 GB / 869 dill files in ~80 minutes on the
      // reporter's machine). Stale entries are swept BEFORE the preflight
      // suite; entries younger than [commandStartedAt] are preserved for
      // concurrent runners.
      await clearDartTestKernelCache(cwd, commandStartedAt: commandStartedAt);

      // 1. Resolve feature (for cycle-log destination).
      if (featureFlag != null && featureFlag.isNotEmpty) {
        // Issue #1471: the reference may name a bug directory
        // (`.specify/bugs/<slug>`) outside `specs/` — resolve through the
        // shared resolver so artifacts land beside the real spec.
        final resolved = TddFeaturePaths.resolveWithPin(
          projectRoot: cwd,
          featureRef: featureFlag,
        );
        featureName = resolved.name;
        featureDir = resolved.dir;
      } else {
        featureName = await _inferFeature(cwd) ?? 'default';
        featureDir = p.join(cwd, 'specs', featureName);
      }
      // Issue #1471: the REAL relative location for user-facing messages.
      final featureDisplay = TddFeaturePaths.displayDir(
        cwd: cwd,
        dir: featureDir,
      );

      // 2. Preflight (FR-001, FR-002) — load the profile suite template.
      final runner = const SingleTestRunner();
      String suiteTemplate;
      try {
        suiteTemplate = await runner.loadSuiteTemplate(workingDirectory: cwd);
      } on StateError catch (e) {
        print(e.message);
        outcome = RefactorOutcome.runnerError;
        _printSummary(feature: featureName, outcome: outcome, applied: 0);
        exitCode = 1;
        return;
      }

      // Issue #1588: resolve the exempt behaviors' registered test paths
      // BEFORE the gate. A parked BLOCKED contract's red test on disk is
      // the designed park state (#1007/#1544), not this feature's doing;
      // the #741 baseline cannot know it (gen created the test after the
      // baseline capture), so it counts as a NEW #922 failure and poisons
      // every refactor preflight. The exemption removes ONLY the failures
      // whose identifier belongs to a named behavior's registered test —
      // every other failure still refuses (safe fallback kept), and an id
      // with no registered artifact is ignored (fail-open).
      //
      // The designed park is the exemption's whole justification, so when
      // the feature has a run state the handed ids are cross-checked
      // against its blocked entries: an id the state does not mark blocked
      // is dropped (the gate stays strict) and named in the output. A
      // missing or unreadable state keeps the ids as handed (fail-open —
      // the flag is driver-only and the driver hands exactly the parked
      // set).
      var effectiveExemptIds = exemptBehaviorIds;
      if (exemptBehaviorIds.isNotEmpty) {
        final blockedIds = await _blockedBehaviorIds(featureDir);
        if (blockedIds != null) {
          final ignored = exemptBehaviorIds
              .where((id) => !blockedIds.contains(id))
              .toList();
          if (ignored.isNotEmpty) {
            print(
              '   parked-exempt ids not recorded as blocked in '
              'run-state.json — ignored: ${ignored.join(', ')}',
            );
            effectiveExemptIds = exemptBehaviorIds
                .where(blockedIds.contains)
                .toList();
          }
        }
      }
      final exemptTestsByPath = <String, String>{};
      if (effectiveExemptIds.isNotEmpty) {
        final records = await ArtifactRegistry(
          featureDir: featureDir,
        ).loadAll();
        for (final record in records) {
          if (!effectiveExemptIds.contains(record.behaviorId)) continue;
          exemptTestsByPath[_normalizeGatePath(record.testPath, cwd)] =
              record.behaviorId;
        }
        if (exemptTestsByPath.isNotEmpty) {
          print(
            '   parked-exempt behaviors (issue #1588): '
            '${exemptTestsByPath.values.toSet().join(', ')} — their '
            'registered tests are excluded from the gate',
          );
        }
      }

      // The behavior id whose registered test a failing identifier
      // belongs to, or null when the failure is not exempt. The dart test
      // compact reporter prints failures as
      // `test/foo_test.dart: group name test name [E]` — the identifier
      // always STARTS with the file path, so the prefix match is exact.
      String? exemptBehaviorFor(String failingId) {
        for (final MapEntry(key: path, value: behavior)
            in exemptTestsByPath.entries) {
          if (failingId == path || failingId.startsWith('$path:')) {
            return behavior;
          }
        }
        return null;
      }

      // Issue #1589: a failure inside a handed parked seam — the driving
      // run's BLOCKED verdict attests its own failing test file — is
      // known red by the same economics as the #1588 registry exemption,
      // with or without a baseline. The registry matches by registered
      // test path prefix; the seam matches by file, so both feed the
      // same gate.
      bool exemptFailure(String failingId) =>
          exemptBehaviorFor(failingId) != null ||
          _isParkedSeamFailure(failingId, parkedSeams);

      // Issue #1588: the driver-only pass-batch fast path. A valid ledger
      // (same suite template, same baseline content, same suite
      // configuration, same exempt set, byte-identical lib/ and test/
      // trees) means a previous invocation of THIS batch already proved
      // the identical gate — preflight, pass registry and re-proof are
      // inherited, costing this spawn two tree snapshots and a file read
      // instead of a full pipeline. A flag-less standalone refactor never
      // reaches this branch: the absolute-green contract (spec 048
      // FR-001) stands unchanged. `--full-reproof` never reaches it
      // either: an explicit request for the strongest proof is always
      // answered by running the full pipeline.
      if (passBatch && !fullReproof) {
        final libNow = await TreeSnapshot.capture(cwd, trees: const ['lib']);
        final testNow = await TreeSnapshot.capture(cwd, trees: const ['test']);
        final ledger = await PassBatchLedger.read(featureDir);
        if (ledger != null &&
            ledger.matches(
              suite: suiteTemplate,
              baselineKey: await PassBatchLedger.baselineKeyFor(
                suiteBaselinePath,
              ),
              configKey: await PassBatchLedger.configKeyFor(cwd),
              exemptBehaviors: effectiveExemptIds,
              libDigest: PassBatchLedger.treeDigest(libNow),
              testDigest: PassBatchLedger.treeDigest(testNow),
            )) {
          print(
            'zfa tdd refactor: pass-batch ledger hit (issue #1588) — the '
            'batch gate is inherited',
          );
          print(
            '   proved ${ledger.capturedAt}: preflight, pass registry and '
            're-proof skipped for this behavior (byte-identical lib/ and '
            'test/ trees; the full gate still runs at feature completion '
            '+ nightly, spec 069 T001)',
          );
          print(
            '   inherited verdicts: preflight ${ledger.preflightVerdict}; '
            're-proof ${ledger.reproofVerdict}',
          );
          if (effectiveExemptIds.isNotEmpty) {
            print(
              '   parked-exempt behaviors: '
              '${effectiveExemptIds.join(', ')}',
            );
          }
          outcome = RefactorOutcome.clean;
          await CycleLog(featureDir).append(
            CycleLogEntry(
              behaviorId: '$featureName-refactor',
              kind: CycleEntryKind.refactor,
              runnerCommand: suiteTemplate,
              exitCode: 0,
              capturedOutput:
                  'pass-batch: gate inherited from the recorded batch proof '
                  'at ${ledger.capturedAt} (issue #1588) — byte-identical '
                  'lib/ and test/ trees, same suite template, same baseline '
                  'content, same exempt set.\n'
                  'inherited preflight verdict: ${ledger.preflightVerdict}\n'
                  'inherited re-proof verdict: ${ledger.reproofVerdict}\n'
                  'applied: 0 actions (pass registry skipped on the '
                  'unchanged tree).',
              sourceCriterion: 'FR-008',
              testPath: 'test/',
              timestamp: DateTime.now().toUtc().toIso8601String(),
              isNoOp: true,
            ),
          );
          _printSummary(feature: featureName, outcome: outcome, applied: 0);
          exitCode = 0;
          return;
        }
      }

      // 3. Run the preflight suite.
      print('zfa tdd refactor: preflight suite');
      print('   command: $suiteTemplate');
      final preflight = await runner.runSuite(
        suiteTemplate: suiteTemplate,
        workingDirectory: cwd,
        timeout: timeout,
        environment: scratchEnv,
      );
      print('   preflight exit: ${preflight.exitCode}');

      // Issue #922: the driving run hands its cached baseline to spawned
      // refactor steps. With a usable baseline, the preflight's verdict is
      // "no NEW failures" — failures already red at baseline are tolerated
      // (the same U16 discipline make applies), so pre-existing red in
      // unrelated files cannot block the run's done transition. Without a
      // baseline (standalone refactor) or with an unusable cache, the
      // absolute-green contract applies (spec 048 FR-001) — a safe
      // fallback, never a silent pass.
      SuiteSnapshot? suiteBaseline;
      if (suiteBaselinePath != null && suiteBaselinePath.isNotEmpty) {
        final cached = await const RunBaselineCache().read(suiteBaselinePath);
        if (cached != null && cached.parseable) {
          suiteBaseline = cached;
          print(
            '   suite baseline: cached (${cached.capturedAt}) — '
            '${cached.failedTests.length} pre-existing failure(s) excluded '
            'from the green verdicts (issue #922)',
          );
        } else {
          print(
            '   suite baseline cache unreadable — the absolute-green '
            'preflight applies (safe fallback, issue #922)',
          );
        }
      }

      if (preflight.timedOut) {
        // Bug #742: the preflight child outlived the deadline and was
        // killed — an infrastructure failure, never `not-green` (that
        // would claim an observed red).
        print(
          'zfa tdd refactor: preflight suite timed out: ${preflight.output}',
        );
        print(
          '   re-run with a larger --timeout <minutes> if the suite '
          'legitimately needs longer.',
        );
        outcome = RefactorOutcome.runnerError;
        _printSummary(feature: featureName, outcome: outcome, applied: 0);
        exitCode = 1;
        return;
      }

      if (!preflight.startedProcess) {
        // Runner could not launch → runner-error (U15 / A3).
        print('   runner did not start: ${preflight.output}');
        outcome = RefactorOutcome.runnerError;
        _printSummary(feature: featureName, outcome: outcome, applied: 0);
        exitCode = 1;
        return;
      }

      if (preflight.exitCode != 0) {
        // Red preflight (U14 / A2) — refuse, name failing tests, point to
        // `zfa tdd make`, modify zero files. Issue #922: with a usable run
        // baseline, only NEW failures refuse — failures already red at
        // baseline are pre-existing red, not this feature's doing, and are
        // tolerated (the U16 discipline make already applies). An
        // unparseable transcript is never tolerated: a red the parser
        // cannot name may be a runner/compile failure, so the refusal
        // stands (safe failure — never a silent pass). Issue #1588: the
        // parked-exempt behaviors' registered tests are removed from the
        // failing set BEFORE the verdict — their red is the designed park
        // state (#1007/#1544), and without the removal every preflight in
        // the batch refuses for a behavior this run can never fix.
        // Issue #1589: a failure whose file the driving run attested as a
        // PARKED contract's seam (a BLOCKED verdict's own failing test) is
        // the same known red — the same pre-existing-failure economics,
        // with or without a baseline. The tolerance is surgical: any NEW
        // failure outside the exempt set still refuses.
        final preflightSnapshot = preflight.startedProcess
            ? const SuiteGuard().fromRunRecord(
                record: preflight,
                capturedAt: DateTime.now().toUtc().toIso8601String(),
              )
            : null;
        final preflightParseable =
            preflightSnapshot != null && preflightSnapshot.parseable;
        final nonExemptFailures = <String>[
          if (preflightParseable)
            ...preflightSnapshot.failedTests.where((id) => !exemptFailure(id)),
        ]..sort();
        final exemptedFailures = <String>[
          if (preflightParseable)
            ...preflightSnapshot.failedTests.where(exemptFailure),
        ]..sort();
        final newFailures = <String>[
          if (preflightParseable && suiteBaseline != null)
            ...nonExemptFailures.where(
              (id) => !suiteBaseline!.failedTests.contains(id),
            ),
        ]..sort();
        final preflightToleratedVerdict =
            preflightParseable &&
            (suiteBaseline != null
                ? newFailures.isEmpty
                : nonExemptFailures.isEmpty);
        if (preflightToleratedVerdict) {
          // Issue #1588 (review): the tolerated count is the NON-EXEMPT
          // pre-existing failures — a parked-exempt failure is not at
          // baseline (gen created its test after the capture), so counting
          // it as tolerated pre-existing red would overstate the #922
          // evidence on the loudest line. The excluded count is disclosed
          // separately below.
          preflightTolerated = nonExemptFailures.length;
          preflightExempted = exemptedFailures.length;
          if (suiteBaseline != null) {
            if (preflightExempted == 0) {
              print(
                '   suite is RED but every failure is pre-existing at '
                'baseline — $preflightTolerated tolerated (issue #922):',
              );
            } else {
              print(
                '   suite is RED but every failure is either pre-existing '
                'at baseline or parked-exempt — $preflightTolerated '
                'pre-existing tolerated, $preflightExempted parked-exempt '
                'excluded (issues #922/#1588):',
              );
            }
          } else {
            print(
              '   suite is RED but every failure belongs to a '
              'parked-exempt behavior or a handed parked seam — '
              '$preflightExempted failure(s) excluded '
              '(issues #1588/#1589):',
            );
          }
          for (final name in preflightSnapshot.failedTests) {
            final owner = exemptBehaviorFor(name);
            print(
              owner != null
                  ? '   parked-exempt ($owner, issue #1588): $name'
                  : _isParkedSeamFailure(name, parkedSeams)
                  ? '   tolerated (parked contract seam, issue #1589): $name'
                  : '   tolerated: $name',
            );
          }
        } else {
          final failingTests = _extractFailingTestNames(preflight.output);
          print('   suite is RED — refusing to refactor.');
          for (final name in failingTests) {
            print('   failing: $name');
          }
          if (failingTests.isEmpty) {
            print('   (no individual test names parsed from output)');
            print('   --- suite output ---');
            print(preflight.output.trim());
          }
          if (newFailures.isNotEmpty) {
            print(
              '   NEW failures vs baseline (${newFailures.length}) — '
              'these are not pre-existing red:',
            );
            for (final name in newFailures) {
              print('   new: $name');
            }
          }
          print(
            '   Return to `zfa tdd make` to restore green before refactoring.',
          );
          outcome = RefactorOutcome.notGreen;
          _printSummary(feature: featureName, outcome: outcome, applied: 0);
          exitCode = 1;
          return;
        }
      }

      // 4. Capture before snapshots for immutability + attribution checks.
      final testBefore = await TreeSnapshot.capture(cwd, trees: const ['test']);
      final libBefore = await TreeSnapshot.capture(cwd, trees: const ['lib']);

      // 5. Run the pass registry (FR-003, FR-005, FR-010). The build pass
      // entrypoint resolves through the same tiers make/gen/verify use;
      // --zfa-bin overrides it (bug #689: never the hardcoded
      // bin/zfa.dart, which zfa setup does not create).
      // Issue #1472: the build gate the registry applies is ERRORS-ONLY
      // (warnings are the dart fix pass's input) unless this project's
      // TDD profile opts back into the legacy warnings-blocking
      // strictness with `analyze-gate: warnings-blocking` — the same
      // machine-readable key, resolution order, and default the make's
      // #1407 errors-only gate honors.
      print('zfa tdd refactor: applying passes');
      final passes = RefactorPasses(
        cwd,
        zfaBinOverride: (zfaBin != null && zfaBin.isNotEmpty) ? zfaBin : null,
        passTimeout: timeout,
        warningsBlocking: await TddProfileKeys.warningsBlocking(cwd),
        environment: scratchEnv,
      );
      final passResult = await passes.run();
      for (final action in passResult.actions) {
        print('   pass: ${action.name}');
        print('     command: ${action.command}');
        print('     exit: ${action.exitCode}');
        if (action.filesChanged.isNotEmpty) {
          print('     changed: ${action.filesChanged.join(', ')}');
        } else {
          print('     changed: (none)');
        }
        // Spec 1540: surface the tracked-placeholder restore-or-refuse
        // evidence the pass registry recorded (the full tool output stays
        // in the action record / cycle log — only the [1540] lines are
        // stdout-worthy).
        for (final line in action.output.split('\n')) {
          if (line.contains('[1540]')) {
            print('     $line');
          }
        }
      }
      // Spec 1540: computed BEFORE the misfire/refusal branches so the
      // summary line reports the true applied count on every exit path.
      applied = passResult.actions
          .where((a) => a.filesChanged.isNotEmpty)
          .length;
      if (passResult.stopped) {
        // Misfire-stop (FR-010) — a pass failed. Re-run the suite to
        // determine the resulting safety state.
        print('   pass "${passResult.failedPass}" failed — misfire-stop.');
        // Spec 1540 (restore-or-refuse): the registry REFUSED because the
        // build pass deleted a git-tracked generated-name file it could not
        // restore. Re-proving a broken tree would be dishonest evidence —
        // hard-stop here with the exact restore remedy, exit non-zero.
        if (passResult.refusalReason != null) {
          print('   ${passResult.refusalReason}');
          print('   Restore the file, then re-run `zfa tdd refactor`.');
          outcome = RefactorOutcome.runnerError;
          _printSummary(
            feature: featureName,
            outcome: outcome,
            applied: applied,
          );
          exitCode = 1;
          return;
        }
        final failedAction = passResult.actions
            .where((a) => a.name == passResult.failedPass)
            .toList();
        if (failedAction.isNotEmpty && failedAction.single.timedOut) {
          // Bug #742: the pass was killed at the deadline — surface the
          // timeout message (behavior/feature context: pass + command).
          print('   timed out: ${failedAction.single.output}');
          print(
            '   re-run with a larger --timeout <minutes> if this pass '
            'legitimately needs longer.',
          );
        }
      }

      // 6. Post-pass immutability + attribution checks (FR-004, FR-005).
      final testAfter = await TreeSnapshot.capture(cwd, trees: const ['test']);
      final testViolations = testBefore.changedPaths(testAfter);
      if (testViolations.isNotEmpty) {
        print('   TEST-DIRECTORY IMMUTABILITY VIOLATION:');
        for (final v in testViolations) {
          print('     $v');
        }
        outcome = RefactorOutcome.runnerError;
        _printSummary(feature: featureName, outcome: outcome, applied: applied);
        exitCode = 1;
        return;
      }

      final libAfter = await TreeSnapshot.capture(cwd, trees: const ['lib']);
      final libChanged = libBefore.changedPaths(libAfter);
      final attributedPaths = <String>{};
      for (final action in passResult.actions) {
        attributedPaths.addAll(action.filesChanged);
      }
      final unattributed = libChanged
          .where((path) => !attributedPaths.contains(path))
          .toList();
      if (unattributed.isNotEmpty) {
        print(
          '   UNATTRIBUTED lib/ CHANGES (no recorded action touched them):',
        );
        for (final path in unattributed) {
          print('     $path');
        }
        outcome = RefactorOutcome.runnerError;
        _printSummary(feature: featureName, outcome: outcome, applied: applied);
        exitCode = 1;
        return;
      }

      // Spec 069 T001 (incremental verification): persist the
      // pass-registry-changed files, then scope the re-proof to the
      // covering tests of those files. The FULL suite still runs at
      // feature completion (`zfa tdd verify`'s preflight) and nightly
      // (the corpus lane) — the gate exists, its frequency is
      // engineered. The scoped path requires EVERY changed file to be
      // a registered artifact's subject (the gen pairing); one
      // unattributable file falls back to the full suite (safe
      // failure, never a silently narrowed re-proof).
      if (libChanged.isNotEmpty) {
        final formatPass = passResult.actions
            .where((a) => a.filesChanged.isNotEmpty)
            .lastOrNull;
        await PassRegistryTracker(featureDir: featureDir).record(
          changedFiles: libChanged,
          capturedAt: DateTime.now().toUtc().toIso8601String(),
          command: formatPass?.command,
        );
      }
      final artifacts = await ArtifactRegistry(
        featureDir: featureDir,
      ).loadAll();
      // Issue #1430: a sanctioned rewrite of a CERTIFIED subject strands
      // its green evidence — the next make's #1036 guard would refuse the
      // drift the loop itself produced (subject-drift stale-artifacts, the
      // resume dead end). Compute the refresh candidates now and, after a
      // green re-proof, reconcile them below. The honesty gate rides the
      // re-proof scope itself: when the pass is scoped, coveringTestsFor
      // maps every changed registered subject to its own paired test, so
      // each candidate's test is exercised by construction; every other
      // green path is the full suite. A failed re-proof returns above, so
      // a refused/misfired/regressed pass never reconciles.
      final refreshCandidates = await SubjectEvidenceRefresh.candidates(
        projectRoot: cwd,
        featureName: featureName,
        changedPaths: libChanged,
        artifacts: artifacts,
      );
      final coveringTests = fullReproof
          ? const <String>{}
          : PassRegistryTracker.coveringTestsFor(
              changedFiles: libChanged.toSet(),
              artifacts: artifacts,
              projectRoot: cwd,
            );
      final scopedReproof =
          coveringTests.isNotEmpty && libChanged.isNotEmpty && !fullReproof;
      final reproofPaths = scopedReproof
          ? (coveringTests.toList()..sort())
          : const <String>[];

      // 7. Re-run the suite (FR-006) — scoped to the covering tests of
      //    the pass-registry-changed files when every changed file maps
      //    to a registered artifact (spec 069 T001); the full suite
      //    otherwise (and under --full-reproof). On regression, name the
      //    regressed tests, exit non-zero, write no success evidence.
      String reproofCommand;
      if (scopedReproof) {
        // Quote each path so a feature directory with spaces survives
        // the suite runner's whitespace split (same token contract as
        // zfaBuildCommand's quoteIfNeeded + the pass executor's
        // quote-aware tokenizer, bug #689; spec 069 T001).
        reproofCommand = [
          suiteTemplate,
          ...reproofPaths.map((path) => '"$path"'),
        ].join(' ');
        print(
          'zfa tdd refactor: re-proof: scoped '
          '(${reproofPaths.length} covering test(s) for '
          '${libChanged.length} changed file(s))',
        );
        print('   command: $reproofCommand');
      } else {
        reproofCommand = suiteTemplate;
        if (fullReproof) {
          print('zfa tdd refactor: re-proof: full (--full-reproof)');
        } else if (libChanged.isNotEmpty) {
          print(
            'zfa tdd refactor: re-proof: full (changed set not fully '
            'attributable to registered artifacts — safe fallback)',
          );
        } else {
          print('zfa tdd refactor: re-proof suite');
        }
        print('   command: $reproofCommand');
      }
      var reproof = await runner.runSuite(
        suiteTemplate: reproofCommand,
        workingDirectory: cwd,
        timeout: timeout,
        environment: scratchEnv,
      );
      print('   re-proof exit: ${reproof.exitCode}');

      // Issue #1333 — a transient dart test runner failure (the
      // incremental kernel-cache race: exit 255, "Cannot retrieve length
      // of file", dart_test.kernel ENOENT) is an INFRA-level failure, not
      // a regression. Retry the re-proof with a cleared kernel cache
      // before believing any verdict; a crashed runner cannot certify a
      // regression any more than it can certify a pass. Genuine assertion
      // failures (exit 1 with parseable failing-test names) and
      // unparseable reds never enter this loop — they regress immediately
      // (FR-4) — and timeouts stay bug-#742 runner-errors (a legitimate
      // long suite needs a larger --timeout, not a re-run).
      var reproofRetries = 0;
      while (!reproof.timedOut &&
          (!reproof.startedProcess || reproof.exitCode != 0) &&
          reproofRetries < _maxReproofRetries &&
          classifyReproofFailure(
                exitCode: reproof.exitCode,
                output: reproof.output,
                startedProcess: reproof.startedProcess,
              ) ==
              ReproofFailureClass.infraRunner) {
        reproofRetries++;
        print(
          '   infra-level runner failure (exit ${reproof.exitCode}) — '
          'clearing the dart test kernel cache and retrying '
          '($reproofRetries/$_maxReproofRetries) [issue #1333]',
        );
        final signature = kernelCacheSignatureLine(reproof.output);
        if (signature != null) {
          print('   infra signature: $signature');
        }
        await clearDartTestKernelCache(cwd, commandStartedAt: commandStartedAt);
        reproof = await runner.runSuite(
          suiteTemplate: reproofCommand,
          workingDirectory: cwd,
          timeout: timeout,
          environment: scratchEnv,
        );
        print('   re-proof exit: ${reproof.exitCode} (retry $reproofRetries)');
      }

      if (reproof.timedOut) {
        // Bug #742: the re-proof child outlived the deadline and was
        // killed — the suite safety state cannot be certified. Issue
        // #1333 FR-3: the verdict + transcript tail still reach the
        // cycle log, so the timeout is auditable.
        print('zfa tdd refactor: re-proof suite timed out: ${reproof.output}');
        print(
          '   re-run with a larger --timeout <minutes> if the suite '
          'legitimately needs longer.',
        );
        await _appendReproofDiagnostics(
          cwd: cwd,
          featureDir: featureDir,
          featureName: featureName,
          reproofCommand: reproofCommand,
          reproof: reproof,
          verdict: 'runner-timeout',
          retries: reproofRetries,
          classification: FailureClass.runnerError,
        );
        outcome = RefactorOutcome.runnerError;
        _printSummary(feature: featureName, outcome: outcome, applied: applied);
        exitCode = 1;
        return;
      }

      if (!reproof.startedProcess || reproof.exitCode != 0) {
        // Issue #1333: classify the failure BEFORE the baseline tolerance
        // check — an infra-level runner failure is neither tolerated red
        // nor a regression; the retries above have been exhausted and the
        // honest outcome is runner-error. A crashed runner cannot certify
        // a regression any more than it can certify a pass.
        final failureClass = classifyReproofFailure(
          exitCode: reproof.exitCode,
          output: reproof.output,
          startedProcess: reproof.startedProcess,
        );
        if (failureClass == ReproofFailureClass.infraRunner) {
          final signature = kernelCacheSignatureLine(reproof.output);
          print(
            '   infra-level runner failure persists after $reproofRetries '
            'retry(ies) — outcome is runner-error, NOT a regression '
            '(issue #1333).',
          );
          if (signature != null) {
            print('   infra signature: $signature');
          }
          await _appendReproofDiagnostics(
            cwd: cwd,
            featureDir: featureDir,
            featureName: featureName,
            reproofCommand: reproofCommand,
            reproof: reproof,
            verdict: 'infra-runner-error',
            retries: reproofRetries,
            classification: FailureClass.runnerError,
            actions: passResult.actions,
          );
          outcome = RefactorOutcome.runnerError;
          _printSummary(
            feature: featureName,
            outcome: outcome,
            applied: applied,
          );
          exitCode = 1;
          return;
        }
        // Issue #922: with a usable run baseline, the re-proof verdict is
        // "no NEW failures" — the same pre-existing red the preflight
        // tolerated is not a regression introduced by the passes. An
        // unparseable transcript still classifies as a regression (safe
        // failure), and so does any failure whose identifier the baseline
        // does not already record. Issue #1588: the parked-exempt
        // behaviors' registered tests are removed from the failing set
        // BEFORE the verdict — the same exclusion the preflight applied,
        // so a scoped or full re-proof is not regressed by the designed
        // park state of a BLOCKED contract. Issue #1589: a failure inside
        // a handed parked seam is the same known red here — a parked
        // verdict's failing test cannot grade the passes a regression.
        final reproofSnapshot = !reproof.startedProcess
            ? null
            : const SuiteGuard().fromRunRecord(
                record: reproof,
                capturedAt: DateTime.now().toUtc().toIso8601String(),
              );
        final reproofParseable =
            reproofSnapshot != null && reproofSnapshot.parseable;
        final nonExemptReproofFailures = <String>[
          if (reproofParseable)
            ...reproofSnapshot.failedTests.where((id) => !exemptFailure(id)),
        ]..sort();
        final newReproofFailures = <String>[
          if (reproofParseable && suiteBaseline != null)
            ...nonExemptReproofFailures.where(
              (id) => !suiteBaseline!.failedTests.contains(id),
            ),
        ]..sort();
        final reproofToleratedVerdict =
            reproofParseable &&
            (suiteBaseline != null
                ? newReproofFailures.isEmpty
                : nonExemptReproofFailures.isEmpty);
        if (reproofToleratedVerdict) {
          // Same review fix as the preflight: tolerated counts the
          // NON-EXEMPT pre-existing failures only; the parked-exempt
          // failures are disclosed as excluded, never as tolerated
          // pre-existing red (issue #1588).
          reproofTolerated = nonExemptReproofFailures.length;
          reproofExempted = reproofSnapshot.failedTests
              .where(exemptFailure)
              .length;
          if (suiteBaseline != null) {
            if (reproofExempted == 0) {
              print(
                '   re-proof RED but every failure is pre-existing at '
                'baseline — $reproofTolerated tolerated, no regression '
                '(issue #922).',
              );
            } else {
              print(
                '   re-proof RED but every failure is either pre-existing '
                'at baseline or parked-exempt — $reproofTolerated '
                'pre-existing tolerated, $reproofExempted parked-exempt '
                'excluded, no regression (issues #922/#1588).',
              );
            }
          } else {
            print(
              '   re-proof RED but every failure belongs to a '
              'parked-exempt behavior or a handed parked seam — '
              '$reproofExempted failure(s) excluded, no regression '
              '(issues #1588/#1589).',
            );
          }
        } else {
          final regressedTests = _extractFailingTestNames(reproof.output);
          print('   REGRESSION detected — suite is no longer green.');
          for (final name in regressedTests) {
            print('   regressed: $name');
          }
          if (regressedTests.isEmpty) {
            print('   --- suite output ---');
            print(reproof.output.trim());
          }
          if (newReproofFailures.isNotEmpty) {
            print(
              '   NEW failures vs baseline (${newReproofFailures.length}):',
            );
            for (final name in newReproofFailures) {
              print('   new: $name');
            }
          }
          // Issue #1333 FR-3: the failed re-proof cycle is appended to
          // the cycle log — verdict + exit code + retry count + transcript
          // tail — so the regression is auditable instead of silent.
          await _appendReproofDiagnostics(
            cwd: cwd,
            featureDir: featureDir,
            featureName: featureName,
            reproofCommand: reproofCommand,
            reproof: reproof,
            verdict: 'regression',
            retries: reproofRetries,
            classification: regressedTests.isNotEmpty
                ? FailureClass.assertionFailure
                : null,
            actions: passResult.actions,
          );
          outcome = RefactorOutcome.regression;
          _printSummary(
            feature: featureName,
            outcome: outcome,
            applied: applied,
          );
          exitCode = 1;
          return;
        }
      }

      if (passResult.stopped) {
        outcome = RefactorOutcome.runnerError;
        _printSummary(feature: featureName, outcome: outcome, applied: applied);
        exitCode = 1;
        return;
      }

      // Issue #1311: the passes rewrote receipted artifacts — append the
      // sanctioned refactor provenance event re-hashing those receipts to
      // the formatted bytes, so `zfa proof check` passes after a
      // sanctioned run and `zfa tdd verify` is not blocked by preflight
      // drift (NOT_ASSESSED). Fires only when a receipted file was
      // actually mutated (backward compatibility — FR-4); best-effort: a
      // receipt failure never flips a sanctioned refactor to a failure,
      // the loss stays fail-visible via `zfa proof check`.
      final refresh = await RefactorReceiptRefresh.refreshBestEffort(
        projectRoot: cwd,
        feature: featureName,
        changedPaths: libChanged,
        passes: passResult.actions.map((a) => a.name).toList(),
      );
      if (refresh.fired) {
        print(
          '   receipts refreshed: ${refresh.refreshedPaths.length} '
          'receipted artifact(s) re-hashed after the refactor passes '
          '(sanctioned refactor provenance, issue #1311)',
        );
      }

      final reproofNote = scopedReproof
          ? 're-proof: scoped (${reproofPaths.length} covering test(s) '
                'for ${libChanged.length} changed file(s); spec 069 T001 — '
                'the full gate runs at feature completion + nightly)'
          : 're-proof: full';

      // 8. Green before AND after. Append evidence (FR-007) or record a
      // clean no-op (FR-008). The verdicts name tolerated pre-existing red
      // honestly (issue #922) instead of claiming an absolute green that
      // did not exist.
      final preflightVerdict = preflightTolerated > 0
          ? 'tolerated $preflightTolerated pre-existing failure(s) '
                '(issue #922)'
          : 'green';
      final reproofVerdict = reproofTolerated > 0
          ? 'tolerated $reproofTolerated pre-existing failure(s) '
                '(issue #922)'
          : 'green';
      // Issue #1588: the parked-exemption counts ride the verdict strings
      // honestly — never a green claim that hides an excluded red.
      final preflightVerdictWithExempt = preflightExempted > 0
          ? '$preflightVerdict; $preflightExempted parked-exempt '
                'failure(s) excluded (issue #1588)'
          : preflightVerdict;
      final reproofVerdictWithExempt = reproofExempted > 0
          ? '$reproofVerdict; $reproofExempted parked-exempt '
                'failure(s) excluded (issue #1588)'
          : reproofVerdict;

      // Issue #1333 FR-3: the re-proof verdict line (verdict + exit code)
      // and a truncated transcript tail ride along on the GREEN path too —
      // every verdict is auditable, not just the failures.
      final reproofVerdictLine =
          're-proof verdict: $reproofVerdict (exit ${reproof.exitCode})';
      final reproofDiagnostics =
          '$reproofVerdictLine\n'
          're-proof retries: $reproofRetries\n'
          're-proof output tail (stdout+stderr, truncated):\n'
          '${reproofOutputTail(reproof.output)}';
      if (applied == 0) {
        // Clean no-op — no fabricated actions.
        print('   no actions applied — clean no-op.');
        outcome = RefactorOutcome.clean;
        final log = CycleLog(featureDir);
        await log.append(
          CycleLogEntry(
            behaviorId: '$featureName-refactor',
            kind: CycleEntryKind.refactor,
            runnerCommand: suiteTemplate,
            exitCode: 0,
            capturedOutput:
                'preflight: $preflightVerdictWithExempt\n'
                're-proof: $reproofVerdictWithExempt\n'
                '$reproofDiagnostics\n'
                '$reproofNote\n'
                'applied: 0 actions.',
            sourceCriterion: 'FR-008',
            testPath: 'test/',
            timestamp: DateTime.now().toUtc().toIso8601String(),
            isNoOp: true,
          ),
        );
      } else {
        outcome = RefactorOutcome.refactored;
        // Append refactor evidence.
        final log = CycleLog(featureDir);
        await log.append(
          CycleLogEntry(
            behaviorId: '$featureName-refactor',
            kind: CycleEntryKind.refactor,
            runnerCommand: reproofCommand,
            exitCode: 0,
            capturedOutput:
                'preflight: $preflightVerdictWithExempt\n'
                're-proof: $reproofVerdictWithExempt\n'
                '$reproofDiagnostics\n'
                '$reproofNote\n'
                'receipts refreshed: ${refresh.fired ? refresh.refreshedPaths.length : 0} '
                'receipted artifact(s) re-hashed (sanctioned refactor '
                'provenance, issue #1311)\n'
                'applied: ${passResult.actions.length} action(s), '
                '$applied with file changes.',
            sourceCriterion: 'FR-007',
            testPath: 'test/',
            timestamp: DateTime.now().toUtc().toIso8601String(),
            refactorActions: passResult.actions,
            isNoOp: false,
          ),
        );
        print(
          '   refactor evidence appended to $featureDisplay/tdd/'
          'cycle-log.md',
        );
        // Issue #1430: the green re-proof above is the witness — re-bind
        // each touched certified subject's evidence to its post-rewrite
        // shape. The candidates were computed BEFORE the re-proof and its
        // scope was widened to cover their tests, so a refresh never
        // outruns its proof; every failure path above returns before this
        // line, so a refused/misfired/regressed pass reconciles nothing.
        final refreshed = await SubjectEvidenceRefresh.reconcile(
          projectRoot: cwd,
          featureName: featureName,
          candidates: refreshCandidates,
          reproofCommand: reproofCommand,
          reproofExit: reproof.exitCode,
        );
        if (refreshed > 0) {
          print(
            '   subject evidence refreshed: $refreshed certified '
            'subject(s) re-bound to the post-rewrite shapes (issue #1430)',
          );
        }
      }
      // Issue #1588: record the batch gate this green application proved,
      // so the NEXT behavior's refactor spawn inherits it instead of
      // re-paying the full pipeline. The gate's witness is the tree the
      // re-proof certified (testAfter/libAfter), re-captured HERE so the
      // ledger is only written for a tree that still matches the proof: a
      // future post-proof writer inside lib/ or test/ degrades the cache
      // loudly (a warning; the next spawn re-runs the full pipeline)
      // instead of recording a tree the gate never proved. Best-effort: a
      // ledger write failure costs the next spawn one full pipeline, never
      // correctness.
      if (passBatch) {
        try {
          final libAtWrite = await TreeSnapshot.capture(
            cwd,
            trees: const ['lib'],
          );
          final testAtWrite = await TreeSnapshot.capture(
            cwd,
            trees: const ['test'],
          );
          final libDigest = PassBatchLedger.treeDigest(libAtWrite);
          final testDigest = PassBatchLedger.treeDigest(testAtWrite);
          if (libDigest == PassBatchLedger.treeDigest(libAfter) &&
              testDigest == PassBatchLedger.treeDigest(testAfter)) {
            await PassBatchLedger(
              capturedAt: DateTime.now().toUtc().toIso8601String(),
              suite: suiteTemplate,
              baselineKey: await PassBatchLedger.baselineKeyFor(
                suiteBaselinePath,
              ),
              configKey: await PassBatchLedger.configKeyFor(cwd),
              exemptBehaviors: effectiveExemptIds,
              libDigest: libDigest,
              testDigest: testDigest,
              preflightVerdict: preflightVerdictWithExempt,
              reproofVerdict: reproofVerdictWithExempt,
            ).write(featureDir: featureDir);
          } else {
            print(
              '   WARNING: lib/ or test/ changed between the re-proof and '
              'the ledger write — the pass-batch ledger is NOT recorded '
              '(issue #1588); the next batch spawn re-runs the full '
              'pipeline.',
            );
          }
        } catch (e) {
          print(
            '   WARNING: could not write the pass-batch ledger '
            '(issue #1588): $e — the next batch spawn re-runs the full '
            'pipeline.',
          );
        }
      }
      _printSummary(feature: featureName, outcome: outcome, applied: applied);
      exitCode = 0;
    } catch (e, st) {
      // Misfire-stop on any unexpected error — keep the summary line last.
      print('zfa tdd refactor: misfire — $e');
      print(st.toString().split('\n').take(5).join('\n'));
      outcome = RefactorOutcome.runnerError;
      _printSummary(feature: featureName, outcome: outcome, applied: applied);
      exitCode = 1;
    }
  }

  /// Issue #1588: the run state's BLOCKED behavior ids, or null when the
  /// feature has no run state (or one too corrupt to read) — the caller
  /// then keeps the handed exemption ids as-is (fail-open: the flag is
  /// driver-only and the driver hands exactly the lane's parked set).
  Future<Set<String>?> _blockedBehaviorIds(String featureDir) async {
    try {
      final state = await RunStateStore(featureDir).load();
      if (state == null) return null;
      return {
        for (final entry in state.behaviorStates.entries)
          if (entry.value == BehaviorState.blocked) entry.key,
      };
    } on RunStateCorruptException {
      return null;
    }
  }

  /// Infer the feature name from the unique specs/ subdirectory that has a
  /// tdd/ subdirectory. Returns null when ambiguous or none.
  Future<String?> _inferFeature(String cwd) async {
    final specsDir = Directory(p.join(cwd, 'specs'));
    if (!await specsDir.exists()) return null;
    final candidates = <String>[];
    for (final dir in specsDir.listSync().whereType<Directory>()) {
      final tddDir = Directory(p.join(dir.path, 'tdd'));
      if (await tddDir.exists()) {
        candidates.add(p.basename(dir.path));
      }
    }
    if (candidates.length == 1) return candidates.single;
    return null;
  }

  /// Extract individual failing test names from a `dart test` output.
  ///
  /// Delegates to the pure [parseFailingTestNames] (spec 1333): the `[E]`
  /// line grammar lives in ONE place, shared with the re-proof failure
  /// classifier. `dart test` prints failures with the test name on a line
  /// like `00:01 +0 -1: test name [E]`; the result is sorted and de-duped.
  List<String> _extractFailingTestNames(String output) =>
      parseFailingTestNames(output);

  /// Issue #1589: whether a failing-test identifier lives inside a handed
  /// parked seam — the file part of the identifier (everything before the
  /// first `:`, `loading ` stripped) boundary-matches one of the parked
  /// seam paths the driving run attested. The same file-suffix match the
  /// make's #731 scoping uses (the `/` boundary keeps `u2_test.dart` from
  /// matching `xu2_test.dart`), so absolute/relative and Windows/POSIX
  /// path shapes compare equal.
  bool _isParkedSeamFailure(String identifier, Set<String> parkedSeams) {
    if (parkedSeams.isEmpty) return false;
    var s = identifier.trim();
    const loading = 'loading ';
    if (s.startsWith(loading)) s = s.substring(loading.length);
    final idx = s.indexOf(':');
    if (idx > 0) s = s.substring(0, idx);
    final file = p.normalize(s.trim()).replaceAll(r'\', '/');
    for (final seam in parkedSeams) {
      if (file == seam || file.endsWith('/$seam') || seam.endsWith('/$file')) {
        return true;
      }
    }
    return false;
  }

  /// Append the re-proof verdict + transcript tail to the feature's
  /// cycle-log (spec 1333 FR-3) on every non-green verdict: the failed
  /// re-proof cycle becomes auditable (verdict + exit code + retry count
  /// + truncated transcript tail). Best-effort: a cycle-log write failure
  /// prints a warning and never masks the primary verdict.
  Future<void> _appendReproofDiagnostics({
    required String cwd,
    required String featureDir,
    required String featureName,
    required String reproofCommand,
    required SuiteRunRecord reproof,
    required String verdict,
    required int retries,
    FailureClass? classification,
    List<RefactorAction> actions = const [],
  }) async {
    // Issue #1471: name the REAL directory in the warning, not a
    // fabricated `specs/<name>` path.
    final featureDisplay = TddFeaturePaths.displayDir(
      cwd: cwd,
      dir: featureDir,
    );
    try {
      await CycleLog(featureDir).append(
        CycleLogEntry(
          behaviorId: '$featureName-refactor',
          kind: CycleEntryKind.refactor,
          runnerCommand: reproofCommand,
          exitCode: reproof.exitCode,
          capturedOutput:
              're-proof verdict: $verdict (exit ${reproof.exitCode})\n'
              're-proof retries: $retries\n'
              're-proof output tail (stdout+stderr, truncated):\n'
              '${reproofOutputTail(reproof.output)}',
          classification: classification,
          sourceCriterion: 'FR-3',
          testPath: 'test/',
          timestamp: DateTime.now().toUtc().toIso8601String(),
          refactorActions: actions,
        ),
      );
    } catch (e) {
      print(
        '   WARNING: could not append re-proof diagnostics to '
        '$featureDisplay/tdd/cycle-log.md: $e',
      );
    }
  }

  void _printSummary({
    required String feature,
    required RefactorOutcome outcome,
    required int applied,
  }) {
    print(
      'refactor: feature=$feature outcome=${outcome.label} applied=$applied',
    );
    // Issue #969: the outcome label IS the exit class.
    _verdict
      ..exitClass = outcome.label
      ..outcome = switch (outcome) {
        RefactorOutcome.clean => VerdictOutcome.pass,
        RefactorOutcome.refactored => VerdictOutcome.pass,
        _ => VerdictOutcome.fail,
      }
      ..details['applied'] = applied
      ..feature = feature == 'unknown' ? null : feature;
  }
}

/// `--feature` lands in a filesystem path: accept exactly the shapes
/// [TddFeaturePaths] resolves (a plain segment, `specs/<name>`,
/// `.specify/bugs/<slug>`, or an absolute path) and refuse the rest —
/// `.`, `..`, a traversal shape, or a trailing separator (issue #1471).
void _validateFeatureSegment(String feature) {
  if (TddFeaturePaths.isSupportedRef(feature) &&
      !feature.endsWith('/') &&
      !feature.endsWith(r'\')) {
    return;
  }
  throw UsageException(
    'invalid --feature "$feature": expected a single spec directory name '
        'such as 048-tdd-refactor, not a path.',
    'zfa tdd refactor [--feature <name>] [--project <path>]',
  );
}
