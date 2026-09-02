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
import 'source_restorer.dart';
import 'tdd_timeout.dart';

/// The result of a green-suite preflight.
class PreflightResult {
  PreflightResult({
    required this.exitCode,
    required this.output,
    this.timedOut = false,
  });

  /// 0 = green, non-zero = red.
  final int exitCode;

  /// Captured stdout from the preflight run.
  final String output;

  /// True when the preflight process was killed by the per-command timeout
  /// (bug #742): an infrastructure failure — the tests never finished, so
  /// the audit is NOT_ASSESSED, never `preflight_red`.
  final bool timedOut;

  bool get isGreen => exitCode == 0;

  factory PreflightResult.green({
    required int exitCode,
    required String output,
  }) => PreflightResult(exitCode: exitCode, output: output);

  factory PreflightResult.red({
    required int exitCode,
    required String output,
  }) => PreflightResult(exitCode: exitCode, output: output);
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
    Future<MutationResult> Function()? runMutation,
    Duration? preflightTimeout,
    Duration? mutationTimeout,
    double? scoreThreshold,
  }) : _runPreflightOverride = runPreflight,
       _runMutationOverride = runMutation,
       _preflightTimeout = preflightTimeout,
       _mutationTimeout = mutationTimeout,
       _scoreThreshold = scoreThreshold;

  final String featureDir;
  final String workingDirectory;
  final Future<PreflightResult> Function(List<String> scopePaths)?
  _runPreflightOverride;
  final Future<MutationResult> Function()? _runMutationOverride;

  /// Per-command deadlines (bug #742); `null` uses the shared defaults.
  final Duration? _preflightTimeout;
  final Duration? _mutationTimeout;

  /// Mutation score threshold from `.zfa.json` (bug #837); `null` applies
  /// the strict policy (any survived or timed-out mutant fails the gate).
  final double? _scoreThreshold;

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

    // Green-suite preflight FIRST (FR-013). Run only the test paths
    // (not subject paths — subject files are not tests and `dart test`
    // would fail to load them as tests).
    final preflight = await (_runPreflightOverride ?? _defaultPreflight)(
      scope.testPaths,
    );
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
          await (_runMutationOverride ?? () => _defaultMutation(scope))();
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
    );
  }

  Future<PreflightResult> _defaultPreflight(List<String> scopePaths) async {
    // Run `dart test <scope>` under a hard deadline (bug #742) and capture
    // the exit code + output.
    if (scopePaths.isEmpty) {
      return PreflightResult.green(exitCode: 0, output: '(no scope)');
    }
    try {
      final result = await runTimed(
        'dart',
        ['test', ...scopePaths],
        workingDirectory: workingDirectory,
        timeout: _preflightTimeout ?? TddTimeouts.defaultMutationPreflight,
      );
      if (result.exitCode == 0) {
        return PreflightResult.green(
          exitCode: 0,
          output: result.stdout.toString(),
        );
      }
      return PreflightResult.red(
        exitCode: result.exitCode,
        output: '${result.stdout}\n${result.stderr}',
      );
    } on ProcessTimeoutException catch (e) {
      return PreflightResult(
        exitCode: -1,
        output: e.toString(),
        timedOut: true,
      );
    }
  }

  Future<MutationResult> _defaultMutation(MutationScope scope) async {
    // Bug #837: the mutation run is scoped to the feature's registered
    // subjects (namespaced per #827) — never the whole repo — and the
    // mutant test command runs only the feature's scope tests. The scoped
    // config is generated on the fly under `.dart_tool` (gitignored) so a
    // feature project needs no hand-written mutation-test.xml; this is
    // what makes the mutation phase actually executable.
    final configPath = p.join(
      workingDirectory,
      '.dart_tool',
      'zfa',
      'tdd-verify-mutation.xml',
    );
    final configFile = File(configPath);
    await configFile.parent.create(recursive: true);
    await configFile.writeAsString(
      buildScopedMutationConfig(
        subjectPaths: _relativeToWorkingDirectory(scope.subjectPaths),
        testPaths: _relativeToWorkingDirectory(scope.testPaths),
      ),
    );
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

/// Builds the feature-scoped mutation_test config for `zfa tdd verify`
/// (bug #837).
///
/// Mutants are generated for the feature's registered subjects ONLY
/// (namespacing per #827) and the mutant test command runs ONLY the
/// feature's scope tests, keeping the run bounded at corpus scale. Paths
/// must already be project-relative.
String buildScopedMutationConfig({
  required List<String> subjectPaths,
  required List<String> testPaths,
}) {
  String esc(String raw) => raw
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  final files = subjectPaths
      .map((f) => '    <file>${esc(f)}</file>')
      .join('\n');
  final command = testPaths.map(esc).join(' ');
  return '<mutations version="1.0">\n'
      '  <files>\n'
      '$files\n'
      '  </files>\n'
      '  <commands>\n'
      '    <command group="test" expected-return="0" '
      'working-directory=".">dart test $command</command>\n'
      '  </commands>\n'
      '</mutations>\n';
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
