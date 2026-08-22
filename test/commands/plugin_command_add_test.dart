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

String _zfaRoot = _safeRoot();
void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('zfa_plugin_test_');
    Directory.current = tmpDir.path;
    Directory('${tmpDir.path}/lib').createSync();
  });

  tearDown(() {
    // Restore CWD before deleting anything.
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

  group('PluginCommand.execute add', () {
    test('adds zuraffa_feature_example plugin to main.dart', () async {
      final mainFile = File('${tmpDir.path}/lib/main.dart');
      mainFile.writeAsStringSync("""
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';

void main() async {
  final engine = ZuraffaEngine()..register(CorePlugin());
  await engine.bootstrap();
  runApp(MyApp());
}
""");

      final cmd = PluginCommand();
      await cmd.execute(['add', 'zuraffa_feature_example']);

      final content = mainFile.readAsStringSync();
      expect(
        content,
        contains(
          "import 'package:zuraffa_feature_example/zuraffa_feature_example.dart';",
        ),
      );
      expect(content, contains('..register(ExamplePlugin())'));
    });

    test('adds plugin to existing cascade chain', () async {
      final mainFile = File('${tmpDir.path}/lib/main.dart');
      mainFile.writeAsStringSync("""
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';

void main() async {
  final engine = ZuraffaEngine()
    ..register(CorePlugin())
    ..register(AuthPlugin());
  await engine.bootstrap();
  runApp(MyApp());
}
""");

      final cmd = PluginCommand();
      await cmd.execute(['add', 'zuraffa_analytics']);

      final content = mainFile.readAsStringSync();
      expect(
        content,
        contains("import 'package:zuraffa_analytics/zuraffa_analytics.dart';"),
      );
      expect(content, contains('..register(AnalyticsPlugin())'));
    });

    test('does not duplicate already imported package', () async {
      final mainFile = File('${tmpDir.path}/lib/main.dart');
      mainFile.writeAsStringSync("""
import 'package:flutter/material.dart';
import 'package:zuraffa_payments/zuraffa_payments.dart';

void main() async {
  final engine = ZuraffaEngine()..register(PaymentsPlugin());
  await engine.bootstrap();
}
""");

      final cmd = PluginCommand();
      await cmd.execute(['add', 'zuraffa_payments']);

      final content = mainFile.readAsStringSync();
      // Should only have one import
      expect(
        'import'
            .allMatches(content)
            .where(
              (m) => content
                  .substring(m.start)
                  .startsWith("import 'package:zuraffa_payments"),
            )
            .length,
        1,
      );
    });
  });
}
