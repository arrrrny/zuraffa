/// `zfa tdd verify --feature <feature>` — runs the mutation audit on the
/// feature's registered behavior artifacts and writes
/// `specs/<feature>/tdd/verification.md` from the REAL run (spec
/// 044-test-tdd-generation, FR-012..023).
///
/// The command:
///   1. Derives the mutation scope from `artifacts.json` (FR-012).
///   2. Runs a green-suite preflight FIRST (FR-013).
///   3. Runs the mutation audit via [MutationAuditor].
///   4. Classifies killed/survived/timed-out as three separate buckets
///      (FR-014).
///   5. Marks unavailable/empty/incomplete/unparseable results as
///      NOT_ASSESSED (FR-015, FR-016).
///   6. Applies the strict policy: ANY survived or timed-out mutant
///      fails the gate (FR-017).
///   7. Traces every outcome to behavior id + source criterion (FR-018).
///   8. States the gate decision (FR-019).
///   9. Includes non-sensitive repro diagnostics (FR-020).
///  10. Restores every temporarily mutated subject before returning
///      (FR-021).
///  11. NEVER edits a test to fake a pass (FR-022).
///  12. Exits non-zero whenever the gate is not PASS (FR-023).
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../../core/proof/proof_checker.dart';
import '../../../core/project/receipt_store.dart';
import '../services/mutation_auditor.dart';
import '../services/receipt_preflight.dart';
import '../services/requirement_scan.dart';
import '../services/tdd_timeout.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';
import '../services/mutation_scope.dart';

