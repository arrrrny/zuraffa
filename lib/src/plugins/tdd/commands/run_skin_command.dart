/// `zfa tdd run-skin <feature>` — the skin-cycle driver (issue #1005,
/// [ZIKZAK-REBUILD] skin hand-written seam).
///
/// The skin half may be hand-written (or AI-written); this cycle is the
/// referee. For every SKIN-lane behavior (the `## Lanes` declaration of
/// `spec.md`, issue #1000), the cycle accepts the hand-written
/// implementation only if:
///
/// (a) the view renders the declared platform slots — verified from the
///     SkinEvent stream the skin emits during the GREEN test run
///     (`skin-event: behavior=W1 slot=mobile` lines in the runner
///     transcript), never from source string matching;
/// (b) the paired widget test exists and actually executes;
/// (c) the tests go red before green — WITNESSED BY THE CYCLE through
///     the stub-revert red witness (the mutation-audit pattern): capture
///     the hand-written bytes, replace ONLY the view-builder function
///     with the inert stub, run the paired test (it MUST fail), restore
///     the file byte-exact (sha256-verified), run the test again (it
///     MUST pass). The test file is never edited (spec 044 FR-022);
/// (d) the implementation file carries a `_XRaySkinHandEdit(behavior:
///     "W1", file: "lib/...", logged_at: ...)` annotation — scanned,
///     parsed, and cross-checked by the cycle (behavior == the row id,
///     file == the registry record's project-relative subject path,
///     logged_at == ISO-8601), never trusted from the author.
///
/// Every run writes `tdd/04-skin-receipt.json` (schema `skin.v1`) with
/// the per-behavior conformance, the platform slot fills, the scanned
/// hand edits, and the sha256 digest of the SkinEvent trace — green or
/// stopped, so a stopped run records its honest partial state.
///
/// Machine contract (the final stdout line):
/// `run-skin: feature=<f> result=<complete|stopped> behaviors=<n>
/// conformed=<n> slots=<fills>/<declared> hand_edits=<n>`; exit 0 iff
/// every SKIN behavior conforms (a feature with no SKIN lane is an
/// honest empty `complete`). `--json` emits the verdict.v1 envelope as
/// the last line (VISION §5, issue #964).
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/red_classification.dart';
import '../models/verdict_envelope.dart';
import '../services/artifact_registry.dart';
import '../services/cycle_log.dart';
import '../services/red_classifier.dart';
import '../services/runner.dart';
import '../services/skin_event_trace.dart';
import '../services/skin_hand_edit.dart';
import '../services/skin_receipt.dart';
import '../services/skin_stub_reverter.dart';
import '../services/spec_parser.dart';
import '../services/tdd_timeout.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

/// Outcome labels for the summary line.
enum RunSkinOutcome {
  /// Every SKIN behavior conformed.
  complete('complete'),

