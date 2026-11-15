import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../cli/plugin_loader.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../mcp/session_store.dart';
import 'base_plugin_command.dart';

/// `zfa mcp` — MCP plugin command.
///
/// Auto-registered by the [McpPlugin] (via [CliAwarePlugin.createCommand]).
/// Inherits the standard plugin flags (--output, --dry-run, --force,
/// --verbose, --revert) from [PluginCommand] and adds two runtime
/// subcommands:
///
///  * `zfa mcp serve [--sse] [--port <n>] [--token <t>]` — runs the
///    scaffolded `bin/mcp_server.dart` from the user's app, which
///    serves stdio (default) or SSE.
///  * `zfa mcp list-tools` — subprocesses `bin/mcp_server.dart
///    --list-tools` and prints the tool definitions as JSON.
///
/// The scaffold capability (`zfa mcp scaffold`) is auto-registered
/// as a subcommand by [PluginCommand]'s constructor (it iterates
/// `plugin.capabilities`).
class McpCommand extends PluginCommand {
  McpCommand(super.plugin) : super() {
    addSubcommand(_ServeCommand());
    addSubcommand(_ListToolsCommand());
    addSubcommand(_ReplayCommand());
  }

  @override
  String get description =>
      'Scaffold / serve / inspect an MCP server that exposes this app\'s '
      'features as AI-callable tools (issue #369)';

  @override
  Future<void> run() async {
    print(usage);
  }
}

/// `zfa mcp replay <session-file|session-id>` (issue #1358; spec 1136
/// lane 3) — re-executes a recorded sequence of MCP tool calls against
/// the REAL scaffolded `bin/mcp_server.dart` over the stdio JSON-RPC
/// wire.
///
/// Two resolution forms:
/// - a **scenario file** (the #1358 contract, unchanged): a committed
///   JSON document `{"session": "<name>", "calls": [{"tool": ...,
///   "arguments": {...}, "expect_contains": "..."}]}`;
/// - a **session id** (spec 1136 lane 3): a persisted
///   `McpSessionStore` session (`.zfa/mcp_sessions/<id>.json`) whose
///   recorded call sequence — appended via the v2 `session_record`
///   tool — becomes the scenario.
///
/// One verdict line per call (`ok` / `missing-tool` / `mismatch` /
/// `error`), a summary line, and a proof-carrying receipt under
/// `.zfa/receipts/` (naming the source). Exit 0 iff every call is ok.
class _ReplayCommand extends Command<void> {
  @override
  String get name => 'replay';

  @override
  String get description =>
      'Re-execute a recorded MCP tool-call scenario (JSON file or '
      'persisted session id) against the scaffolded server and write a '
      'verdict receipt (issue #1358, spec 1136)';

  @override
  String get invocation =>
      'zfa mcp replay <session-file|session-id> [--timeout <seconds>]';

  _ReplayCommand() {
    argParser.addOption(
      'timeout',
      help: 'Deadline for the whole replay in seconds.',
      defaultsTo: '120',
    );
  }

  /// Whether [value] can name a persisted session (a single plain
  /// directory-segment id, not a path).
  static bool _isBareSegment(String value) =>
      value.isNotEmpty &&
      !value.contains('/') &&
      !value.contains(r'\') &&
      !value.contains('..');

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      print('❌ Usage: $invocation');
      exitCode = 2;
      return;
    }
    final target = rest.first;

    final String sessionName;
    final List rawCalls;
    var source = 'scenario-file';
    String? scenarioPath;

