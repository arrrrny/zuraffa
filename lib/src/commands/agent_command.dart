import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../agent/shell/agent_shell.dart';
import '../agent/shell/mission_document.dart';
import '../agent/shell/shell_protocol.dart';

/// `zfa agent` — agent runtime commands (issue #808, VISION 2030 Pillar B).
class AgentCommand extends Command<void> {
  @override
  String get name => 'agent';

  @override
  String get description =>
      'Agent runtime (shell daemon, leases, missions, budgets)';

  AgentCommand() {
    addSubcommand(AgentShellCommand());
  }

  @override
  Future<void> run() async {
    stdout.writeln('Usage: zfa agent <shell>');
    stdout.writeln(
      '  shell   Start the agent shell daemon (NDJSON over stdio)',
    );
  }
}

/// `zfa agent shell` — the long-lived daemon an agent connects to (v0).
///
/// Protocol: one JSON envelope per line on stdin; response/event envelopes
/// (leases, mission progress, budget ticks/breaches) on stdout. Mission
/// snapshots persist under `.zfa/agent-shell/` so a fresh daemon or fresh
/// agent resumes exactly where the last one died.
class AgentShellCommand extends Command<void> {
  AgentShellCommand({
    Stream<String>? stdinLines,
    StringSink? sink,
    String? snapshotDir,
  }) : _stdinLines = stdinLines,
       _sink = sink,
       _snapshotDir = snapshotDir;

  final Stream<String>? _stdinLines;
  final StringSink? _sink;
  final String? _snapshotDir;

  @override
  String get name => 'shell';

  @override
  String get description =>
      'Run the agent shell daemon (NDJSON over stdio) — leases, missions, '
      'budgets (#808)';

  @override
  Future<void> run() async {
    final shell = AgentShell(
      snapshots: SnapshotStore(_snapshotDir ?? '.zfa/agent-shell'),
    );

    final input =
        _stdinLines ??
        stdin
            .transform(const SystemEncoding().decoder)
            .transform(const LineSplitter());
    final out = _sink ?? stdout;

    final inbound = StreamController<Map<String, Object?>>();
    final outbound = shell.attach('cli-agent', inbound.stream);

    final done = Completer<void>();
    outbound.listen(
      (event) {
        out.writeln(ShellProtocol.encodeLine(event).trimRight());
      },
      onDone: done.complete,
      onError: done.completeError,
    );

    await for (final line in input) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        inbound.add(ShellProtocol.decodeLine(trimmed));
      } on FormatException catch (e) {
        out.writeln(
          ShellProtocol.encodeLine(
            ShellProtocol.event(
              'error',
              extra: {'message': 'malformed NDJSON: ${e.message}'},
            ),
          ).trimRight(),
        );
      }
    }
    await inbound.close();
    await done.future;
    await shell.dispose();
  }
}