  /// One or more SKIN behaviors failed conformance (or the runner
  /// misfired) — the receipt records the honest partial state.
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
          'Project root containing specs/, test/, and lib/ (the fixture '
          'or target project). When omitted, the current working '
          'directory is used.',
    );
    argParser.addOption(
      'timeout',
      valueHelp: 'minutes',
      help:
          'Hard deadline in minutes for each spawned test run (default '
          '10). Fractions are allowed.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'run-skin';

  @override
  String get description =>
      'Drive every SKIN-lane behavior through the hand-written '
      'conformance cycle — contract slots, red-before-green witness, '
      '_XRaySkinHandEdit annotation — and write '
      'tdd/04-skin-receipt.json (issue #1005).';

  @override
  String get invocation =>
      'zfa tdd run-skin <feature> [--project <dir>] [--timeout <minutes>]';

  static const _exitComplete = 0;
  static const _exitStopped = 1;
  static const _exitRunnerError = 2;

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      throw UsageException(
        'missing <feature> — name the spec directory whose skin lane to '
        'drive (e.g. 004-login-ui)',
        invocation,
      );
    }
    final feature = _stripSpecsPrefix(rest.first);
    _validateFeatureSegment(feature);
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');

    final Duration? timeoutOverride;
    try {
      timeoutOverride = parseTddTimeoutMinutes(
        argResults?['timeout'] as String?,
      );
    } on TddTimeoutFormatException catch (e) {
      print('zfa tdd run-skin: ${e.message}');
      _printSummary(
        feature: feature,
        result: RunSkinOutcome.stopped,
        behaviors: 0,
        conformed: 0,
        slotFills: 0,
        slotDeclared: 0,
        handEdits: 0,
      );
      exitCode = _exitRunnerError;
      return;
    }

    final featureDir = p.join(projectRoot, 'specs', feature);

    // -----------------------------------------------------------------
    // 1. Feature directory + spec (misfire-stop when absent).
    // -----------------------------------------------------------------
    if (!await Directory(featureDir).exists()) {
      print(
        'zfa tdd run-skin: no feature directory at '
        '${p.relative(featureDir, from: projectRoot)} (project root: '
        '$projectRoot)',
      );
      _printSummary(
        feature: feature,
        result: RunSkinOutcome.stopped,
        behaviors: 0,
        conformed: 0,
        slotFills: 0,
        slotDeclared: 0,
        handEdits: 0,
      );
      exitCode = _exitRunnerError;
      return;
    }
    final specFile = File(p.join(featureDir, 'spec.md'));
    if (!await specFile.exists()) {
      print(
        'zfa tdd run-skin: no spec.md at '
        '${p.relative(specFile.path, from: projectRoot)} — the skin lane '
        'is declared in the spec\'s ## Lanes section (issue #1000).',
      );
      _printSummary(
        feature: feature,
        result: RunSkinOutcome.stopped,
        behaviors: 0,
        conformed: 0,
        slotFills: 0,
        slotDeclared: 0,
        handEdits: 0,
      );
      exitCode = _exitRunnerError;
      return;
    }

    // -----------------------------------------------------------------
    // 2. The SKIN lane declaration (issue #1000): behaviors + slots.
    // -----------------------------------------------------------------
    final lanes = SpecParser().parseLanes(await specFile.readAsString());
    final skinLanes = lanes
        .where((l) => l.lane.trim().toUpperCase() == 'SKIN')
        .toList();
    final declaredSlots = <String>[
      for (final lane in skinLanes) ...lane.adaptiveSlots,
    ];
    final skinBehaviorIds = <String>[
      for (final lane in skinLanes) ...lane.behaviorIds,
    ];

    print('zfa tdd run-skin: feature $feature');
    if (skinBehaviorIds.isEmpty) {
      print(
        '   lane: no SKIN lane declared — nothing to drive '
        '(recorded as an honest empty cycle)',
      );
      await _writeReceipt(
        featureDir: featureDir,
        feature: feature,
        behaviors: const [],
        handEdits: const [],
        trace: SkinEventTrace.merge(const []),
        redWitness: true,
      );
      _printSummary(
        feature: feature,
        result: RunSkinOutcome.complete,
        behaviors: 0,
        conformed: 0,
        slotFills: 0,
        slotDeclared: 0,
        handEdits: 0,
      );
      exitCode = _exitComplete;
      return;
    }
    print('   lane: SKIN ${skinBehaviorIds.join(', ')}');
    print(
      '   slots: '
      '${declaredSlots.isEmpty ? '(none declared)' : declaredSlots.join(', ')}',
    );

    // -----------------------------------------------------------------
    // 3. The registry + the single-test command template.
    // -----------------------------------------------------------------
    final registry = ArtifactRegistry(featureDir: featureDir);

    final String singleTemplate;
    try {
      singleTemplate = await const SingleTestRunner().loadSingleTemplate(
        workingDirectory: projectRoot,
      );
    } on StateError catch (e) {
      print('zfa tdd run-skin: $e');
      _printSummary(
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

    // -----------------------------------------------------------------
    // 4. Drive every skin behavior through the conformance cycle.
    // -----------------------------------------------------------------
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
        timeout: timeoutOverride,
        traces: traces,
        handEdits: handEdits,
        onRedWitnessFailure: () => redWitnessAll = false,
      );
      receipts.add(outcome);
    }

    final trace = SkinEventTrace.merge(traces);
    await _writeReceipt(
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
    _printSummary(
      feature: feature,
      result: allConformed ? RunSkinOutcome.complete : RunSkinOutcome.stopped,
      behaviors: receipts.length,
      conformed: conformed,
      slotFills: slotFills,
      slotDeclared: declaredSlots.length * receipts.length,
      handEdits: handEdits.length,
    );
    exitCode = allConformed ? _exitComplete : _exitStopped;
  }

  // -------------------------------------------------------------------
  // The per-behavior conformance cycle (a) + (b) + (c) + (d).
  // -------------------------------------------------------------------

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
    final preSha = sha256.convert(subjectBytes).toString();

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
        final postSha = sha256
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

  // -------------------------------------------------------------------
  // Receipt + summary.
  // -------------------------------------------------------------------

  Future<void> _writeReceipt({
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

  void _printSummary({
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

  static String _stripSpecsPrefix(String feature) {
    var f = feature.trim();
    while (f.endsWith('/') || f.endsWith(p.separator)) {
      f = f.substring(0, f.length - 1);
    }
    if (f.startsWith('specs/') || f.startsWith('specs${p.separator}')) {
      f = f.substring('specs/'.length);
    }
    return f;
  }

  void _validateFeatureSegment(String feature) {
    if (feature.isEmpty ||
        feature.contains('/') ||
        feature.contains('\\') ||
        feature.contains('..')) {
      throw UsageException(
        '"$feature" is not a feature directory name — pass the bare '
        'name such as 004-login-ui, not a path.',
        invocation,
      );
    }
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
}
