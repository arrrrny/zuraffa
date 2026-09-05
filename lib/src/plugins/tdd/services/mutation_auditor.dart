/// MutationAuditor — wraps the existing [MutationVerifier] with the
/// behavior-traced, scope-derived, NOT_ASSESSED, source-restoration flow
/// required by FR-012..021 of spec 044-test-tdd-generation.
///
/// The auditor:
///   1. Derives the mutation scope from registered behavior artifacts
///      (FR-012).
///   2. Runs a green-suite preflight FIRST (FR-013).
///   3. Runs the mutation audit (delegated to [MutationVerifier]).
///   4. Classifies killed/survived/timed-out as three separate buckets
///      (FR-014).
///   5. Marks unavailable/empty/incomplete/unparseable results as
///      NOT_ASSESSED (FR-015, FR-016).
///   6. Applies the strict policy: ANY survived or timed-out mutant
///      fails the gate (FR-017).
///   7. Traces every outcome to behavior id + source criterion (FR-018).
///   8. Restores every temporarily mutated subject before returning
///      (FR-021).
///   9. NEVER edits a test to fake a pass (FR-022).
library;

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/mutation_outcome.dart';
import 'mutation_scope.dart';
import 'mutation_verifier.dart';
import 'runner.dart';
import 'source_restorer.dart';
import 'tdd_timeout.dart';

/// The result of a green-suite preflight.
class PreflightResult {
  PreflightResult({
    required this.exitCode,
    required this.output,
    this.timedOut = false,
    this.failedToLoad = false,
    this.ranTestPaths = const [],
  });

  /// 0 = green, non-zero = red or load failure.
  final int exitCode;

  /// Captured stdout from the preflight run.
  final String output;

  /// True when the preflight process was killed by the per-command timeout
  /// (bug #742): an infrastructure failure — the tests never finished, so
  /// the audit is NOT_ASSESSED, never `preflight_red`.
  final bool timedOut;

  /// True when the preflight child could not LOAD/COMPILE the test file
  /// (issue #1045): the same infrastructure class as [timedOut] — the
  /// tests never RAN, so the audit is NOT_ASSESSED with a `--> fix:` line,
  /// never `preflight_red` (which would claim an honest red and mislead
  /// downstream tooling in the wrong direction entirely).
  final bool failedToLoad;

  /// The per-behavior test files actually executed before the verdict
  /// (bug #924). Empty when the preflight did not run any per-behavior
  /// test (no own test files, or a pre-#924 combined invocation).
  final List<String> ranTestPaths;

  bool get isGreen => exitCode == 0;

  factory PreflightResult.green({
    required int exitCode,
    required String output,
    List<String> ranTestPaths = const [],
  }) => PreflightResult(
    exitCode: exitCode,
    output: output,
    ranTestPaths: ranTestPaths,
  );

  factory PreflightResult.red({
    required int exitCode,
    required String output,
    List<String> ranTestPaths = const [],
  }) => PreflightResult(
    exitCode: exitCode,
    output: output,
    ranTestPaths: ranTestPaths,
  );

  /// Issue #1045: the child reported a load/compile failure — the tests
  /// never ran (infrastructure), which is NOT_ASSESSED, never a red.
  factory PreflightResult.loadFailure({
    required int exitCode,
    required String output,
    List<String> ranTestPaths = const [],
  }) => PreflightResult(
    exitCode: exitCode,
    output: output,
    failedToLoad: true,
    ranTestPaths: ranTestPaths,
  );
}

/// The complete audit report produced by [MutationAuditor.run].
class MutationAuditReport {
  MutationAuditReport({
    required this.feature,
    required this.gate,
    required this.killedCount,
    required this.survivedCount,
    required this.timedOutCount,
    required this.behaviorIds,
    required this.sourceCriteriaByBehavior,
    required this.mutationWasRun,
    required this.restorationVerified,
    required this.restorationScope,
    this.notAssessedReason,
    this.runnerCommand,
    this.exitCode,
    this.elapsedSeconds,
    this.reportPath,
    this.preflightOutput,
    this.mutationScore,
    this.scoreThreshold,
    this.survivors = const [],
    this.specHash,
    this.subjectHashes = const {},
    this.preflightScopeRan = const [],
  });

  /// The feature name (e.g. `044-test-tdd-generation`).
  final String feature;

  /// The gate decision (FR-019).
  final MutationGateDecision gate;

  /// Killed mutant count (FR-014).
  final int killedCount;

  /// Survived mutant count (FR-014).
  final int survivedCount;

  /// Timed-out mutant count (FR-014).
  final int timedOutCount;

  /// All behavior ids in scope (FR-018).
  final List<String> behaviorIds;

  /// Map of behavior id -> source criterion (FR-018).
  final Map<String, String> sourceCriteriaByBehavior;

  /// True iff the mutation tool was actually invoked (false when the
  /// scope was empty or the preflight was red).
  final bool mutationWasRun;

