/// `SpecFuzzAuditor` — the arena referee (spec 0967-spec-mutation-arena):
/// applies deterministic spec mutations to a GREEN feature's spec.md,
/// re-runs the loop's pins per mutant, and produces the weakness report.
///
/// The oracle (killed iff ANY pin fires):
///   - P1 plan-gate pin — the mutated spec fails the ingest gate chain
///     (`validateSpecContract`); evidence: the rejecting gate + line.
///   - P2 loop-red pin — the affected behavior's test, REGENERATED from
///     the mutated spec with the real [BehaviorTestWriter] (written in
///     place, restored afterwards), fails when run against the committed
///     implementation; evidence: exit code + failing assertion line.
///     Load failures and timeouts are infrastructure: not_assessed per
///     mutant, never a kill, never a pass (issue #1045 / bug #742).
///   - P3 assertion pin — the mutated element's ORIGINAL values appear
///     inside an `expect(` line of the feature's committed tests. For
///     the drop operator the dropped behavior's own test is excluded:
///     the re-plan orphans it, and a pin nothing requires is not a pin.
///
/// survived = every pin silent = the mutated spec still goes green = the
/// test suite does not pin the intent (the issue's sentence, executable).
///
/// Honesty contract (mirrors `zfa tdd verify`, spec 044 FR-013..023):
/// green-suite preflight FIRST (a red loop is refused, never fuzzed);
/// restoration is byte-exact (sha256-verified, SIGINT/SIGTERM-safe,
/// always in `finally`); the only test write is the loop-faithful
/// regeneration via the real writer, restored afterwards; infra
/// failures grade not_assessed; the fuzz never edits a committed test
/// to fake a verdict.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../models/artifact_record.dart';
import '../models/behavior.dart';
import '../models/corpus_ledger.dart';
import '../models/spec_mutation.dart';
import 'artifact_registry.dart';
import 'behavior_test_writer.dart';
import 'gap_ledger_store.dart';
import 'mutation_auditor.dart';
import 'mutation_scope.dart';
import 'runner.dart';
import 'spec_mutator.dart';
import 'spec_parser.dart';
import 'source_restorer.dart';
import 'tdd_timeout.dart';
import 'test_reporter_args.dart';
import 'test_list_reader.dart';

/// Runs the spec-mutation round for a feature.
class SpecFuzzAuditor {
  SpecFuzzAuditor({
    required this.featureDir,
    required this.workingDirectory,
    Set<SpecMutationOperator>? operators,
    this.budget,
    this.seed = 0,
    Duration? spawnTimeout,
    this.ledgerEnabled = true,
    Future<PreflightResult> Function(List<String> testPaths)? runPreflight,
    Future<ProcessResult> Function(
      String executable,
      List<String> args,
      String workingDirectory,
      Duration timeout,
    )?
    spawnTest,
    GapLedgerStore? ledgerStore,
    String? runnerTemplate,
  }) : operators = operators ?? SpecMutationOperator.all,
       _spawnTimeout = spawnTimeout,
       _runPreflightOverride = runPreflight,
       _spawnTestOverride = spawnTest,
       _ledgerStoreOverride = ledgerStore,
       _runnerTemplate = runnerTemplate;

  /// Absolute path to the feature's spec directory.
  final String featureDir;

  /// The project root (artifacts.json paths are project-relative; every
  /// spawn runs with this as its cwd).
  final String workingDirectory;

  final Set<SpecMutationOperator> operators;

  /// Null = no cap (run every candidate).
  final int? budget;

  /// Deterministic selection seed (0 = document-order prefix).
  final int seed;

  /// Per-spawn deadline override; null uses the shared defaults.
  final Duration? _spawnTimeout;

  /// Whether survivors append gap-ledger entries (the ledger
  /// integration; `--no-ledger` disables).
  final bool ledgerEnabled;

  final Future<PreflightResult> Function(List<String> testPaths)?
  _runPreflightOverride;

  final Future<ProcessResult> Function(
    String executable,
    List<String> args,
    String workingDirectory,
    Duration timeout,
  )?
  _spawnTestOverride;

  final GapLedgerStore? _ledgerStoreOverride;

