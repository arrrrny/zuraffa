import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/initialize_command.dart';

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

    Directory useDir(String name) {
      final repoDir = Directory('${tempDir.path}/$name')..createSync();
      final originalCwd = Directory.current;
      Directory.current = repoDir;
      addTearDown(() => Directory.current = originalCwd);
      return repoDir;
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
        () => cmd.execute(['--dart', '--flutter', '--deps-only']),
        throwsA(isA<UsageException>()),
      );
    });

    test('--dart dry-run on repo without pubspec announces bootstrap and '
        'writes nothing', () async {
      useDir('zuraffa_agent');

      final cmd = InitializeCommand();
      await cmd.execute(['--dart', '--deps-only', '--dry-run']);

      // Regression: the old code threw UsageException (missing pubspec)
      // before any announcement. Now dry-run previews and writes nothing.
      expect(File('pubspec.yaml').existsSync(), isFalse,
          reason: 'dry-run must not write');
    });

    test('--dart non-dry-run on repo without pubspec creates minimal '
        'pubspec in-place', () async {
      useDir('zuraffa_agent');

      final cmd = InitializeCommand();
      // Wiring may fail hermetically (git deps need network); the bootstrap
      // itself is the regression under test — catch the wiring error.
      try {
        await cmd.execute(['--dart', '--deps-only']);
      } on StateError {
        // Expected when the dependency wire cannot resolve offline.
      }

      final pubspec = File('pubspec.yaml');
      expect(pubspec.existsSync(), isTrue,
          reason: '--dart bootstraps pubspec.yaml in-place');
      final content = pubspec.readAsStringSync();
      expect(content, startsWith('name: zuraffa_agent\n'));
      expect(content, contains('sdk: ^3.0.0'));
    });

    test('without --dart and no pubspec.yaml still refuses with guidance',
        () async {
      useDir('some_repo');

      final cmd = InitializeCommand();
      expect(
        () => cmd.execute(['--deps-only']),
        throwsA(isA<UsageException>()),
      );
    });

    test('synthesizeMinimalPubspec derives snake_case package names', () {
      expect(InitializeCommand.synthesizeMinimalPubspec('ZikZak-AI'),
          startsWith('name: zikzak_ai\n'));
      expect(InitializeCommand.synthesizeMinimalPubspec('zuraffa_agent'),
          startsWith('name: zuraffa_agent\n'));
      expect(InitializeCommand.synthesizeMinimalPubspec('My Repo'),
          startsWith('name: my_repo\n'));
    });

    test('synthesizeMinimalPubspec falls back on invalid names', () {
      expect(InitializeCommand.synthesizeMinimalPubspec('1abc'),
          startsWith('name: zuraffa_package\n'));
      expect(InitializeCommand.synthesizeMinimalPubspec(''),
          startsWith('name: zuraffa_package\n'));
    });
  });
}
