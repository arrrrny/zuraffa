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
import '../services/pass_registry_tracker.dart';
import '../services/refactor_passes.dart';
import '../services/refactor_receipt_refresh.dart';
import '../services/reproof_failure_classifier.dart';
import '../services/run_baseline_cache.dart';
import '../services/runner.dart';
import '../services/subject_evidence_refresh.dart';
import '../services/suite_guard.dart';
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
    // Note (FR-002): there is INTENTIONALLY no --skip-preflight option.
    // The preflight is the entire discipline of the refactor step; skipping
    // it would destroy the signal that makes refactoring safe.
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

    await _run(
      cwd: cwd,
      featureFlag: featureFlag,
      zfaBin: zfaBinFlag,
      timeout: timeoutOverride,
      fullReproof: argResults?['full-reproof'] as bool? ?? false,
      suiteBaselinePath: argResults?['suite-baseline'] as String?,
    );
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

    try {
      // 1. Resolve feature (for cycle-log destination).
      if (featureFlag != null && featureFlag.isNotEmpty) {
        // Issue #1471: the reference may name a bug directory
        // (`.specify/bugs/<slug>`) outside `specs/` — resolve through the
        // shared resolver so artifacts land beside the real spec.
        final resolved = TddFeaturePaths.resolve(
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
      final featureDisplay = p
          .relative(featureDir, from: cwd)
          .replaceAll(r'\', '/');

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

      // 3. Run the preflight suite.
      print('zfa tdd refactor: preflight suite');
      print('   command: $suiteTemplate');
      final preflight = await runner.runSuite(
        suiteTemplate: suiteTemplate,
        workingDirectory: cwd,
        timeout: timeout,
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
        // stands (safe failure — never a silent pass).
        final preflightSnapshot = suiteBaseline == null
            ? null
            : const SuiteGuard().fromRunRecord(
                record: preflight,
                capturedAt: DateTime.now().toUtc().toIso8601String(),
              );
        final newFailures = (suiteBaseline == null || preflightSnapshot == null)
            ? const <String>[]
            : const SuiteGuard()
                  .diff(baseline: suiteBaseline, guard: preflightSnapshot)
                  .newFailures;
        if (preflightSnapshot != null &&
            preflightSnapshot.parseable &&
            newFailures.isEmpty) {
          preflightTolerated = preflightSnapshot.failedTests.length;
          print(
            '   suite is RED but every failure is pre-existing at '
            'baseline — $preflightTolerated tolerated (issue #922):',
          );
          for (final name in preflightSnapshot.failedTests) {
            print('   tolerated: $name');
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
      print('zfa tdd refactor: applying passes');
      final passes = RefactorPasses(
        cwd,
        zfaBinOverride: (zfaBin != null && zfaBin.isNotEmpty) ? zfaBin : null,
        passTimeout: timeout,
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
      }
      if (passResult.stopped) {
        // Misfire-stop (FR-010) — a pass failed. Re-run the suite to
        // determine the resulting safety state.
        print('   pass "${passResult.failedPass}" failed — misfire-stop.');
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
      applied = passResult.actions
          .where((a) => a.filesChanged.isNotEmpty)
          .length;

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
        await _clearDartTestKernelCache(
          cwd,
          commandStartedAt: commandStartedAt,
        );
        reproof = await runner.runSuite(
          suiteTemplate: reproofCommand,
          workingDirectory: cwd,
          timeout: timeout,
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
        // does not already record.
        final reproofSnapshot =
            (!reproof.startedProcess || suiteBaseline == null)
            ? null
            : const SuiteGuard().fromRunRecord(
                record: reproof,
                capturedAt: DateTime.now().toUtc().toIso8601String(),
              );
        final newReproofFailures =
            (suiteBaseline == null || reproofSnapshot == null)
            ? const <String>[]
            : const SuiteGuard()
                  .diff(baseline: suiteBaseline, guard: reproofSnapshot)
                  .newFailures;
        if (reproofSnapshot != null &&
            reproofSnapshot.parseable &&
            newReproofFailures.isEmpty) {
          reproofTolerated = reproofSnapshot.failedTests.length;
          print(
            '   re-proof RED but every failure is pre-existing at '
            'baseline — $reproofTolerated tolerated, no regression '
            '(issue #922).',
          );
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
                'preflight: $preflightVerdict\nre-proof: $reproofVerdict\n'
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
                'preflight: $preflightVerdict\nre-proof: $reproofVerdict\n'
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
    final featureDisplay = p
        .relative(featureDir, from: cwd)
        .replaceAll(r'\', '/');
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

  /// Clear the dart test incremental kernel cache (spec 1333 FR-2): the
  /// project's `.dart_tool/test/` directory and stale shared
  /// `$TMPDIR/dart_test.kernel.*` files. Files created or updated after
  /// [commandStartedAt] may belong to a concurrent runner and are left
  /// untouched. Best-effort: a clear failure prints a note and never crashes
  /// the command; the retry simply re-runs and the classifier grades the next
  /// attempt from its own transcript.
  Future<void> _clearDartTestKernelCache(
    String projectRoot, {
    required DateTime commandStartedAt,
  }) async {
    try {
      final cacheDir = Directory(p.join(projectRoot, '.dart_tool', 'test'));
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      print('   kernel cache clear (project .dart_tool/test/) failed: $e');
    }
    final tmpRoot =
        Platform.environment['TMPDIR'] ??
        Platform.environment['TEMP'] ??
        Platform.environment['TMP'] ??
        Directory.systemTemp.path;
    try {
      final tmpDir = Directory(tmpRoot);
      if (!await tmpDir.exists()) return;
      await for (final entity in tmpDir.list()) {
        if (entity is File &&
            p.basename(entity.path).startsWith('dart_test.kernel.')) {
          try {
            final modifiedAt = await entity.lastModified();
            if (modifiedAt.isBefore(commandStartedAt)) {
              await entity.delete();
            }
          } catch (_) {
            // A kernel file pinned by a concurrent runner is skipped —
            // the next suite run re-derives it.
          }
        }
      }
    } catch (e) {
      print('   kernel cache clear (TMPDIR) failed: $e');
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
