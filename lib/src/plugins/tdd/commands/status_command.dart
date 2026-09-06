/// `zfa tdd status <feature>` — read the two lane receipts and print a
/// one-line verdict (spec 1008-two-cycle-driver, issue #1008).
///
/// Reads `tdd/04-engine-receipt.json` and `tdd/04-skin-receipt.json` and
/// prints exactly one line:
///
///     status: feature=<f> engine=<verdict> skin=<verdict>
///
/// with each verdict green | red | error | absent (no receipt). Exit 0
/// iff both lanes are green; any other combination exits 1 — a script
/// can gate on the command without parsing the journal. A missing
/// feature directory refuses with the run commands' misfire semantics
/// (exit 2, the location named).
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../../../engine/engine_gate_receipt.dart';
import '../services/lane_receipts.dart';
import '../tdd_plugin.dart';
import 'run_driver_core.dart';

class StatusCommand extends Command<void> {
  StatusCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and .specify/ (the fixture '
          'or target project). When omitted, the current working directory '
          'is used.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'status';

  @override
  String get description =>
      'Read the engine and skin lane receipts and print a one-line verdict: '
      'status: feature=<f> engine=<verdict> skin=<verdict> (exit 0 iff '
      'both green; spec 1008, issue #1008).';

  @override
  String get invocation => 'zfa tdd status <feature> [--project <dir>]';

  static const _exitNotGreen = 1;
  static const _exitRunnerError = 2;

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      throw UsageException(
        'missing <feature> — name the spec directory whose lane verdicts to '
        'read (e.g. 004-login-ui)',
        invocation,
      );
    }
    final feature = stripSpecsPrefix(rest.first);
    validateFeatureSegment(feature, invocation);
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? projectFlag
        : ProjectRoot.find(anchorDir: 'specs');

    final featureDir = p.join(projectRoot, 'specs', feature);
    if (!await Directory(featureDir).exists()) {
      print(
        'zfa tdd status: no feature directory at '
        '${p.relative(featureDir, from: projectRoot)} (project root: '
        '$projectRoot)',
      );
      exitCode = _exitRunnerError;
      return;
    }

    // A corrupt receipt is an honest `error` verdict, never a silent
    // green: the line names it and the exit code stays non-zero.
    final line = await LaneReceipts(featureDir).statusLine(feature);
    print(line);

    // Spec 1110 (issue #1110): render the cert-gate refusal's exact fix.
    // A blocked engine lane is not just "red" — the refusal receipt
    // names the entity, the reason, and the recovery command; surfacing
    // it here is the whole point of the block being a receipt.
    final refusals = EngineGateReceipt.loadAllInFeature(featureDir);
    var gateBlocked = false;
    for (final doc in refusals.values) {
      gateBlocked = true;
      print(
        'gate: entity=${doc['entity']} refused — '
        '${doc['reason']}\n'
        '  --> fix: ${doc['fix']} '
        '(${p.relative(EngineGateReceipt.refusedPathInFeature(featureDir, doc['entity'] as String), from: projectRoot)})',
      );
    }

    final bothGreen = line.endsWith('engine=green skin=green');
    exitCode = bothGreen && !gateBlocked ? 0 : _exitNotGreen;
  }
}
