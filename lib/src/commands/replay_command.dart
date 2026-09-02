/// `zfa replay` — the top-level dream surface of issue #806: `zfa replay
/// tdd/cycle-log.md` (or a feature id) re-executes a feature's recorded
/// TDD history. A thin delegate to the same capability as
/// `zfa tdd replay` (spec 066-zfa-replay FR-001).
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import '../plugins/tdd/services/replay_runner.dart';
import '../plugins/tdd/services/tdd_timeout.dart';

class ReplayCommand extends Command<void> {
  ReplayCommand() {
    argParser.addOption(
      'behavior',
      help: 'Replay only this behavior id (default: every recorded behavior)',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help: 'The project root (default: nearest pubspec.yaml walk-up)',
    );
    argParser.addOption(
      'zfa-bin',
      help: 'The zfa entrypoint recorded gen steps resolve to (default: PATH)',
    );
    argParser.addOption(
      'timeout',
      help: 'Per-recorded-command timeout in minutes (bug #742)',
    );
    argParser.addOption(
      'events',
      help: 'Write the NDJSON event log to this path (spec 066 FR-014)',
    );
    argParser.addFlag(
      'keep-sandbox',
      negatable: false,
      help: 'Keep the replay sandbox for debugging (path in the summary)',
    );
  }

  @override
  String get name => 'replay';

  @override
  String get description =>
      'Deterministically re-execute a feature\'s recorded TDD history: '
      'zfa replay <feature> or zfa replay <path>/tdd/cycle-log.md. '
      'History becomes executable documentation that either runs or screams.';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      usageException(
        'A feature id or a cycle-log path is required: '
        'zfa replay <feature|path/to/tdd/cycle-log.md>',
      );
    }
    final Duration? timeout;
    try {
      timeout = parseTddTimeoutMinutes(argResults?['timeout'] as String?);
    } on TddTimeoutFormatException catch (e) {
      usageException(e.message);
    }
    exitCode = await ReplayRunner.execute(
      featureArg: rest.first,
      projectFlag: argResults?['project'] as String?,
      zfaBin: argResults?['zfa-bin'] as String?,
      timeout: timeout,
      behaviorFilter: argResults?['behavior'] as String?,
      eventsPath: argResults?['events'] as String?,
      keepSandbox: (argResults?['keep-sandbox'] as bool?) ?? false,
    );
  }
}
