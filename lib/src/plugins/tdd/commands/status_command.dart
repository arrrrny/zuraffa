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

import '../services/lane_receipts.dart';
import '../models/verdict_envelope.dart';
import '../services/verdict_emitter.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';
import 'run_command.dart';
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
    argParser.addFlag('json', help: kJsonFlagHelp, negatable: false);
  }

  final TddPlugin plugin;

  /// SPEC 917/#838: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  Future<void> run() =>
      runWithVerdictEnvelope(this, _verdict, _run, featureFromRest: true);

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

  Future<void> _run() async {
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
      // SPEC 917/#838: the JSON verdict carries the remediation.
      _verdict
        ..outcome = VerdictOutcome.error
        ..exitClass = 'runner-error'
        ..fix =
            'create the feature (zfa tdd init <feature> / zfa specify '
            '<feature>) or pass --project with the right root, then re-run';
      exitCode = _exitRunnerError;
      return;
    }

    // A corrupt receipt is an honest `error` verdict, never a silent
    // green: the line names it and the exit code stays non-zero.
    final line = await LaneReceipts(featureDir).statusLine(feature);
    print(line);
    final bothGreen = line.endsWith('engine=green skin=green');
    // SPEC 917/#838: the machine verdict mirrors the text verdict — the
    // lane tokens ride in `details`, and a not-green status names the fix.
    _verdict
      ..details['engine'] = _verdictToken(line, 'engine')
      ..details['skin'] = _verdictToken(line, 'skin');
    if (!bothGreen) {
      _verdict
        ..outcome = VerdictOutcome.fail
        ..exitClass = 'fail'
        ..fix =
            'drive the failing lane(s): `zfa tdd run-engine $feature` '
            'then `zfa tdd run-skin $feature`';
    }
    exitCode = bothGreen ? 0 : _exitNotGreen;
  }

  /// Extracts `<key>=<token>` from the status line (e.g. `engine=absent`).
  static String? _verdictToken(String line, String key) {
    final match = RegExp('$key=([a-z]+)').firstMatch(line);
    return match?.group(1);
  }
}