  /// The mutation score (killed / total) when the mutation ran and
  /// produced mutants; null otherwise (bug #837).
  final double? mutationScore;

  /// The `.zfa.json` score threshold this audit was gated against, when
  /// configured (bug #837). Null = the strict policy (any survivor fails).
  final double? scoreThreshold;

  /// Every survived mutant (bug #837): the per-mutant detail parsed from
  /// the mutation_test report, cited by file + line.
  final List<MutationSurvivor> survivors;

  /// sha256 of the feature's `artifacts.json` at verify time — binds the
  /// verification report to the exact spec it audited (bug #837).
  final String? specHash;

  /// Map of subject absolute path → pre-audit sha256 (bug #837). Binds the
  /// verification report to the exact subject sources that were mutated.
  final Map<String, String> subjectHashes;

  /// True iff all temporarily mutated subjects were restored post-audit.
  final bool restorationVerified;

  /// List of paths the restorer touched (subject files only; never test
  /// files — FR-022).
  final List<String> restorationScope;

  /// Non-null reason when the gate is NOT_ASSESSED.
  final String? notAssessedReason;

  /// Non-sensitive repro diagnostics (FR-020).
  final String? runnerCommand;
  final int? exitCode;
  final int? elapsedSeconds;
  final String? reportPath;
  final String? preflightOutput;

  /// The per-behavior test files the preflight actually executed before
  /// its verdict (bug #924) — fail-fast diagnostics: with 24+ pre-existing
  /// failures the report must show exactly which of the feature's own
  /// test files ran, never a full-suite baseline.
  final List<String> preflightScopeRan;

  /// Render the report as markdown for `verification.md`.
  String toMarkdown() {
    final buf = StringBuffer()
      ..writeln('# TDD Verification — feature `$feature`')
      ..writeln()
      ..writeln('Generated fresh by `zfa tdd verify --feature $feature`.')
      ..writeln()
      ..writeln('## Gate')
      ..writeln()
      ..writeln('- gate: `${gate.label}`');
    if (notAssessedReason != null) {
      buf.writeln('- not_assessed_reason: $notAssessedReason');
    }
    buf
      ..writeln()
      ..writeln('## Mutation buckets (FR-014)')
      ..writeln()
      ..writeln('- killed: $killedCount')
      ..writeln('- survived: $survivedCount')
      ..writeln('- timed_out: $timedOutCount')
      ..writeln()
      ..writeln('## Behavior scope (FR-018)')
      ..writeln();
    if (behaviorIds.isEmpty) {
      buf.writeln('- (no behavior artifacts in scope)');
    } else {
      for (final id in behaviorIds) {
        final criterion = sourceCriteriaByBehavior[id] ?? '(unknown)';
        buf.writeln('- `$id` — traces: `$criterion`');
      }
    }
    buf
      ..writeln()
      ..writeln('## Restoration (FR-021)')
      ..writeln()
      ..writeln('- restoration_verified: $restorationVerified')
      ..writeln('- restoration_scope_count: ${restorationScope.length}');
    if (restorationScope.isNotEmpty) {
      buf.writeln('- restoration_scope (subjects only, never tests):');
      for (final path in restorationScope) {
        buf.writeln('  - `$path`');
      }
    }
    buf
      ..writeln()
      ..writeln('## Repro diagnostics (FR-020, non-sensitive)')
      ..writeln();
    if (runnerCommand != null) {
      buf.writeln('- runner_command: `$runnerCommand`');
    }
    if (exitCode != null) {
      buf.writeln('- exit_code: $exitCode');
    }
    if (elapsedSeconds != null) {
      buf.writeln('- elapsed_seconds: $elapsedSeconds');
    }
    if (reportPath != null) {
      buf.writeln('- report_path: `$reportPath`');
    }
    if (preflightOutput != null) {
      buf.writeln('- preflight_output: `${_truncate(preflightOutput!, 400)}`');
    }
    if (preflightScopeRan.isNotEmpty) {
      buf
        ..writeln('- preflight_scope_ran (bug #924, per-behavior):')
        ..writeln('  - `${preflightScopeRan.first}`');
      for (final path in preflightScopeRan.skip(1)) {
        buf.writeln('  - `$path`');
      }
    }
    buf
      ..writeln()
      ..writeln('## Mutation run')
      ..writeln()
      ..writeln('- mutation_was_run: $mutationWasRun');
    if (mutationScore != null) {
      buf.writeln('- mutation_score: ${mutationScore!.toStringAsFixed(4)}');
    }
    if (scoreThreshold != null) {
      buf.writeln(
        '- score_threshold: ${scoreThreshold!.toStringAsFixed(4)} '
        '(from .zfa.json)',
      );
    }
    if (survivors.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## Survived mutants (bug #837)')
        ..writeln();
      for (final s in survivors) {
        buf.writeln('- `${s.file}:${s.line}`');
        buf.writeln(
          '  --> fix: add or strengthen a scope test that fails on '
          'this mutant (report: ${reportPath ?? 'mutation-test report'})',
        );
      }
    }
    if (specHash != null || subjectHashes.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## Evidence binding (bug #837)')
        ..writeln();
      if (specHash != null) {
        buf.writeln('- spec_hash: $specHash');
      }
      if (subjectHashes.isNotEmpty) {
        final paths = subjectHashes.keys.toList()..sort();
        for (final path in paths) {
          buf.writeln('- subject_hash: `$path` ${subjectHashes[path]}');
        }
      }
    }
    return buf.toString();
  }
}

