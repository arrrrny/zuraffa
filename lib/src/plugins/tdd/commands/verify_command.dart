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

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/mutation_auditor.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class VerifyCommand extends Command<void> {
  VerifyCommand(this.plugin) {
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
  }

  final TddPlugin plugin;

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Run the mutation_test audit on the feature\'s registered behavior '
      'artifacts and write tdd/verification.md (spec 044, FR-012..023).';

  @override
  String get invocation => 'zfa tdd verify [--feature <name>]';

  @override
  Future<void> run() async {
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
        : ProjectRoot.find();

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

    stdout.writeln('zfa tdd verify: running mutation audit...');
    stdout.writeln('   feature: $featureName');
    stdout.writeln('   feature_dir: $featureDir');

    final auditor = MutationAuditor(
      featureDir: featureDir,
      workingDirectory: cwd,
    );
    final report = await auditor.run();

    // Print the gate decision.
    stdout.writeln('   gate: ${report.gate.label}');
    if (report.notAssessedReason != null) {
      stdout.writeln('   reason: ${report.notAssessedReason}');
    }
    stdout.writeln('   killed: ${report.killedCount}');
    stdout.writeln('   survived: ${report.survivedCount}');
    stdout.writeln('   timed_out: ${report.timedOutCount}');
    stdout.writeln('   mutation_was_run: ${report.mutationWasRun}');
    stdout.writeln('   restoration_verified: ${report.restorationVerified}');

    // Machine-readable summary line for CI / scripts.
    stdout.writeln(
      'mutation: gate=${report.gate.label} '
      'killed=${report.killedCount} '
      'survived=${report.survivedCount} '
      'timed_out=${report.timedOutCount} '
      'mutation_was_run=${report.mutationWasRun}',
    );

    // Write verification.md from the REAL run (never a stale copy).
    await _writeVerificationMd(featureDir, report);

    // Exit non-zero whenever the gate is not PASS (FR-023).
    if (report.gate != MutationGateDecision.pass) {
      throw UsageException(
        'mutation audit gate: ${report.gate.label}'
            '${report.notAssessedReason != null ? ' (${report.notAssessedReason})' : ''}',
        'See specs/$featureName/tdd/verification.md for the full report.',
      );
    }
  }
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