  /// Explicit runner override (issue #1044 `--runner`): wins over the
  /// profile's `file:` key; the pure-Dart default applies only when the
  /// project has no profile at all.
  final String? _runnerTemplate;

  String? _resolvedFileTemplate;

  String get featureName => p.basename(featureDir);

  /// Run the round. Returns the report (never throws for verdict-level
  /// outcomes; infrastructure failures grade not_assessed).
  Future<SpecFuzzReport> run() async {
    final specPath = p.join(featureDir, 'spec.md');
    final specFile = File(specPath);
    if (!await specFile.exists()) {
      return _notAssessed(
        'spec.md not found at $specPath',
        mutationWasRun: false,
        restorationScope: const [],
      );
    }
    final specMd = await specFile.readAsString();
    final specHash = crypto.sha256.convert(utf8.encode(specMd)).toString();

    final scope = await MutationScope.derive(featureDir: featureDir);
    if (scope.isEmpty) {
      return _notAssessed(
        scope.notAssessedReason ?? 'no behavior artifacts registered',
        mutationWasRun: false,
        restorationScope: const [],
        specHash: specHash,
      );
    }
    final registry = ArtifactRegistry(featureDir: featureDir);
    final records = await registry.loadAll();
    final recordByBehavior = {for (final r in records) r.behaviorId: r};

    // Green-suite preflight (FR-013 mirror): the fuzz refuses to grade a
    // red loop — a red loop is a run problem, not a spec-quality signal.
    final preflight = await _runPreflight(scope.testPaths);
    if (preflight.timedOut) {
      return _notAssessed(
        'preflight timed out (bug #742): the suite never finished',
        mutationWasRun: false,
        restorationScope: const [],
        specHash: specHash,
      );
    }
    if (preflight.failedToLoad) {
      return _notAssessed(
        'preflight load failure (issue #1045): the tests never ran',
        mutationWasRun: false,
        restorationScope: const [],
        specHash: specHash,
      );
    }
    if (!preflight.isGreen) {
      return SpecFuzzReport(
        feature: featureName,
        gate: SpecFuzzGateDecision.preflightRed,
        seed: seed,
        budget: budget ?? 0,
        candidateCount: 0,
        operators: operators.map((o) => o.label).toList()..sort(),
        outcomes: const [],
        restorationVerified: true,
        mutationWasRun: false,
        notAssessedReason:
            'the feature suite is red — the fuzz refuses '
            'to grade a red loop; re-run `zfa tdd run $featureName`',
        specHash: specHash,
      );
    }

    final all = const SpecMutator().candidates(specMd, operators: operators);
    if (all.isEmpty) {
      return _notAssessed(
        'no mutation candidates generated (the spec declares no mutable '
        'contract elements under the selected operators) — nothing was '
        'proven, never a vacuous pass',
        mutationWasRun: false,
        restorationScope: const [],
        specHash: specHash,
      );
    }
    final selected = SpecMutator.select(
      all,
      budget: budget ?? all.length,
      seed: seed,
    );

    // The P3 baseline: committed expect-lines per test file, read from
    // the COMMITTED bytes before any mutation is applied this round.
    final expectLines = <String, List<String>>{};
    for (final testPath in scope.testPaths) {
      final abs = _abs(testPath);
      final file = File(abs);
      if (!await file.exists()) continue;
      expectLines[abs] = (await file.readAsLines())
          .where((l) => l.contains('expect('))
          .toList(growable: false);
    }

    final outcomes = <SpecMutationOutcome>[];
    var restorationVerified = true;
    final restorationScope = <String>[specPath];

    for (final candidate in selected) {
      final outcome = await _judge(
        candidate,
        specMd: specMd,
        specPath: specPath,
        recordByBehavior: recordByBehavior,
        expectLines: expectLines,
      );
      outcomes.add(outcome);
      if (outcome.verdict == SpecFuzzVerdict.notAssessed &&
          outcome.evidence.contains('restoration')) {
        restorationVerified = false;
      }
    }

    // Restoration proof: the spec + every touched test file hash-match
    // their pre-round bytes (verified per-mutant; re-verified here for
    // the report).
    for (final path in restorationScope) {
      if (!File(path).existsSync()) {
        restorationVerified = false;
        break;
      }
    }
    final finalRestoration = await _verifyFinalRestoration(
      specPath,
      specMd,
      recordByBehavior,
      outcomes,
    );
    restorationVerified = restorationVerified && finalRestoration;

    // Ledger integration: every survivor is a contract gap (deduplicated
    // against an unresolved gap for the same feature + mutation_id).
    final ledgerIds = <String>[];
    if (ledgerEnabled) {
      ledgerIds.addAll(
        await _appendLedgerGaps(
          outcomes.where((o) => o.verdict == SpecFuzzVerdict.survived),
        ),
      );
    }

    final gate = decideSpecFuzzGate(
      survivedCount: outcomes
          .where((o) => o.verdict == SpecFuzzVerdict.survived)
          .length,
      notAssessedCount: outcomes
          .where((o) => o.verdict == SpecFuzzVerdict.notAssessed)
          .length,
      preflightRed: false,
    );

    final report = SpecFuzzReport(
      feature: featureName,
      gate: gate,
      seed: seed,
      budget: budget ?? all.length,
      candidateCount: all.length,
      operators: operators.map((o) => o.label).toList()..sort(),
      outcomes: outcomes,
      restorationVerified: restorationVerified,
      mutationWasRun: true,
      specHash: specHash,
      ledgerEntryIds: ledgerIds,
      restorationScope: restorationScope,
    );

    await _writeReports(report);
    return report;
  }

