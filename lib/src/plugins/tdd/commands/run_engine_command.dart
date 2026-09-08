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
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../../../engine/engine_gate_receipt.dart';
import '../../mock/certification/cert_registry.dart';
import '../../mock/certification/mock_cert_receipt.dart';
import '../models/verdict_envelope.dart';
import '../services/cycle_log_terminal_receipt.dart';
import '../services/entity_lookup.dart';
import '../services/journal.dart';
import '../services/test_list_reader.dart';
import '../services/tdd_timeout.dart';
import '../services/verdict_emitter.dart';
import '../tdd_plugin.dart';
import 'run_command.dart';
import 'run_driver_core.dart';

/// The certification gate's decision (spec 1001, issue #1001; hardened
/// by spec 1110, issue #1110): "mocks the framework certifies, not the
/// agent" — the engine refuses to proceed when a CORE entity's mock is
/// present but uncertified, unsatisfied, or stale.
class RunEngineGateResult {
  const RunEngineGateResult({
    required this.coreEntities,
    required this.mocks,
    required this.certified,
    required this.uncertified,
    required this.blockedEntity,
    this.blockedReason,
    this.blockedFix,
    this.refusedReceiptPath,
  });

  /// The feature's declared Key Entities (CORE entities).
  final List<String> coreEntities;

  /// CORE entities that have a mock datasource on disk.
  final List<String> mocks;

  /// Mock-holding CORE entities with an all-satisfied receipt.
  final List<String> certified;

  /// Mock-holding CORE entities without a valid certification.
  final List<String> uncertified;

  /// The first uncertified entity (the refusal names it), or null.
  final String? blockedEntity;

  /// Spec 1110: the blocked entity's reason (missing / unsatisfied /
  /// corrupt / stale), when a block fired.
  final String? blockedReason;

  /// Spec 1110: the exact cert command for the blocked entity.
  final String? blockedFix;

  /// Spec 1110: the feature-tdd-relative path of the written
  /// `engine.gate.<Entity>.refused.json` refusal receipt, when the gate
  /// blocked. Null when the gate is clean.
  final String? refusedReceiptPath;

