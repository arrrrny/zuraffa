/// `zfa dream "<feature description>"` — the one-command app (issue
/// #1010, the vision track's end): a plain-English feature description
/// produces a spec, a plan, receipts, and a PR.
///
/// A thin CLI surface over `DreamRunner.execute` (the ReplayCommand
/// pattern): the command parses flags and delegates; every phase of the
/// pipeline is an existing command or the existing MCP v2 surface —
/// this file adds no logic of its own.
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import '../plugins/tdd/models/verdict_envelope.dart';
import '../plugins/tdd/services/dream_runner.dart';

class DreamCommand extends Command<void> {
  DreamCommand() {
    argParser.addOption(
      'feature',
      help:
          'Feature name (specs/<feature>). Default: the next sequential '
          'number + the description slug.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help: 'Project root (default: nearest pubspec/specs walk-up).',
    );
    argParser.addOption(
      'zfa-bin',
      help:
          'The zfa entrypoint the spawned phases run through '
          '(default: resolved like zfa tdd run).',
    );
    argParser.addOption(
      'max-retries',
      help:
          'Draft/ingest attempts before an honest stop (default: 3; the '
          'ingest refusal re-prompts the drafter).',
    );
    argParser.addOption(
      'engine-attempts',
      help:
          'Engine-cycle run budget before an honest stop (default: 2; '
          'zfa tdd run is resumable).',
    );
    argParser.addFlag(
      'no-pr',
      negatable: false,
      help:
          'Skip the git/gh phase entirely (tests, CI, offline runs — '
          'receipts and the summary line still record everything).',
    );
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
    );
  }

  @override
  String get name => 'dream';

  @override
  String get description =>
      'Dream a feature from plain English: draft the spec via the MCP v2 '
      'tool, ingest it, run the engine cycle to green, run the skin '
      'cycle (opening a hand-edit branch when the view is scaffolded), '
      'write the engine/skin receipts, and open a PR (draft until the '
      'engine is green). One command over the proven stack (issue #1010).';

  @override
  String get invocation => 'zfa dream "<feature description>"';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      // Sets the global exit code directly (the UsageException path
      // does not propagate through runCapturing's non-exiting runner —
      // the zap command's pattern).
      print('A feature description is required: $invocation');
      print(usage);
      exitCode = 64;
      return;
    }
    final description = rest.first;

    int? parseInt(String key) {
      final raw = argResults?[key] as String?;
      if (raw == null || raw.isEmpty) return null;
      return int.tryParse(raw);
    }

    final maxRetries = parseInt('max-retries');
    if (argResults?['max-retries'] != null &&
        (argResults?['max-retries'] as String).isNotEmpty &&
        maxRetries == null) {
      print('--max-retries must be an integer');
      exitCode = 64;
      return;
    }
    final engineAttempts = parseInt('engine-attempts');
    if (argResults?['engine-attempts'] != null &&
        (argResults?['engine-attempts'] as String).isNotEmpty &&
        engineAttempts == null) {
      print('--engine-attempts must be an integer');
      exitCode = 64;
      return;
    }

    final code = await DreamRunner.execute(
      description: description,
      feature: argResults?['feature'] as String?,
      projectFlag: argResults?['project'] as String?,
      zfaBin: argResults?['zfa-bin'] as String?,
      maxRetries: maxRetries ?? 3,
      engineAttempts: engineAttempts ?? 2,
      noPr: (argResults?['no-pr'] as bool?) ?? false,
    );

    if ((argResults?['json'] as bool?) ?? false) {
      VerdictEnvelope.emit(
        command: 'dream',
        outcome: code == 0 ? VerdictOutcome.pass : VerdictOutcome.stopped,
        details: {'description': description},
      );
    }
    exitCode = code;
  }
}