/// Truncates a string for inclusion in the report (FR-020: non-sensitive).
String _truncate(String s, int max) {
  if (s.length <= max) return s;
  return '${s.substring(0, max)}…';
}

/// Runs the mutation audit for a feature.
class MutationAuditor {
  MutationAuditor({
    required this.featureDir,
    required this.workingDirectory,
    Future<PreflightResult> Function(List<String> scopePaths)? runPreflight,
    Future<PreflightResult> Function(String testPath)? runPreflightBehavior,
    Future<MutationResult> Function()? runMutation,
    Duration? preflightTimeout,
    Duration? mutationTimeout,
    double? scoreThreshold,
    String? runnerTemplate,
    this.spawnTest,
  }) : _runPreflightOverride = runPreflight,
       _runPreflightBehaviorOverride = runPreflightBehavior,
       _runMutationOverride = runMutation,
       _preflightTimeout = preflightTimeout,
       _mutationTimeout = mutationTimeout,
       _scoreThreshold = scoreThreshold,
       _runnerTemplate = runnerTemplate;

  final String featureDir;
  final String workingDirectory;
  final Future<PreflightResult> Function(List<String> scopePaths)?
  _runPreflightOverride;

  /// Per-behavior preflight runner (bug #924): when provided, the DEFAULT
  /// preflight delegates each of the feature's own test files to it
  /// (fail-fast) instead of spawning `dart test` itself. The list-level
  /// [runPreflight] override still bypasses the loop entirely.
  final Future<PreflightResult> Function(String testPath)?
  _runPreflightBehaviorOverride;
  final Future<MutationResult> Function()? _runMutationOverride;

  /// Per-command deadlines (bug #742); `null` uses the shared defaults.
  final Duration? _preflightTimeout;
  final Duration? _mutationTimeout;

  /// Mutation score threshold from `.zfa.json` (bug #837); `null` applies
  /// the strict policy (any survived or timed-out mutant fails the gate).
  final double? _scoreThreshold;

  /// Explicit runner override (issue #1044 `--runner`): a whole-file
  /// command template that wins over the profile's `file:` key. Null
  /// resolves from the profile, falling back to the pure-Dart default
  /// only when the project has no profile at all.
  final String? _runnerTemplate;

  /// Injectable preflight spawn (fast tier): records/executes the resolved
  /// runner argv instead of a real process. Defaults to [runTimed].
  final Future<ProcessResult> Function(
    String executable,
    List<String> args,
    String workingDirectory,
    Duration timeout,
  )?
  spawnTest;

  /// The resolved whole-file runner template (issue #1044), cached per
  /// audit. Resolution order: the explicit [_runnerTemplate] override
  /// (`--runner`), the project profile's `file:` key, then — only when the
  /// project has NO profile at all — the pure-Dart default (the pre-#1044
  /// behavior). A profile present without a usable `file:` key throws
  /// [StateError]: the caller grades that honestly (NOT_ASSESSED with a
  /// `--> fix:` line) instead of silently running the wrong runner.
  String? _resolvedFileTemplate;
  Future<String> _fileTemplate() async {
    final cached = _resolvedFileTemplate;
    if (cached != null) return cached;
    if (_runnerTemplate != null) {
      return _resolvedFileTemplate = _runnerTemplate;
    }
    final profileFile = File(
      p.join(workingDirectory, SingleTestRunner.defaultProfilePath),
    );
    if (!await profileFile.exists()) {
      return _resolvedFileTemplate = 'dart test {file}';
    }
    final template = await SingleTestRunner().loadFileTemplate(
      workingDirectory: workingDirectory,
    );
    return _resolvedFileTemplate = template;
  }