class VerifyCommand extends Command<void> {
  VerifyCommand(this.plugin) {
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
          'Feature name (e.g. 044-test-tdd-generation). The audit derives '
          'its scope from specs/<feature>/tdd/artifacts.json and writes '
          'specs/<feature>/tdd/verification.md.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and lib/. When omitted, the '
          'current working directory is used. Tests pass the temp fixture '
          'root here instead of mutating Directory.current.',
    );
    argParser.addOption(
      'timeout',
      valueHelp: 'minutes',
      help:
          'Hard deadline in minutes for the preflight suite (default 10) and '
          'the mutation run (default 30). Fractions are allowed. On timeout '
          'the child is killed and the audit reports NOT_ASSESSED (bug '
          '#742).',
    );
    argParser.addOption(
      'runner',
      help:
          "Override the test runner for this audit: 'dart' or 'flutter'. "
          'Wins over the tdd-profile file: template; when omitted the '
          'profile resolves the runner and a project without a profile '
          'keeps the pure-Dart default (issue #1044).',
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Run the mutation_test audit on the feature\'s registered behavior '
      'artifacts and write tdd/verification.md (spec 044, FR-012..023).';

  @override
  String get invocation => 'zfa tdd verify [--feature <name>]';

  @override
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    final argResults = this.argResults;
    final feature = argResults?['feature'] as String?;
    if (feature != null && feature.isNotEmpty) {
      _validateFeatureSegment(feature);
    }
    // Prefer an explicit --project root so the command never depends on the
    // process-global Directory.current. Falls back to CWD for real CLI use.
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');

    // Bug #742: the --timeout override for the preflight and the mutation
    // run (one uniform deadline for both when given).
    Duration? timeoutOverride;
    try {
      timeoutOverride = parseTddTimeoutMinutes(
        argResults?['timeout'] as String?,
      );
    } on TddTimeoutFormatException catch (e) {
      stderr.writeln('zfa tdd verify: ${e.message}');
      exitCode = 1;
      return;
    }

    // Issue #1044: explicit runner override — wins over the profile's
    // file: template. Anything other than dart|flutter is a usage error
    // (exit 64) with the fix line, never a guessed runner.
    final runnerFlag = argResults?['runner'] as String?;
    String? runnerTemplate;
    if (runnerFlag != null && runnerFlag.isNotEmpty) {
      switch (runnerFlag) {
        case 'dart':
          runnerTemplate = 'dart test {file}';
        case 'flutter':
          runnerTemplate = 'flutter test {file}';
        default:
          stderr.writeln(
            "zfa tdd verify: --runner accepts 'dart' or 'flutter' "
            "(got '$runnerFlag') --> fix: pass dart|flutter, or set the "
            'file: key in .specify/memory/tdd-profile.md and omit --runner',
          );
          exitCode = 64;
          return;
      }
    }

    // Resolve the feature directory. Treat empty string as absent.
    final featureName = (feature != null && feature.isNotEmpty)
        ? feature
        : _resolveFeatureFromCwd(cwd);
    if (featureName == null) {
      stderr.writeln(
        'zfa tdd verify: no --feature specified and no feature directory '
        'could be resolved from $cwd.',
      );
      throw StateError('zfa tdd verify: feature not specified');
    }
    final featureDir = p.join(cwd, 'specs', featureName);

    // Drift gate (bug #846): when the plan artifact carries a
    // traceability hash, the spec contract must be unchanged — a spec
    // edited after plan means the behaviors no longer prove the
    // contract. Drift = exit 3, re-plan required (checked BEFORE the
    // audit: auditing against a stale contract proves nothing).
    final drift = await _traceabilityDrift(featureDir);
    if (drift != null) {
      print('   drift: ${drift.reason}');
      print(
        'zfa tdd verify: DRIFT — ${drift.reason}\n'
        '   re-plan required: re-run `zfa tdd plan $featureName '
        '--project <dir>` to refresh the traceability matrix, then '
        're-verify.',
      );
      exitCode = 3;
      return;
    }

    // Proof preflight gate (issue #969, T004): the feature's receipted
    // artifacts must still match the bytes their generating verbs wrote.
    // Digest drift means the mutation audit would assess unprovenanced
    // bytes — refuse with NOT_ASSESSED, non-zero, and a fix line, BEFORE
    // the mutation audit runs.
    final proofDrift = await _proofPreflightDrift(cwd, featureName);
    if (proofDrift != null) {
      print(
        'zfa tdd verify: NOT_ASSESSED — the feature\'s artifacts failed '
        'the proof preflight (digest drift before the audit).',
      );
      print('   [${proofDrift.kind}] ${proofDrift.path}');
      print('   ${proofDrift.detail}');
      print(
        '   --> fix: restore the receipted bytes by re-running the '
        'generating verbs (zfa tdd plan / gen / make), then re-verify.',
      );
      _verdict
        ..exitClass = 'not-assessed'
        ..outcome = VerdictOutcome.error
        ..fix =
            'restore the receipted bytes by re-running the generating '
            'verbs (zfa tdd plan / gen / make), then re-verify';
      _verdict.drifts.add(
        '${proofDrift.kind}: ${proofDrift.path} — ${proofDrift.detail}',
      );
      exitCode = 3;
      return;
    }

    // Receipt preflight gate (spec 0996, issue #996): the audit step
    // includes receipt-checking BEFORE the mutation audit runs. Every
    // shipped receipt must validate, and — when the project ships
    // receipts at all — every subject the audit is about to mutate must
    // be covered by one (missing receipt = gate failure, exit 1, no
    // audit). Projects without receipts keep working (vacuous gate).
    final scope = await MutationScope.derive(featureDir: featureDir);
    final receiptGate = await ReceiptPreflight(
      projectRoot: cwd,
    ).check(auditedPaths: scope.subjectPaths);
    if (!receiptGate.ok) {
      print('zfa tdd verify: receipt preflight — FAIL');
      print(
        '   receipts checked: ${receiptGate.receipts}, '
        'findings: ${receiptGate.findings.length}',
      );
      for (final finding in receiptGate.findings) {
        print('   ${finding.toString()}');
      }
      print(
        '   --> fix: regenerate the receipted artifact with its '
        'capability (e.g. `zfa di create <Entity>`) or restore the '
        '.zfa/receipts/ entry, then re-verify.',
      );
      exitCode = 1;
      return;
    }
    if (receiptGate.gateActive) {
      print(
        '   receipt preflight: ok (${receiptGate.receipts} receipt(s) '
        'validated, ${scope.subjectPaths.length} audited subject(s))',
      );
    } else {
      print(
        '   receipt preflight: skipped (no receipts shipped — proof-'
        'carrying generation not in use)',
      );
    }

    print('zfa tdd verify: running mutation audit...');
    print('   feature: $featureName');
    print('   feature_dir: $featureDir');

    final auditor = MutationAuditor(
      featureDir: featureDir,
      workingDirectory: cwd,
      preflightTimeout: timeoutOverride,
      mutationTimeout: timeoutOverride,
      scoreThreshold: _readScoreThreshold(cwd),
      runnerTemplate: runnerTemplate,
    );
    final report = await auditor.run();

    // Print the gate decision.
    print('   gate: ${report.gate.label}');
    if (report.notAssessedReason != null) {
      print('   reason: ${report.notAssessedReason}');
    }
    print('   killed: ${report.killedCount}');
    print('   survived: ${report.survivedCount}');
    print('   timed_out: ${report.timedOutCount}');
    if (report.mutationScore != null) {
      print('   mutation_score: ${report.mutationScore!.toStringAsFixed(4)}');
    }
    if (report.scoreThreshold != null) {
      print(
        '   score_threshold: ${report.scoreThreshold!.toStringAsFixed(4)} '
        '(from .zfa.json)',
      );
    }
    print('   mutation_was_run: ${report.mutationWasRun}');
    print('   restoration_verified: ${report.restorationVerified}');

    // Bug #837: a per-mutant report with an actionable fix line for every
    // survived mutant; a fix hint when the mutation phase could not run at
    // all (infrastructure, never silently a pass).
    if (report.survivors.isNotEmpty) {
      print('   survived_mutants:');
      for (final s in report.survivors) {
        print('     - ${s.file}:${s.line}');
        print(
          '       --> fix: add or strengthen a scope test that fails on '
          'this mutant '
          '(${report.reportPath ?? 'see the mutation report for the diff'})',
        );
      }
    }
    if (report.notAssessedReason != null) {
      print(
        '   --> fix: make the mutation phase runnable — add mutation_test '
        'to dev_dependencies (dart pub add dev:mutation_test) and re-run.',
      );
    }

    // Machine-readable summary line for CI / scripts.
    print(
      'mutation: gate=${report.gate.label} '
      'killed=${report.killedCount} '
      'survived=${report.survivedCount} '
      'timed_out=${report.timedOutCount} '
      'mutation_was_run=${report.mutationWasRun}',
    );
    // Issue #969: the gate label IS the exit class (shipped taxonomy).
    _verdict
      ..exitClass = report.gate.label
      ..outcome = report.gate == MutationGateDecision.pass
          ? VerdictOutcome.pass
          : VerdictOutcome.fail
      ..details['killed'] = report.killedCount
      ..details['survived'] = report.survivedCount
      ..details['timed_out'] = report.timedOutCount
      ..details['mutation_was_run'] = report.mutationWasRun
      ..feature = featureName;

    // Write verification.md from the REAL run (never a stale copy).
    await _writeVerificationMd(featureDir, report);

    // Bug #837 exit protocol: a quality failure (survived or timed-out
    // mutants) is a real gate verdict — exit 1 with the per-mutant report
    // above. Usage/config-class refusals (preflight_red, not_assessed)
    // keep the 64 usage class (FR-023: never exit zero on a non-PASS
    // gate).
    if (report.gate == MutationGateDecision.failSurvived ||
        report.gate == MutationGateDecision.failTimeout) {
      exitCode = 1;
      return;
    }
    if (report.gate != MutationGateDecision.pass) {
      throw UsageException(
        'mutation audit gate: ${report.gate.label}'
            '${report.notAssessedReason != null ? ' (${report.notAssessedReason})' : ''}',
        'See specs/$featureName/tdd/verification.md for the full report.',
      );
    }
  }
}

