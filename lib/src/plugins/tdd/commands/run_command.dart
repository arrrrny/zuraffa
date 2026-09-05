/// `zfa tdd run <feature>` — the meta-driver of the two-cycle runner
/// (spec 1008-two-cycle-driver, issue #1008): engine lane first, skin
/// lane second, fail-fast on the first red.
///
/// Before the engine/skin split (#1000) this command drove every behavior
/// of a feature's test list through the two-phase loop itself. It now
/// chains the two lanes over the SAME shared driver core
/// ([RunDriverCore] — spec 049 semantics unchanged):
///
/// 1. **Engine lane** — CORE + BOTH behaviors (for a legacy feature with
///    no lane declarations, that is every behavior: the run is
///    byte-compatible with the pre-split driver, plus the receipts). Its
///    receipt `tdd/04-engine-receipt.json` records the lane verdict.
/// 2. **Fail fast** — an engine lane that does not complete stops the
///    meta run at the engine's honest stop (no skin step is ever
///    spawned; the skin depends on the engine's certified mocks).
/// 3. **Skin lane** — SKIN + BOTH behaviors (skipping BOTH behaviors the
///    engine lane already certified DONE — evidence beats state,
///    FR-003). Its receipt `tdd/04-skin-receipt.json` records the lane
///    verdict. The skin lane of a legacy feature is empty: it completes
///    vacuously without spawning any step.
/// 4. **Unified journal entry** — when both lanes are green, one entry is
///    appended to `tdd/cycle-log.md` naming both receipts (no `-
///    behavior:` field, so the evidence parsers read past it).
///
/// Machine contract (FR-009/FR-010, unchanged): every completed step
/// prints `[run] <behavior> <step> -> <outcome>`, and every invocation
/// ends with the final summary line
/// `run: feature=<f> result=<r> pending=<n> red=<n> green=<n> done=<n>`
/// plus ` stopped_at=<behavior>:<step>` when stopped — the counts cover
/// every behavior of the test list (the union of the lanes). Exit codes:
/// 0 complete, 1 stopped, 2 runner-error, 3 corrupt-state,
/// 4 concurrent-run — 0 means exactly "all DONE with complete evidence"
/// and both receipts green.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../models/verdict_envelope.dart';
import '../services/lane_receipts.dart';
import '../services/tdd_timeout.dart';
import '../services/verdict_emitter.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';
import 'run_driver_core.dart';
import 'run_engine_command.dart';

class RunCommand extends Command<void> {
  RunCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
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

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'run';

  @override
  String get description =>
      'Drive a feature through BOTH lanes of the two-cycle runner — '
      'run-engine (CORE+BOTH behaviors) then run-skin (SKIN+BOTH, gated on '
      'a green engine) — failing fast on the first red, resuming from '
      'tdd/run-state.json, writing both lane receipts and the unified '
      'journal entry (spec 1008 over the spec 049 driver).';

  @override
  String get invocation =>
      'zfa tdd run <feature> [--project <dir>] [--zfa-bin <path>]';

  static const _exitComplete = 0;
  static const _exitRunnerError = 2;

  @override
  Future<void> run() =>
      runWithVerdictEnvelope(this, _verdict, _run, featureFromRest: true);