  /// Run the audit. Returns a [MutationAuditReport].
  Future<MutationAuditReport> run() async {
    final scope = await MutationScope.derive(featureDir: featureDir);

    // Bug #837: bind the audit to the exact spec + subjects it verifies.
    // The spec hash is the sha256 of the feature's artifacts.json — the
    // machine-readable behavior registry the scope was derived from.
    final registryFile = File(p.join(featureDir, 'tdd', 'artifacts.json'));
    final specHash = registryFile.existsSync()
        ? sha256.convert(registryFile.readAsBytesSync()).toString()
        : null;

    if (scope.isEmpty) {
      // No behavior artifacts registered → NOT_ASSESSED (FR-012).
      return MutationAuditReport(
        feature: p.basename(featureDir),
        gate: MutationGateDecision.notAssessed,
        killedCount: 0,
        survivedCount: 0,
        timedOutCount: 0,
        behaviorIds: const [],
        sourceCriteriaByBehavior: const {},
        mutationWasRun: false,
        restorationVerified: true,
        restorationScope: const [],
        notAssessedReason: scope.notAssessedReason,
        scoreThreshold: _scoreThreshold,
        specHash: specHash,
      );
    }

    // Bug #924: resolve the mutation config BEFORE the preflight. A
    // missing/unresolvable mutation config (`mutation-test.xml not found`
    // in the issue's forklift repro) must surface `gate: not_assessed`
    // IMMEDIATELY — never after paying the full-suite preflight cost. The
    // default mutation phase reuses the config written here.
    // Issue #1044: resolve the whole-file runner ONCE, before anything
    // spawns — the preflight and the scoped mutation config's test
    // command must run under the SAME runner (the profile's, not a
    // hardcoded `dart test`). A broken profile is an honest NOT_ASSESSED
    // with a `--> fix:` line — never a wrong-runner run, never a crash.
    final String fileTemplate;
    try {
      fileTemplate = await _fileTemplate();
    } on StateError catch (e) {
      return MutationAuditReport(
        feature: p.basename(featureDir),
        gate: MutationGateDecision.notAssessed,
        killedCount: 0,
        survivedCount: 0,
        timedOutCount: 0,
        behaviorIds: scope.behaviorIds,
        sourceCriteriaByBehavior: scope.sourceCriteriaByBehavior,
        mutationWasRun: false,
        restorationVerified: true,
        restorationScope: const [],
        notAssessedReason:
            'test runner template: ${e.message} --> fix: add a `file:` key '
            'with a {file} placeholder to .specify/memory/tdd-profile.md, '
            'or pass --runner dart|flutter',
        scoreThreshold: _scoreThreshold,
        specHash: specHash,
      );
    }
    if (!fileTemplate.contains('{file}')) {
      return MutationAuditReport(
        feature: p.basename(featureDir),
        gate: MutationGateDecision.notAssessed,
        killedCount: 0,
        survivedCount: 0,
        timedOutCount: 0,
        behaviorIds: scope.behaviorIds,
        sourceCriteriaByBehavior: scope.sourceCriteriaByBehavior,
        mutationWasRun: false,
        restorationVerified: true,
        restorationScope: const [],
        notAssessedReason:
            "the resolved test runner template '$fileTemplate' carries no "
            '{file} placeholder --> fix: add {file} to the `file:` key in '
            '.specify/memory/tdd-profile.md or pass --runner dart|flutter',
        scoreThreshold: _scoreThreshold,
        specHash: specHash,
      );
    }

    String? ensuredConfigPath;
    if (_runMutationOverride == null) {
      try {
        ensuredConfigPath = await _ensureScopedMutationConfig(
          scope,
          fileTemplate,
        );
      } on MutationConfigError catch (e) {
        return MutationAuditReport(
          feature: p.basename(featureDir),
          gate: MutationGateDecision.notAssessed,
          killedCount: 0,
          survivedCount: 0,
          timedOutCount: 0,
          behaviorIds: scope.behaviorIds,
          sourceCriteriaByBehavior: scope.sourceCriteriaByBehavior,
          mutationWasRun: false,
          restorationVerified: true,
          restorationScope: const [],
          notAssessedReason: 'mutation config error: $e',
          scoreThreshold: _scoreThreshold,
          specHash: specHash,
        );
      }
    }

    // Green-suite preflight FIRST (FR-013). Run only the test paths
    // (not subject paths — subject files are not tests and `dart test`
    // would fail to load them as tests). Bug #924: the default preflight
    // runs the feature's own per-behavior test files individually
    // (fail-fast) instead of one full-suite baseline invocation.
    // Issue #1044: each file runs under the RESOLVED runner template —
    // `flutter test <file>` for Flutter projects — never a literal
    // `dart test`.
    final preflight = _runPreflightOverride != null
        ? await _runPreflightOverride(scope.testPaths)
        : await _defaultPreflight(scope.testPaths, fileTemplate);
    if (preflight.timedOut) {
      // Bug #742: the preflight child outlived the deadline and was killed.
      // The tests never finished, so this is NOT_ASSESSED (infrastructure
      // failure) — never `preflight_red`, which would claim an honest red.
      return MutationAuditReport(
        feature: p.basename(featureDir),
        gate: MutationGateDecision.notAssessed,
        killedCount: 0,
        survivedCount: 0,
        timedOutCount: 0,
        behaviorIds: scope.behaviorIds,
        sourceCriteriaByBehavior: scope.sourceCriteriaByBehavior,
        mutationWasRun: false,
        restorationVerified: true,
        restorationScope: const [],
        notAssessedReason: 'preflight timed out: ${preflight.output}',
        runnerCommand: 'dart test ${scope.testPaths.join(' ')}',
        preflightOutput: preflight.output,
        preflightScopeRan: preflight.ranTestPaths,
      );
    }
    if (preflight.failedToLoad) {
      // Issue #1045: the preflight child could not LOAD/COMPILE the test
      // files — infrastructure, the same class as the #742 timeout. The
      // tests never ran, so this is NOT_ASSESSED: `preflight_red` would
      // claim an honest red (and mislead downstream tooling in the wrong
      // direction entirely — the suite may be green under the correct
      // runner).
      return MutationAuditReport(
        feature: p.basename(featureDir),
        gate: MutationGateDecision.notAssessed,
        killedCount: 0,
        survivedCount: 0,
        timedOutCount: 0,
        behaviorIds: scope.behaviorIds,
        sourceCriteriaByBehavior: scope.sourceCriteriaByBehavior,
        mutationWasRun: false,
        restorationVerified: true,
        restorationScope: const [],
        notAssessedReason:
            'preflight could not load/compile the test files — a '
            'runner/compile problem, NOT an honest red --> fix: check the '
            'named file and the runner (issue #1044: the runner resolves '
            'from .specify/memory/tdd-profile.md; override with --runner '
            'dart|flutter)',
        runnerCommand: 'dart test ${scope.testPaths.join(' ')}',
        preflightOutput: preflight.output,
        preflightScopeRan: preflight.ranTestPaths,
      );
    }
    if (!preflight.isGreen) {
      return MutationAuditReport(
        feature: p.basename(featureDir),
        gate: MutationGateDecision.preflightRed,
        killedCount: 0,
        survivedCount: 0,
        timedOutCount: 0,
        behaviorIds: scope.behaviorIds,
        sourceCriteriaByBehavior: scope.sourceCriteriaByBehavior,
        mutationWasRun: false,
        restorationVerified: true,
        restorationScope: const [],
        preflightOutput: preflight.output,
        preflightScopeRan: preflight.ranTestPaths,
      );
    }

    // Capture pre-audit bytes for source restoration (FR-021).
    // Resolve relative paths against the working directory (the paths
    // stored in the registry may be repo-relative).
    final absoluteSubjectPaths = scope.subjectPaths
        .map(
          (path) => p.isAbsolute(path) ? path : p.join(workingDirectory, path),
        )
        .toList();
    final restorer = SourceRestorer(paths: absoluteSubjectPaths);
    await restorer.capture();

    // Bug #837: pre-audit subject hashes — the evidence binding for the
    // verification report.
    final subjectHashes = <String, String>{
      for (final path in restorer.capturedPaths)
        if (restorer.hashOf(path) != null) path: restorer.hashOf(path)!,
    };

    // Run the mutation audit (delegated to MutationVerifier by default,
    // or to the override).
    MutationResult? mutationResult;
    String? notAssessedReason;

    // Register signal handlers to restore source before process exit (FR-021).
    // Without this, SIGINT/SIGTERM would terminate before the finally block
    // completes, leaving mutated subjects on disk.
    final sigintSub = ProcessSignal.sigint.watch().listen((_) async {
      await restorer.restoreAndVerify();
    });
    final sigtermSub = ProcessSignal.sigterm.watch().listen((_) async {
      await restorer.restoreAndVerify();
    });

    try {
      mutationResult =
          await (_runMutationOverride ??
              // The config was ensured before the preflight (bug #924);
              // the default mutation phase reuses it.
              () => _defaultMutation(scope, ensuredConfigPath!))();
    } on MutationToolUnavailable catch (e) {
      notAssessedReason = 'mutation tool unavailable: $e';
    } on MutationConfigError catch (e) {
      notAssessedReason = 'mutation config error: $e';
    } on ProcessTimeoutException catch (e) {
      // Bug #742: the mutation run outlived its deadline and was killed.
      notAssessedReason = 'mutation run timed out: $e';
    } catch (e) {
      notAssessedReason = 'mutation audit failed: $e';
    } finally {
      // Always restore, even on interrupt (FR-021).
      await sigintSub.cancel();
      await sigtermSub.cancel();
      await restorer.restoreAndVerify();
    }

    if (notAssessedReason != null) {
      return MutationAuditReport(
        feature: p.basename(featureDir),
        gate: MutationGateDecision.notAssessed,
        killedCount: 0,
        survivedCount: 0,
        timedOutCount: 0,
        behaviorIds: scope.behaviorIds,
        sourceCriteriaByBehavior: scope.sourceCriteriaByBehavior,
        mutationWasRun: false,
        restorationVerified: restorer.hashMatchesAll(),
        restorationScope: restorer.capturedPaths,
        notAssessedReason: notAssessedReason,
        runnerCommand: 'dart run mutation_test',
        scoreThreshold: _scoreThreshold,
        specHash: specHash,
        subjectHashes: subjectHashes,
        preflightScopeRan: preflight.ranTestPaths,
      );
    }

    // Determine if the report is empty/incomplete/unparseable (FR-016).
    final isEmpty = mutationResult!.totalMutants == 0;
    if (isEmpty) {
      return MutationAuditReport(
        feature: p.basename(featureDir),
        gate: MutationGateDecision.notAssessed,
        killedCount: 0,
        survivedCount: 0,
        timedOutCount: 0,
        behaviorIds: scope.behaviorIds,
        sourceCriteriaByBehavior: scope.sourceCriteriaByBehavior,
        mutationWasRun: true,
        restorationVerified: restorer.hashMatchesAll(),
        restorationScope: restorer.capturedPaths,
        notAssessedReason: 'mutation report was empty or unparseable',
        runnerCommand: 'dart run mutation_test',
        exitCode: mutationResult.exitCode,
        elapsedSeconds: mutationResult.elapsed.inSeconds,
        scoreThreshold: _scoreThreshold,
        specHash: specHash,
        subjectHashes: subjectHashes,
        preflightScopeRan: preflight.ranTestPaths,
      );
    }

    // Compute the gate decision (FR-017; bug #837 threshold gate).
    //
    // Without a configured threshold the strict policy holds (any survived
    // or timed-out mutant fails). With a `.zfa.json` threshold the score
    // governs — except timed-out mutants, which always fail (a bounded
    // wall-clock kill is never a pass).
    final MutationGateDecision gate;
    if (_scoreThreshold != null) {
      if (mutationResult.timeoutCount > 0) {
        gate = MutationGateDecision.failTimeout;
      } else if (mutationResult.killedCount / mutationResult.totalMutants >=
          _scoreThreshold) {
        gate = MutationGateDecision.pass;
      } else {
        gate = MutationGateDecision.failSurvived;
      }
    } else {
      gate = MutationGateDecision.decide(
        killedCount: mutationResult.killedCount,
        survivedCount: mutationResult.survivedCount,
        timedOutCount: mutationResult.timeoutCount,
        notAssessed: false,
        preflightRed: false,
      );
    }

    return MutationAuditReport(
      feature: p.basename(featureDir),
      gate: gate,
      killedCount: mutationResult.killedCount,
      survivedCount: mutationResult.survivedCount,
      timedOutCount: mutationResult.timeoutCount,
      behaviorIds: scope.behaviorIds,
      sourceCriteriaByBehavior: scope.sourceCriteriaByBehavior,
      mutationWasRun: true,
      restorationVerified: restorer.hashMatchesAll(),
      restorationScope: restorer.capturedPaths,
      runnerCommand: 'dart run mutation_test',
      exitCode: mutationResult.exitCode,
      elapsedSeconds: mutationResult.elapsed.inSeconds,
      reportPath: mutationResult.reportPath,
      mutationScore: mutationResult.killedCount / mutationResult.totalMutants,
      scoreThreshold: _scoreThreshold,
      survivors: mutationResult.survivors,
      specHash: specHash,
      subjectHashes: subjectHashes,
      preflightScopeRan: preflight.ranTestPaths,
    );
  }

