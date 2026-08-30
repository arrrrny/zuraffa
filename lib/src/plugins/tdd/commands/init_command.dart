/// `zfa tdd init` — idempotently ensure the Part-1 TDD environment exists.
library;

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../../cli/writers/tdd/dart_test_yaml_writer.dart';
import '../../../cli/writers/tdd/pubspec_dev_dependencies_patcher.dart';
import '../../../cli/writers/tdd/smoke_test_writer.dart';
import '../../../cli/writers/tdd/tdd_profile_writer.dart';
import 'verify_red_command.dart' show zfaTddWorkingDirectory;
import '../tdd_plugin.dart';

class InitCommand extends Command<void> {
  InitCommand(this.plugin);

  final TddPlugin plugin;

  @override
  String get name => 'init';

  @override
  String get description =>
      'Idempotently ensure the TDD baseline exists in the current project '
      '(test/, dart_test.yaml, .specify/memory/tdd-profile.md, testing '
      'dev_dependencies).';

  @override
  String get invocation => 'zfa tdd init';

  @override
  Future<void> run() async {
    final cwd =
        Zone.current[zfaTddWorkingDirectory] as String? ??
        Directory.current.path;
    final isFlutter = await _isFlutterProject(cwd);

    stdout.writeln(
      'zfa tdd init: ensuring TDD baseline in $cwd '
      '(${isFlutter ? "Flutter" : "Dart"})',
    );

    final failures = <String>[];

    try {
      final written = await TddProfileWriter(
        profile: isFlutter ? TddProfile.flutter : TddProfile.dart,
      ).write(cwd);
      stdout.writeln(
        written == null
            ? '   ✓ .specify/memory/tdd-profile.md (already present)'
            : '   ✓ .specify/memory/tdd-profile.md (created)',
      );
    } on StateError catch (e) {
      stdout.writeln('   ✗ .specify/memory/tdd-profile.md: $e');
      failures.add('tdd_profile_writer: $e');
    }

    try {
      final written = await const DartTestYamlWriter().write(cwd);
      stdout.writeln(
        written == null
            ? '   ✓ dart_test.yaml (already present)'
            : '   ✓ dart_test.yaml (created)',
      );
    } on StateError catch (e) {
      stdout.writeln('   ✗ dart_test.yaml: $e');
      failures.add('dart_test_yaml_writer: $e');
    }

    final appName = _deriveAppName(cwd);
    try {
      final written = await const SmokeTestWriter().write(cwd, appName);
      stdout.writeln(
        written == null
            ? '   ✓ test/bootstrap_smoke_test.dart (already present)'
            : '   ✓ test/bootstrap_smoke_test.dart (created)',
      );
    } on StateError catch (e) {
      stdout.writeln('   ✗ test/bootstrap_smoke_test.dart: $e');
      failures.add('smoke_test_writer: $e');
    }

    try {
      final added = await PubspecDevDependenciesPatcher(
        isFlutter: isFlutter,
      ).ensure(cwd);
      if (added.isEmpty) {
        stdout.writeln('   ✓ pubspec.yaml dev_dependencies (already complete)');
      } else {
        stdout.writeln(
          '   ✓ pubspec.yaml dev_dependencies (added: ${added.join(', ')})',
        );
      }
    } on FormatException catch (e) {
      stdout.writeln('   ✗ pubspec.yaml dev_dependencies: $e');
      failures.add('pubspec_dev_dependencies_patcher: $e');
    } on StateError catch (e) {
      stdout.writeln('   ✗ pubspec.yaml dev_dependencies: $e');
      failures.add('pubspec_dev_dependencies_patcher: $e');
    }

    if (failures.isNotEmpty) {
      stderr.writeln(
        '\nzfa tdd init: misfire — ${failures.length} writer(s) failed. '
        'Resolve the failures above and re-run `zfa tdd init`.',
      );
      for (final f in failures) {
        stderr.writeln('  - $f');
      }
      throw StateError('zfa tdd init: misfire');
    }

    stdout.writeln(
      '\nTDD baseline ensured. Run `flutter test` (or '
      '`dart test`) to confirm a green baseline.',
    );
  }

  Future<bool> _isFlutterProject(String cwd) async {
    final pubspec = File('$cwd/pubspec.yaml');
    if (!await pubspec.exists()) return false;
    final raw = await pubspec.readAsString();
    return raw.contains('environment:') &&
        (raw.contains('flutter') || raw.contains('sdk: flutter'));
  }

  String _deriveAppName(String cwd) {
    final base = cwd.split(Platform.pathSeparator).last;
    return base.isEmpty ? 'myapp' : base;
  }
}