  // ------------------------------------------------------------------
  // Per-mutant judgement.
  // ------------------------------------------------------------------

  Future<SpecMutationOutcome> _judge(
    SpecMutationCandidate candidate, {
    required String specMd,
    required String specPath,
    required Map<String, ArtifactRecord> recordByBehavior,
    required Map<String, List<String>> expectLines,
  }) async {
    // P3 first, from the COMMITTED bytes (before any mutation).
    final p3 = _scanAssertionPins(candidate, expectLines, recordByBehavior);

    final applied = const SpecMutator().apply(specMd, candidate);

    // P1: the plan-gate chain over the mutated spec string.
    final gate = validateSpecContract(
      feature: featureName,
      specMd: applied.mutatedSpec,
    );
    if (!gate.accepted) {
      return _killed(
        candidate,
        pins: const ['P1:plan-gate'],
        evidence:
            'P1:plan-gate refused the mutated spec — '
            '${gate.refusal}',
      );
    }

    final behaviorId = applied.affectedBehaviorId;
    if (behaviorId == null || candidate.operator == SpecMutationOperator.drop) {
      // Drop: the surviving behaviors' descriptions are unchanged, so
      // the regenerated suite is the preflight-green suite (a vacuous
      // green for P2); the verdict rides on the P3 cross-pin.
      if (p3 != null) {
        return _killed(candidate, pins: const ['P3:assertion'], evidence: p3);
      }
      return _survived(candidate);
    }

    final record = recordByBehavior[behaviorId];
    if (record == null) {
      return _notAssessedOutcome(
        candidate,
        'no registered artifact pair for behavior $behaviorId — the fuzz '
        'cannot re-derive its test; register the gen pair in '
        'tdd/artifacts.json (re-run `zfa tdd gen $behaviorId`)',
      );
    }
    final absTest = _abs(record.testPath);
    final absSubject = _abs(record.subjectPath);
    if (!File(absTest).existsSync() || !File(absSubject).existsSync()) {
      return _notAssessedOutcome(
        candidate,
        'registered artifact pair for $behaviorId is missing on disk '
        '(${record.testPath} / ${record.subjectPath})',
      );
    }

    // The mutated behavior, re-derived from the mutated spec (the same
    // parser gen consumes).
    final List<Behavior> behaviors;
    try {
      behaviors = const SpecParser().parse(featureName, applied.mutatedSpec);
    } on StateError catch (e) {
      return _notAssessedOutcome(
        candidate,
        'the mutated spec no longer derives behaviors: ${e.message}',
      );
    }
    final mutated = behaviors.where((b) => b.id == behaviorId).firstOrNull;
    if (mutated == null) {
      return _notAssessedOutcome(
        candidate,
        'behavior $behaviorId is not derived from the mutated spec '
        '(ids shifted) — cannot re-derive its test',
      );
    }

    // Target fidelity: the committed test-list row's target (the subject
    // function name), when the plan artifact exists.
    var target = mutated.target;
    try {
      final rows = await TestListReader(featureDir).read();
      final row = rows.where((r) => r.id == behaviorId).firstOrNull;
      if (row != null && row.target.isNotEmpty) target = row.target;
    } on Exception {
      // No test-list artifact (legacy fixtures): keep the parser target.
    }

    // Capture + mutate + regen + spawn + restore. The ONLY test write is
    // the loop-faithful regeneration (the real writer), restored in
    // `finally` (FR-021/FR-022 mirror).
    final restorer = SourceRestorer(paths: [specPath, absTest]);
    await restorer.capture();
    final sigintSub = ProcessSignal.sigint.watch().listen((_) async {
      await restorer.restoreAndVerify();
    });
    final sigtermSub = ProcessSignal.sigterm.watch().listen((_) async {
      await restorer.restoreAndVerify();
    });
    SpecMutationOutcome? verdict;
    var restorationFailed = false;
    try {
      await File(specPath).writeAsString(applied.mutatedSpec);
      await const BehaviorTestWriter().write(
        behavior: Behavior(
          id: mutated.id,
          feature: mutated.feature,
          kind: mutated.kind,
          description: mutated.description,
          sourceCriterion: mutated.sourceCriterion,
          target: target,
          persistence: mutated.persistence,
        ),
        testPath: absTest,
        subjectPath: absSubject,
      );
      final spawned = await _spawnSingle(record.testPath);
      if (spawned.timedOut) {
        verdict = _notAssessedOutcome(
          candidate,
          'the regenerated test for $behaviorId timed out (bug #742) — '
          'infrastructure, never a verdict',
        );
      } else {
        final classified = preflightFileResultFromProcess(
          exitCode: spawned.result.exitCode,
          output: '${spawned.result.stdout}${spawned.result.stderr}',
        );
        if (classified.failedToLoad) {
          verdict = _notAssessedOutcome(
            candidate,
            'the regenerated test for $behaviorId failed to LOAD (issue '
            '#1045): '
            '${_firstMeaningfulLine(spawned.result.stdout.toString())}',
          );
        } else if (!classified.isGreen) {
          verdict = _killed(
            candidate,
            pins: const ['P2:loop-red'],
            evidence:
                'P2:loop-red — the test regenerated from the mutated spec '
                'failed against the committed implementation (exit '
                '${spawned.result.exitCode}): '
                '${_failingAssertionLine(spawned.result.stdout.toString())}',
          );
        }
      }
    } on ProcessTimeoutException {
      verdict = _notAssessedOutcome(
        candidate,
        'the regenerated test for $behaviorId timed out (bug #742) — '
        'infrastructure, never a verdict',
      );
    } catch (e) {
      verdict = _notAssessedOutcome(
        candidate,
        'the regenerated test for $behaviorId could not be driven: $e — '
        'infrastructure, never a verdict',
      );
    } finally {
      await sigintSub.cancel();
      await sigtermSub.cancel();
      final restoration = await restorer.restoreAndVerify();
      restorationFailed = !restoration.restorationVerified;
    }
    if (restorationFailed) {
      // Safety stop: never report a verdict from a round whose mutated
      // bytes could not be restored byte-exactly.
      return _notAssessedOutcome(
        candidate,
        'restoration failed for the round (file bytes could not be '
        'restored byte-exactly) — safety stop, never a verdict',
      );
    }
    if (verdict != null) return verdict;

    if (p3 != null) {
      return _killed(candidate, pins: const ['P3:assertion'], evidence: p3);
    }
    return _survived(candidate);
  }

