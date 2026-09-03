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
/// Rejections and misfires are signaled through dart:io `exitCode` (which
/// [CliRunner] honors) rather than by throwing, so the summary line stays
/// the final stdout line.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/artifact_registry.dart';
import '../services/cycle_log.dart';
import '../services/pass_registry_tracker.dart';
import '../services/refactor_passes.dart';
import '../services/runner.dart';
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

    await _run(
      cwd: cwd,
      featureFlag: featureFlag,
      zfaBin: zfaBinFlag,
      timeout: timeoutOverride,
      fullReproof: argResults?['full-reproof'] as bool? ?? false,
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
  }) async {
    RefactorOutcome outcome;
    int applied = 0;
    String featureName = featureFlag ?? 'unknown';

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
        // `zfa tdd make`, modify zero files.
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
        print(
          '   Return to `zfa tdd make` to restore green before refactoring.',
        );
        outcome = RefactorOutcome.notGreen;
        _printSummary(feature: featureName, outcome: outcome, applied: 0);
        exitCode = 1;
        return;
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
        await PassRegistryTracker(
          featureDir: p.join(cwd, 'specs', featureName),
        ).record(
          changedFiles: libChanged,
          capturedAt: DateTime.now().toUtc().toIso8601String(),
          command: formatPass?.command,
        );
      }
      final artifacts = await ArtifactRegistry(
        featureDir: p.join(cwd, 'specs', featureName),
      ).loadAll();
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
        reproofCommand = [suiteTemplate, ...reproofPaths].join(' ');
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
      final reproof = await runner.runSuite(
        suiteTemplate: reproofCommand,
        workingDirectory: cwd,
        timeout: timeout,
      );
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
        final regressedTests = _extractFailingTestNames(reproof.output);
        print('   REGRESSION detected — suite is no longer green.');
        for (final name in regressedTests) {
          print('   regressed: $name');
        }
        if (regressedTests.isEmpty) {
          print('   --- suite output ---');
          print(reproof.output.trim());
        }
        outcome = RefactorOutcome.regression;
        _printSummary(feature: featureName, outcome: outcome, applied: applied);
        exitCode = 1;
        return;
      }

      if (passResult.stopped) {
        outcome = RefactorOutcome.runnerError;
        _printSummary(feature: featureName, outcome: outcome, applied: applied);
        exitCode = 1;
        return;
      }

      final reproofNote = scopedReproof
          ? 're-proof: scoped (${reproofPaths.length} covering test(s) '
                'for ${libChanged.length} changed file(s); spec 069 T01 — '
                'the full gate runs at feature completion + nightly)'
          : 're-proof: full';

      // 8. Green before AND after. Append evidence (FR-007) or record a
      // clean no-op (FR-008).
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
                'preflight: green\nre-proof: green\n'
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
        final log = CycleLog(p.join(cwd, 'specs', featureName));
        await log.append(
          CycleLogEntry(
            behaviorId: '$featureName-refactor',
            kind: CycleEntryKind.refactor,
            runnerCommand: reproofCommand,
            exitCode: 0,
            capturedOutput:
                'preflight: green\nre-proof: green\n'
                '$reproofNote\n'
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
