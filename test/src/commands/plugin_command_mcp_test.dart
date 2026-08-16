import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/commands/plugin_command.dart';

/// Resolve a known-good directory via Platform.script.
/// Immune to CWD changes by other tests.
String _safeRoot() {
  try {
    var dir = File(Platform.script.toFilePath()).parent;
    for (var i = 0; i < 10; i++) {
      final ps = File('${dir.path}/pubspec.yaml');
      if (ps.existsSync()) {
        final c = ps.readAsStringSync();
        if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(c)) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {}
  return Directory.systemTemp.path;
}

final _zfaRoot = _safeRoot();

void main() {
  group('PluginCommand.execute mcp', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('zfa_plugin_mcp_test_');
      Directory.current = tmpDir.path;
      File('${tmpDir.path}/pubspec.yaml').writeAsStringSync('''
name: zfa_mcp_alias_test
environment:
  sdk: ^3.11.0
''');
    });

    tearDown(() {
      try {
        Directory.current = Directory(_zfaRoot);
      } catch (_) {
        try {
          Directory.current = Directory.systemTemp;
        } catch (_) {}
      }
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('mcp alias with --dry-run previews scaffold without writing files', () async {
      final cmd = PluginCommand();
      await cmd.execute(['mcp', '--dry-run']);

      // No files should have been written because --dry-run was forwarded.
      expect(
        File('${tmpDir.path}/lib/src/mcp/tools.dart').existsSync(),
        isFalse,
      );
      expect(
        File('${tmpDir.path}/bin/mcp_server.dart').existsSync(),
        isFalse,
      );
    });

    test('mcp alias with --force writes the scaffolded files', () async {
      final cmd = PluginCommand();
      await cmd.execute(['mcp', '--force']);

      expect(
        File('${tmpDir.path}/lib/src/mcp/tools.dart').existsSync(),
        isTrue,
      );
      expect(
        File('${tmpDir.path}/bin/mcp_server.dart').existsSync(),
        isTrue,
      );
    });
  });
}