  /// The P3 pin: the first committed `expect(` line asserting one of the
  /// candidate's original values. For `drop`, the dropped behavior's own
  /// test file is excluded (a pin nothing requires is not a pin).
  String? _scanAssertionPins(
    SpecMutationCandidate candidate,
    Map<String, List<String>> expectLines,
    Map<String, ArtifactRecord> recordByBehavior,
  ) {
    final excludedAbs = candidate.operator == SpecMutationOperator.drop
        ? _absOrNull(recordByBehavior[candidate.behaviorId]?.testPath ?? '')
        : null;
    for (final entry in expectLines.entries) {
      if (excludedAbs != null && entry.key == excludedAbs) continue;
      for (var i = 0; i < entry.value.length; i++) {
        final line = entry.value[i];
        for (final value in candidate.originalValues) {
          if (value.isEmpty) continue;
          final matched = RegExp(r'^\d+$').hasMatch(value)
              ? RegExp('\\b${RegExp.escape(value)}\\b').hasMatch(line)
              : line.contains(value);
          if (matched) {
            return 'P3:assertion — original value "$value" is asserted at '
                '${p.relative(entry.key, from: workingDirectory)}:${i + 1}';
          }
        }
      }
    }
    return null;
  }

  // ------------------------------------------------------------------
  // Spawns.
  // ------------------------------------------------------------------