  /// The whole preflight phase's deadline (bug #742): one wall-clock
  /// budget shared across the per-behavior runs, so `--timeout` keeps
  /// bounding the phase exactly as it bounded the pre-#924 combined
  /// invocation.
  Duration get _effectivePreflightTimeout =>
      _preflightTimeout ?? TddTimeouts.defaultMutationPreflight;

  /// Bug #924: per-behavior green-suite preflight. When the feature has
  /// its own test files, run EACH registered test file individually (the
  /// TDD profile's single/file template shape) and fail fast on the first
  /// red — instead of one combined `dart test` over the whole scope, the
  /// full-suite baseline that hung at corpus scale with 24+ pre-existing
  /// failures. The whole phase stays bounded by [_effectivePreflightTimeout];
  /// the files actually executed are recorded in [PreflightResult.ranTestPaths]
  /// for the verification diagnostics. No own test files → green no-op:
  /// there is NO full-suite fallback.
  Future<PreflightResult> _defaultPreflight(
    List<String> scopePaths,
    String fileTemplate,
  ) async {
    if (scopePaths.isEmpty) {
      return PreflightResult.green(exitCode: 0, output: '(no scope)');
    }
    final ran = <String>[];
    final combined = StringBuffer();
    final phase = Stopwatch()..start();
    for (final testPath in scopePaths) {
      final remaining = _effectivePreflightTimeout - phase.elapsed;
      if (remaining <= Duration.zero) {
        return PreflightResult(
          exitCode: -1,
          output: _preflightBudgetExhaustedOutput(combined, ran),
          timedOut: true,
          ranTestPaths: List.unmodifiable(ran),
        );
      }
      PreflightResult fileResult;
      try {
        fileResult = _runPreflightBehaviorOverride != null
            // Hook path: bound the hook future by the remaining budget.
            ? await _runPreflightBehaviorOverride
                  .call(testPath)
                  .timeout(remaining)
            // Real spawn path: the child itself is killed at the budget.
            : await _runPreflightTestFile(testPath, remaining, fileTemplate);
      } on TimeoutException {
        // The per-behavior run outlived the phase's remaining budget.
        ran.add(testPath);
        return PreflightResult(
          exitCode: -1,
          output: _preflightBudgetExhaustedOutput(combined, ran),
          timedOut: true,
          ranTestPaths: List.unmodifiable(ran),
        );
      } on ProcessTimeoutException {
        // Same verdict for the real spawn path (runTimed killed the child
        // at the remaining budget) — infrastructure, never preflight_red.
        ran.add(testPath);
        return PreflightResult(
          exitCode: -1,
          output: _preflightBudgetExhaustedOutput(combined, ran),
          timedOut: true,
          ranTestPaths: List.unmodifiable(ran),
        );
      }
      ran.add(testPath);
      combined.writeln('--- $testPath ---');
      combined.write(fileResult.output);
      if (!fileResult.isGreen) {
        // Fail fast: the preflight only needs a green/red verdict, and
        // the first red file already decides it (bug #924). Issue
        // #1045: the CLASS travels — a load/compile failure is
        // infrastructure (the tests never ran), not an honest red, and
        // the phase verdict must say so.
        if (fileResult.failedToLoad) {
          return PreflightResult.loadFailure(
            exitCode: fileResult.exitCode,
            output: combined.toString(),
            ranTestPaths: List.unmodifiable(ran),
          );
        }
        return PreflightResult.red(
          exitCode: fileResult.exitCode,
          output: combined.toString(),
          ranTestPaths: List.unmodifiable(ran),
        );
      }
    }
    return PreflightResult.green(
      exitCode: 0,
      output: combined.toString(),
      ranTestPaths: List.unmodifiable(ran),
    );
  }