/// The proof preflight (issue #969, T004): re-derives the digests of the
/// feature's receipted artifacts and returns the FIRST drift finding —
/// modified, deleted, or stale-spec — scoped to receipts this feature's
/// verbs wrote (`input.feature`) plus anything under the feature's spec
/// directory. Null when the feature has no receipted artifacts or every
/// digest still matches (nothing to gate on, nothing drifted).
Future<ProofFinding?> _proofPreflightDrift(
  String cwd,
  String featureName,
) async {
  final records = await ReceiptStore(projectRoot: cwd).loadAll();
  final featurePaths = <String>{};
  for (final record in records) {
    final input = record.receipt.input;
    final feature = input['feature'];
    final inScope =
        (feature is String && feature == featureName) ||
        record.receipt.files.any(
          (entry) => entry.path.startsWith('specs/$featureName/'),
        );
    if (!inScope) continue;
    for (final entry in record.receipt.files) {
      featurePaths.add(entry.path);
    }
  }
  if (featurePaths.isEmpty) return null;
  final report = await ProofChecker(projectRoot: cwd).check();
  for (final finding in report.findings) {
    if (featurePaths.contains(finding.path)) return finding;
  }
  return null;
}

/// The traceability drift between the plan artifact and the current
/// spec contract, or null when verify may proceed (no plan artifact —
/// legacy features keep working — or the hash still matches).
Future<_TraceabilityDrift?> _traceabilityDrift(String featureDir) async {
  final traceFile = File(p.join(featureDir, 'tdd', 'traceability.md'));
  final specFile = File(p.join(featureDir, 'spec.md'));
  if (!await traceFile.exists() || !await specFile.exists()) return null;

  final stored = TraceabilityMatrix.extractSpecHash(
    await traceFile.readAsString(),
  );
  if (stored == null) return null; // no machine block — nothing to check.

  final specMd = await specFile.readAsString();
  final scan = const RequirementScanner().scan(specMd);
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

/// `--feature` lands in a filesystem path, so it must stay a single plain
/// directory segment: a value like `../../etc` would otherwise create and
/// append to a file outside `specs/`.
void _validateFeatureSegment(String feature) {
  if (feature.contains('/') ||
      feature.contains(r'\') ||
      feature == '.' ||
      feature == '..') {
    throw UsageException(
      'invalid --feature "$feature": expected a single spec directory name '
          'such as 044-test-tdd-generation, not a path.',
      'zfa tdd verify [--feature <name>]',
    );
  }
}

/// Try to resolve the feature directory from the cwd. Used when --feature
/// is not specified. Looks at the current branch name pattern.
String? _resolveFeatureFromCwd(String cwd) {
  // For now, we don't auto-resolve. Caller must pass --feature.
  return null;
}

/// Reads `tdd.mutation.scoreThreshold` from `<projectRoot>/.zfa.json`
/// (bug #837).
///
/// Returns null when the file or the key is absent — the strict policy
/// (any survived or timed-out mutant fails) applies. A present-but-invalid
/// value warns on stderr and returns null: a broken config can never
/// silently loosen or harden the gate, the strict policy is the honest
/// fallback.
double? _readScoreThreshold(String projectRoot) {
  final file = File(p.join(projectRoot, '.zfa.json'));
  if (!file.existsSync()) return null;
  Object? raw;
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      stderr.writeln(
        'zfa tdd verify: .zfa.json is not a JSON object — ignoring the '
        'mutation score threshold.',
      );
      return null;
    }
    raw =
        ((decoded['tdd'] as Map<String, dynamic>?)?['mutation']
            as Map<String, dynamic>?)?['scoreThreshold'];
  } on FormatException {
    stderr.writeln(
      'zfa tdd verify: .zfa.json is malformed — ignoring the mutation '
      'score threshold.',
    );
    return null;
  }
  if (raw == null) return null;
  if (raw is! num || raw < 0 || raw > 1) {
    stderr.writeln(
      'zfa tdd verify: invalid tdd.mutation.scoreThreshold in .zfa.json '
      '($raw) — expected a number between 0 and 1. Ignoring it; the '
      'strict policy applies.',
    );
    return null;
  }
  return raw.toDouble();
}

/// Write the verification.md file from the REAL run. This overwrites any
/// prior file (FR-019: the report must reflect the actual current run,
/// never a stale copy).
Future<void> _writeVerificationMd(
  String featureDir,
  MutationAuditReport report,
) async {
  final dir = Directory(p.join(featureDir, 'tdd'));
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, 'verification.md'));
  await file.writeAsString(report.toMarkdown());
}
