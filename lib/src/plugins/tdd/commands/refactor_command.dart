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
/// Rejections and misfires are signaled through dart:io `exitCode` (which
/// [CliRunner] honors) rather than by throwing, so the summary line stays
/// the final stdout line.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/cycle_log.dart';
import '../services/pass_registry_tracker.dart';
import '../services/refactor_passes.dart';
import '../services/run_baseline_cache.dart';
import '../services/runner.dart';
import '../services/suite_guard.dart';
import '../services/tdd_timeout.dart';
import '../services/tree_snapshot.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class RefactorCommand extends Command<void> {
  RefactorCommand(this.plugin) {
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
    argParser.addOption(
      'reproof',
      allowed: ['auto', 'full'],
      defaultsTo: 'auto',
      help:
          'Re-proof scope policy (spec 069-corpus-economics, issue #916). '
          'auto (default): the re-proof is INCREMENTAL — scoped to the '
          'tests covering pass-registry-changed files, escalating to the '
          'full suite on the first proof, on unowned file changes, and '
          'when the nightly full-proof window expires; a zero delta '
          'skips the redundant re-proof spawn (the full gate still runs '
          'at preflight, feature completion, and nightly). full: force '
          'the full-suite re-proof unconditionally (the pre-069 '
          'behavior).',
    );
    argParser.addOption(
      'full-proof-interval',
      valueHelp: 'hours',
      defaultsTo: '24',
      help:
          'The nightly full-proof window in hours (spec 069): when the '
          'last FULL-suite proof is older than this, an otherwise-scoped '
          're-proof escalates to full — the full verify gate still '
          'exists, its frequency is engineered. Fractions allowed.',
    );
    // Note (FR-002): there is INTENTIONALLY no --skip-preflight option.
    // The preflight is the entire discipline of the refactor step; skipping
    // it would destroy the signal that makes refactoring safe.
  }

  final TddPlugin plugin;

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
  Future<void> run() async {
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

    // Spec 069: the re-proof scope policy + the nightly full-proof
    // window (hours, fractions allowed; 24 = nightly by default).
    final reproofMode = (argResults?['reproof'] as String?) ?? 'auto';
    Duration? fullProofInterval;
    final intervalRaw = argResults?['full-proof-interval'] as String?;
    if (intervalRaw != null && intervalRaw.isNotEmpty) {
      final hours = double.tryParse(intervalRaw);
      if (hours == null || hours <= 0) {
        print(
          'zfa tdd refactor: invalid --full-proof-interval '
          '"$intervalRaw" — expected hours > 0 (fractions allowed).',
        );
        _printSummary(
          feature: featureFlag ?? 'unknown',
          outcome: RefactorOutcome.runnerError,
          applied: 0,
        );
        exitCode = 1;
        return;
      }
      fullProofInterval = Duration(
        microseconds: (hours * Duration.microsecondsPerHour).round(),
      );
    }

    await _run(
      cwd: cwd,
      featureFlag: featureFlag,
      zfaBin: zfaBinFlag,
      timeout: timeoutOverride,
      suiteBaselinePath: argResults?['suite-baseline'] as String?,
      reproofMode: reproofMode,
      fullProofInterval: fullProofInterval,
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
    String? suiteBaselinePath,
    String reproofMode = 'auto',
    Duration? fullProofInterval,
  }) async {
    RefactorOutcome outcome;
    int applied = 0;
    String featureName = featureFlag ?? 'unknown';
    // Issue #922: how many failures each suite verdict tolerated as
    // pre-existing (recorded in the run baseline) — 0 when the verdict
    // was absolutely green or no usable baseline was handed in. The
    // evidence entry records them honestly instead of claiming green.
    var preflightTolerated = 0;
    var reproofTolerated = 0;

    try {
      // 1. Resolve feature (for cycle-log destination).
      if (featureFlag != null && featureFlag.isNotEmpty) {
        featureName = featureFlag;
      } else {
        featureName = await _inferFeature(cwd) ?? 'default';
      }

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

      // 7. Re-run the suite (FR-006) — spec 069-corpus-economics: the
      //    re-proof is INCREMENTAL. The pass registry records the
      //    checksum of every registered artifact file at the last
      //    proof; the re-proof scope is decided from the delta between
      //    that state and the CURRENT disk state (captured AFTER the
      //    passes, so pass-caused changes count):
      //      - first proof (no registry)            -> FULL
      //      - unowned file changed                 -> FULL (honest scope)
      //      - nightly full-proof window expired    -> FULL (the gate)
      //      - zero delta since the last proof      -> SKIPPED (the exact
      //        file state already carries a green proof; the full gate
      //        still runs at preflight, feature completion, nightly)
      //      - otherwise                            -> SCOPED to the
      //        tests covering the pass-registry-changed files.
      //    On regression, name the regressed tests, exit non-zero,
      //    write no success evidence.
      final tracker = const PassRegistryTracker();
      final featureDir = p.join(cwd, 'specs', featureName);
      final previousRegistry = await tracker.load(featureDir);
      final currentRegistry = await tracker.capture(
        projectRoot: cwd,
        featureDir: featureDir,
      );
      // The tree delta (test/ + lib/, registered or not) is the honest
      // change signal; ownership decides scopeability.
      final delta = PassRegistryTracker.delta(
        previousRegistry ??
            PassRegistryState(feature: featureName, files: const {}),
        currentRegistry,
      );
      final covering = await tracker.coveringTestsFor(
        changedPaths: delta.allChanged,
        projectRoot: cwd,
        featureDir: featureDir,
      );
      final scope = PassRegistryTracker.decideScope(
        previous: previousRegistry,
        delta: delta,
        current: currentRegistry,
        coveringTests: covering,
        fullProofInterval: fullProofInterval,
        forceFull: reproofMode == 'full',
      );

      final SuiteRunRecord reproof;
      if (scope.skipped) {
        print(
          '   re-proof scope: skipped (no pass-registry changes since '
          'the last proof) [069 corpus economics]',
        );
        reproof = const SuiteRunRecord(
          command: '',
          exitCode: 0,
          output: '',
          startedProcess: true,
        );
      } else if (scope.full) {
        print(
          '   re-proof scope: full (${scope.reason}) '
          '[069 corpus economics]',
        );
        if (scope.reason == 'unowned-files') {
          final unowned = scope.changedFiles
              .where((f) => !previousRegistry!.files.containsKey(f))
              .toList();
          for (final path in unowned) {
            print('   unowned change: $path');
          }
        }
        print('zfa tdd refactor: re-proof suite');
        reproof = await runner.runSuite(
          suiteTemplate: suiteTemplate,
          workingDirectory: cwd,
          timeout: timeout,
        );
      } else {
        print(
          '   re-proof scope: scoped (${scope.testPaths.length} test '
          'file(s), ${scope.changedFiles.length} changed file(s)) '
          '[069 corpus economics]',
        );
        print('zfa tdd refactor: re-proof suite (scoped)');
        reproof = await runner.runScopedSuite(
          suiteTemplate: suiteTemplate,
          testPaths: scope.testPaths,
          workingDirectory: cwd,
          timeout: timeout,
        );
      }
      print('   re-proof exit: ${reproof.exitCode}');
      if (reproof.timedOut) {
        // Bug #742: the re-proof child outlived the deadline and was
        // killed — the suite safety state cannot be certified.
        print('zfa tdd refactor: re-proof suite timed out: ${reproof.output}');
        print(
          '   re-run with a larger --timeout <minutes> if the suite '
          'legitimately needs longer.',
        );
        outcome = RefactorOutcome.runnerError;
        _printSummary(feature: featureName, outcome: outcome, applied: applied);
        exitCode = 1;
        return;
      }

      if (!reproof.startedProcess || reproof.exitCode != 0) {
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

      // 8. Green before AND after. Append evidence (FR-007) or record a
      // clean no-op (FR-008). The verdicts name tolerated pre-existing red
      // honestly (issue #922) instead of claiming an absolute green that
      // did not exist.
      final preflightVerdict = preflightTolerated > 0
          ? 'tolerated $preflightTolerated pre-existing failure(s) '
                '(issue #922)'
          : 'green';
      // Spec 069: the re-proof verdict names its SCOPE (scoped / full
      // / skipped) alongside the honest tolerated-red accounting.
      final reproofVerdict = _reproofVerdict(
        scope: scope,
        tolerated: reproofTolerated,
      );
      if (applied == 0) {
        // Clean no-op — no fabricated actions.
        print('   no actions applied — clean no-op.');
        outcome = RefactorOutcome.clean;
        final log = CycleLog(p.join(cwd, 'specs', featureName));
        await log.append(
          CycleLogEntry(
            behaviorId: '$featureName-refactor',
            kind: CycleEntryKind.refactor,
            runnerCommand: suiteTemplate,
            exitCode: 0,
            capturedOutput:
                'preflight: $preflightVerdict\nre-proof: $reproofVerdict\n'
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
        final log = CycleLog(p.join(cwd, 'specs', featureName));
        await log.append(
          CycleLogEntry(
            behaviorId: '$featureName-refactor',
            kind: CycleEntryKind.refactor,
            runnerCommand: suiteTemplate,
            exitCode: 0,
            capturedOutput:
                'preflight: $preflightVerdict\nre-proof: $reproofVerdict\n'
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
          '   refactor evidence appended to specs/$featureName/tdd/'
          'cycle-log.md',
        );
      }
      // Spec 069: commit the pass registry at the proven state — the
      // NEXT refactor's delta is measured from here. Full proofs stamp
      // last_full_proof_at (the nightly window restarts); scoped proofs
      // preserve the previous stamp (the window still expires); skipped
      // re-proofs commit nothing (nothing was re-proven).
      if (!scope.skipped) {
        await tracker.commit(
          featureDir: featureDir,
          state: currentRegistry,
          fullProof: scope.full,
          proofAt: DateTime.now().toUtc().toIso8601String(),
        );
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
  /// `dart test` prints failures with the test name on a line like
  /// `00:01 +0 -1: test name [E]`. Returns the names sorted and de-duped.
  List<String> _extractFailingTestNames(String output) {
    final names = <String>{};
    for (final line in output.split('\n')) {
      // Match lines like `00:01 +0 -1: some test name [E]`.
      final m = RegExp(
        r'^\s*\d{2}:\d{2}\s+\+?\d*\s+-\d+:\s+(.+?)\s+\[E\]\s*$',
      ).firstMatch(line);
      if (m != null) {
        names.add(m.group(1)!);
      }
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  /// The re-proof verdict line for the cycle-log evidence, naming the
  /// spec 069 scope alongside the issue #922 tolerated-red accounting.
  /// The tolerated form keeps the legacy prefix contract
  /// (`re-proof: tolerated … (issue #922)`) so #922 evidence consumers
  /// keep parsing; the scope detail follows.
  String _reproofVerdict({
    required ReproofScope scope,
    required int tolerated,
  }) {
    if (scope.skipped) {
      return 'skipped (no pass-registry changes since the last proof) '
          '[069]';
    }
    final scopeLabel = scope.full
        ? 'full (${scope.reason})'
        : 'scoped (${scope.testPaths.length} test file(s), '
              '${scope.changedFiles.length} changed file(s))';
    if (tolerated > 0) {
      return 'tolerated $tolerated pre-existing failure(s) '
          '(issue #922) — scope: $scopeLabel [069]';
    }
    return '$scopeLabel green [069]';
  }

  void _printSummary({
    required String feature,
    required RefactorOutcome outcome,
    required int applied,
  }) {
    print(
      'refactor: feature=$feature outcome=${outcome.label} applied=$applied',
    );
  }
}

/// `--feature` lands in a filesystem path: keep it a single plain
/// directory segment (mirrors verify_command.dart).
void _validateFeatureSegment(String feature) {
  if (feature.contains('/') ||
      feature.contains(r'\') ||
      feature == '.' ||
      feature == '..') {
    throw UsageException(
      'invalid --feature "$feature": expected a single spec directory name '
          'such as 048-tdd-refactor, not a path.',
      'zfa tdd refactor [--feature <name>] [--project <path>]',
    );
  }
}
