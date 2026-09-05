/// `zfa tdd diff-check` — the schema-parity gate of the differential
/// harness (bug #915): compares the committed mock fixture's response
/// shapes with the recorded real-adapter shapes for one feature's
/// adapter contracts, and reports any drift as a NAMED verdict with the
/// field-level difference. Drift = exit 2.
///
/// Fixture contract (remediation item 1): one committed pair per
/// adapter contract under `specs/<feature>/tdd/fixtures/<contract>/` —
/// `mock.json` (the mock adapter's source of responses) and `real.json`
/// (the recorded real-adapter responses) — consumed by BOTH the mock
/// and the realize differential.
///
/// Default lane: shape parity only (field names, types, nesting, list
/// element shapes — parity is shape, not bytes). `--full` additionally
/// runs the fault-injection parity gate (timeouts, 5xx, corrupted
/// payloads must be triggerable against BOTH lanes) and prints the
/// corpus rollup — the #915 hard constraint keeps the burdensome parts
/// opt-in.
///
/// Machine contract: ends with
/// `diff-check: contracts=<n> matched=<n> drifted=<n> incomplete=<n>
/// result=<match|drift|incomplete>`. Exit 0 every committed contract
/// matches; 2 drift (every drift named at field level); 1 incomplete
/// (a fixture lane is missing or unreadable — never a silent pass).
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/adapter_parity_checker.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class DiffCheckCommand extends Command<void> {
  DiffCheckCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #969).',
      negatable: false,
    );
    argParser.addOption(
      'feature',
      help:
          'Feature name whose adapter contracts are checked (e.g. '
          '067-tdd-realize-mock-swap). Reads '
          'specs/<feature>/tdd/fixtures/<contract>/{mock,real}.json.',
    );
    argParser.addOption(
      'contract',
      help:
          'Check a single adapter contract by name. When omitted, every '
          'committed contract under the feature is checked.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/. When omitted, the current '
          'working directory is used.',
    );
    argParser.addFlag(
      'full',
      help:
          'Also run the fault-injection parity gate (timeouts, 5xx, '
          'corrupted payloads triggerable against both lanes) and print '
          'the corpus rollup line. Opt-in per bug #915.',
      negatable: false,
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'diff-check';

  @override
  String get description =>
      'Check fixture parity between the mock and real adapters for the '
      'feature\'s committed adapter contracts; drift = named verdict, '
      'exit 2 (bug #915).';

  @override
  String get invocation =>
      'zfa tdd diff-check --feature <name> [--contract <name>] [--full]';

  @override
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    final argResults = this.argResults;
    final feature = argResults?['feature'] as String?;
    if (feature == null || feature.isEmpty) {
      throw UsageException(
        'zfa tdd diff-check requires --feature (the spec directory whose '
        'adapter contracts are checked).',
        invocation,
      );
    }
    if (feature.contains('/') ||
        feature.contains(r'\') ||
        feature == '.' ||
        feature == '..') {
      throw UsageException(
        'invalid --feature "$feature": expected a single spec directory '
        'name, not a path.',
        invocation,
      );
    }
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final full = argResults?['full'] as bool? ?? false;
    final only = argResults?['contract'] as String?;

    final featureDir = p.join(projectRoot, 'specs', feature);
    final contracts = only != null && only.isNotEmpty
        ? [only]
        : AdapterParityChecker.discoverContracts(featureDir);

    print('zfa tdd diff-check: checking adapter fixture parity...');
    print('   feature: $feature');
    print('   full: $full');

    final reports = <ContractParityReport>[];
    for (final contract in contracts) {
      final report = AdapterParityChecker.checkContract(
        featureDir,
        contract,
        full: full,
      );
      reports.add(report);
      print('   ${report.toString()}');
      for (final drift in report.drifts) {
        print('      - $drift');
      }
      for (final drift in report.faultDrifts) {
        print('      - fault drift: $drift');
      }
    }

    final matched = reports
        .where((r) => r.verdict == ParityVerdict.match)
        .length;
    final drifted = reports
        .where((r) => r.verdict == ParityVerdict.drift)
        .length;
    final incomplete = reports
        .where((r) => r.verdict == ParityVerdict.incomplete)
        .length;
    final result = drifted > 0
        ? 'drift'
        : incomplete > 0
        ? 'incomplete'
        : 'match';

    if (full) {
      final rollup = ParityRollup(reports: reports);
      print('parity: ${rollup.summaryLine}');
    }

    print(
      'diff-check: contracts=${reports.length} matched=$matched '
      'drifted=$drifted incomplete=$incomplete result=$result',
    );
    // Issue #969: the result label IS the exit class.
    _verdict
      ..exitClass = switch (result) {
        'drift' => 'drift',
        'incomplete' => 'incomplete',
        _ => 'ok',
      }
      ..outcome = switch (result) {
        'drift' => VerdictOutcome.fail,
        'incomplete' => VerdictOutcome.fail,
        _ => VerdictOutcome.pass,
      };
    _verdict.details
      ..['contracts'] = reports.length
      ..['matched'] = matched
      ..['drifted'] = drifted
      ..['incomplete'] = incomplete;
    if (result != 'ok') {
      _verdict.fix = result == 'drift'
          ? 're-run zfa tdd gen/realize to restore the contract fixtures '
              '(or re-commit the intended fixtures)'
          : 'commit the missing fixture lane (mock/real json) for every '
              'incomplete contract';
    }
    exitCode = switch (result) {
      'drift' => 2,
      'incomplete' => 1,
      _ => 0,
    };
  }
}
