/// `zfa tdd referee` — the CI referee command family (spec
/// 070-ci-referee-provenance):
///
/// - `run` — the golden workflow (FR-001): setup → corpus verify →
///   per-feature gates → gap ledger + coverage matrix, rendered as the
///   PR verdict comment (FR-002) with failure artifacts (FR-006) and
///   posted to the PR (dry-run by default).
/// - `gate` — the publishing gate (FR-004/FR-005/FR-015).
/// - `rollup` — the provenance rollup (FR-003) with archival (FR-012).
///
/// The referee is read-only over the recorded infrastructure; its only
/// writes are its own documents under `.zfa/corpus/`.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../models/verdict_envelope.dart';
import '../services/verdict_emitter.dart';
import '../tdd_plugin.dart';
import '../services/ci_referee/failure_artifacts.dart';
import '../services/ci_referee/feature_provenance.dart';
import '../services/ci_referee/feature_provenance_reader.dart';
import '../services/ci_referee/golden_workflow.dart';
import '../services/ci_referee/pr_comment_poster.dart';
import '../services/ci_referee/provenance_rollup.dart';
import '../services/ci_referee/publishing_gate.dart';
import '../services/ci_referee/verdict_comment.dart';
import '../../../core/project/project_root.dart';

class RefereeCommand extends Command<void> {
  final TddPlugin plugin;

  /// Issue #969: parents emit a usage envelope too.
  final VerdictContext _verdict = VerdictContext();

  RefereeCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #969).',
      negatable: false,
    );
    addSubcommand(RefereeRunCommand(plugin));
    addSubcommand(RefereeGateCommand(plugin));
    addSubcommand(RefereeRollupCommand(plugin));
  }

  @override
  String get name => 'referee';

  @override
  String get description =>
      'CI referee: the golden workflow verdict, the publishing gate, and '
      'the provenance rollup (spec 070).';

  @override
  String get invocation => 'zfa tdd referee <subcommand> [options]';

  @override
  Future<void> run() =>
      runWithVerdictEnvelope(this, _verdict, _run, commandOverride: 'referee');

  Future<void> _run() async {
    _verdict
      ..outcome = VerdictOutcome.stopped
      ..exitClass = 'usage';
    printUsage();
  }
}

/// Shared `--project` resolution for the referee subcommands.
String _resolveProject(Command<void> command) {
  final argResults = command.argResults;
  final projectFlag = argResults?['project'] as String?;
  return projectFlag != null && projectFlag.isNotEmpty
      ? p.absolute(projectFlag)
      : ProjectRoot.find(anchorDir: 'specs');
}