  String _preflightBudgetExhaustedOutput(
    StringBuffer combined,
    List<String> ran,
  ) =>
      '${combined}preflight phase budget exhausted after '
      '${ran.length} per-behavior test file(s) '
      '(--timeout ${formatTddTimeout(_effectivePreflightTimeout)})';

  /// Runs one behavior's test file under [remaining] — the real spawn
  /// path. Issue #1044: the runner comes from the resolved whole-file
  /// template (the profile's `file:` key; `flutter test {file}` for
  /// Flutter projects), never a literal `dart test`. The child is killed
  /// (SIGKILL) if it outlives the remaining budget — [runTimed] throws
  /// [ProcessTimeoutException] and the loop maps the phase to timed out
  /// (NOT_ASSESSED, never preflight_red).
  Future<PreflightResult> _runPreflightTestFile(
    String testPath,
    Duration remaining,
    String fileTemplate,
  ) async {
    final substituted = fileTemplate.replaceAll('{file}', testPath);
    final tokens = SingleTestRunner.splitCommand(substituted);
    final spawn =
        spawnTest ??
        (String executable, List<String> args, String wd, Duration timeout) =>
            runTimed(executable, args, workingDirectory: wd, timeout: timeout);
    final result = await spawn(
      tokens.first,
      tokens.sublist(1),
      workingDirectory,
      remaining,
    );
    final output = '${result.stdout}\n${result.stderr}';
    return preflightFileResultFromProcess(
      exitCode: result.exitCode,
      output: output,
    );
  }