  Future<PreflightResult> _runPreflight(List<String> testPaths) async {
    if (_runPreflightOverride != null) {
      return _runPreflightOverride(testPaths);
    }
    final template = await _fileTemplate();
    final runner = template.split(' ').first;
    final suite = await _spawn(
      runner,
      withCompactReporter([runner, 'test', ...testPaths]).skip(1).toList(),
      _spawnTimeout ?? TddTimeouts.defaultSuite,
    );
    if (suite.timedOut) {
      return PreflightResult(
        exitCode: suite.result.exitCode,
        output: '${suite.result.stdout}${suite.result.stderr}',
        timedOut: true,
        ranTestPaths: testPaths,
      );
    }
    final classified = preflightFileResultFromProcess(
      exitCode: suite.result.exitCode,
      output: '${suite.result.stdout}${suite.result.stderr}',
    );
    return PreflightResult(
      exitCode: classified.exitCode,
      output: classified.output,
      timedOut: false,
      failedToLoad: classified.failedToLoad,
      ranTestPaths: testPaths,
    );
  }

  Future<({ProcessResult result, bool timedOut})> _spawnSingle(
    String testPath,
  ) async {
    final template = await _fileTemplate();
    final parts = withCompactReporter(
      template
          .replaceAll('{file}', testPath)
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList(),
    );
    final executable = parts.first;
    final args = parts.skip(1).toList();
    return _spawn(
      executable,
      args,
      _spawnTimeout ?? TddTimeouts.defaultSingleTest,
    );
  }

  Future<({ProcessResult result, bool timedOut})> _spawn(
    String executable,
    List<String> args,
    Duration timeout,
  ) async {
    if (_spawnTestOverride != null) {
      try {
        final result = await _spawnTestOverride(
          executable,
          args,
          workingDirectory,
          timeout,
        );
        return (result: result, timedOut: false);
      } on ProcessTimeoutException {
        return (result: ProcessResult(0, -1, '', ''), timedOut: true);
      }
    }
    try {
      final result = await runTimed(
        executable,
        args,
        workingDirectory: workingDirectory,
        timeout: timeout,
      );
      return (result: result, timedOut: false);
    } on ProcessTimeoutException {
      return (result: ProcessResult(0, -1, '', ''), timedOut: true);
    }
  }