class RefereeRunCommand extends Command<void> {
  RefereeRunCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #969).',
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help: 'Project root of the driven app (containing .zfa/, specs/).',
    );
    argParser.addOption(
      'pr',
      help: 'Pull request number to comment on (omit for dry-run).',
    );
    argParser.addOption(
      'repo',
      help: 'Repository slug (owner/name) for the PR comment.',
    );
    argParser.addOption(
      'token-env',
      defaultsTo: 'GITHUB_TOKEN',
      help: 'Environment variable holding the GitHub token.',
    );
    argParser.addOption(
      'changed-files',
      help: 'File listing the PR\'s changed paths (doc-only detection).',
    );
    argParser.addFlag(
      'resume',
      help: 'Resume an interrupted golden workflow run (FR-010).',
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'run';

  @override
  String get description =>
      'Run the golden workflow and render (or post) the PR verdict '
      'comment (spec 070, FR-001/FR-002).';

  @override
  String get invocation =>
      'zfa tdd referee run [--project <dir>] '
      '[--pr <n> --repo <slug>] [--changed-files <file>] [--resume]';

  @override
  Future<void> run() => runWithVerdictEnvelope(
    this,
    _verdict,
    _run,
    commandOverride: 'referee run',
  );

  Future<void> _run() async {
    final projectRoot = _resolveProject(this);
    print('zfa tdd referee run: golden workflow (spec 070)...');
    print('   project: $projectRoot');

    final argResults = this.argResults!;
    final resume = argResults['resume'] as bool;
    final workflow = GoldenWorkflow(projectRoot);
    final verdict = await workflow.run(resume: resume);

    // Doc-only detection (FR-008): when the PR's changed files touch no
    // feature or lib/ path, the minimal verdict replaces the table.
    var docOnly = false;
    final changedFilesPath = argResults['changed-files'] as String?;
    if (changedFilesPath != null && changedFilesPath.isNotEmpty) {
      final file = File(changedFilesPath);
      if (await file.exists()) {
        final changed = (await file.readAsLines())
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        docOnly =
            changed.isNotEmpty &&
            changed.every(
              (path) => !path.startsWith('lib/') && !path.startsWith('specs/'),
            );
      }
    }

    // Failure artifacts (FR-006): concise excerpts appended to the
    // verdict when red evidence exists.
    final failures = await FailureArtifactBuilder(projectRoot).build();
    final failureReport = failures.isEmpty
        ? ''
        : '${FailureReportRenderer.render(failures).join('\n')}\n\n';

    final renderer = const VerdictCommentRenderer();
    final comment = verdict.features.isEmpty || docOnly
        ? renderer.renderMinimal(
            reason: docOnly
                ? 'no feature provenance was affected'
                : 'no features have been driven yet',
          )
        : renderer.renderFull(
            features: verdict.features,
            gapLedger: verdict.gapLedger,
            coverage: CoverageMatrixSummary(
              features: verdict.coverage.rows.length,
              verified: verdict.coverage.verifiedFeatures,
              tiers: _tierLabels(verdict),
            ),
            result: verdict.result,
          );

    final body = '$comment\n$failureReport'.replaceAll(
      RegExp(r'\n{3,}'),
      '\n\n',
    );

    // Posting: dry-run unless --pr (and --repo + token) are supplied.
    var posted = 'dry-run';
    final prRaw = argResults['pr'] as String?;
    final repoSlug = argResults['repo'] as String?;
    final prNumber = prRaw == null ? null : int.tryParse(prRaw);
    if (prNumber != null && repoSlug != null && repoSlug.isNotEmpty) {
      final token = Platform.environment[argResults['token-env'] as String];
      if (token == null || token.isEmpty) {
        print(
          'zfa tdd referee run: no token in '
          '${argResults['token-env']} — falling back to dry-run.',
        );
      } else {
        final poster = GithubPrCommentPoster(
          repoSlug: repoSlug,
          prNumber: prNumber,
          token: token,
        );
        final ok = await poster.postComment(body);
        posted = ok ? 'posted' : 'post-failed';
      }
    }
    if (posted == 'dry-run') {
      print('--- verdict comment (dry-run) ---');
      print(body);
      print('--- end verdict comment ---');
    }

    print('verdict written: ${workflow.verdictPath}');
    print(
      'referee: features=${verdict.features.length} '
      'failures=${failures.length} steps=${verdict.steps.join('>')} '
      'result=${verdict.result} posted=$posted'
      '${verdict.resumedFrom == null ? '' : ' resumed-from=${verdict.resumedFrom}'}',
    );
    // Issue #969: the result label IS the exit class.
    _verdict
      ..exitClass = verdict.result
      ..outcome = verdict.result == 'pass' || verdict.result == 'empty'
          ? VerdictOutcome.pass
          : VerdictOutcome.fail
      ..details['features'] = verdict.features.length
      ..details['failures'] = failures.length
      ..details['posted'] = posted;
    exitCode = verdict.result == 'pass' || verdict.result == 'empty' ? 0 : 1;
  }

  static List<String> _tierLabels(RefereeVerdict verdict) {
    final tiers = <String>{};
    for (final row in verdict.coverage.rows) {
      tiers.addAll(row.tiers);
    }
    final labels = tiers.toList()..sort();
    return labels.isEmpty ? const ['(none)'] : labels;
  }
}

