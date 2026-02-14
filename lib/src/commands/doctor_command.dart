import 'dart:io';
import 'package:args/command_runner.dart';
import '../version.dart';

class DoctorCommand extends Command {
  @override
  final String name = 'doctor';

  @override
  final String description = 'Show information about the installed tooling.';

  @override
  Future<void> run() async {
    print('🩺 Zuraffa Doctor\n');

    // Check Zuraffa version
    print('Zuraffa CLI: v$version');

    // Check Dart version
    try {
      final dartResult = await Process.run('dart', ['--version']);
      // dart --version prints to stderr
      final dartOutput = dartResult.stdout.toString().trim().isNotEmpty
          ? dartResult.stdout.toString().trim()
          : dartResult.stderr.toString().trim();
      print('Dart: $dartOutput');
    } catch (e) {
      print('Dart: ❌ Not found');
    }

    // Check Flutter version
    try {
      final flutterResult = await Process.run('flutter', ['--version']);
      if (flutterResult.exitCode == 0) {
        final flutterOutput = flutterResult.stdout.toString().split('\n').first;
        print('Flutter: $flutterOutput');
      } else {
        print('Flutter: ⚠️ Not found (exit code ${flutterResult.exitCode})');
      }
    } catch (e) {
      print('Flutter: ⚠️ Not found (this is fine if you are only using Dart)');
    }

    print(''); // Spacer

    // Check Project Config
    final configFile = File('.zfa.json');
    if (configFile.existsSync()) {
      print('Configuration: ✅ Found .zfa.json');
    } else {
      print(
        'Configuration: ⚠️ No .zfa.json found (run "zfa config init" to create one)',
      );
    }

    // Check pubspec.yaml
    final pubspecFile = File('pubspec.yaml');
    if (pubspecFile.existsSync()) {
      print('Project: ✅ Found pubspec.yaml');

      // Check if zuraffa is in dependencies
      try {
        final content = await pubspecFile.readAsString();
        if (content.contains('zuraffa:')) {
          print('Dependencies: ✅ Zuraffa package found');
        } else {
          print('Dependencies: ⚠️ Zuraffa package not found in pubspec.yaml');
        }
      } catch (e) {
        print('Dependencies: ❌ Could not read pubspec.yaml');
      }
    } else {
      print('Project: ❌ No pubspec.yaml found');
    }

    print(''); // Spacer
    await _checkDeadCode();
  }

  Future<void> _checkDeadCode() async {
    stdout.write('Dead Code Analysis: ⏳ Running dart analyze...');
    try {
      final result = await Process.run('dart', ['analyze']);
      final output = result.stdout.toString();

      // Clear the loading message (CR)
      stdout.write('\r');

      if (output.contains('Dead code') || output.contains('dead_code')) {
        print('Dead Code Analysis: ⚠️ Found dead code issues');

        final lines = output.split('\n');
        final deadCodeLines = lines
            .where(
              (line) =>
                  line.contains('Dead code') || line.contains('dead_code'),
            )
            .take(5)
            .toList(); // Show top 5

        for (final line in deadCodeLines) {
          print('  $line');
        }

        if (deadCodeLines.length <
            lines.where((l) => l.contains('dead_code')).length) {
          print('  ... and more.');
        }
      } else {
        print('Dead Code Analysis: ✅ No dead code found');
      }
    } catch (e) {
      stdout.write('\r');
      print('Dead Code Analysis: ❌ Failed to run analysis: $e');
    }
  }
}