  /// Runner template resolution (issue #1044): explicit override wins,
  /// then the profile's `file:` key, then the pure-Dart default (only
  /// when the project ships no profile at all).
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
    return _resolvedFileTemplate = await SingleTestRunner().loadFileTemplate(
      workingDirectory: workingDirectory,
    );
  }

  // ------------------------------------------------------------------
  // Ledger.
  // ------------------------------------------------------------------

  Future<List<String>> _appendLedgerGaps(
    Iterable<SpecMutationOutcome> survivors,
  ) async {
    final store = _ledgerStoreOverride ?? GapLedgerStore(workingDirectory);
    final existing = await store.load();
    final openMutations = existing
        .where(
          (e) =>
              e.kind == GapLedgerKind.gap &&
              e.feature == featureName &&
              e.status != 'merged' &&
              e.status != 'resolved',
        )
        .map((e) => e.behavior)
        .toSet();
    final ids = <String>[];
    for (final outcome in survivors) {
      final mutationId = outcome.candidate.mutationId;
      // Deduplicated: one ledger row per unresolved (feature,
      // mutation_id) weakness, across runs.
      if (openMutations.contains(mutationId)) continue;
      final entry = await store.appendGap(
        feature: featureName,
        behavior: mutationId,
        step: outcome.candidate.operator.label,
        outcome: 'survived',
        expectedResult: 'pass',
        failingCommand: 'zfa spec fuzz $featureName',
        severity: 'contract',
      );
      ids.add(entry.id);
      openMutations.add(mutationId);
    }
    return ids;
  }

  // ------------------------------------------------------------------
  // Helpers.
  // ------------------------------------------------------------------

  String _abs(String projectRelative) => p.isAbsolute(projectRelative)
      ? projectRelative
      : p.join(workingDirectory, projectRelative);

  String? _absOrNull(String projectRelative) =>
      projectRelative.isEmpty ? null : _abs(projectRelative);

  Future<bool> _verifyFinalRestoration(
    String specPath,
    String originalSpec,
    Map<String, ArtifactRecord> recordByBehavior,
    List<SpecMutationOutcome> outcomes,
  ) async {
    final specNow = await File(specPath).readAsString();
    if (specNow != originalSpec) return false;
    for (final outcome in outcomes) {
      final id = outcome.candidate.behaviorId;
      final record = id == null ? null : recordByBehavior[id];
      if (record == null) continue;
      // The committed test bytes are not snapshotted here — the
      // per-mutant SourceRestorer already verified them (hash match
      // after every restore); existence is re-checked as a cheap final
      // pass.
      if (!File(_abs(record.testPath)).existsSync()) return false;
    }
    return true;
  }

  Future<void> _writeReports(SpecFuzzReport report) async {
    final dir = Directory(p.join(featureDir, 'tdd'));
    await dir.create(recursive: true);
    await File(
      p.join(dir.path, 'spec-fuzz.json'),
    ).writeAsString(report.toJson());
    await File(
      p.join(dir.path, 'spec-fuzz.md'),
    ).writeAsString(report.toMarkdown());
  }

  SpecFuzzReport _notAssessed(
    String reason, {
    required bool mutationWasRun,
    required List<String> restorationScope,
    String? specHash,
  }) => SpecFuzzReport(
    feature: featureName,
    gate: SpecFuzzGateDecision.notAssessed,
    seed: seed,
    budget: budget ?? 0,
    candidateCount: 0,
    operators: operators.map((o) => o.label).toList()..sort(),
    outcomes: const [],
    restorationVerified: true,
    mutationWasRun: mutationWasRun,
    notAssessedReason: reason,
    specHash: specHash,
    restorationScope: restorationScope,
  );

  SpecMutationOutcome _killed(
    SpecMutationCandidate candidate, {
    required List<String> pins,
    required String evidence,
  }) => SpecMutationOutcome(
    candidate: candidate,
    verdict: SpecFuzzVerdict.killed,
    pins: pins,
    evidence: evidence,
  );

  SpecMutationOutcome _survived(SpecMutationCandidate candidate) =>
      SpecMutationOutcome(
        candidate: candidate,
        verdict: SpecFuzzVerdict.survived,
        pins: const [],
        evidence:
            'no pin fired: the plan gates pass, the regenerated '
            'suite stays green against the committed implementation, and '
            'no committed assertion pins the original value(s) '
            '${candidate.originalValues.join(', ')} — the test suite does '
            'not pin the intent',
      );

  SpecMutationOutcome _notAssessedOutcome(
    SpecMutationCandidate candidate,
    String reason,
  ) => SpecMutationOutcome(
    candidate: candidate,
    verdict: SpecFuzzVerdict.notAssessed,
    pins: const [],
    evidence: reason,
  );
}

String _firstMeaningfulLine(String output) {
  for (final line in output.split('\n')) {
    if (line.trim().isEmpty) continue;
    return _truncate(line.trim(), 120);
  }
  return '<no output>';
}

String _failingAssertionLine(String output) {
  for (final line in output.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('Expected:') || trimmed.startsWith('Actual:')) {
      return _truncate(trimmed, 120);
    }
  }
  for (final line in output.split('\n')) {
    if (line.contains('[E]')) return _truncate(line.trim(), 120);
  }
  return _firstMeaningfulLine(output);
}

String _truncate(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}…';