    final scenarioFile = File(target);
    if (await scenarioFile.exists()) {
      // The #1358 form: a committed scenario file.
      scenarioPath = target;
      final Object? decoded;
      try {
        decoded = jsonDecode(await scenarioFile.readAsString());
      } on FormatException catch (e) {
        print('❌ Malformed scenario file: $target (${e.message})');
        exitCode = 1;
        return;
      }
      if (decoded is! Map<String, dynamic>) {
        print('❌ Malformed scenario file: $target (not an object)');
        exitCode = 1;
        return;
      }
      sessionName = (decoded['session'] as String?) ?? 'session';
      final scenarioCalls = decoded['calls'];
      if (scenarioCalls is! List) {
        print('❌ Malformed scenario file: $target ("calls" must be a list)');
        exitCode = 1;
        return;
      }
      if (scenarioCalls.isEmpty) {
        print(
          '❌ Malformed scenario file: $target ("calls" is empty — a '
          'zero-call replay proves nothing)',
        );
        exitCode = 1;
        return;
      }
      rawCalls = scenarioCalls;
    } else if (_isBareSegment(target)) {
      // Spec 1136 lane 3: a persisted McpSessionStore session id.
      source = 'session-store';
      final store = McpSessionStore(projectRoot: Directory.current.path);
      final sessionFile = File(
        p.join(Directory.current.path, '.zfa', 'mcp_sessions', '$target.json'),
      );
      if (!await sessionFile.exists()) {
        print('❌ Usage: $invocation');
        print(
          '   no scenario file at: $target, and no recorded session at: '
          '${sessionFile.path}',
        );
        exitCode = 2;
        return;
      }
      final recorded = await store.callsOf(target);
      if (recorded.isEmpty) {
        print(
          '❌ session "$target" has no recorded tool calls — record '
          'calls first (the v2 session_record tool, or '
          'McpSessionStore.appendCall), then replay.',
        );
        exitCode = 1;
        return;
      }
      sessionName = target;
      rawCalls = recorded;
    } else {
      print('❌ Usage: $invocation');
      print('   scenario file not found: $target');
      exitCode = 2;
      return;
    }

    final binPath = 'bin/mcp_server.dart';
    if (!await File(binPath).exists()) {
      print(
        '❌ $binPath not found — the replay needs the scaffolded server. '
        'Run `zfa mcp scaffold` first.',
      );
      exitCode = 1;
      return;
    }

    final timeoutSeconds =
        int.tryParse(argResults!['timeout'] as String? ?? '120') ?? 120;

    final peer = await _startReplayPeer(binPath, timeoutSeconds);
    if (peer == null) {
      exitCode = 1;
      return;
    }

    final verdictLines = <Map<String, dynamic>>[];
    var ok = 0;
    var failed = 0;

    Future<void> replayCall(Map<String, dynamic> call, int index) async {
      final tool = call['tool'] as String?;
      final rawArguments = call['arguments'];
      if (rawArguments != null && rawArguments is! Map<String, dynamic>) {
        failed++;
        verdictLines.add({
          'call': index,
          'tool': tool,
          'verdict': 'error',
          'detail': '"arguments" must be an object',
        });
        return;
      }
      final arguments = (rawArguments as Map<String, dynamic>?) ?? const {};
      final expectContains = call['expect_contains'] as String?;
      if (tool == null || tool.isEmpty) {
        failed++;
        verdictLines.add({
          'call': index,
          'verdict': 'error',
          'detail': 'scenario entry has no "tool"',
        });
        return;
      }
      final response = await peer.request('tools/call', {
        'name': tool,
        'arguments': arguments,
      });
      if (response == null) {
        failed++;
        verdictLines.add({
          'call': index,
          'tool': tool,
          'verdict': 'error',
          'detail': 'timeout or no response',
        });
        return;
      }
      if (response['error'] != null) {
        final error = response['error'] as Map<String, dynamic>;
        failed++;
        verdictLines.add({
          'call': index,
          'tool': tool,
          'verdict': error['code'] == -32602 ? 'missing-tool' : 'error',
          'detail': '${error['message']}',
        });
        return;
      }
      var text = '';
      final result = response['result'];
      if (result is Map<String, dynamic>) {
        final content = result['content'];
        if (content is List && content.isNotEmpty) {
          final first = content.first;
          if (first is Map<String, dynamic> && first['text'] is String) {
            text = first['text'] as String;
          }
        }
      }
      if (expectContains != null && !text.contains(expectContains)) {
        failed++;
        verdictLines.add({
          'call': index,
          'tool': tool,
          'verdict': 'mismatch',
          'detail': 'output did not contain "$expectContains"',
        });
        return;
      }
      ok++;
      verdictLines.add({
        'call': index,
        'tool': tool,
        'verdict': 'ok',
        'output': text,
      });
    }

    try {
      for (var i = 0; i < rawCalls.length; i++) {
        final call = rawCalls[i];
        if (call is! Map<String, dynamic>) {
          failed++;
          verdictLines.add({
            'call': i,
            'verdict': 'error',
            'detail': 'scenario entry is not an object',
          });
          continue;
        }
        await replayCall(call, i);
      }
    } finally {
      await peer.close();
    }

