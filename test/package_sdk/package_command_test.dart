@Tags(['slow'])
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/package_command.dart';

void main() {
  late Directory tempDir;
  late CommandRunner<void> runner;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_package_cmd_');
    runner = CommandRunner<void>('zfa', 'test')..addCommand(PackageCommand());
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('zfa package create (FR-001/FR-014 — spec 025)', () {
    test('U21: command is registered with create subcommand', () {
      expect(runner.commands.containsKey('package'), isTrue);
      final command = runner.commands['package'] as PackageCommand;
      expect(command.subcommands.keys, contains('create'));
    });

    test(
      'U19: valid name scaffolds the package under the output parent',
      () async {
        final exitCode = await _run(runner, [
          'package',
          'create',
          'demo_pkg',
          '--output',
          tempDir.path,
          // Pin the hosted constraint: the CLI keeps this suite off pub.dev.
          '--zuraffa-constraint',
          '^6.2.2',
        ]);
        expect(exitCode, 0);

        final pkg = p.join(tempDir.path, 'demo_pkg');
        expect(File(p.join(pkg, 'pubspec.yaml')).existsSync(), isTrue);
        expect(File(p.join(pkg, 'build.yaml')).existsSync(), isTrue);
        expect(
          File(
            p.join(pkg, 'lib', 'src', 'module', 'demo_pkg_package_module.dart'),
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            p.join(pkg, 'lib', 'src', 'di', 'demo_pkg_package_registrar.dart'),
          ).existsSync(),
          isTrue,
        );
      },
    );

    test('U19b: invalid name → usage error, nothing written', () async {
      final exitCode = await _run(runner, [
        'package',
        'create',
        'Bad-Name',
        '--output',
        tempDir.path,
      ]);
      expect(exitCode, isNot(0));
      expect(Directory(p.join(tempDir.path, 'Bad-Name')).existsSync(), isFalse);
    });

    test('U19c: --dry-run writes nothing', () async {
      final exitCode = await _run(runner, [
        'package',
        'create',
        'dry_pkg',
        '--output',
        tempDir.path,
        '--zuraffa-constraint',
        '^6.2.2',
        '--dry-run',
      ]);
      expect(exitCode, 0);
      expect(Directory(p.join(tempDir.path, 'dry_pkg')).existsSync(), isFalse);
    });

    test(
      'U19e: --zuraffa-constraint is stamped verbatim into the pubspec',
      () async {
        final exitCode = await _run(runner, [
          'package',
          'create',
          'pinned_pkg',
          '--output',
          tempDir.path,
          '--zuraffa-constraint',
          '6.2.2',
        ]);
        expect(exitCode, 0);

        final pubspec = File(
          p.join(tempDir.path, 'pinned_pkg', 'pubspec.yaml'),
        ).readAsStringSync();
        expect(
          pubspec,
          contains('zuraffa: 6.2.2'),
          reason:
              'the value is used as-is — a bare version is an exact pin, '
              'not ^6.2.2',
        );
        expect(pubspec, isNot(contains('zuraffa: ^6.2.2')));
      },
    );

    test('U19f: --zuraffa-constraint is offered on both create paths', () {
      final command = runner.commands['package'] as PackageCommand;
      for (final subcommand in const ['create', 'create-plugin']) {
        expect(
          command.subcommands[subcommand]!.argParser.options,
          contains('zuraffa-constraint'),
          reason: '$subcommand must offer the pinned-constraint option',
        );
      }
    });

    test(
      'U20: existing directory → clear error, exit non-zero, untouched',
      () async {
        // Use a collision-resistant name so a leftover `clash_pkg` entry left
        // in /tmp by an interrupted prior run can never poison this test.
        final collidingName =
            'clash_pkg_${DateTime.now().microsecondsSinceEpoch}';
        final existing = Directory(p.join(tempDir.path, collidingName))
          ..createSync();
        File(p.join(existing.path, 'precious.txt')).writeAsStringSync('data');

        final exitCode = await _run(runner, [
          'package',
          'create',
          collidingName,
          '--output',
          tempDir.path,
        ]);
        expect(exitCode, isNot(0));
        expect(
          File(p.join(existing.path, 'precious.txt')).readAsStringSync(),
          'data',
        );
        expect(
          File(p.join(existing.path, 'pubspec.yaml')).existsSync(),
          isFalse,
        );
      },
    );

    test('U19d: missing name → usage error', () async {
      final exitCode = await _run(runner, ['package', 'create']);
      expect(exitCode, isNot(0));
    });
  });
}

/// Runs [runner] with [args], capturing stdout/stderr, and returns the
/// process-equivalent exit code (0 = success, 64 = usage, 1 = error).
Future<int> _run(CommandRunner<void> runner, List<String> args) async {
  try {
    await runner.run(args);
    return 0;
  } on UsageException {
    return 64;
  } on PackageCommandException catch (e) {
    // The command prints its error; surface it for debugging.
    // ignore: avoid_print
    print('command error: $e');
    return 1;
  }
}
