import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli/plugin_loader.dart';
import '../core/plugin_system/plugin_registry.dart';
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

/// `zfa mcp replay <session-file>` (issue #1358) — re-executes a
/// committed JSON scenario of MCP tool calls against the REAL
/// scaffolded `bin/mcp_server.dart` over the stdio JSON-RPC wire.
/// The scenario file IS the recorded session (committed, diffable):
/// `{"session": "<name>", "calls": [{"tool": "...", "arguments": {...},
/// "expect_contains": "..."}]}`. One verdict line per call (`ok` /
/// `missing-tool` / `mismatch` / `error`), a summary line, and a
/// proof-carrying receipt under `.zfa/receipts/`. Exit 0 iff every
/// call is ok.
class _ReplayCommand extends Command<void> {
  @override
  String get name => 'replay';

  @override
  String get description =>
      'Re-execute a committed MCP tool-call scenario (JSON) against the '
      'scaffolded server and write a verdict receipt (issue #1358)';

  @override
  String get invocation =>
      'zfa mcp replay <session-file> [--timeout <seconds>]';

  _ReplayCommand() {
    argParser.addOption(
      'timeout',
      help: 'Deadline for the whole replay in seconds.',
      defaultsTo: '120',
    );
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      print('❌ Usage: $invocation');
      exitCode = 2;
      return;
    }
    final scenarioPath = rest.first;
    final scenarioFile = File(scenarioPath);
    if (!await scenarioFile.exists()) {
      print('❌ Usage: $invocation');
      print('   scenario file not found: $scenarioPath');
      exitCode = 2;
      return;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(await scenarioFile.readAsString());
    } on FormatException catch (e) {
      print('❌ Malformed scenario file: $scenarioPath (${e.message})');
      exitCode = 1;
      return;
    }
    if (decoded is! Map<String, dynamic>) {
      print('❌ Malformed scenario file: $scenarioPath (not an object)');
      exitCode = 1;
      return;
    }
    final sessionName = (decoded['session'] as String?) ?? 'session';
    final rawCalls = decoded['calls'];
    if (rawCalls is! List) {
      print(
        '❌ Malformed scenario file: $scenarioPath ("calls" must be a list)',
      );
      exitCode = 1;
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

    final process = await Process.start('dart', ['run', binPath]);

    final responses = <int, Completer<Map<String, dynamic>>>{};
    final verdictLines = <Map<String, dynamic>>[];
    var nextId = 0;

    final stdoutLines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final subscription = stdoutLines.listen((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return;
      try {
        final message = jsonDecode(trimmed) as Map<String, dynamic>;
        final id = message['id'];
        if (id is int) {
          responses.remove(id)?.complete(message);
        }
      } on FormatException {
        // Non-JSON stdout lines (banner noise) are ignored.
      }
    });

    Future<Map<String, dynamic>?> request(
      String method,
      Map<String, dynamic>? params,
    ) async {
      final id = ++nextId;
      final completer = Completer<Map<String, dynamic>>();
      responses[id] = completer;
      process.stdin.writeln(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'method': method,
          'params': ?params,
        }),
      );
      await process.stdin.flush();
      return completer.future.timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () => <String, dynamic>{},
      );
    }

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
      final response = await request('tools/call', {
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
      final initialize = await request('initialize', {
        'protocolVersion': '2024-11-05',
        'capabilities': {},
        'clientInfo': {'name': 'zfa-mcp-replay', 'version': '1.0.0'},
      });
      if (initialize == null) {
        print(
          '❌ The scaffolded server did not answer initialize within '
          '$timeoutSeconds seconds.',
        );
        process.kill();
        exitCode = 1;
        return;
      }
      process.stdin.writeln(
        jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
      );
      await process.stdin.flush();

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
      subscription.cancel();
      process.kill();
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
      '${const JsonEncoder.withIndent('  ').convert({'command': 'zfa mcp replay', 'session': sessionName, 'scenario': scenarioPath, 'at': DateTime.now().toUtc().toIso8601String(), 'calls': verdictLines, 'ok': ok, 'failed': failed, 'passed': failed == 0})}\n',
    );
    print('   receipt: ${receiptFile.path}');

    exitCode = failed == 0 ? 0 : 1;
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