    for (final line in verdictLines) {
      final verdict = line['verdict'];
      final detail = line['detail'];
      print(
        '  $verdict ${line['tool'] ?? '(no tool)'}'
        '${detail == null ? '' : ' — $detail'}',
      );
    }
    print(
      'mcp-replay: session=$sessionName '
      'calls=${verdictLines.length} ok=$ok failed=$failed',
    );

    // The proof-carrying receipt (#807 family).
    final receiptsDir = Directory('.zfa/receipts');
    await receiptsDir.create(recursive: true);
    final sanitized = sessionName.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final receiptFile = File('${receiptsDir.path}/mcp-replay-$sanitized.json');
    await receiptFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert({'command': 'zfa mcp replay', 'session': sessionName, 'source': source, 'scenario': ?scenarioPath, 'at': DateTime.now().toUtc().toIso8601String(), 'calls': verdictLines, 'ok': ok, 'failed': failed, 'passed': failed == 0})}\n',
    );
    print('   receipt: ${receiptFile.path}');

    exitCode = failed == 0 ? 0 : 1;
  }
}

/// Spawns `dart run <binPath>` and answers `initialize`, re-spawning ONCE
/// when the child dies at startup (issue #2091).
///
/// A fresh `dart run` child is slow to become a peer — cold JIT plus an
/// implicit pub get — and a loaded host can kill it before it reads a
/// line. That is a hiccup, not a verdict: one re-spawn separates the two.
/// Returns null (after printing the reason) when the retry also failed.
Future<_ReplayPeer?> _startReplayPeer(
  String binPath,
  int timeoutSeconds,
) async {
  _ReplaySpawnFailure? last;
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      return await _ReplayPeer.start(binPath, timeoutSeconds);
    } on _ReplaySpawnFailure catch (e) {
      last = e;
    }
  }
  print('❌ ${last?.message ?? 'the scaffolded MCP server did not start.'}');
  return null;
}

/// The scaffolded MCP server never became a usable peer: it died, or it
/// stayed silent past the replay deadline (issue #2091).
class _ReplaySpawnFailure implements Exception {
  const _ReplaySpawnFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One spawned `dart run bin/mcp_server.dart` peer and its stdio
/// JSON-RPC plumbing (issue #2091).
///
/// Two properties the old inline plumbing lacked:
///
///  * the child's stderr is drained into a bounded tail, so a peer that
///    dies can NAME why — and a chatty child cannot fill the stderr pipe
///    and deadlock against its own stdout;
///  * a transport failure (the child's stdin read end closing under a
///    write) and a request that simply never gets an answer both read as
///    "no answer", never as a raw `SocketException` and never as a
///    successful call.
class _ReplayPeer {
  _ReplayPeer._(this._process, this._binPath, this._timeoutSeconds);

  final Process _process;
  final String _binPath;
  final int _timeoutSeconds;

  static const _stderrTailLines = 5;

  final Map<int, Completer<Map<String, dynamic>?>> _responses = {};
  final List<String> _stderrTail = [];
  final Completer<void> _stderrDone = Completer<void>();
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  int _nextId = 0;
  int? _exitCode;

  /// Spawns the child and answers `initialize`.
  ///
  /// Throws [_ReplaySpawnFailure] when the child dies or never answers —
  /// the caller re-spawns once before reporting (#2091).
  static Future<_ReplayPeer> start(String binPath, int timeoutSeconds) async {
    final Process process;
    try {
      process = await Process.start('dart', ['run', binPath]);
    } on ProcessException catch (e) {
      throw _ReplaySpawnFailure('could not spawn `dart run $binPath` — $e');
    }
    final peer = _ReplayPeer._(process, binPath, timeoutSeconds);
    peer._listen();
    try {
      final answer = await peer.request('initialize', {
        'protocolVersion': '2024-11-05',
        'capabilities': {},
        'clientInfo': {'name': 'zfa-mcp-replay', 'version': '1.0.0'},
      });
      if (answer == null || answer.isEmpty) {
        throw _ReplaySpawnFailure(
          await peer.noAnswerReason(
            '`dart run $binPath` did not answer `initialize` within '
            '$timeoutSeconds seconds',
          ),
        );
      }
      await peer._write({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      });
      return peer;
    } catch (_) {
      await peer.close();
      rethrow;
    }
  }

