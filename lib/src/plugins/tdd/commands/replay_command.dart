/// `zfa tdd replay` — deterministically re-execute a feature's recorded
/// TDD history in a clean sandbox (spec 066-zfa-replay, issue #806).
///
/// Thin surface: argument parsing only — the capability lives in
/// `ReplayRunner.execute` (services/replay_runner.dart), shared with the
/// top-level `zfa replay` dream surface.
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import '../services/replay_runner.dart';
import '../services/tdd_timeout.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';

class ReplayCommand extends Command<void> {
  ReplayCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #969).',
      negatable: false,
    );
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

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'replay';

  @override
  String get description =>
      'Replay a feature\'s recorded TDD history in a clean sandbox: '
      'chain integrity, gen artifact compare, green verify. '
      'Clean = silent pass; divergence = the step named.';

  @override
  Future<void> run() =>
      runWithVerdictEnvelope(this, _verdict, _run, featureFromRest: true);

  Future<void> _run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      usageException('Feature id is required: zfa tdd replay <feature>');
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
    // Issue #969: replay's exit code IS its taxonomy; the envelope
    // carries the class label.
    _verdict
      ..exitClass = switch (exitCode) {
        0 => 'clean',
        _ => 'divergence',
      }
      ..outcome = exitCode == 0 ? VerdictOutcome.pass : VerdictOutcome.fail
      ..details['feature'] = rest.first;
  }
}
