/// `zfa tdd run-engine <feature>` — drive ONLY the ENGINE lane (CORE +
/// BOTH behaviors, the engine plan) through the shared two-phase driver
/// core (spec 1008-two-cycle-driver, issue #1008).
///
/// The engine lane is the foundation the skin lane depends on: it
/// certifies the pure-Dart behaviors and the mocks the skin will bind.
/// The run writes the engine journal (`tdd/cycle-log.md`, via the driven
/// steps) and, once driving began, the lane verdict receipt
/// `tdd/04-engine-receipt.json`:
///
/// - `verdict: green` — every lane behavior DONE with complete evidence
///   (the driver's `result=complete`, spec 049 FR-010);
/// - `verdict: red` — the lane stopped honestly (result=stopped);
/// - `verdict: error` — a runner-error after driving started.
///
/// Lane truth: the `tdd/04-ENGINE.md` plan file when present (#1000),
/// else the ` [core]` / ` [both]` row tags, else the legacy CORE default
/// (every behavior — the pre-split driver's exact behavior).
///
/// Machine contract (the spec 049 exit codes, unchanged): exit 0
/// complete, 1 stopped, 2 runner-error, 3 corrupt-state, 4
/// concurrent-run; every completed step prints
/// `[run] <behavior> <step> -> <outcome>` and the invocation ends with
/// the lane summary line
/// `run-engine: feature=<f> lane=engine result=<r> pending=<n> red=<n>
/// green=<n> done=<n>` plus ` stopped_at=<behavior>:<step>` when stopped.
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import '../services/tdd_timeout.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';
import 'run_driver_core.dart';

class RunEngineCommand extends Command<void> {
  RunEngineCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and .specify/ (the fixture '
          'or target project). When omitted, the current working directory '
          'is used. The driver never mutates the process-global working '
          'directory.',
    );
    argParser.addOption(
      'zfa-bin',
      help:
          'Path to the zfa CLI entrypoint used to spawn the step commands '
          '(defaults to this package\'s bin/zfa.dart). Point this at a '
          'scripted fake to drive the loop against stubbed steps.',
    );
    argParser.addOption(
      'timeout',
      valueHelp: 'minutes',
      help:
          'Hard deadline in minutes for each spawned step command (bug #742; '
          'default 10). Fractions are allowed. On timeout the child is '
          'killed and the run stops with result=runner-error.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'run-engine';

  @override
  String get description =>
      'Drive only the ENGINE lane (CORE+BOTH behaviors, the engine plan) '
      'through gen -> verify-red -> make -> refactor and write the '
      '04-engine-receipt.json verdict (spec 1008, issue #1008).';

  @override
  String get invocation =>
      'zfa tdd run-engine <feature> [--project <dir>] [--zfa-bin <path>]';

  static const _exitRunnerError = 2;

  @override
  Future<void> run() async {
    const label = 'run-engine';
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      throw UsageException(
        'missing <feature> — name the spec directory whose engine lane to '
        'drive (e.g. 004-login-ui)',
        invocation,
      );
    }
    final feature = stripSpecsPrefix(rest.first);
    validateFeatureSegment(feature, invocation);
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? projectFlag
        : ProjectRoot.find(anchorDir: 'specs');
    final zfaBin = argResults?['zfa-bin'] as String?;

    // Bug #742: the --timeout override for each spawned step command.
    Duration? timeoutOverride;
    try {
      timeoutOverride = parseTddTimeoutMinutes(
        argResults?['timeout'] as String?,
      );
    } on TddTimeoutFormatException catch (e) {
      print('zfa tdd $label: ${e.message}');
      print(
        RunDriverCore.summaryLine(
          label: label,
          feature: feature,
          lane: 'engine',
          result: 'runner-error',
          counts: const {
            'total': 0,
            'pending': 0,
            'red': 0,
            'green': 0,
            'done': 0,
          },
        ),
      );
      exitCode = _exitRunnerError;
      return;
    }

    final outcome = await RunDriverCore().drive(
      feature: feature,
      projectRoot: projectRoot,
      zfaBin: zfaBin,
      timeout: timeoutOverride,
      lane: 'engine',
      label: label,
    );
    if (outcome.message != null) print('zfa tdd $label: ${outcome.message}');
    print(
      RunDriverCore.summaryLine(
        label: label,
        feature: feature,
        lane: 'engine',
        result: outcome.result,
        counts: outcome.counts,
        stoppedAt: outcome.stoppedAt,
      ),
    );
    exitCode = outcome.exitCode;
  }
}