  /// Sends one JSON-RPC request and awaits its answer.
  ///
  /// Returns null when the peer cannot answer — a write to a child whose
  /// stdin read end closed, a child that exited with a request in flight,
  /// or a deadline that passed. A null is never a verdict: the caller
  /// records an `error`, and only the startup probe retries (#2091).
  Future<Map<String, dynamic>?> request(
    String method,
    Map<String, dynamic>? params,
  ) async {
    final id = ++_nextId;
    final completer = Completer<Map<String, dynamic>?>();
    _responses[id] = completer;
    try {
      await _write({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': ?params,
      });
    } on SocketException {
      _responses.remove(id);
      return null;
    } on StateError {
      _responses.remove(id);
      return null;
    }
    return completer.future.timeout(
      Duration(seconds: _timeoutSeconds),
      onTimeout: () => null,
    );
  }

  Future<void> _write(Map<String, dynamic> message) async {
    _process.stdin.writeln(jsonEncode(message));
    await _process.stdin.flush();
  }

  void _listen() {
    _stdoutSub = _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return;
          try {
            final message = jsonDecode(trimmed) as Map<String, dynamic>;
            final id = message['id'];
            if (id is int) _responses.remove(id)?.complete(message);
          } on FormatException {
            // Non-JSON stdout lines (banner noise) are ignored.
          }
        });
    _stderrSub = _process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            _stderrTail.add(line);
            if (_stderrTail.length > _stderrTailLines) _stderrTail.removeAt(0);
          },
          onDone: () {
            if (!_stderrDone.isCompleted) _stderrDone.complete();
          },
        );
    // A peer that exits with a request in flight can never answer it:
    // settle the waiters now instead of holding them for the whole
    // replay deadline (#2091).
    unawaited(
      _process.exitCode.then((code) {
        _exitCode = code;
        for (final completer in _responses.values) {
          if (!completer.isCompleted) completer.complete(null);
        }
      }),
    );
  }

  /// Why this peer produced no answer: the child's exit code and stderr
  /// tail when it died, or [fallback] when it is alive but silent.
  Future<String> noAnswerReason(String fallback) async {
    final exit =
        _exitCode ??
        await _process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () => -1,
        );
    // The child's last stderr line races its exit; let the pipe deliver.
    await _stderrDone.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () {},
    );
    final tail = _stderrTail.isEmpty
        ? ''
        : ' — stderr: ${_stderrTail.join(' | ')}';
    if (exit < 0) return '$fallback$tail';
    return '`dart run $_binPath` exited $exit before it answered$tail';
  }

  Future<void> close() async {
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    // Release the stdin pipe: a long-lived process that replays many
    // sessions must not accumulate one write end per spawn.
    try {
      await _process.stdin.close();
    } on SocketException {
      // The child is already gone; the pipe closed under us.
    } on StateError {
      // Already closed.
    }
    try {
      _process.kill();
    } on ProcessException {
      // Already gone — there is nothing left to kill.
    }
  }
}

/// `zfa mcp serve [--sse] [--port <n>] [--token <t>]`
///
/// Subprocesses the user's scaffolded `bin/mcp_server.dart` with
/// passthrough args. Inherits stdio so the agent connects to the
/// subprocess directly.
class _ServeCommand extends Command<void> {
  @override
  String get name => 'serve';

  @override
  String get description =>
      'Run the scaffolded MCP server (stdio by default, or --sse for HTTP+SSE)';

  _ServeCommand() {
    argParser.addFlag(
      'sse',
      negatable: false,
      help: 'Serve over HTTP+SSE instead of stdio',
    );
    argParser.addOption(
      'port',
      abbr: 'p',
      defaultsTo: '8372',
      help: 'Port for the SSE server (ignored without --sse)',
    );
    argParser.addOption(
      'token',
      help: 'Bearer token for SSE auth (loopback always allowed)',
    );
  }

