/// `zfa spec fuzz <feature>` — the spec-mutation arena's referee round
/// (spec 0967-spec-mutation-arena, VISION §7, issue #967).
///
/// Applies deterministic spec mutations to a GREEN feature's spec,
/// re-runs the loop's pins per mutant (plan-gate chain, regenerated
/// test against the committed implementation, committed assertion
/// pins), and reports killed/survived. A survived mutant is a proven
/// spec weakness — the test suite does not pin the intent. Survivors
/// append `severity: contract` gap-ledger entries (deduplicated), the
/// machine line carries `certified=<bool>`, and exit is non-zero when
/// survived > 0.
///
/// Exit protocol (the tdd family's): 0 pass / 1 survived > 0 / 2 corpus
/// catalog misfire / 3 spec drift (traceability hash, bug #846) / 64
/// usage + honest not_assessed/preflight_red refusals.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../../cli/services/corpus_catalog.dart';
import '../../../cli/services/corpus_walker.dart';
import '../../../core/project/project_root.dart';
import '../models/spec_mutation.dart';
import '../models/verdict_envelope.dart';
import '../services/requirement_scan.dart';
import '../services/spec_fuzz_auditor.dart';
import '../services/tdd_timeout.dart';
import '../services/verdict_emitter.dart';

class SpecFuzzCommand extends Command<void> {
  SpecFuzzCommand() {
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
          'Feature name (e.g. 0967-spec-mutation-arena). The fuzz derives '
          'its scope from specs/<feature>/tdd/artifacts.json and writes '
          'specs/<feature>/tdd/spec-fuzz.{json,md}.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and lib/. When omitted, '
          'the current working directory is used. Tests pass the temp '
          'fixture root here instead of mutating Directory.current.',
    );
    argParser.addOption(
      'operators',
      valueHelp: 'weaken,drop,swap-literal,widen,drop-must-not',
      help:
          'Comma-separated mutation operators to apply (default: all '
          'five, declared per contract element).',
    );
    argParser.addOption(
      'budget',
      valueHelp: 'N',
      help:
          'Cap the number of mutants run this round (default: every '
          'candidate). With a nonzero seed the subset is a stable '
          'seeded shuffle — deterministic, replay-compatible (#806).',
    );
    argParser.addOption(
      'seed',
      valueHelp: 'N',
      help:
          'Deterministic selection seed (default 0 = document-order '
          'prefix when the budget caps the round).',
    );
    argParser.addOption(
      'timeout',
      valueHelp: 'minutes',
      help:
          'Per-spawn deadline in minutes for the preflight suite and the '
          'per-mutant single-test runs (default: the shared TDD timeouts). '
          'Fractions are allowed. On timeout the mutant is NOT_ASSESSED '
          '(bug #742).',
    );
    argParser.addOption(
      'runner',
      help:
          "Override the test runner: 'dart' or 'flutter'. Wins over the "
          'tdd-profile file: template (issue #1044 semantics).',
    );
    argParser.addFlag(
      'no-ledger',
      negatable: false,
      help:
          'Skip the gap-ledger integration (survivors normally append '
          'severity: contract gap entries, deduplicated per mutation).',
    );
    argParser.addOption(
      'corpus',
      valueHelp: 'target',
      help:
          'Corpus mode: fuzz every feature in the cataloged target '
          '(requireCatalog — the #953 corpus-economics surface) under one '
          'global mutant budget; never stops at a failing feature.',
    );
  }

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'fuzz';

  @override
  String get description =>
      'Mutation testing for intent: apply deterministic spec mutations, '
      're-run the loop, report killed/survived (spec 0967, VISION §7). '
      'Survived mutants are proven spec weaknesses.';

  @override
  String get invocation => 'zfa spec fuzz <feature> [options]';

  @override
  Future<void> run() => runWithVerdictEnvelope(
    this,
    _verdict,
    _run,
    featureFromRest: true,
    commandOverride: 'spec fuzz',
  );

  Future<void> _run() async {
    final args = argResults;
    final rest = args?.rest ?? const <String>[];

    // ---- Operator set (usage errors before any I/O). ----
    final operatorsRaw = args?['operators'] as String?;
    Set<SpecMutationOperator>? operators;
    if (operatorsRaw != null && operatorsRaw.isNotEmpty) {
      try {
        operators = SpecMutationOperator.parseList(operatorsRaw);
      } on FormatException catch (e) {
        usageException(e.message);
      }
      if (operators.isEmpty) {
        usageException(
          '--operators selected nothing — pass at least one of '
          '${SpecMutationOperator.all.map((o) => o.label).join(', ')}',
        );
      }
    }

    // ---- Budget + seed. ----
    final budgetRaw = args?['budget'] as String?;
    int? budget;
    if (budgetRaw != null && budgetRaw.isNotEmpty) {
      budget = int.tryParse(budgetRaw);
      if (budget == null || budget < 1) {
        usageException(
          'invalid --budget "$budgetRaw" — expected an integer >= 1 '
          '(the number of mutants to run this round).',
        );
      }
    }
    final seedRaw = args?['seed'] as String?;
    var seed = 0;
    if (seedRaw != null && seedRaw.isNotEmpty) {
      final parsed = int.tryParse(seedRaw);
      if (parsed == null || parsed < 0) {
        usageException(
          'invalid --seed "$seedRaw" — expected a non-negative integer '
          '(the deterministic selection seed).',
        );
      }
      seed = parsed;
    }

    // ---- Runner override (issue #1044). ----
    final runnerFlag = args?['runner'] as String?;
    String? runnerTemplate;
    if (runnerFlag != null && runnerFlag.isNotEmpty) {
      switch (runnerFlag) {
        case 'dart':
          runnerTemplate = 'dart test {file}';
        case 'flutter':
          runnerTemplate = 'flutter test {file}';
        default:
          // The corpus family's print-to-stdout convention (usage-class
          // refusals must be greppable in captured output).
          print(
            "zfa spec fuzz: --runner accepts 'dart' or 'flutter' "
            "(got '$runnerFlag') --> fix: pass dart|flutter, or set the "
            'file: key in .specify/memory/tdd-profile.md and omit --runner',
          );
          exitCode = 64;
          return;
      }
    }

    // ---- Timeout override. ----
    Duration? timeoutOverride;
    final timeoutRaw = args?['timeout'] as String?;
    if (timeoutRaw != null && timeoutRaw.isNotEmpty) {
      try {
        timeoutOverride = parseTddTimeoutMinutes(timeoutRaw);
      } on TddTimeoutFormatException catch (e) {
        stderr.writeln('zfa spec fuzz: ${e.message}');
        exitCode = 1;
        return;
      }
    }

    final projectFlag = args?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');

    final corpusTarget = args?['corpus'] as String?;
    if (corpusTarget != null && corpusTarget.isNotEmpty) {
      if (rest.isNotEmpty ||
          (args?['feature'] as String?)?.isNotEmpty == true) {
        usageException(
          'choose either a feature (positional or --feature) or '
          '--corpus <target>, not both — the corpus round walks the '
          'cataloged features itself.',
        );
      }
      exitCode = await _runCorpus(
        target: corpusTarget,
        cwd: cwd,
        operators: operators,
        budget: budget,
        seed: seed,
        timeoutOverride: timeoutOverride,
        runnerTemplate: runnerTemplate,
        ledgerEnabled: (args?['no-ledger'] as bool?) != true,
        json: (args?['json'] as bool?) ?? false,
      );
      return;
    }

    // ---- Single-feature mode. ----
    final featureFlag = args?['feature'] as String?;
    final featureName = (featureFlag != null && featureFlag.isNotEmpty)
        ? featureFlag
        : (rest.isNotEmpty ? rest.first : null);
    if (featureName == null || featureName.isEmpty) {
      usageException(
        'feature name is required: $invocation (or pass --corpus <target>)',
      );
    }
    _validateFeatureSegment(featureName);

    final featureDir = p.join(cwd, 'specs', featureName);

    // Drift gate (bug #846 mirror): fuzzing a spec that drifted from the
    // plan's traceability hash audits a stale contract — refuse.
    final drift = await _traceabilityDrift(featureDir);
    if (drift != null) {
      print('   drift: ${drift.reason}');
      print(
        'zfa spec fuzz: DRIFT — ${drift.reason}\n'
        '   re-plan required: re-run `zfa tdd plan $featureName '
        '--project <dir>` to refresh the traceability matrix, then '
        're-fuzz.',
      );
      _verdict
        ..exitClass = 'drift'
        ..outcome = VerdictOutcome.error
        ..fix =
            're-run `zfa tdd plan $featureName --project <dir>`, then '
            're-fuzz'
        ..drifts.add(drift.reason)
        ..feature = featureName;
      exitCode = 3;
      return;
    }

    print('zfa spec fuzz: running the spec-mutation round...');
    print('   feature: $featureName');
    print('   feature_dir: $featureDir');
    print('   operators: ${_operatorLabels(operators).join(', ')}');
    print('   seed: $seed, budget: ${budget ?? 'all candidates'}');

    final auditor = SpecFuzzAuditor(
      featureDir: featureDir,
      workingDirectory: cwd,
      operators: operators,
      budget: budget,
      seed: seed,
      spawnTimeout: timeoutOverride,
      ledgerEnabled: (args?['no-ledger'] as bool?) != true,
      runnerTemplate: runnerTemplate,
    );
    final report = await auditor.run();

    // Human verdict + the machine summary line (the CI contract).
    print('   gate: ${report.gate.name}');
    if (report.notAssessedReason != null) {
      print('   reason: ${report.notAssessedReason}');
    }
    print('   mutations: ${report.outcomes.length}');
    print('   killed: ${report.killedCount}');
    print('   survived: ${report.survivedCount}');
    print('   not_assessed: ${report.notAssessedCount}');
    print('   certified: ${report.certified}');
    print('   fuzz_was_run: ${report.mutationWasRun}');
    print('   restoration_verified: ${report.restorationVerified}');
    final survivors = report.outcomes
        .where((o) => o.verdict == SpecFuzzVerdict.survived)
        .toList();
    if (survivors.isNotEmpty) {
      print('   survived_mutations:');
      for (final s in survivors) {
        print(
          '     - ${s.candidate.mutationId} — ${s.candidate.element} '
          '(spec line ${s.candidate.specLine})',
        );
        print(
          '       --> fix: pin the intent — assert '
          '${s.candidate.originalValues.join(', ')} in the feature\'s '
          'tests, or tighten the statement so the loop re-derives a '
          'stronger assertion.',
        );
      }
    }
    print(report.summaryLine());
    _verdict
      ..exitClass = report.gate.name
      ..outcome = report.gate == SpecFuzzGateDecision.pass
          ? VerdictOutcome.pass
          : VerdictOutcome.fail
      ..details['mutations'] = report.outcomes.length
      ..details['killed'] = report.killedCount
      ..details['survived'] = report.survivedCount
      ..details['not_assessed'] = report.notAssessedCount
      ..details['certified'] = report.certified
      ..details['fuzz_was_run'] = report.mutationWasRun
      ..details['seed'] = report.seed
      ..details['budget'] = report.budget
      ..feature = featureName;
    if (report.gate == SpecFuzzGateDecision.failSurvived) {
      _verdict.fix =
          'pin every survived mutation (see '
          'specs/$featureName/tdd/spec-fuzz.md) — survived mutants are '
          'proven spec weaknesses';
    }

    // Exit protocol: a quality failure (survived > 0) is a real gate
    // verdict — exit 1 with the per-mutant report. Refusal-class gates
    // (not_assessed, preflight_red) keep the 64 usage class (never exit
    // zero on a non-PASS gate).
    if (report.gate == SpecFuzzGateDecision.failSurvived) {
      exitCode = 1;
      return;
    }
    if (report.gate != SpecFuzzGateDecision.pass) {
      throw UsageException(
        'spec fuzz gate: ${report.gate.name}'
            '${report.notAssessedReason != null ? ' (${report.notAssessedReason})' : ''}',
        'See specs/$featureName/tdd/spec-fuzz.md for the full report.',
      );
    }
  }

  // ------------------------------------------------------------------
  // Corpus mode (#953 / #1016 surface).
  // ------------------------------------------------------------------

  Future<int> _runCorpus({
    required String target,
    required String cwd,
    required Set<SpecMutationOperator>? operators,
    required int? budget,
    required int seed,
    required Duration? timeoutOverride,
    required String? runnerTemplate,
    required bool ledgerEnabled,
    required bool json,
  }) async {
    final CorpusCatalog catalog;
    try {
      catalog = requireCatalog(target: target, projectRoot: cwd);
    } on CorpusWalkException catch (e) {
      print('zfa spec fuzz: $e');
      if (!json) {
        _verdict
          ..exitClass = 'runner-error'
          ..outcome = VerdictOutcome.error;
      }
      return 2;
    }
    var remaining = budget;
    final features = <String, Map<String, Object?>>{};
    var certified = 0;
    var failed = 0;
    var notAssessed = 0;
    var used = 0;

    // Never stop at a failing feature — the budget is the gate (#1016).
    for (final feature in catalog.features) {
      if (remaining != null && remaining <= 0) {
        features[feature.name] = {
          'verdict': 'not_assessed',
          'reason': 'budget exhausted',
          'mutations': 0,
        };
        notAssessed++;
        continue;
      }
      final auditor = SpecFuzzAuditor(
        featureDir: p.join(cwd, 'specs', feature.name),
        workingDirectory: cwd,
        operators: operators,
        budget: remaining,
        seed: seed,
        spawnTimeout: timeoutOverride,
        ledgerEnabled: ledgerEnabled,
        runnerTemplate: runnerTemplate,
      );
      final report = await auditor.run();
      final mutations = report.outcomes.length;
      used += mutations;
      if (remaining != null) remaining -= mutations;
      features[feature.name] = {
        'verdict': report.gate.name,
        'mutations': mutations,
        'killed': report.killedCount,
        'survived': report.survivedCount,
        'not_assessed': report.notAssessedCount,
        'certified': report.certified,
      };
      switch (report.gate) {
        case SpecFuzzGateDecision.pass:
          certified++;
        case SpecFuzzGateDecision.failSurvived:
          failed++;
        case SpecFuzzGateDecision.preflightRed:
        case SpecFuzzGateDecision.notAssessed:
          notAssessed++;
      }
      print(
        '[spec-fuzz] ${feature.name} -> ${report.gate.name} '
        '(mutations=$mutations survived=${report.survivedCount})',
      );
    }

    final overBudget = remaining != null && remaining <= 0;
    final result = overBudget ? 'over-budget' : 'ok';
    final state = {
      'target': target,
      'features': features,
      'summary': {
        'features': features.length,
        'certified': certified,
        'failed': failed,
        'not_assessed': notAssessed,
        'budget': budget,
        'used': used,
        'result': result,
      },
    };
    final stateDir = Directory(p.join(cwd, '.zfa', 'corpus', 'spec-fuzz'));
    await stateDir.create(recursive: true);
    await File(
      p.join(stateDir.path, '$target.json'),
    ).writeAsString(const JsonEncoder().convert(state));

    print(
      'spec-fuzz: corpus=$target features=${features.length} '
      'certified=$certified failed=$failed not_assessed=$notAssessed '
      'budget=${budget ?? 'unbounded'} used=$used result=$result',
    );
    _verdict
      ..exitClass = failed > 0 ? 'fail_survived' : result
      ..outcome = failed > 0 ? VerdictOutcome.fail : VerdictOutcome.pass
      ..details['features'] = features.length
      ..details['certified'] = certified
      ..details['failed'] = failed
      ..details['not_assessed'] = notAssessed
      ..details['budget'] = budget
      ..details['used'] = used
      ..details['result'] = result;
    return failed > 0 ? 1 : 0;
  }

  List<String> _operatorLabels(Set<SpecMutationOperator>? operators) =>
      (operators ?? SpecMutationOperator.all).map((o) => o.label).toList()
        ..sort();
}

