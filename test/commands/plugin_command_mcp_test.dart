import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/commands/plugin_command.dart';

void main() {
  group('PluginCommand.execute mcp', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('zfa_plugin_mcp_test_');
      File('${tmpDir.path}/pubspec.yaml').writeAsStringSync('''
name: zfa_mcp_alias_test
environment:
  sdk: ^3.11.0
''');
    });

    tearDown(() {
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test(
      'mcp alias with --dry-run previews scaffold without writing files',
      () async {
        final cmd = PluginCommand();
        await cmd.execute(['mcp', '--dry-run', '--root', tmpDir.path]);

        // No files should have been written because --dry-run was forwarded.
        expect(
          File('${tmpDir.path}/lib/src/mcp/tools.dart').existsSync(),
          isFalse,
        );
        expect(
          File('${tmpDir.path}/bin/mcp_server.dart').existsSync(),
          isFalse,
        );
      },
    );

    test('mcp alias with --force writes the scaffolded files', () async {
      final cmd = PluginCommand();
      await cmd.execute(['mcp', '--force', '--root', tmpDir.path]);

      expect(
        File('${tmpDir.path}/lib/src/mcp/tools.dart').existsSync(),
        isTrue,
      );
      expect(File('${tmpDir.path}/bin/mcp_server.dart').existsSync(), isTrue);
    });
  });
}