  @override
  Future<void> run() async {
    final binPath = 'bin/mcp_server.dart';
    final binFile = File(binPath);
    if (!await binFile.exists()) {
      stderr.writeln(
        '❌ $binPath not found. Run `zfa mcp scaffold` first to generate it.',
      );
      exit(1);
    }

    final args = <String>['run', binPath];
    final sse = argResults!['sse'] == true;
    if (sse) args.add('--sse');

    // Validate the port before forwarding it: a non-integer --port must
    // fail loudly rather than silently fall back to the server's 8372.
    final portRaw = argResults!['port'] as String?;
    final port = int.tryParse(portRaw ?? '');
    if (port == null) {
      stderr.writeln(
        '❌ Invalid --port value "$portRaw": expected an integer port number.',
      );
      exit(1);
    }
    if (portRaw != null && portRaw.isNotEmpty) {
      args.addAll(['--port', portRaw]);
    }

    final token = argResults!['token'] as String?;
    if (token != null && token.isNotEmpty) {
      args.addAll(['--token', token]);
    } else if (sse) {
      stderr.writeln(
        '⚠ WARNING: serving SSE without --token — the endpoint is '
        'unauthenticated/open to any client that can reach it.',
      );
      stderr.writeln(
        '  Pass --token <token> to require Bearer auth for remote clients.',
      );
    }

    stderr.writeln('[zfa mcp serve] dart ${args.join(' ')}');
    final proc = await Process.start(
      'dart',
      args,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await proc.exitCode;
    if (code != 0) exit(code);
  }
}

/// `zfa mcp list-tools`
///
/// Subprocesses `dart run bin/mcp_server.dart --list-tools` and
/// prints the JSON tool definitions. Falls back to the codegen-side
/// PluginRegistry enumeration when no `bin/mcp_server.dart` exists.
class _ListToolsCommand extends Command<void> {
  @override
  String get name => 'list-tools';

  @override
  String get description =>
      'List the MCP tools the scaffolded server would expose (JSON)';

  _ListToolsCommand() {
    argParser.addFlag(
      'pretty',
      negatable: false,
      help: 'Pretty-print the JSON (default: compact)',
    );
  }

  @override
  Future<void> run() async {
    final binPath = 'bin/mcp_server.dart';
    final binFile = File(binPath);
    if (!await binFile.exists()) {
      stderr.writeln(
        '⚠ $binPath not found — falling back to the codegen MCP tool list '
        '(zuraffa_* capabilities). Run `zfa mcp scaffold` to scaffold the '
        'runtime server.',
      );
      await _printCodegenTools();
      return;
    }

    final result =
        await Process.run('dart', [
          'run',
          binPath,
          '--list-tools',
        ], stdoutEncoding: utf8).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            stderr.writeln(
              '❌ bin/mcp_server.dart --list-tools timed out after 30 seconds.',
            );
            exit(1);
          },
        );
    if (result.exitCode != 0) {
      stderr.writeln('❌ bin/mcp_server.dart --list-tools failed:');
      stderr.write(result.stderr);
      exit(result.exitCode);
    }

    final stdoutText = result.stdout.toString().trim();
    if (stdoutText.isEmpty) {
      stderr.writeln('❌ bin/mcp_server.dart emitted no output.');
      exit(1);
    }

    if (argResults!['pretty'] == true) {
      try {
        final parsed = jsonDecode(stdoutText);
        const encoder = JsonEncoder.withIndent('  ');
        print(encoder.convert(parsed));
      } on FormatException catch (e) {
        stderr.writeln('❌ Failed to parse JSON output: $e');
        stderr.writeln('Raw output:');
        stderr.writeln(stdoutText);
        exit(1);
      }
    } else {
      print(stdoutText);
    }
  }

  /// Emits the codegen-side capabilities in the same `{ "tools": [...] }`
  /// shape `zuraffa_mcp_server` would serve — the runtime server isn't
  /// scaffolded, so we list the codegen-only tools as a fallback.
  Future<void> _printCodegenTools() async {
    // Ensure the PluginRegistry is bootstrapped before iterating its
    // plugins, mirroring _scaffoldMcp's registry-loading behavior when
    // invoked outside the normal CliRunner._ensureInitialized() path.
    final registry = PluginRegistry.instance;
    if (registry.plugins.isEmpty) {
      final loader = PluginLoader(
        outputDir: 'lib/src',
        dryRun: false,
        force: false,
        verbose: false,
        config: PluginConfig.load(),
      );
      final loaded = loader.buildRegistry();
      for (final plugin in loaded.plugins) {
        if (!registry.plugins.any((p) => p.id == plugin.id)) {
          registry.register(plugin);
        }
      }
    }

    final tools = <Map<String, dynamic>>[];
    for (final plugin in registry.plugins) {
      for (final capability in plugin.capabilities) {
        tools.add({
          'name': 'zuraffa_${plugin.id}_${capability.name}',
          'description': capability.description,
          'inputSchema': capability.inputSchema,
        });
      }
    }
    final encoder = argResults!['pretty'] == true
        ? const JsonEncoder.withIndent('  ')
        : const JsonEncoder();
    print(encoder.convert({'tools': tools}));
  }
}
