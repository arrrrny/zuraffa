// X-Ray Bridge CLI command.
//
// Usage:
//   zfa xray bridge              Start the X-Ray bridge (default port 8471)
//   zfa xray bridge --port=9000  Custom port
//   zfa xray bridge --token=secret   Require Bearer token for auth
//   zfa xray bridge --remote     Bind to 0.0.0.0 instead of localhost

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../presentation/xray/xray_bridge_server.dart';
import '../presentation/xray/xray_mode.dart';

/// CLI subcommand for the X-Ray bridge server.
class XrayBridgeCommand extends Command<void> {
  @override
  String get name => 'bridge';

  @override
  String get description =>
      'Start the X-Ray bridge server for AI agent inspection';

  XrayBridgeCommand() {
    argParser.addOption(
      'port',
      abbr: 'p',
      help: 'Port to bind the bridge server (default: 8471)',
      defaultsTo: '8471',
    );
    argParser.addOption(
      'token',
      abbr: 't',
      help: 'Bearer token for remote agent authentication',
    );
    argParser.addFlag(
      'remote',
      abbr: 'r',
      help: 'Bind to 0.0.0.0 instead of localhost (requires --token)',
      negatable: false,
    );
  }

  @override
  Future<void> run() async {
    final portStr = argResults!['port'] as String;
    final port = int.tryParse(portStr) ?? XRayBridgeServer.defaultPort;
    final token = argResults!['token'] as String?;
    final remote = argResults!['remote'] as bool;
    final localhostOnly = !remote;

    if (remote && token == null) {
      print('Error: --remote requires --token for authentication.');
      print('Use --token=<secret> to set a Bearer token.');
      return;
    }

    // Check if X-Ray mode is enabled
    final configFile = File(XRayMode.configPath);
    bool xrayEnabled = false;
    if (configFile.existsSync()) {
      try {
        final content = configFile.readAsStringSync();
        final config = jsonDecode(content) as Map<String, dynamic>;
        xrayEnabled = config['enabled'] == true;
      } catch (_) {
        // Ignore malformed config
      }
    }

    if (!xrayEnabled) {
      print('X-Ray mode is not enabled. The bridge will still start,');
      print('but /xray/tree will return 503 until X-Ray is activated.');
      print('Run: zfa xray enable');
      print('');
    }

    final server = XRayBridgeServer(
      port: port,
      authToken: token,
      localhostOnly: localhostOnly,
    );

    // Handle SIGINT / SIGTERM for graceful shutdown
    final completer = Completer<void>();
    ProcessSignal.sigint.watch().listen((_) {
      print('');
      print('Shutting down X-Ray bridge...');
      server.stop().then((_) {
        completer.complete();
        exit(0);
      });
    });

    ProcessSignal.sigterm.watch().listen((_) {
      server.stop().then((_) {
        completer.complete();
        exit(0);
      });
    });

    final actualPort = await server.start();
    if (actualPort < 0) {
      print('X-Ray bridge cannot start in release mode.');
      return;
    }

    final bindAddr = localhostOnly ? '127.0.0.1' : '0.0.0.0';
    print('');
    print('  X-Ray Bridge running');
    print('  ─────────────────────────────');
    print('  Endpoints:');
    print('    GET  http://$bindAddr:$actualPort/xray/tree');
    print('    POST http://$bindAddr:$actualPort/xray/action');
    print('    POST http://$bindAddr:$actualPort/xray/control-deck');
    print('    WS   ws://$bindAddr:$actualPort/xray/ws');
    if (token != null) {
      print('  Auth: Bearer token required');
    } else {
      print('  Auth: localhost-only (no token)');
    }
    print('');
    print('  Press Ctrl+C to stop.');
    print('');

    // Keep alive
    await completer.future;
  }
}