class RefereeGateCommand extends Command<void> {
  RefereeGateCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #969).',
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help: 'Project root of the driven app (containing .zfa/, specs/).',
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'gate';

  @override
  String get description =>
      'Evaluate the publishing gate: production only when every feature '
      'is complete(real) (spec 070, FR-004/FR-005/FR-015).';

  @override
  String get invocation => 'zfa tdd referee gate [--project <dir>]';

  @override
  Future<void> run() => runWithVerdictEnvelope(
    this,
    _verdict,
    _run,
    commandOverride: 'referee gate',
  );

  Future<void> _run() async {
    final projectRoot = _resolveProject(this);
    print('zfa tdd referee gate: publishing gate...');
    print('   project: $projectRoot');

    final features = await FeatureProvenanceReader(projectRoot).read();
    final decision = const PublishingGate().evaluate(features);

    print(decision.summaryLine);
    if (decision.outcome == GateOutcome.simulation) {
      print('   offered build: ${decision.label}');
    }
    for (final blocker in decision.blockers) {
      print('   blocker: $blocker');
    }
    // Issue #969: the gate outcome IS the exit class.
    _verdict
      ..exitClass = decision.outcome.name
      ..outcome = decision.outcome == GateOutcome.production
          ? VerdictOutcome.pass
          : VerdictOutcome.fail
      ..details['offered_build'] = decision.label;
    exitCode = decision.outcome == GateOutcome.production ? 0 : 1;
  }
}

class RefereeRollupCommand extends Command<void> {
  RefereeRollupCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #969).',
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help: 'Project root of the driven app (containing .zfa/, specs/).',
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'rollup';

  @override
  String get description =>
      'Generate the provenance rollup: per-feature and corpus-wide '
      'receipt-verified ratios with archival (spec 070, FR-003/FR-012).';

  @override
  String get invocation => 'zfa tdd referee rollup [--project <dir>]';

  @override
  Future<void> run() => runWithVerdictEnvelope(
    this,
    _verdict,
    _run,
    commandOverride: 'referee rollup',
  );

  Future<void> _run() async {
    final projectRoot = _resolveProject(this);
    print('zfa tdd referee rollup: provenance rollup...');
    print('   project: $projectRoot');

    final rollup = await ProvenanceRollupBuilder(projectRoot).build();

    if (rollup.isEmpty) {
      print(
        'rollup: features=0 generated=0% mock=0% hand-delta=0% '
        'hand-written=0% receipt-verified=true archived=0',
      );
      print('   no features have been realized yet (empty state).');
      print('   report: ${rollup.path}');
      _verdict
        ..exitClass = 'empty'
        ..outcome = VerdictOutcome.pass
        ..details['features'] = 0;
      exitCode = 0;
      return;
    }

    print(
      'rollup: features=${rollup.corpus.totalFeatures} '
      'generated=${rollup.corpus.generatedPercent}% '
      'mock=${rollup.corpus.mockPercent}% '
      'hand-delta=${rollup.corpus.handDeltaPercent}% '
      'hand-written=${rollup.corpus.handWrittenPercent}% '
      'receipt-verified=${rollup.receiptVerified} '
      'archived=${rollup.archivedFrom == null ? 0 : 1}',
    );
    for (final feature in rollup.perFeature) {
      print(
        '   ${feature.feature}: ${feature.state.label} '
        'receipts=${feature.receiptCount} '
        'hand-delta=${feature.handDeltaReceipts} '
        'g/m/h=${feature.ratioCell}',
      );
    }
    print('   report: ${rollup.path}');
    _verdict
      ..exitClass = 'ok'
      ..outcome = VerdictOutcome.pass
      ..details['features'] = rollup.corpus.totalFeatures;
    exitCode = 0;
  }
}