  bool get ok => uncertified.isEmpty;
}

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
    argParser.addFlag('json', help: kJsonFlagHelp, negatable: false);
    argParser.addFlag('stream', help: kStreamFlagHelp, negatable: false);
  }

  final TddPlugin plugin;

  /// Issue #969/#838: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

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
  Future<void> run() => runWithVerdictEnvelope(
    this,
    _verdict,
    _run,
    featureFromRest: true,
    // SPEC 917: --stream also closes with the envelope.
    envelopeEnabled: () =>
        tddJsonMode(this) || (argResults?['stream'] as bool? ?? false),
  );

  Future<void> _run() async {
    const label = 'run-engine';
    final journalStartedAt = DateTime.now().toUtc().toIso8601String();
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

    // Spec 1001 pre-start preflight — hardened by spec 1110 (issue
    // #1110): an uncertified OR STALE CORE mock stops the lane before
    // any step is spawned, and the block is a receipt, not an
    // exception: engine.gate.<entity>.refused.json lands in the
    // feature's tdd dir with the exact fix command.
    final gate = await checkFeature(
      projectRoot: projectRoot,
      featureDir: p.join(projectRoot, 'specs', feature),
    );
    if (!gate.ok) {
      final entity = gate.blockedEntity!;
      stderr.writeln(
        'zfa tdd run-engine: CORE entity "$entity" has a mock on disk '
        'that is NOT certified — the engine refuses to proceed '
        '(spec 1001: mocks the framework certifies, not the agent).',
      );
      if (gate.blockedReason != null) {
        stderr.writeln('   ${gate.blockedReason}');
      }
      stderr.writeln(
        '--> fix: ${gate.blockedFix ?? 'zfa mock certify $entity'} '
        '(or zfa mock create $entity --certify), then re-run.',
      );
      if (gate.refusedReceiptPath != null) {
        stderr.writeln('🧾 refusal receipt: ${gate.refusedReceiptPath}');
      }
      // Spec 1113: the cert-gate refusal is journaled preflight_red —
      // the skin lane and `zfa tdd status` read the same record.
      try {
        final writer = JournalWriter(p.join(projectRoot, 'specs', feature));
        final refs = await writer.resolveRefs();
        await writer.append(
          JournalEntry(
            feature: feature,
            cycle: 'engine',
            phase: 'gate',
            startedAt: journalStartedAt,
            finishedAt: DateTime.now().toUtc().toIso8601String(),
            gateState: 'preflight_red',
            receipts: const [],
            violations: [
              'cert-gate: entity=$entity refused '
                  '(${gate.blockedReason ?? 'uncertified CORE mock'})',
            ],
            engineReceipt: refs.engine,
            skinReceipt: refs.skin,
            contractSchema: refs.contract,
            result: 'preflight-refused',
            mocks: {
              'total': gate.mocks.length,
              'certified': gate.certified.length,
            },
          ),
        );
      } on FileSystemException {
        // A record, never a gate — the refusal stands on its stderr +
        // refusal receipt; a failed journal write is only reported.
        stderr.writeln(
          'zfa tdd run-engine: failed to write the preflight journal '
          'entry at '
          '${p.join(projectRoot, 'specs', feature, 'tdd', 'journal.json')}',
        );
      }
      _printGateSummary(feature: feature, result: gate);
      // SPEC 917/#838: the JSON verdict carries the same remediation.
      _verdict
        ..outcome = VerdictOutcome.fail
        ..exitClass = 'blocked'
        ..fix =
            'zfa mock certify $entity (or zfa mock create $entity '
            '--certify), then re-run'
        ..details['blocked_entity'] = entity;
      exitCode = 1;
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
      // SPEC 917/#838: the JSON verdict carries the remediation.
      _verdict
        ..exitClass = 'runner-error'
        ..outcome = VerdictOutcome.error
        ..fix = 'pass --timeout in minutes (e.g. --timeout 10) and re-run';
      exitCode = _exitRunnerError;
      return;
    }

    final driver = RunDriverCore();
    // SPEC 917 (--stream): one NDJSON step-verdict.v1 event per completed
    // step while the lane drives.
    if (argResults?['stream'] as bool? ?? false) {
      driver.onStepEvent = (event) => print(event.toNdjsonLine());
    }
    final outcome = await driver.drive(
      feature: feature,
      projectRoot: projectRoot,
      zfaBin: zfaBin,
      timeout: timeoutOverride,
      lane: 'engine',
      label: label,
      skipWidget: argResults?['skip-widget'] as bool? ?? false,
      // Spec 1113: the gate's mock accounting rides the engine entry
      // (the status verdict's `mocks c/t` segment).
      mockCounts: {
        'total': gate.mocks.length,
        'certified': gate.certified.length,
      },
    );
    _collectVerdict(outcome);
    if (outcome.message != null) print('zfa tdd $label: ${outcome.message}');
    // Issue #1327: the lane's spawned steps appended evidence to
    // tdd/cycle-log.md (verify-red's red witness, make's green evidence,
    // the refactor evidence) after the last `tdd make` receipt covering
    // the log was written. On a COMPLETE lane, close the run with ONE
    // terminal receipt re-hashing the log to its final bytes so
    // result=complete implies `zfa proof check` passes with zero
    // digest-drift findings. A run that stopped early writes nothing —
    // its receipt drift stays the honest record (criterion 4).
    // Best-effort: a record, never a gate; the summary line stays the
    // run's final stdout line (FR-009/FR-010).
    if (outcome.result == 'complete') {
      await CycleLogTerminalReceipt.refreshBestEffort(
        projectRoot: projectRoot,
        feature: feature,
        command: 'tdd $label',
      );
    }
    print(
      RunDriverCore.summaryLine(
        label: label,
        feature: feature,
        lane: 'engine',
        result: outcome.result,
        counts: outcome.counts,
        stoppedAt: outcome.stoppedAt,
        skippedWidgetIds: outcome.skippedWidgetIds,
      ),
    );
    exitCode = outcome.exitCode;
  }

  /// SPEC 917/#838: mirrors the shipped exit taxonomy into the envelope —
  /// the driver's `result` IS the exit_class; the verdict derives from it
  /// (complete → pass, stopped → stopped, else error), and every non-green
  /// verdict carries the machine-actionable remediation.
  void _collectVerdict(RunDriverOutcome outcome) {
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
      ..details['done'] = outcome.counts['done']
      ..fix = switch (outcome.result) {
        'complete' => null,
        'stopped' =>
          'resume the lane: `zfa tdd run-engine '
              '${_verdict.feature ?? '<feature>'}` (the run resumes from '
              'tdd/run-state.json)',
        'corrupt-state' =>
          'recover the corrupt state named above, then re-run '
              '`zfa tdd run-engine`',
        'concurrent-run' =>
          'wait for the active run to finish (or remove its stale lock), '
              'then re-run `zfa tdd run-engine`',
        _ =>
          'fix the runner issue named above (missing feature dir / '
              'entrypoint), then re-run `zfa tdd run-engine`',
      };
    if (outcome.stoppedAt != null) {
      _verdict.details['stopped_at'] = outcome.stoppedAt;
    }
  }

  /// The gate itself — also invoked by `zfa tdd run` as its pre-start
  /// preflight (spec 1001, issue #1001; spec 1110 adds the freshness
  /// check and the refusal receipt).
  static Future<RunEngineGateResult> checkFeature({
    required String projectRoot,
    required String featureDir,
  }) async {
    final entities = await TestListReader(featureDir).readEntities();
    final coreEntities = entities.map((e) => e.name).toList();
    final mocks = <String>[];
    final certified = <String>[];
    final uncertified = <String>[];
    String? blockedEntity;
    String? blockedReason;
    String? blockedFix;
    String? refusedReceiptPath;

    for (final name in coreEntities) {
      final snake = toSnakeCase(name);
      final mockPath = p.join(
        projectRoot,
        'lib',
        'src',
        'data',
        'datasources',
        snake,
        '${snake}_mock_datasource.dart',
      );
      if (!File(mockPath).existsSync()) continue;
      mocks.add(name);
      // Spec 1110: the gate walks the certification REGISTRY — one
      // check for existence (receipt present, all methods satisfied)
      // AND freshness (receipt written after the entity source's last
      // change). A stale certification no longer describes the entity
      // on disk; it blocks exactly like a missing one.
      final entry = CertRegistry.checkEntity(
        entity: name,
        projectRoot: projectRoot,
      );
      final receipt = loadMockCertReceipt(projectRoot, name);
      if (receipt != null && receipt.allSatisfied && !entry.blocked) {
        certified.add(name);
      } else {
        uncertified.add(name);
        if (blockedEntity == null) {
          blockedEntity = name;
          final reason = entry.blocked
              ? entry.reason
              : 'mock-cert.$name.json is not an all-satisfied '
                    'certification';
          final fix = entry.fix.isNotEmpty
              ? entry.fix
              : CertRegistry.certifyFixCommand(name);
          blockedReason = reason;
          blockedFix = fix;
          // The refusal receipt (spec 1110): a receipt, not an
          // exception — written into the feature's tdd dir where
          // `zfa tdd status` reads it.
          refusedReceiptPath = await EngineGateReceipt.write(
            projectRoot: projectRoot,
            entity: name,
            reason: reason,
            fix: fix,
            command: 'zfa tdd run-engine ${p.basename(featureDir)}',
            featureDir: featureDir,
          );
        }
      }
    }

    // The gate healed: every wired CORE entity certified — a prior
    // refusal receipt must not outlive its block (spec 1110).
    if (uncertified.isEmpty) {
      for (final name in coreEntities) {
        EngineGateReceipt.clear(
          projectRoot: projectRoot,
          entity: name,
          featureDir: featureDir,
        );
      }
    }

    return RunEngineGateResult(
      coreEntities: coreEntities,
      mocks: mocks,
      certified: certified,
      uncertified: uncertified,
      blockedEntity: blockedEntity,
      blockedReason: blockedReason,
      blockedFix: blockedFix,
      refusedReceiptPath: refusedReceiptPath,
    );
  }

  static void _printGateSummary({
    required String feature,
    required RunEngineGateResult result,
  }) {
    stdout.writeln(
      'run-engine: feature=$feature '
      'core-entities=${result.coreEntities.length} '
      'mocks=${result.mocks.length} '
      'certified=${result.certified.length} '
      'uncertified=${result.uncertified.length}'
      '${result.blockedEntity != null ? ' blocked=${result.blockedEntity}' : ''}',
    );
  }
}
