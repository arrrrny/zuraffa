/// `zfa tdd run-skin <feature>` — the SKIN lane driver, gated on a green
/// engine receipt (spec 1008, issue #1008), with TWO driving modes:
///
/// 1. **Conformance mode (spec 1005, issue #1005)** — when the spec's
///    `## Lanes` section declares SKIN lanes with `adaptive_slots`, the
///    skin half may be hand-written (or AI-written); this cycle is the
///    referee. For every SKIN behavior the cycle accepts the
///    hand-written implementation only if:
///
///    (a) the view renders the declared platform slots — verified from
///        the SkinEvent stream the skin emits during the GREEN test run
///        (`skin-event: behavior=W1 slot=mobile` lines in the runner
///        transcript), never from source string matching;
///    (b) the paired widget test exists and actually executes;
///    (c) the tests go red before green — WITNESSED BY THE CYCLE through
///        the stub-revert red witness (the mutation-audit pattern):
///        capture the hand-written bytes, replace ONLY the view-builder
///        function with the inert stub, run the paired test (it MUST
///        fail), restore the file byte-exact (sha256-verified), run the
///        test again (it MUST pass). The test file is never edited
///        (spec 044 FR-022);
///    (d) the implementation file carries a `_XRaySkinHandEdit(behavior:
///        ...)` annotation with a valid timestamp.
///
///    Writes the `skin.v1` receipt (`tdd/04-skin-receipt.json`).
///
/// 2. **Lane mode (spec 1008)** — legacy SKIN lanes WITHOUT declared
///    adaptive slots drive ONLY the SKIN + BOTH behaviors (the skin
///    plan) through the shared two-phase driver core ([RunDriverCore]).
///    BOTH behaviors already DONE by the engine lane are skipped, never
///    re-driven from scratch — evidence beats state, FR-003. Writes the
///    lane-schema receipt (`tdd/04-skin-receipt.json`).
///
/// In BOTH modes the engine gate (issue #1008) runs FIRST: until
/// `tdd/04-engine-receipt.json` records `verdict: green`, the skin lane
/// refuses to start — exit 2, zero steps, no skin receipt — naming the
/// missing/not-green receipt and the remediation (`zfa tdd
/// run-engine`). The skin binds the engine's certified mocks.
///
/// Machine contract — lane mode: the spec 049 exit codes (0 complete,
/// 1 stopped, 2 runner-error, 3 corrupt-state, 4 concurrent-run) plus
/// the gate refusal `result=engine-required` (also exit 2); the summary
/// line is `run-skin: feature=<f> lane=skin result=<r> pending=<n>
/// red=<n> green=<n> done=<n>` plus ` stopped_at=<behavior>:<step>`.
/// Machine contract — conformance mode: exit 0 when every skin behavior
/// conforms, 1 otherwise, 2 usage/runner errors; the summary line is
/// `run-skin: feature=<f> result=<r> behaviors=<n> conformed=<n>
/// slots=<fills>/<declared> hand_edits=<n>`.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../models/red_classification.dart';
import '../models/verdict_envelope.dart';
import '../services/artifact_registry.dart';
import '../services/cycle_log.dart';
import '../services/lane_receipts.dart';
import '../services/red_classifier.dart';
import '../services/runner.dart';
import '../services/skin_event_trace.dart';
import '../services/skin_hand_edit.dart';
import '../services/skin_receipt.dart';
import '../services/skin_stub_reverter.dart';
import '../services/spec_parser.dart';
import '../services/tdd_timeout.dart';
import '../tdd_plugin.dart';
import 'run_driver_core.dart';

/// The conformance cycle's end-of-run outcome.
enum RunSkinOutcome {
  complete('complete'),
  stopped('stopped');

  const RunSkinOutcome(this.label);
  final String label;
}