  Future<void> _run() async {
    const label = 'run';
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      throw UsageException(
        'missing <feature> — name the spec directory whose test list to '
        'drive (e.g. 049-tdd-run)',
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

    final skipWidget = argResults?['skip-widget'] as bool? ?? false;
    final core = RunDriverCore();

    // -----------------------------------------------------------------
    // Spec 1001 pre-start preflight: an uncertified CORE mock stops the
    // meta run before the engine lane spawns any step ("mocks the
    // framework certifies, not the agent" — the engine cannot bypass
    // its own gate).
    // -----------------------------------------------------------------
    final gate = await RunEngineCommand.checkFeature(
      projectRoot: projectRoot,
      featureDir: p.join(projectRoot, 'specs', feature),
    );
    if (!gate.ok) {
      final entity = gate.blockedEntity!;
      stderr.writeln(
        'zfa tdd $label: CORE entity "$entity" has a mock on disk '
        'that is NOT certified — the engine refuses to proceed '
        '(spec 1001: mocks the framework certifies, not the agent).',
      );
      stderr.writeln(
        '--> fix: zfa mock certify $entity '
        '(or zfa mock create $entity --certify), then re-run.',
      );
      exitCode = 1;
      return;
    }

    // -----------------------------------------------------------------
    // Lane 1 — the engine lane, announced and driven with the `run` label
    // so its output is byte-identical to the pre-split single-run driver
    // (for a legacy feature the engine lane IS the whole test list).
    // -----------------------------------------------------------------
    final engine = await core.drive(
      feature: feature,
      projectRoot: projectRoot,
      zfaBin: zfaBin,
      timeout: timeoutOverride,
      lane: 'engine',
      label: label,
      announce: true,
      skipWidget: skipWidget,
    );

    // Fail fast (issue #1008): the engine lane must be green before the
    // skin runs — the skin binds the engine's certified mocks. The engine
    // receipt records the honest outcome; no skin step is spawned.
    if (engine.result != 'complete') {
      if (engine.message != null) print('zfa tdd $label: ${engine.message}');
      _printSummary(feature, engine);
      exitCode = engine.exitCode;
      return;
    }

    // -----------------------------------------------------------------
    // Lane 2 — the skin lane, silent banner (the engine lane announced
    // the run; its steps print with the same [run] prefix). Both lanes
    // share tdd/run-state.json and tdd/cycle-log.md: BOTH behaviors the
    // engine certified DONE are skipped here, never re-driven.
    // -----------------------------------------------------------------
    final skin = await core.drive(
      feature: feature,
      projectRoot: projectRoot,
      zfaBin: zfaBin,
      timeout: timeoutOverride,
      lane: 'skin',
      label: label,
      announce: false,
      skipWidget: skipWidget,
    );

    if (skin.result != 'complete') {
      if (skin.message != null) print('zfa tdd $label: ${skin.message}');
      _printSummary(feature, skin);
      exitCode = skin.exitCode;
      return;
    }

    // -----------------------------------------------------------------
    // Both lanes green: the unified journal entry naming both receipts
    // (issue #1008) and the final summary line over EVERY behavior.
    // -----------------------------------------------------------------
    await LaneReceipts(
      p.join(projectRoot, 'specs', feature),
    ).appendUnifiedJournalEntry(
      feature: feature,
      engineVerdict: engine.verdict,
      skinVerdict: skin.verdict,
    );
    _printSummary(feature, skin);
    exitCode = _exitComplete;
  }

  /// The final summary line over EVERY behavior of the test list (the
  /// union of the lanes) — the pre-split driver's exact shape (FR-009 /
  /// FR-010: `run: feature=<f> result=<r> pending=<n> red=<n> green=<n>
  /// done=<n>` plus ` stopped_at=...` when stopped).
  void _printSummary(String feature, RunDriverOutcome outcome) {
    print(
      RunDriverCore.summaryLine(
        label: 'run',
        feature: feature,
        result: outcome.result,
        counts: laneCounts(
          outcome.rows,
          outcome.state?.behaviorStates ?? const {},
        ),
        stoppedAt: outcome.stoppedAt,
        skippedWidgetIds: outcome.skippedWidgetIds,
      ),
    );
    // Issue #969: carry the shipped exit taxonomy into the envelope —
    // the label IS the class; no taxonomy changes. Restored from the
    // pre-split single-run driver — the spec 1008 two-cycle refactor
    // (issue #1092) dropped the wiring and the --json envelope vanished
    // from every run error path (bug #1107).
    _verdict
      ..exitClass = outcome.result
      ..outcome = switch (outcome.result) {
        'complete' => VerdictOutcome.pass,
        'stopped' => VerdictOutcome.stopped,
        _ => VerdictOutcome.error,
      }
      ..details['pending'] = outcome.counts['pending']
      ..details['red'] = outcome.counts['red']
      ..details['green'] = outcome.counts['green']
      ..details['done'] = outcome.counts['done'];
    if (outcome.stoppedAt != null) {
      _verdict.details['stopped_at'] = outcome.stoppedAt;
    }
  }
}
