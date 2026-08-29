import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/xray_config.dart';
import 'xray_deck_command.dart';
import 'xray_mock_command.dart';

/// CLI command for X-Ray mode management.
///
/// Usage:
/// ```
/// zfa xray enable   # activate X-Ray overlay on next app launch
/// zfa xray disable  # deactivate X-Ray overlay
/// zfa xray status   # show current X-Ray configuration status
///                    # (add --json for machine-readable output)
/// zfa xray deck     # generate Control Deck registration
/// zfa xray mock     # scaffold @XRayMock annotations on usecases
/// ```
///
/// Track 4.2 — Spec 036 (issue #181):
///   - `status --json` emits `{"enabled": <bool>, "release_mode": <bool>}`.
///   - `enable` / `disable` are no-ops in release mode (FR-007 / SC-004).
///   - `--root` flag mirrors `zfa xray deck --root` so subcommands can
///     be invoked hermetically against a sandbox.
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
    addSubcommand(XrayMockCommand());
  }

  @override
  Future<void> run() async {
    print('Usage: zfa xray <enable|disable|status|deck|mock>');
    print('  enable   Activate X-Ray overlay (debug/profile mode)');
    print('  disable  Deactivate X-Ray overlay');
    print('  status   Show current X-Ray configuration status');
    print('           (--json flag for machine-readable output)');
    print('  deck     Generate Control Deck from annotations/YAML');
    print('  mock     Scaffold @XRayMock annotations on usecases');
    print('');
    print('X-Ray bridge: the bridge server now runs inside the Flutter app');
    print('  process via zuraffa_flutter (XRayBridgeServer.start()). The');
    print('  standalone `zfa xray bridge` command was removed with the');
    print('  pure-Dart core split — the bridge needs the widget tree.');
  }

  /// Check if the X-Ray config flag is set to enabled.
  static bool isConfigEnabled() {
    final config = _readConfig(null);
    return config?['enabled'] == true;
  }

  static Map<String, dynamic>? _readConfig(String? root) {
    final file = File(xrayConfigPathFor(root));
    if (!file.existsSync()) return null;
    try {
      final content = file.readAsStringSync();
      return json.decode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static void _writeConfig(String? root, Map<String, dynamic> config) {
    final configPath = xrayConfigPathFor(root);
    final dir = Directory(p.dirname(configPath));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File(configPath);
    file.writeAsStringSync(json.encode(config));
  }
}

class _XrayEnableCommand extends Command<void> {
  @override
  String get name => 'enable';

  @override
  String get description => 'Enable X-Ray overlay on next app launch';

  _XrayEnableCommand() {
    argParser.addOption(
      'root',
      abbr: 'r',
      help: 'Project root directory (defaults to current directory).',
    );
  }

  @override
  Future<void> run() async {
    final root = argResults?['root'] as String?;
    if (kXrayReleaseMode) {
      // Release-mode strip: silent no-op (FR-007 / SC-004).
      return;
    }
    XrayCommand._writeConfig(root, {'enabled': true});
    print('✓ X-Ray overlay enabled.');
    print('  Restart your app, or activate via two-finger long press / shake.');
  }
}

class _XrayDisableCommand extends Command<void> {
  @override
  String get name => 'disable';

  @override
  String get description => 'Disable X-Ray overlay';

  _XrayDisableCommand() {
    argParser.addOption(
      'root',
      abbr: 'r',
      help: 'Project root directory (defaults to current directory).',
    );
  }

  @override
  Future<void> run() async {
    final root = argResults?['root'] as String?;
    if (kXrayReleaseMode) {
      // Release-mode strip: silent no-op (FR-007 / SC-004).
      return;
    }
    XrayCommand._writeConfig(root, {'enabled': false});
    print('✓ X-Ray overlay disabled.');
  }
}

class _XrayStatusCommand extends Command<void> {
  @override
  String get name => 'status';

  @override
  String get description => 'Show current X-Ray configuration status';

  _XrayStatusCommand() {
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Emit machine-readable JSON (consumed by the overlay UI and CI).',
    );
    argParser.addOption(
      'root',
      abbr: 'r',
      help: 'Project root directory (defaults to current directory).',
    );
  }

  @override
  Future<void> run() async {
    final root = argResults?['root'] as String?;
    final asJson = argResults?['json'] as bool? ?? false;
    final config = XrayCommand._readConfig(root);
    final enabled = config?['enabled'] == true;

    if (asJson) {
      // Machine-readable JSON for the overlay UI + CI + the MCP bridge.
      final jsonMap = {
        'enabled': enabled && !kXrayReleaseMode,
        'release_mode': kXrayReleaseMode,
      };
      print(json.encode(jsonMap));
      return;
    }

    if (kXrayReleaseMode) {
      print('X-Ray overlay: disabled (release mode)');
    } else if (enabled) {
      print('X-Ray overlay: enabled');
    } else {
      print('X-Ray overlay: disabled');
    }
  }
}