class RunSkinCommand extends Command<void> {
  RunSkinCommand(this.plugin) {
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

  @override
  String get name => 'run-skin';

  @override
  String get description =>
      'Drive the SKIN lane, gated on a green engine receipt (spec 1008). '
      'SKIN lanes with adaptive_slots run the hand-written conformance '
      'cycle — contract slots, red-before-green witness, '
      '_XRaySkinHandEdit annotation (spec 1005); others run '
      'gen -> verify-red -> make -> refactor. Both write '
      '04-skin-receipt.json.';

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

    // -----------------------------------------------------------------
    // Mode selection: SKIN lanes declaring adaptive_slots are hand-
    // written seams (spec 1005) — the conformance cycle referees them.
    // Legacy SKIN lanes without slots go through the shared two-phase
    // driver core (spec 1008 lane mode).
    // -----------------------------------------------------------------
    final specFile = File(p.join(featureDir, 'spec.md'));
    var declaredSlots = const <String>[];
    if (await specFile.exists()) {
      final lanes = SpecParser().parseLanes(await specFile.readAsString());
      declaredSlots = <String>[
        for (final lane in lanes.where(
          (l) => l.lane.trim().toUpperCase() == 'SKIN',
        ))
          ...lane.adaptiveSlots,
      ];
    }
    if (declaredSlots.isNotEmpty) {
      await _runConformanceMode(
        feature: feature,
        featureDir: featureDir,
        projectRoot: projectRoot,
        declaredSlots: declaredSlots,
        timeout: timeoutOverride,
      );
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

  // -------------------------------------------------------------------
  // Conformance mode (spec 1005).
  // -------------------------------------------------------------------

  Future<void> _runConformanceMode({
    required String feature,
    required String featureDir,
    required String projectRoot,
    required List<String> declaredSlots,
    required Duration? timeout,
  }) async {
    final lanes = SpecParser().parseLanes(
      await File(p.join(featureDir, 'spec.md')).readAsString(),
    );
    final skinLanes = lanes
        .where((l) => l.lane.trim().toUpperCase() == 'SKIN')
        .toList();
    final skinBehaviorIds = <String>[
      for (final lane in skinLanes) ...lane.behaviorIds,
    ];

    print('zfa tdd run-skin: feature $feature (conformance mode)');
    if (skinBehaviorIds.isEmpty) {
      print(
        '   lane: no SKIN behavior declared — nothing to drive '
        '(recorded as an honest empty cycle)',
      );
      await _writeConformanceReceipt(
        featureDir: featureDir,
        feature: feature,
        behaviors: const [],
        handEdits: const [],
        trace: SkinEventTrace.merge(const []),
        redWitness: true,
      );
      _printConformanceSummary(
        feature: feature,
        result: RunSkinOutcome.complete,
        behaviors: 0,
        conformed: 0,
        slotFills: 0,
        slotDeclared: 0,
        handEdits: 0,
      );
      exitCode = 0;
      return;
    }
    print('   lane: SKIN ${skinBehaviorIds.join(', ')}');
    print('   slots: ${declaredSlots.join(', ')}');

    final registry = ArtifactRegistry(featureDir: featureDir);

    final String singleTemplate;
    try {
      singleTemplate = await const SingleTestRunner().loadSingleTemplate(
        workingDirectory: projectRoot,
      );
    } on StateError catch (e) {
      print('zfa tdd run-skin: $e');
      _printConformanceSummary(
        feature: feature,
        result: RunSkinOutcome.stopped,
        behaviors: skinBehaviorIds.length,
        conformed: 0,
        slotFills: 0,
        slotDeclared: declaredSlots.length,
        handEdits: 0,
      );
      exitCode = _exitRunnerError;
      return;
    }

    final receipts = <SkinReceipt>[];
    final handEdits = <SkinHandEditRecord>[];
    final traces = <SkinEventTrace>[];
    var redWitnessAll = true;

    for (final id in skinBehaviorIds) {
      print('   skin $id:');
      final outcome = await _driveBehavior(
        featureDir: featureDir,
        projectRoot: projectRoot,
        id: id,
        registry: registry,
        declaredSlots: declaredSlots,
        singleTemplate: singleTemplate,
        timeout: timeout,
        traces: traces,
        handEdits: handEdits,
        onRedWitnessFailure: () => redWitnessAll = false,
      );
      receipts.add(outcome);
    }

    final trace = SkinEventTrace.merge(traces);
    await _writeConformanceReceipt(
      featureDir: featureDir,
      feature: feature,
      behaviors: receipts,
      handEdits: handEdits,
      trace: trace,
      redWitness: redWitnessAll,
    );

    final conformed = receipts.where((r) => r.conformance).length;
    final slotFills = receipts.fold<int>(
      0,
      (sum, r) => sum + r.platformSlotFills.length,
    );
    final allConformed = conformed == receipts.length;
    _printConformanceSummary(
      feature: feature,
      result: allConformed ? RunSkinOutcome.complete : RunSkinOutcome.stopped,
      behaviors: receipts.length,
      conformed: conformed,
      slotFills: slotFills,
      slotDeclared: declaredSlots.length * receipts.length,
      handEdits: handEdits.length,
    );
    exitCode = allConformed ? 0 : 1;
  }

  /// The per-behavior conformance cycle (a) + (b) + (c) + (d).
  Future<SkinReceipt> _driveBehavior({
    required String featureDir,
    required String projectRoot,
    required String id,
    required ArtifactRegistry registry,
    required List<String> declaredSlots,
    required String singleTemplate,
    required Duration? timeout,
    required List<SkinEventTrace> traces,
    required List<SkinHandEditRecord> handEdits,
    required void Function() onRedWitnessFailure,
  }) async {
    final cycleLog = CycleLog(featureDir);
    void refuse(String why) => print('      conformance: false — $why');

    // -- (b) the registry record + the paired artifacts ---------------
    final record = await registry.findRecord(id);
    if (record == null) {
      refuse('no registry record (run `zfa tdd gen $id` first)');
      return SkinReceipt(
        behavior: id,
        conformance: false,
        testPath: '',
        subjectPath: '',
        platformSlotFills: const [],
      );
    }
    final subjectAbs = p.normalize(
      p.isAbsolute(record.subjectPath)
          ? record.subjectPath
          : p.join(projectRoot, record.subjectPath),
    );
    final testAbs = p.normalize(
      p.isAbsolute(record.testPath)
          ? record.testPath
          : p.join(projectRoot, record.testPath),
    );
    final subjectRel = _posixRel(subjectAbs, projectRoot);
    final testRel = _posixRel(testAbs, projectRoot);
    print('      subject: $subjectRel');
    print('      test: $testRel');

    final subjectFile = File(subjectAbs);
    if (!await subjectFile.exists()) {
      refuse('implementation file missing');
      return _refused(record, subjectRel, testRel);
    }
    final testFile = File(testAbs);
    if (!await testFile.exists()) {
      refuse('paired test missing (run `zfa tdd gen $id`)');
      return _refused(record, subjectRel, testRel);
    }

    final subjectSource = await subjectFile.readAsString();
    final testSource = await testFile.readAsString();

    // -- (d) the _XRaySkinHandEdit annotation, cycle-verified ----------
    final scanned = scanSkinHandEdits(subjectSource);
    for (final edit in scanned) {
      handEdits.add(
        SkinHandEditRecord(
          behavior: edit.behavior,
          file: edit.file,
          loggedAt: edit.loggedAt,
        ),
      );
    }
    final matchedEdit = scanned
        .where((e) => e.matches(behaviorId: id, subjectRelPath: subjectRel))
        .where((e) => e.hasValidTimestamp)
        .toList();
    print(
      '      hand-edit: '
      '${matchedEdit.isEmpty ? "NONE (issue #1005 refusal)" : "logged_at ${matchedEdit.first.loggedAt}"}',
    );

    // -- (c) the red witness: stub-revert -> RED -> restore -> GREEN ---
    final testName = record.plainTestName;
    final runner = const SingleTestRunner();
    final subjectBytes = await subjectFile.readAsBytes();
    final preSha = crypto.sha256.convert(subjectBytes).toString();

    // The view-builder target comes from the IMMUTABLE test source —
    // `subject.<name>(` — never from the author's implementation.
    final targetMatch = RegExp(
      r'subject\.([A-Za-z_][A-Za-z0-9_]*)\s*\(',
    ).firstMatch(testSource);
    final target = targetMatch?.group(1);

    var redWitnessed = false;
    var greenPassed = false;
    var slotFills = const <String>[];

    if (target == null) {
      refuse(
        'the paired test never calls a subject view-builder '
        '(`subject.<name>()`) — no red witness is possible',
      );
    } else {
      final stubbed = stubViewBuilder(subjectSource, target);
      if (stubbed == null) {
        refuse(
          'no `$target` view-builder declaration found in $subjectRel — '
          'the hand-written view must keep the builder the paired test '
          'boots',
        );
      } else {
        // RED: the inert stub must fail the paired test.
        await subjectFile.writeAsString(stubbed);
        try {
          final redRun = await runner.runSingle(
            singleTemplate: singleTemplate,
            testPath: record.testPath,
            testName: testName,
            workingDirectory: projectRoot,
            timeout: timeout,
          );
          traces.add(SkinEventTrace.parse(redRun.output, phase: SkinPhase.red));
          if (redRun.exitCode == 0) {
            refuse(
              'the red witness FAILED: the paired test passed against '
              'the inert stub — the test proves nothing about the view',
            );
          } else {
            redWitnessed = true;
            print('      red: witnessed (exit ${redRun.exitCode})');
            await cycleLog.append(
              CycleLogEntry(
                behaviorId: id,
                kind: CycleEntryKind.red,
                runnerCommand: redRun.command,
                exitCode: redRun.exitCode,
                capturedOutput: _tail(redRun.output),
                classification: _failureClassOf(classify(redRun)),
                sourceCriterion: record.sourceCriterion,
                testPath: record.testPath,
                timestamp: DateTime.now().toUtc().toIso8601String(),
              ),
            );
          }
        } finally {
          // RESTORE: byte-exact — even when the run misfired or threw.
          await subjectFile.writeAsBytes(subjectBytes);
        }
        final postSha = crypto.sha256
            .convert(await subjectFile.readAsBytes())
            .toString();
        if (postSha != preSha) {
          refuse(
            'restore verification failed — the hand-written bytes '
            'changed during the red witness',
          );
          onRedWitnessFailure();
          return _refused(record, subjectRel, testRel);
        }
        print('      restored: byte-exact (sha256 verified)');

        // GREEN: the restored hand-written view must pass.
        final greenRun = await runner.runSingle(
          singleTemplate: singleTemplate,
          testPath: record.testPath,
          testName: testName,
          workingDirectory: projectRoot,
          timeout: timeout,
        );
        final greenTrace = SkinEventTrace.parse(
          greenRun.output,
          phase: SkinPhase.green,
        );
        traces.add(greenTrace);
        if (greenRun.exitCode == 0) {
          greenPassed = true;
          print('      green: passed');
          await cycleLog.append(
            CycleLogEntry(
              behaviorId: id,
              kind: CycleEntryKind.green,
              runnerCommand: greenRun.command,
              exitCode: 0,
              capturedOutput: _tail(greenRun.output),
              sourceCriterion: record.sourceCriterion,
              testPath: record.testPath,
              timestamp: DateTime.now().toUtc().toIso8601String(),
            ),
          );
        } else {
          refuse(
            'the paired test is still red after the hand-written view '
            'was restored (exit ${greenRun.exitCode})',
          );
        }

        // -- (a) platform slot fills from the GREEN SkinEvent stream ---
        if (greenPassed) {
          slotFills = greenTrace.slotsOf(id);
          if (slotFills.isNotEmpty) {
            print('      slots: ${slotFills.join(', ')}');
          }
        }
      }
    }
    if (!redWitnessed) onRedWitnessFailure();

    final slotsConform =
        declaredSlots.isEmpty || declaredSlots.every(slotFills.contains);
    if (!slotsConform) {
      refuse(
        'declared slots not all filled: [${declaredSlots.join(', ')}] '
        'declared vs [${slotFills.join(', ')}] observed',
      );
    }

    final conformance =
        slotsConform && matchedEdit.isNotEmpty && redWitnessed && greenPassed;
    if (conformance) {
      print('      conformance: true');
    }

    return SkinReceipt(
      behavior: id,
      conformance: conformance,
      testPath: testRel,
      subjectPath: subjectRel,
      platformSlotFills: slotFills,
    );
  }

  SkinReceipt _refused(
    ArtifactRecord record,
    String subjectRel,
    String testRel,
  ) => SkinReceipt(
    behavior: record.behaviorId,
    conformance: false,
    testPath: testRel,
    subjectPath: subjectRel,
    platformSlotFills: const [],
  );

  Future<void> _writeConformanceReceipt({
    required String featureDir,
    required String feature,
    required List<SkinReceipt> behaviors,
    required List<SkinHandEditRecord> handEdits,
    required SkinEventTrace trace,
    required bool redWitness,
  }) async {
    final writer = SkinReceiptWriter(featureDir: featureDir);
    final path = await writer.write(
      SkinReceiptDocument(
        feature: feature,
        command: 'zfa tdd run-skin $feature',
        behaviors: behaviors,
        handEdits: handEdits,
        skinEventTraceDigest: trace.digest,
        redWitness: redWitness,
        generatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    print('   receipt: ${p.relative(path, from: featureDir)}');
  }

  void _printConformanceSummary({
    required String feature,
    required RunSkinOutcome result,
    required int behaviors,
    required int conformed,
    required int slotFills,
    required int slotDeclared,
    required int handEdits,
  }) {
    final json = argResults?['json'] as bool? ?? false;
    if (json) {
      VerdictEnvelope.emit(
        command: 'run-skin',
        outcome: result == RunSkinOutcome.complete
            ? VerdictOutcome.pass
            : VerdictOutcome.fail,
        feature: feature,
        details: {
          'result': result.label,
          'behaviors': behaviors,
          'conformed': conformed,
          'slot_fills': slotFills,
          'slot_declared': slotDeclared,
          'hand_edits': handEdits,
        },
      );
      return;
    }
    print(
      'run-skin: feature=$feature result=${result.label} '
      'behaviors=$behaviors conformed=$conformed '
      'slots=$slotFills/$slotDeclared hand_edits=$handEdits',
    );
  }

  /// Project-relative POSIX path.
  static String _posixRel(String abs, String root) {
    if (p.isWithin(root, abs) || p.equals(root, abs)) {
      return p.relative(abs, from: root).replaceAll('\\', '/');
    }
    return p.normalize(abs).replaceAll('\\', '/');
  }

  /// The cycle-log failure class for a classified red run (the
  /// verify-red mapping: only an honest assertion red is recorded as
  /// one; every other class keeps its own name).
  static FailureClass _failureClassOf(RedClassification classification) =>
      switch (classification) {
        RedClassification.assertion => FailureClass.assertionFailure,
        RedClassification.compileError => FailureClass.compileError,
        RedClassification.loadError => FailureClass.loadError,
        RedClassification.skipped => FailureClass.skipped,
        RedClassification.unexpectedGreen => FailureClass.unexpectedGreen,
        _ => FailureClass.runnerError,
      };

  static String _tail(String output, {int maxLines = 12}) {
    final lines = output.trim().split('\n');
    if (lines.length <= maxLines) return output.trim();
    return '(… ${lines.length - maxLines} earlier lines …)\n'
        '${lines.sublist(lines.length - maxLines).join('\n')}';
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
