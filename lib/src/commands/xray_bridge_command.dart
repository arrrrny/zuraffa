// X-Ray Bridge CLI command.
//
// The bridge server requires Flutter (it communicates with the widget tree).
// This command is retained in zuraffa so `zfa xray bridge` exists in the CLI,
// but it prints a guidance message directing users to zuraffa_flutter.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

/// CLI subcommand for the X-Ray bridge server.
class XrayBridgeCommand extends Command<void> {
  @override
  String get name => 'bridge';

  @override
  String get description =>
      'Start the X-Ray bridge server for AI agent inspection';

  static const int _defaultPort = 8471;

  XrayBridgeCommand() {
    argParser.addOption(
      'port',
      abbr: 'p',
      help: 'Port to bind the bridge server (default: $_defaultPort)',
      defaultsTo: '$_defaultPort',
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
    final port = int.tryParse(portStr);

    if (port == null) {
      throw UsageException(
        'Invalid port: "$portStr" is not a valid integer.',
        usage,
      );
    }

    if (port < 1 || port > 65535) {
      throw UsageException(
        'Port must be between 1 and 65535, got: $port',
        usage,
      );
    }

    final token = argResults!['token'] as String?;
    final remote = argResults!['remote'] as bool;

    if (remote && token == null) {
      throw UsageException(
        '--remote requires --token for authentication.',
        usage,
      );
    }

    // Check if X-Ray is enabled via config file.
    const configPath = '.dart_tool/zuraffa/xray.json';
    final configFile = File(configPath);
    bool xrayEnabled = false;
    if (configFile.existsSync()) {
      try {
        final content = configFile.readAsStringSync();
        final config = jsonDecode(content) as Map<String, dynamic>;
        xrayEnabled = config['enabled'] == true;
      } catch (_) {
        // Ignore malformed config.
      }
    }

    if (!xrayEnabled) {
      print('X-Ray mode is not enabled.');
      print('Run: zfa xray enable');
      print('');
    }

    // The bridge server communicates with the Flutter widget tree and
    // therefore lives in the zuraffa_flutter package.
    // To start it, call XRayBridgeServer.start() from your Flutter app
    // after registering ZuraffaFlutterPlugin.
    print('The X-Ray bridge server runs inside the Flutter app process.');
    print('Make sure your app depends on zuraffa_flutter and calls:');
    print('');
    print('  XRayBridgeServer(port: $port).start();');
    print('');
    print('The bridge will be available at:');
    final bindAddr = remote ? '0.0.0.0' : '127.0.0.1';
    print('  GET  http://$bindAddr:$port/xray/tree');
    print('  POST http://$bindAddr:$port/xray/action');
    print('  POST http://$bindAddr:$port/xray/control-deck');
    print('  WS   ws://$bindAddr:$port/xray/ws');
    if (token != null) {
      print('  Auth: Bearer token required');
    } else {
      print('  Auth: localhost-only (no token)');
    }
  }
}
