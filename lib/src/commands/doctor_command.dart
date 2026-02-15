import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../version.dart';

class DoctorCommand extends Command {
  @override
  final String name = 'doctor';

  @override
  final String description = 'Show information about the installed tooling.';

  static const _timeout = Duration(seconds: 10);

  void _print(String message) {
    print(message);
  }

  @override
  Future<void> run() async {
    _print('🩺 Zuraffa Doctor\n');

    _print('Zuraffa CLI: v$version');

    try {
      final dartResult = await Process.run('dart', [
        '--version',
      ]).timeout(_timeout);
      final dartOutput = dartResult.stdout.toString().trim().isNotEmpty
          ? dartResult.stdout.toString().trim()
          : dartResult.stderr.toString().trim();
      _print('Dart: $dartOutput');
    } on TimeoutException {
      _print('Dart: ⚠️ Timeout');
    } catch (e) {
      _print('Dart: ❌ Not found');
    }

    try {
      final flutterResult = await Process.run('flutter', [
        '--version',
      ]).timeout(_timeout);
      if (flutterResult.exitCode == 0) {
        final flutterOutput = flutterResult.stderr
            .toString()
            .split('\n')
            .first
            .trim();
        if (flutterOutput.isEmpty) {
          _print('Flutter: ✅ Installed');
        } else {
          _print('Flutter: $flutterOutput');
        }
      } else {
        _print('Flutter: ⚠️ Not found (exit code ${flutterResult.exitCode})');
      }
    } on TimeoutException {
      _print('Flutter: ⚠️ Timeout (this is fine if you are only using Dart)');
    } catch (e) {
      _print('Flutter: ⚠️ Not found (this is fine if you are only using Dart)');
    }

    _print('');

    final configFile = File('.zfa.json');
    if (configFile.existsSync()) {
      _print('Configuration: ✅ Found .zfa.json');
    } else {
      _print(
        'Configuration: ⚠️ No .zfa.json found (run "zfa config init" to create one)',
      );
    }

    final pubspecFile = File('pubspec.yaml');
    if (pubspecFile.existsSync()) {
      _print('Project: ✅ Found pubspec.yaml');

      try {
        final content = await pubspecFile.readAsString();
        if (content.contains('zuraffa:')) {
          _print('Dependencies: ✅ Zuraffa package found');
        } else {
          _print('Dependencies: ⚠️ Zuraffa package not found in pubspec.yaml');
        }

        if (content.contains('zorphy_annotation:')) {
          _print('              ✅ zorphy_annotation found');
        } else {
          _print(
            '              ⚠️ zorphy_annotation not found - required for entity generation',
          );
          _print('                 Add: dart pub add zorphy_annotation');
        }
      } catch (e) {
        _print('Dependencies: ❌ Could not read pubspec.yaml');
      }
    } else {
      _print('Project: ❌ No pubspec.yaml found');
    }

    _print('');

    try {
      final zorphyResult = await Process.run('dart', [
        'pub',
        'global',
        'list',
      ]).timeout(_timeout);
      final output = zorphyResult.stdout.toString();
      if (output.contains('zorphy')) {
        final match = RegExp(r'zorphy\s+(\S+)').firstMatch(output);
        final zorphyVersion = match?.group(1) ?? 'unknown';
        _print('zorphy CLI: ✅ v$zorphyVersion (globally installed)');
      } else {
        _print('zorphy CLI: ℹ️  Not installed globally (optional)');
        _print('             zfa entity commands work without it (bundled)');
        _print(
          '             For standalone use: dart pub global activate zorphy',
        );
      }
    } on TimeoutException {
      _print('zorphy CLI: ⚠️ Timeout checking global packages');
    } catch (e) {
      _print('zorphy CLI: ❌ Could not check: $e');
    }

    _print('');
    await _checkDeadCode();
  }

  Future<void> _checkDeadCode() async {
    _print('Dead Code Analysis: ⏳ Running dart analyze...');

    // Count entities for dynamic timeout (min 60s, max 120s)
    final entitiesDir = Directory('lib/src/domain/entities');
    int entityCount = 0;
    if (await entitiesDir.exists()) {
      entityCount = await entitiesDir
          .list()
          .where((e) => e is Directory)
          .length;
    }
    final timeout = Duration(seconds: (entityCount * 5 + 60).clamp(60, 120));

    try {
      final result = await Process.run('dart', ['analyze']).timeout(timeout);
      final output = result.stdout.toString();

      if (output.contains('Dead code') || output.contains('dead_code')) {
        _print('Dead Code Analysis: ⚠️ Found dead code issues');

        final lines = output.split('\n');
        final deadCodeLines = lines
            .where(
              (line) =>
                  line.contains('Dead code') || line.contains('dead_code'),
            )
            .take(5)
            .toList();

        for (final line in deadCodeLines) {
          _print('  $line');
        }

        if (deadCodeLines.length <
            lines.where((l) => l.contains('dead_code')).length) {
          _print('  ... and more.');
        }
      } else {
        _print('Dead Code Analysis: ✅ No dead code found');
      }
    } on TimeoutException {
      _print('Dead Code Analysis: ⚠️ Timeout (skipped)');
    } catch (e) {
      _print('Dead Code Analysis: ❌ Failed to run analysis: $e');
    }
  }
}