  Future<MutationResult> _defaultMutation(
    MutationScope scope,
    String configPath,
  ) async {
    // Bug #837: the mutation run is scoped to the feature's registered
    // subjects (namespaced per #827) — never the whole repo — and the
    // mutant test command runs only the feature's scope tests. Bug #924:
    // the scoped config was already written by [_ensureScopedMutationConfig]
    // BEFORE the preflight (so a config failure returns NOT_ASSESSED
    // immediately); this phase only consumes it.
    final verifier = MutationVerifier(
      configPath: configPath,
      outputDir: p.join(
        workingDirectory,
        '.dart_tool',
        'zfa',
        'tdd-verify-report',
      ),
      workingDirectory: workingDirectory,
      timeout: _mutationTimeout,
    );
    return verifier.run();
  }

  /// Writes the feature-scoped mutation_test config under
  /// `.dart_tool/zfa/` and returns its absolute path (bug #924: called
  /// BEFORE the preflight so a missing/unwritable config yields
  /// `gate: not_assessed` without running any tests). Throws
  /// [MutationConfigError] when the config cannot be created.
  /// Issue #1044: the mutant test command is built from [fileTemplate] —
  /// the same resolved runner the preflight used — so mutants re-run
  /// under the profile's runner.
  Future<String> _ensureScopedMutationConfig(
    MutationScope scope,
    String fileTemplate,
  ) async {
    final configPath = p.join(
      workingDirectory,
      '.dart_tool',
      'zfa',
      'tdd-verify-mutation.xml',
    );
    try {
      final configFile = File(configPath);
      await configFile.parent.create(recursive: true);
      await configFile.writeAsString(
        buildScopedMutationConfig(
          subjectPaths: _relativeToWorkingDirectory(scope.subjectPaths),
          testPaths: _relativeToWorkingDirectory(scope.testPaths),
          fileTemplate: fileTemplate,
        ),
      );
    } on IOException catch (e) {
      throw MutationConfigError(
        'could not write the scoped mutation config at $configPath: $e',
      );
    }
    return configPath;
  }

