import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../core/xray_config.dart';
import 'xray_deck_command.dart';

/// CLI command for X-Ray mode management.
///
/// Usage:
/// ```
/// zfa xray enable   # activate X-Ray overlay on next app launch
/// zfa xray disable  # deactivate X-Ray overlay
/// zfa xray deck     # generate Control Deck registration
/// ```
class XrayCommand extends Command<void> {
  @override
  String get name => 'xray';

  @override
  String get description => 'X-Ray debug tools (overlay, control deck)';

  XrayCommand() {
    addSubcommand(_XrayEnableCommand());
    addSubcommand(_XrayDisableCommand());
    addSubcommand(_XrayStatusCommand());
    addSubcommand(XrayDeckCommand());
  }

  @override
  Future<void> run() async {
    print('Usage: zfa xray <enable|disable|status|deck>');
    print('  enable   Activate X-Ray overlay (debug/profile mode)');
    print('  disable  Deactivate X-Ray overlay');
    print('  status   Show current X-Ray configuration status');
    print('  deck     Generate Control Deck from annotations/YAML');
    print('');
    print('X-Ray bridge: the bridge server now runs inside the Flutter app');
    print('  process via zuraffa_flutter (XRayBridgeServer.start()). The');
    print('  standalone `zfa xray bridge` command was removed with the');
    print('  pure-Dart core split — the bridge needs the widget tree.');
  }

  static String get _configPath => xrayConfigPath;

  static Map<String, dynamic>? _readConfig() {
    final file = File(_configPath);
    if (!file.existsSync()) return null;
    try {
      final content = file.readAsStringSync();
      return json.decode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static void _writeConfig(Map<String, dynamic> config) {
    final configPath = _configPath;
    final dir = Directory(configPath.substring(0, configPath.lastIndexOf('/')));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File(configPath);
    file.writeAsStringSync(json.encode(config));
  }

  /// Check if the X-Ray config flag is set to enabled.
  static bool isConfigEnabled() {
    final config = _readConfig();
    return config?['enabled'] == true;
  }
}

class _XrayEnableCommand extends Command<void> {
  @override
  String get name => 'enable';

  @override
  String get description => 'Enable X-Ray overlay on next app launch';

  @override
  Future<void> run() async {
    XrayCommand._writeConfig({'enabled': true});
    print('✓ X-Ray overlay enabled.');
    print('  Restart your app, or activate via two-finger long press / shake.');
  }
}

class _XrayDisableCommand extends Command<void> {
  @override
  String get name => 'disable';

  @override
  String get description => 'Disable X-Ray overlay';

  @override
  Future<void> run() async {
    XrayCommand._writeConfig({'enabled': false});
    print('✓ X-Ray overlay disabled.');
  }
}

class _XrayStatusCommand extends Command<void> {
  @override
  String get name => 'status';

  @override
  String get description => 'Show current X-Ray configuration status';

  @override
  Future<void> run() async {
    final config = XrayCommand._readConfig();
    if (config == null) {
      print('X-Ray overlay: disabled');
    } else if (config['enabled'] == true) {
      print('X-Ray overlay: enabled');
    } else {
      print('X-Ray overlay: disabled');
    }
  }
}
