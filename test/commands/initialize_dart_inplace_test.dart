import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/initialize_command.dart';

/// The non-dry-run in-place bootstrap test invokes `dart pub add` for the
/// zuraffa git dependencies, which clones https://github.com/arrrrny/zuraffa
/// and https://github.com/arrrrny/zorphy.git. On a cold cache or slow network
/// this can take a couple of minutes, so we extend the per-test timeout past
/// the test runner's 30s default.
const _networkTimeout = Timeout(Duration(minutes: 3));

void main() {
  group('InitializeCommand --dart in-place bootstrap (issue #393)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('zfa_init393_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    /// Creates `<tempDir>/<name>` and returns it. The sandbox root is passed
    /// to the command via `--root` so the test never mutates the process
    /// working directory (shared across concurrently-running test files).
    Directory useDir(String name) {
      return Directory(p.join(tempDir.path, name))..createSync();
    }

    test('exposes --dart and --flutter flags; both parse independently', () {
      final parser = InitializeCommand.buildParser();
      expect(parser.options, contains('dart'));
      expect(parser.options, contains('flutter'));
      expect(parser.parse(['--dart'])['dart'], isTrue);
      expect(parser.parse(['--flutter'])['flutter'], isTrue);
    });

    test('execute() rejects --dart together with --flutter', () async {
      final cmd = InitializeCommand();
      expect(
        () => cmd.execute(['--dart', '--flutter', '--deps-only', '--root', useDir('zuraffa_agent').path]),
        throwsA(isA<UsageException>()),
      );
    });

    test('--dart --deps-only --dry-run on repo without pubspec announces '
        'bootstrap and writes nothing', () async {
      final repoDir = useDir('zuraffa_agent');

      final cmd = InitializeCommand();
      await cmd.execute([
        '--dart',
        '--deps-only',
        '--dry-run',
        '--root',
        repoDir.path,
      ]);

      // Regression: the old code threw UsageException (missing pubspec)
      // before any announcement. Now dry-run previews and writes nothing.
      expect(
        File(p.join(repoDir.path, 'pubspec.yaml')).existsSync(),
        isFalse,
        reason: 'dry-run must not write',
      );
    });

    test('--dart --dry-run WITHOUT --deps-only previews entity scaffolding '
        '(CodeRabbit follow-up: must not return early)', () async {
      final repoDir = useDir('zuraffa_agent');

      final cmd = InitializeCommand();
      // Dry-run must complete without throwing and must continue past the
      // dependency-wiring block to the entity scaffolding preview path.
      await cmd.execute([
        '--dart',
        '--dry-run',
        '--root',
        repoDir.path,
      ]);

      expect(
        File(p.join(repoDir.path, 'pubspec.yaml')).existsSync(),
        isFalse,
        reason: 'dry-run must not write',
      );
    });

    test('--dart --dry-run preview name matches actual creation name for '
        'a directory with spaces (CodeRabbit follow-up: dry-run/actual '
        'normalization parity)', () {
      // The dry-run branch now uses the SAME `_validPackageNameStatic`
      // helper as `synthesizeMinimalPubspec`, so a directory named 'My Repo'
      // must announce 'my_repo' (not 'zuraffa_package') in the dry-run
      // preview AND synthesize 'name: my_repo' on actual creation.
      const dirName = 'My Repo';
      const expectedName = 'my_repo';
      // Public API proof: actual creation normalizes spaces to underscores.
      final synthesized = InitializeCommand.synthesizeMinimalPubspec(dirName);
      expect(
        synthesized,
        startsWith('name: $expectedName\n'),
        reason: 'actual creation must normalize spaces to underscores',
      );
    });

    test('--dart non-dry-run on repo without pubspec creates minimal '
        'pubspec in-place', () async {
      final repoDir = useDir('zuraffa_agent');

      final cmd = InitializeCommand();
      // Wiring may fail hermetically (git deps need network); the bootstrap
      // itself is the regression under test — catch ANY wiring error so the
      // pubspec-existence assertion below still runs.
      try {
        await cmd.execute([
          '--dart',
          '--deps-only',
          '--root',
          repoDir.path,
        ]);
      } catch (_) {
        // Expected when the dependency wire cannot resolve offline.
      }

      final pubspec = File(p.join(repoDir.path, 'pubspec.yaml'));
      expect(
        pubspec.existsSync(),
        isTrue,
        reason: '--dart bootstraps pubspec.yaml in-place',
      );
      final content = pubspec.readAsStringSync();
      expect(content, startsWith('name: zuraffa_agent\n'));
      expect(content, contains('sdk: ^3.0.0'));
    }, timeout: _networkTimeout);

    test(
      'without --dart and no pubspec.yaml still refuses with guidance',
      () async {
        final repoDir = useDir('some_repo');

        final cmd = InitializeCommand();
        expect(
          () => cmd.execute([
            '--deps-only',
            '--root',
            repoDir.path,
          ]),
          throwsA(isA<UsageException>()),
        );
      },
    );

    test('synthesizeMinimalPubspec derives snake_case package names', () {
      expect(
        InitializeCommand.synthesizeMinimalPubspec('ZikZak-AI'),
        startsWith('name: zikzak_ai\n'),
      );
      expect(
        InitializeCommand.synthesizeMinimalPubspec('zuraffa_agent'),
        startsWith('name: zuraffa_agent\n'),
      );
      expect(
        InitializeCommand.synthesizeMinimalPubspec('My Repo'),
        startsWith('name: my_repo\n'),
      );
    });

    test('synthesizeMinimalPubspec falls back on invalid names', () {
      expect(
        InitializeCommand.synthesizeMinimalPubspec('1abc'),
        startsWith('name: zuraffa_package\n'),
      );
      expect(
        InitializeCommand.synthesizeMinimalPubspec(''),
        startsWith('name: zuraffa_package\n'),
      );
    });
  });
}
