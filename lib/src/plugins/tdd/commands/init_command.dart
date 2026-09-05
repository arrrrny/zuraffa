/// `zfa tdd init` — idempotently ensure the Part-1 TDD environment exists.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../../cli/writers/tdd/app_module_writer.dart';
import '../../../cli/writers/tdd/dart_test_yaml_writer.dart';
import '../../../cli/writers/tdd/pubspec_dev_dependencies_patcher.dart';
import '../../../cli/writers/tdd/smoke_test_writer.dart';
import '../../../cli/writers/tdd/tdd_profile_writer.dart';
import '../services/verdict_emitter.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class InitCommand extends Command<void> {
  InitCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root to initialize the TDD baseline in. When omitted, the '
          'current working directory is used. Tests pass the temp fixture '
          'root here instead of mutating Directory.current.',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      help:
          'Overwrite existing baseline files whose content differs from what '
          'the writers would generate. Without --force, `zfa tdd init` is '
          'strictly idempotent and refuses to clobber a file that was hand '
          'edited or generated under a different profile (e.g. Dart vs '
          'Flutter). With --force, those files are replaced in place.',
      negatable: false,
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

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
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    // Prefer an explicit --project root so the command never depends on the
    // process-global Directory.current. Falls back to CWD for real CLI use.
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final isFlutter = await _isFlutterProject(cwd);
    final force = argResults?['force'] == true;

    stdout.writeln(
      'zfa tdd init: ensuring TDD baseline in $cwd '
      '(${isFlutter ? "Flutter" : "Dart"})'
      '${force ? " (force: overwrite on content mismatch)" : ""}',
    );

    final failures = <String>[];

    try {
      final written = await TddProfileWriter(
        profile: isFlutter ? TddProfile.flutter : TddProfile.dart,
      ).write(cwd, force: force);
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
      // Issue #664: gate the smoke-test flavor behind the project flavor —
      // a pure Dart package must not receive `package:flutter_test` imports
      // it cannot resolve.
      final written = await SmokeTestWriter(
        isFlutter: isFlutter,
      ).write(cwd, appName);
      stdout.writeln(
        written == null
            ? '   ✓ test/bootstrap_smoke_test.dart (already present)'
            : '   ✓ test/bootstrap_smoke_test.dart (created)',
      );
    } on StateError catch (e) {
      stdout.writeln('   ✗ test/bootstrap_smoke_test.dart: $e');
      failures.add('smoke_test_writer: $e');
    }

    // Issue #626: in a Flutter project the smoke test asserts the
    // zfa-generated app module (<AppName>Container in lib/app.dart), so
    // the baseline is only green when the module exists. Skip-if-exists —
    // existing user content is never touched (FR-008).
    if (isFlutter) {
      try {
        final written = await const AppModuleWriter(
          isFlutter: true,
        ).write(cwd, appName);
        stdout.writeln(
          written == null
              ? '   ✓ lib/app.dart (already present)'
              : '   ✓ lib/app.dart (created)',
        );
      } on StateError catch (e) {
        stdout.writeln('   ✗ lib/app.dart: $e');
        failures.add('app_module_writer: $e');
      }
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
    _verdict.details['failures'] = 0;
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
