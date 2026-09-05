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
import '../../mock/certification/mock_cert_receipt.dart';
import '../services/entity_lookup.dart';
import '../services/test_list_reader.dart';
import '../services/tdd_timeout.dart';
import '../tdd_plugin.dart';
import 'run_driver_core.dart';

/// The certification gate's decision (spec 1001, issue #1001): "mocks the
/// framework certifies, not the agent" — the engine refuses to proceed
/// when a CORE entity's mock is present but uncertified.
class RunEngineGateResult {
  const RunEngineGateResult({
    required this.coreEntities,
    required this.mocks,
    required this.certified,
    required this.uncertified,
    required this.blockedEntity,
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

    // Spec 1001 pre-start preflight: an uncertified CORE mock stops the
    // lane before any step is spawned — the engine cannot bypass the
    // certification gate ("mocks the framework certifies, not the agent").
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
      stderr.writeln(
        '--> fix: zfa mock certify $entity '
        '(or zfa mock create $entity --certify), then re-run.',
      );
      _printGateSummary(feature: feature, result: gate);
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
      skipWidget: argResults?['skip-widget'] as bool? ?? false,
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
        skippedWidgetIds: outcome.skippedWidgetIds,
      ),
    );
    exitCode = outcome.exitCode;
  }

  /// The gate itself — also invoked by `zfa tdd run` as its pre-start
  /// preflight (spec 1001, issue #1001).
  static Future<RunEngineGateResult> checkFeature({
    required String projectRoot,
    required String featureDir,
  }) async {
    final entities = await TestListReader(featureDir).readEntities();
    final coreEntities = entities.map((e) => e.name).toList();
    final mocks = <String>[];
    final certified = <String>[];
    final uncertified = <String>[];

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
      final receipt = loadMockCertReceipt(projectRoot, name);
      if (receipt != null && receipt.allSatisfied) {
        certified.add(name);
      } else {
        uncertified.add(name);
      }
    }

    return RunEngineGateResult(
      coreEntities: coreEntities,
      mocks: mocks,
      certified: certified,
      uncertified: uncertified,
      blockedEntity: uncertified.isNotEmpty ? uncertified.first : null,
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