/// `--feature` lands in a filesystem path: keep it a single plain
/// directory segment (the verify gate's rule).
void _validateFeatureSegment(String feature) {
  if (feature.contains('/') ||
      feature.contains(r'\') ||
      feature == '.' ||
      feature == '..') {
    throw UsageException(
      'invalid feature "$feature": expected a single spec directory name '
          'such as 0967-spec-mutation-arena, not a path.',
      'zfa spec fuzz <feature> [options]',
    );
  }
}

/// The traceability drift between the plan artifact and the current spec
/// contract (bug #846, the verify gate's logic): the fuzz must grade the
/// spec the plan actually planned.
Future<_TraceabilityDrift?> _traceabilityDrift(String featureDir) async {
  final traceFile = File(p.join(featureDir, 'tdd', 'traceability.md'));
  final specFile = File(p.join(featureDir, 'spec.md'));
  if (!await traceFile.exists() || !await specFile.exists()) return null;
  final stored = TraceabilityMatrix.extractSpecHash(
    await traceFile.readAsString(),
  );
  if (stored == null) return null;
  final scan = const RequirementScanner().scan(await specFile.readAsString());
  final current = SpecContractHash.compute(scan);
  if (current == stored) return null;
  return _TraceabilityDrift(
    reason:
        'spec.md changed after plan '
        '(traceability hash $stored -> $current)',
  );
}

class _TraceabilityDrift {
  const _TraceabilityDrift({required this.reason});
  final String reason;
}
