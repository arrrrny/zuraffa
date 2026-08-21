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
