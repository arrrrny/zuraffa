/// `zfa tdd run-skin <feature>` — drive ONLY the SKIN lane (SKIN + BOTH
/// behaviors, the skin plan) through the shared two-phase driver core,
/// GATED on a green engine receipt (spec 1008-two-cycle-driver, issue
/// #1008).
///
/// The skin depends on the engine's certified mocks: until
/// `tdd/04-engine-receipt.json` records `verdict: green`, the skin lane
/// refuses to start — exit 2, zero steps, no skin receipt — naming the
/// missing/not-green receipt and the remediation (`zfa tdd
/// run-engine`). A green engine lane followed by `run-skin` drives the
/// SKIN+BOTH rows (BOTH behaviors already DONE by the engine lane are
/// skipped, never re-driven from scratch — evidence beats state,
/// FR-003) and writes `tdd/04-skin-receipt.json`.
///
/// A feature with no skin behaviors at all (every legacy pure-Dart
/// feature) completes vacuously once the engine is green: zero steps,
/// `verdict: green`, `behaviors: []`.
///
/// Machine contract: the spec 049 exit codes (0 complete, 1 stopped,
/// 2 runner-error, 3 corrupt-state, 4 concurrent-run) plus the gate
/// refusal `result=engine-required` (also exit 2 — issue #1008: "fails
/// with exit 2 if the engine receipt does not exist"). The invocation
/// ends with the lane summary line
/// `run-skin: feature=<f> lane=skin result=<r> pending=<n> red=<n>
/// green=<n> done=<n>` plus ` stopped_at=<behavior>:<step>` when stopped.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/lane_receipts.dart';
import '../services/tdd_timeout.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';
import 'run_driver_core.dart';

class RunSkinCommand extends Command<void> {
  RunSkinCommand(this.plugin) {
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
    argParser.addFlag(
      'skip-widget',
      help:
          'Widget-lane behaviors whose gen refuses on the shadcn_ui gate '
          '(issue #938) are skipped instead of stopping the run: each keeps '
          'its current state — never a fake DONE — and the end-of-run '
          'summary names the count (issue #992). Without the flag the '
          'refusal still stops the run.',
      negatable: false,
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'run-skin';

  @override
  String get description =>
      'Drive only the SKIN lane (SKIN+BOTH behaviors, the skin plan) '
      'through gen -> verify-red -> make -> refactor and write the '
      '04-skin-receipt.json verdict. Refuses (exit 2) unless the engine '
      'receipt is green — the skin binds the engine\'s certified mocks '
      '(spec 1008, issue #1008).';

  @override
  String get invocation =>
      'zfa tdd run-skin <feature> [--project <dir>] [--zfa-bin <path>]';

  static const _exitEngineRequired = 2;
  static const _exitRunnerError = 2;

  @override
  Future<void> run() async {
    const label = 'run-skin';
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      throw UsageException(
        'missing <feature> — name the spec directory whose skin lane to '
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
      _printSummary(feature, 'runner-error', null);
      exitCode = _exitRunnerError;
      return;
    }

    final featureDir = p.join(projectRoot, 'specs', feature);

    // -----------------------------------------------------------------
    // The engine gate (issue #1008): the skin lane requires a green
    // engine receipt BEFORE any step is spawned. Missing, not-green, or
    // corrupt receipt -> exit 2, zero steps, no skin receipt written.
    // -----------------------------------------------------------------
    final refusal = await LaneReceipts(featureDir).engineGateRefusal();
    if (refusal != null) {
      print('zfa tdd $label: $refusal');
      _printSummary(feature, 'engine-required', null);
      exitCode = _exitEngineRequired;
      return;
    }

    final outcome = await RunDriverCore().drive(
      feature: feature,
      projectRoot: projectRoot,
      zfaBin: zfaBin,
      timeout: timeoutOverride,
      lane: 'skin',
      label: label,
      skipWidget: argResults?['skip-widget'] as bool? ?? false,
    );
    if (outcome.message != null) print('zfa tdd $label: ${outcome.message}');
    _printSummary(feature, outcome.result, outcome);
    exitCode = outcome.exitCode;
  }

  void _printSummary(String feature, String result, RunDriverOutcome? outcome) {
    print(
      RunDriverCore.summaryLine(
        label: 'run-skin',
        feature: feature,
        lane: 'skin',
        result: result,
        counts:
            outcome?.counts ??
            const {'total': 0, 'pending': 0, 'red': 0, 'green': 0, 'done': 0},
        stoppedAt: outcome?.stoppedAt,
      ),
    );
  }
}
