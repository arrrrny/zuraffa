/// `zfa tdd status <feature>` — the one-line verdict (spec
/// 1008-two-cycle-driver, issue #1008), now sourced from the unified
/// journal via [JournalReader] (spec 1113-unified-tdd-journal, issue
/// #1113).
///
/// Prints exactly two lines:
///
///     status: feature=<f> engine=<verdict> skin=<verdict>
///     <f> | engine ✅ <done>/<total> | skin ✅ <done>/<total> (<n>
///     platforms) | mocks <c>/<t> certified | <n> violations
///
/// The first is the merged spec-1008 machine line (verdict vocabulary
/// green | red | error | absent — a script can gate on it without
/// parsing anything else). The second is the journal's one-line verdict
/// (issue #1113's shape): per-lane receipt counts, the platforms the
/// skin receipt observed, the cert-gate's mock accounting, and the
/// journal's violation count — everything derived from the ONE
/// canonical stream, no journal file I/O in this command.
///
/// Exit 0 iff both lanes are green; any other combination exits 1 — a
/// script can gate on the command without parsing the journal. A
/// missing feature directory refuses with the run commands' misfire
/// semantics (exit 2, the location named). A present-but-corrupt
/// journal is an honest error (exit 2, the recovery path named) — never
/// a silent green.
///
/// Spec 1110 (issue #1110): a cert-gate refusal receipt under the
/// feature's tdd dir renders its exact fix line after the verdict.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../../../engine/engine_gate_receipt.dart';
import '../services/journal.dart';
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
      'Read the unified journal (via JournalReader) and print the one-line '
      'verdicts: status: feature=<f> engine=<verdict> skin=<verdict> plus '
      'the journal verdict line <f> | engine ✅ d/t | skin ✅ d/t | mocks '
      'c/t | n violations (exit 0 iff both green; spec 1008 + spec 1113).';

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

    // Spec 1113: the ONE canonical stream — the journal entries, the
    // refs-followed receipts, and the derived verdict all come from
    // JournalReader; this command never opens a journal file itself.
    // A corrupt receipt is an honest `error` verdict, never a silent
    // green: the line names it and the exit code stays non-zero.
    final journal = await const JournalReader().read(
      feature: feature,
      projectRoot: projectRoot,
    );
    final verdict = journal.verdict;
    print(
      'status: feature=$feature engine=${verdict.engineVerdict} '
      'skin=${verdict.skinVerdict}',
    );
    // The journal's one-line verdict (issue #1113): counts, platforms,
    // mocks, violations — from the journal stream only.
    print(verdict.oneLine);
    for (final note in verdict.notes) {
      print('note: $note');
    }

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

    final bothGreen =
        verdict.engineVerdict == 'green' && verdict.skinVerdict == 'green';
    exitCode = bothGreen && !gateBlocked ? 0 : _exitNotGreen;
  }
}
