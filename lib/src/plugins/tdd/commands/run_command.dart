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
import '../services/journal.dart';
import '../services/dependency_override_preflight.dart';
import '../services/explain_emitter.dart';
import '../services/lane_receipts.dart';
import '../services/tdd_timeout.dart';
import '../services/verdict_emitter.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';
import 'run_driver_core.dart';
import 'run_engine_command.dart';

/// The `--stream` flag's help text — shared by the three driving commands
/// (run / run-engine / run-skin) so the flag surface stays in lockstep.
const String kStreamFlagHelp =
    'Stream one NDJSON `step-verdict.v1` event per completed loop step as '
    'it happens (SPEC 917, issue #838); the final verdict.v1 envelope '
    'still closes the output.';

/// The `--json` flag's help text for the driving commands.
const String kJsonFlagHelp =
    'Emit a versioned verdict.v1 JSON envelope as the final stdout line '
    '(VISION §5, issue #964/#838).';

class RunCommand extends Command<void> {
  RunCommand(this.plugin) {
    argParser.addFlag('json', help: kJsonFlagHelp, negatable: false);
    argParser.addFlag('explain', help: kExplainFlagHelp, negatable: false);
    argParser.addFlag('stream', help: kStreamFlagHelp, negatable: false);
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
          'Widget-lane behaviors whose gen refuses on the zuraffa_ui gate '
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
  // The SPEC 917 drift class (corrupt-state) — the issue #1303
  // dependency_overrides preflight refuses with this exit code.
  static const _exitCorruptState = 3;

  @override
  Future<void> run() => runWithVerdictEnvelope(
    this,
    _verdict,
    _run,
    featureFromRest: true,
    // SPEC 917: --stream also closes with the envelope — the streamed
    // step-verdict.v1 events are terminated by the final verdict.
    envelopeEnabled: () =>
        tddJsonMode(this) || (argResults?['stream'] as bool? ?? false),
  );

  Future<void> _run() async {
    const label = 'run';
    // Spec 1113: the meta entry's bounds — the meta cycle started when
    // the command began, finishes at its terminal outcome.
    final journalStartedAt = DateTime.now().toUtc().toIso8601String();
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

    // -----------------------------------------------------------------
    // Issue #1303 preflight: a stale `dependency_overrides` path entry
    // would surface only as a raw version-solving dump buried mid-log
    // after minutes of compiling, with the clean-cache retry burning a
    // full rebuild on a resolution error no cache clean can fix.
    // Validate every override path BEFORE the cert gate and any lane
    // step spawns; refuse with the honest drift verdict (exit 3,
    // journaled preflight_red — zero steps).
    // -----------------------------------------------------------------
    final overrideReport = await DependencyOverridePreflight(
      projectRoot: projectRoot,
    ).check();
    if (!overrideReport.ok) {
      for (final finding in overrideReport.findings) {
        print(DependencyOverridePreflight.findingLine(finding));
      }
      print('$kOverrideFixLine `zfa tdd run`');
      await _journalMeta(
        featureDir: p.join(projectRoot, 'specs', feature),
        feature: feature,
        startedAt: journalStartedAt,
        gateState: 'preflight_red',
        phase: 'gate',
        result: 'corrupt-state',
        violations: [
          for (final finding in overrideReport.findings)
            'dependency_overrides["${finding.package}"] path '
                '"${finding.path}" does not resolve to a package '
                '(${finding.detail})',
        ],
      );
      print(
        RunDriverCore.summaryLine(
          label: label,
          feature: feature,
          result: 'corrupt-state',
          counts: const {
            'total': 0,
            'pending': 0,
            'red': 0,
            'green': 0,
            'done': 0,
          },
        ),
      );
      _verdict
        ..exitClass = 'corrupt-state'
        ..outcome = VerdictOutcome.error
        ..details['preflight'] =
            'dependency_overrides path validation '
            'refused the run (issue #1303)';
      _verdict.explain = TddExplain(
        command: 'run',
        features: [feature],
        lane:
            'none — the dependency_overrides preflight refused before any '
            'lane drove (preflight red, issue #1303)',
        fixHints: [
          'correct the override path or remove the entry from '
              'pubspec.yaml, then re-run',
        ],
        summary:
            'Run stopped at the issue-#1303 preflight: a '
            'dependency_overrides path target does not resolve to a '
            'package. No step was spawned and no receipt was written; '
            'the refusal is journaled preflight_red in tdd/journal.json.',
      );
      exitCode = _exitCorruptState;
      return;
    }

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
    // SPEC 917 (--stream): when set, every completed step streams one
    // NDJSON step-verdict.v1 event while the run drives.
    if (argResults?['stream'] as bool? ?? false) {
      core.onStepEvent = (event) => print(event.toNdjsonLine());
    }

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
    // The gate's mock accounting rides the engine entry (the status
    // verdict's `mocks c/t` segment — spec 1113).
    final mockCounts = {
      'total': gate.mocks.length,
      'certified': gate.certified.length,
    };
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
      // Spec 1113: the preflight refusal is journaled preflight_red —
      // zero steps spawned, the refused entity named as the violation.
      await _journalMeta(
        featureDir: p.join(projectRoot, 'specs', feature),
        feature: feature,
        startedAt: journalStartedAt,
        gateState: 'preflight_red',
        phase: 'gate',
        result: 'preflight-refused',
        violations: [
          'cert-gate: entity=$entity refused '
              '(${gate.blockedReason ?? 'uncertified CORE mock'})',
        ],
      );
      // Issue #1125: the preflight refusal's explain block — the cert
      // gate refused BEFORE any lane drove, the fix line is the gate's
      // own (mock certify).
      _verdict.explain = TddExplain(
        command: 'run',
        features: [feature],
        lane:
            'none — the cert gate refused before any lane drove '
            '(preflight red)',
        fixHints: [
          'zfa mock certify $entity (or zfa mock create $entity '
              '--certify), then re-run',
        ],
        summary:
            'Run stopped at the spec-1001 pre-start preflight: CORE entity '
            '"$entity" has a mock on disk that is NOT certified '
            '(${gate.blockedReason ?? 'uncertified CORE mock'}). No '
            'step was spawned and no receipt was written; the refusal '
            'is journaled preflight_red in tdd/journal.json.',
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
      mockCounts: mockCounts,
    );

    // Fail fast (issue #1008): the engine lane must be green before the
    // skin runs — the skin binds the engine's certified mocks. The engine
    // receipt records the honest outcome; no skin step is spawned.
    if (engine.result != 'complete') {
      if (engine.message != null) print('zfa tdd $label: ${engine.message}');
      // Spec 1113: the fail-fast meta outcome is journaled red (the
      // honest stop named as the violation).
      await _journalMeta(
        featureDir: p.join(projectRoot, 'specs', feature),
        feature: feature,
        startedAt: journalStartedAt,
        gateState: 'red',
        phase: 'aggregate',
        result: engine.result,
        receipts: [JournalWriter.engineReceiptRef],
        violations: [
          if (engine.stoppedAt != null)
            'engine lane stopped at ${engine.stoppedAt}',
          'engine lane result=${engine.result} — fail fast, no skin step '
              'spawned',
        ],
      );
      _printSummary(
        feature,
        engine,
        lane: 'engine (fail fast — no skin step spawned)',
        receipts: [JournalWriter.engineReceiptRef],
      );
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
      // Spec 1113: the skin's honest stop is journaled red too — the
      // meta record covers EVERY terminal outcome, not only the green
      // one.
      await _journalMeta(
        featureDir: p.join(projectRoot, 'specs', feature),
        feature: feature,
        startedAt: journalStartedAt,
        gateState: 'red',
        phase: 'aggregate',
        result: skin.result,
        receipts: [
          JournalWriter.engineReceiptRef,
          JournalWriter.skinReceiptRef,
        ],
        violations: [
          if (skin.stoppedAt != null) 'skin lane stopped at ${skin.stoppedAt}',
          'skin lane result=${skin.result}',
        ],
      );
      _printSummary(
        feature,
        skin,
        lane: 'engine (green) + skin',
        receipts: [
          JournalWriter.engineReceiptRef,
          JournalWriter.skinReceiptRef,
        ],
      );
      exitCode = skin.exitCode;
      return;
    }

    // -----------------------------------------------------------------
    // Both lanes green: the unified journal entry naming both receipts
    // (issue #1008) and the structured meta entry (issue #1113) and the
    // final summary line over EVERY behavior.
    // -----------------------------------------------------------------
    await LaneReceipts(
      p.join(projectRoot, 'specs', feature),
    ).appendUnifiedJournalEntry(
      feature: feature,
      engineVerdict: engine.verdict,
      skinVerdict: skin.verdict,
    );
    await _journalMeta(
      featureDir: p.join(projectRoot, 'specs', feature),
      feature: feature,
      startedAt: journalStartedAt,
      gateState: 'green',
      phase: 'aggregate',
      result: 'complete',
      receipts: [JournalWriter.engineReceiptRef, JournalWriter.skinReceiptRef],
      behaviors:
          (engine.rows.map((r) => r.id).toSet()
                ..addAll(skin.rows.map((r) => r.id)))
              .toList(),
    );
    _printSummary(
      feature,
      skin,
      lane: 'engine + skin',
      receipts: [
        JournalWriter.engineReceiptRef,
        JournalWriter.skinReceiptRef,
        'tdd/journal.json (unified meta entry, spec 1113)',
      ],
    );
    exitCode = _exitComplete;
  }

  /// Spec 1113: the meta cycle's journal entry — ONE entry per terminal
  /// outcome of `zfa tdd run` (green / red / preflight_red), the refs
  /// cross-referencing the engine and skin receipts and the skin
  /// contract. A failed write is reported, never fatal (the journal is
  /// a record, not a gate — the receipt discipline).
  Future<void> _journalMeta({
    required String featureDir,
    required String feature,
    required String startedAt,
    required String gateState,
    required String phase,
    String? result,
    List<String> receipts = const [],
    List<String> violations = const [],
    List<String> behaviors = const [],
  }) async {
    try {
      final writer = JournalWriter(featureDir);
      final refs = await writer.resolveRefs();
      await writer.append(
        JournalEntry(
          feature: feature,
          cycle: 'meta',
          phase: phase,
          startedAt: startedAt,
          finishedAt: DateTime.now().toUtc().toIso8601String(),
          gateState: gateState,
          receipts: receipts,
          violations: violations,
          engineReceipt: refs.engine,
          skinReceipt: refs.skin,
          contractSchema: refs.contract,
          result: result,
          behaviors: behaviors,
        ),
      );
    } on FileSystemException {
      stderr.writeln(
        'zfa tdd run: failed to write the meta journal entry at '
        '${p.join(featureDir, 'tdd', 'journal.json')}',
      );
    }
  }

  /// The final summary line over EVERY behavior of the test list (the
  /// union of the lanes) — the pre-split driver's exact shape (FR-009 /
  /// FR-010: `run: feature=<f> result=<r> pending=<n> red=<n> green=<n>
  /// done=<n>` plus ` stopped_at=...` when stopped).
  ///
  /// Issue #1125: the call site's lane/receipts facts also populate the
  /// `--explain` block — the receipts are the journal's own refs
  /// (JournalWriter), never fresh strings.
  void _printSummary(
    String feature,
    RunDriverOutcome outcome, {
    String? lane,
    List<String> receipts = const <String>[],
  }) {
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
    // Issue #1125: the run's explain block — the counts reuse the
    // summary line's numbers, the receipts the journal's refs, the
    // narrative the terminal outcome the two-cycle driver recorded.
    _verdict.explain = TddExplain(
      command: 'run',
      features: [feature],
      lane: lane,
      receipts: receipts,
      summary:
          'Run drove $feature through the two-cycle runner '
          '(spec 1008): result=${outcome.result}, '
          'pending=${outcome.counts['pending']}, '
          'red=${outcome.counts['red']}, '
          'green=${outcome.counts['green']}, '
          'done=${outcome.counts['done']}'
          '${outcome.stoppedAt == null ? '' : ', stopped_at=${outcome.stoppedAt}'}'
          '. ${outcome.result == 'complete' ? 'Both lanes are green — the receipts and the unified journal entry record the evidence.' : 'The run stopped honestly at the first red; resume by re-running `zfa tdd run $feature` — completed behaviors are skipped (evidence beats state).'}',
    );
  }
}