  /// Registry paths may be absolute (the gen convention) or repo-relative;
  /// the mutation config wants project-relative paths.
  List<String> _relativeToWorkingDirectory(List<String> paths) => paths
      .map(
        (path) => p.isAbsolute(path)
            ? p.relative(path, from: workingDirectory)
            : path,
      )
      .toList();
}

/// The per-behavior file verdict from a finished `dart test <file>` child
/// (bug #924, mutation finding M-1): factored out of the spawn path so the
/// fast tier pins the green/red classification directly — the real spawn
/// path is otherwise only driven by the integration tier.
///
/// Issue #1045: the classification is honest by construction — a non-zero
/// exit is only an honest RED when the tests actually RAN and failed
/// (`Some tests failed` / `[E]` lines, no load markers). A load/compile
/// failure (`Failed to load`, `compilation failed`) is infrastructure —
/// the same class as the #742 timeout — and an unrecognizable output is
/// an honest unknown. Both surface as a load failure (NOT_ASSESSED),
/// never as an invented red. Load markers win over the terminal
/// `Some tests failed.` line: a child whose file failed to load prints
/// BOTH.
PreflightResult preflightFileResultFromProcess({
  required int exitCode,
  required String output,
}) {
  if (exitCode == 0) {
    return PreflightResult.green(exitCode: 0, output: output);
  }
  if (preflightOutputIndicatesLoadFailure(output)) {
    return PreflightResult.loadFailure(exitCode: exitCode, output: output);
  }
  if (preflightOutputIndicatesAssertionsRan(output)) {
    return PreflightResult.red(exitCode: exitCode, output: output);
  }
  // No recognizable signature: the tests' state is unknown — an honest
  // NOT_ASSESSED beats an invented red (FR-008's spirit, at the verdict
  // boundary).
  return PreflightResult.loadFailure(exitCode: exitCode, output: output);
}

/// Load/compile failure signatures across the dart/flutter test runners.
bool preflightOutputIndicatesLoadFailure(String output) {
  final lower = output.toLowerCase();
  return lower.contains('failed to load') ||
      lower.contains('compilation failed') ||
      lower.contains('error: compilation');
}

/// Assertion-failure signatures: the tests compiled, ran, and failed.
bool preflightOutputIndicatesAssertionsRan(String output) =>
    output.contains('Some tests failed') || output.contains('[E]');

/// Builds the feature-scoped mutation_test config for `zfa tdd verify`
/// (bug #837).
///
/// Mutants are generated for the feature's registered subjects ONLY
/// (namespacing per #827) and the mutant test command runs ONLY the
/// feature's scope tests, keeping the run bounded at corpus scale. Paths
/// must already be project-relative.
///
/// Issue #1044: [fileTemplate] is the resolved whole-file runner (the
/// profile's `file:` key, an explicit `--runner` override, or the
/// pure-Dart default when no profile exists). The mutant command
/// substitutes the FIRST test path and appends the rest — the same
/// batch convention the profile template documents — so Flutter
/// projects re-run mutants under `flutter test`, never `dart test`.
String buildScopedMutationConfig({
  required List<String> subjectPaths,
  required List<String> testPaths,
  required String fileTemplate,
}) {
  String esc(String raw) => raw
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  final files = subjectPaths
      .map((f) => '    <file>${esc(f)}</file>')
      .join('\n');
  final command = esc(mutantCommandFromTemplate(fileTemplate, testPaths));
  return '<mutations version="1.0">\n'
      '  <files>\n'
      '$files\n'
      '  </files>\n'
      '  <commands>\n'
      '    <command group="test" expected-return="0" '
      'working-directory=".">$command</command>\n'
      '  </commands>\n'
      '</mutations>\n';
}

/// The mutant test command for a resolved whole-file [template] over
/// [testPaths]: the template with the FIRST path substituted, the rest
/// appended (the batch convention `loadFileTemplate` documents).
String mutantCommandFromTemplate(String template, List<String> testPaths) {
  if (testPaths.isEmpty) return template.replaceAll('{file}', '');
  final first = template.replaceAll('{file}', testPaths.first);
  final rest = testPaths.skip(1).join(' ');
  return rest.isEmpty ? first : '$first $rest';
}

/// Extension to make hash-matching ergonomic on [SourceRestorer].
extension on SourceRestorer {
  bool hashMatchesAll() {
    for (final path in capturedPaths) {
      if (!hashMatches(path)) return false;
    }
    return true;
  }
}
