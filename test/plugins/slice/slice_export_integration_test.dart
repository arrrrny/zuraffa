@Tags(['slow'])
/// Acceptance integration tests for slice export/import (US8, FR-017..FR-020).
///
/// Gates traced to specs/043-slice-plugin/tasks.md:
///   T109/A23: export --format tar.gz produces an archive with all sandbox
///             files and a self-contained filtered pubspec.yaml
///   T110/A24: export --format github --repo `<name>` creates/pushes a repo
///             with SLICE.md as README and a working pubspec.yaml
///   T111/A25: export --format github without --repo auto-generates a repo
///             name from project and slice name
///   T112/A26: export of an unverified slice runs verification first and
///             aborts when it fails
///
/// T124: intentionally paired with U58 in capabilities/export_slice_capability
/// _test.dart — one gate, two levels of negative: A26 pins that no gh command
/// fires pre-verify; the unit test pins that no tarball lands on disk.
///   T113/A27: import --from github pulls the repo contents back into the
///             local sandbox, ready for slice merge
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';

import 'helpers/capture_output.dart';
import 'helpers/copy_fixture_project.dart';

void main() {
  late String projectRoot;
  late String sandbox;

  setUp(() async {
    projectRoot = await copySliceFixtureProject();
    sandbox = '$projectRoot/.zuraffa/slices/product_feature';
  });

  tearDown(() async {
    final dir = Directory(projectRoot);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  Future<void> cutSlice() async {
    final cutRunner = CommandRunner<void>('zfa', 'test')
      ..addCommand(SliceCommand(projectRoot: projectRoot));
    await captureOutput(
      () => cutRunner.run([
        'slice',
        'cut',
        'product_feature',
        '--entry',
        'product',
      ]),
    );
  }

  group('slice export (US8)', () {
    test('A23 (T109): tar.gz archive with filtered pubspec', () async {
      await cutSlice();

      final command = SliceCommand(projectRoot: projectRoot);
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      final output = await captureOutput(
        () => runner.run([
          'slice',
          'export',
          'product_feature',
          '--format',
          'tar.gz',
        ]),
      );

      expect(command.exitCode, equals(0), reason: output);
      final archivePath =
          '$projectRoot/.zuraffa/exports/product_feature.tar.gz';
      expect(File(archivePath).existsSync(), isTrue);

      final archive = TarDecoder().decodeBytes(
        GZipDecoder().decodeBytes(File(archivePath).readAsBytesSync()),
      );
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('main_slice.dart'));
      expect(names, contains('SLICE.md'));
      expect(names, contains('slice.yaml'));
      expect(names, contains('pubspec.yaml'));
      expect(
        names.any((n) => n.startsWith('lib/src/')),
        isTrue,
        reason: 'the mirrored lib tree must be in the archive',
      );

      // The embedded pubspec is filtered and self-contained (FR-017).
      final pubspecEntry = archive.files.singleWhere(
        (f) => f.name == 'pubspec.yaml',
      );
      final pubspec =
          loadYaml(String.fromCharCodes(pubspecEntry.content as List<int>))
              as Map;
      expect(pubspec['name'], equals('zik_zak'));
      expect((pubspec['dependencies'] as Map).keys, contains('flutter'));
      expect((pubspec['dependencies'] as Map).keys, contains('get_it'));
      expect(
        (pubspec['dev_dependencies'] as Map).keys,
        everyElement(equals('flutter_test')),
        reason: 'unused dev dependencies (build_runner) must be dropped',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A24 (T110): github export pushes with SLICE.md as README', () async {
      await cutSlice();

      final commands = <List<String>>[];
      final command = SliceCommand(
        projectRoot: projectRoot,
        ghLauncher: (args, {workingDirectory}) async {
          commands.add(args);
          if (args.first == 'auth') {
            return ProcessResult(1, 0, 'Logged in', '');
          }
          if (args.first == 'repo' && args[1] == 'view') {
            return ProcessResult(
              1,
              0,
              '{"url":"https://github.com/agent/product-feature"}',
              '',
            );
          }
          return ProcessResult(1, 0, '', '');
        },
      );
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      final output = await captureOutput(
        () => runner.run([
          'slice',
          'export',
          'product_feature',
          '--format',
          'github',
          '--repo',
          'agent/product-feature',
        ]),
      );

      expect(command.exitCode, equals(0), reason: output);
      expect(output, contains('https://github.com/agent/product-feature'));
      // The repo create call targets the requested repo.
      final create = commands.firstWhere(
        (c) => c.first == 'repo' && c[1] == 'create',
      );
      expect(create[2], equals('agent/product-feature'));
      expect(create, contains('--private'));
      // SLICE.md promoted to README.md in the pushed tree (FR-018).
      expect(
        File('$sandbox/README.md').existsSync(),
        isTrue,
        reason: 'SLICE.md must be staged as README.md',
      );
      // The pushed sandbox carries a working (filtered) pubspec.yaml.
      expect(
        File('$sandbox/pubspec.yaml').existsSync(),
        isTrue,
        reason: 'the exported tree needs a pubspec.yaml to be runnable',
      );
      // exportedTo recorded in slice.yaml (FR-004).
      final manifest =
          loadYaml(File('$sandbox/slice.yaml').readAsStringSync()) as Map;
      expect(
        manifest['exportedTo'],
        equals('https://github.com/agent/product-feature'),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A25 (T111): repo name auto-generated when --repo omitted', () async {
      await cutSlice();

      var seenRepoName = '';
      final command = SliceCommand(
        projectRoot: projectRoot,
        ghLauncher: (args, {workingDirectory}) async {
          if (args.first == 'repo' && args[1] == 'create') {
            seenRepoName = args[2];
          }
          if (args.first == 'repo' && args[1] == 'view') {
            return ProcessResult(
              1,
              0,
              '{"url":"https://github.com/owner/$seenRepoName"}',
              '',
            );
          }
          return ProcessResult(1, 0, '', '');
        },
      );
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      final output = await captureOutput(
        () => runner.run([
          'slice',
          'export',
          'product_feature',
          '--format',
          'github',
        ]),
      );

      expect(command.exitCode, equals(0), reason: output);
      expect(
        seenRepoName,
        equals('zik-zak-slice-product-feature'),
        reason: 'auto-name = <package>-slice-<slice>, slugified',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
      'A26 (T112): export of an unverified slice aborts with no artifact',
      () async {
        await cutSlice();
        File(
          '$sandbox/lib/src/presentation/pages/product/'
          'product_controller.dart',
        ).deleteSync();

        final commands = <List<String>>[];
        final command = SliceCommand(
          projectRoot: projectRoot,
          ghLauncher: (args, {workingDirectory}) async {
            commands.add(args);
            return ProcessResult(1, 0, '', '');
          },
        );
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
        final output = await captureOutput(
          () => runner.run([
            'slice',
            'export',
            'product_feature',
            '--format',
            'github',
          ]),
        );

        expect(command.exitCode, equals(1));
        expect(output, contains('unresolved'));
        expect(commands, isEmpty, reason: 'no gh call may happen pre-verify');
        expect(
          File(
            '$projectRoot/.zuraffa/exports/product_feature.tar.gz',
          ).existsSync(),
          isFalse,
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('slice import (US8)', () {
    test('A27 (T113): import pulls the repo back over the sandbox', () async {
      await cutSlice();
      // Simulate an exported repo: mutate the sandbox "remotely" and record
      // the URL, then dirty the local sandbox.
      final view = File(
        '$sandbox/lib/src/presentation/pages/product/product_view.dart',
      );
      final remoteContent =
          '// agent-edited remotely\n'
          '${view.readAsStringSync()}';
      final remoteRepo = '$projectRoot/.zuraffa/remote_repo';
      await Directory(remoteRepo).create(recursive: true);
      await File(
        '$remoteRepo/agent_note.txt',
      ).writeAsString('edited by the agent\n');

      // Record exportedTo by exporting with a fake gh seam.
      final exportCommand = SliceCommand(
        projectRoot: projectRoot,
        ghLauncher: (args, {workingDirectory}) async {
          if (args.first == 'repo' && args[1] == 'view') {
            return ProcessResult(
              1,
              0,
              '{"url":"https://github.com/agent/product-feature"}',
              '',
            );
          }
          return ProcessResult(1, 0, '', '');
        },
      );
      final exportRunner = CommandRunner<void>('zfa', 'test')
        ..addCommand(exportCommand);
      await captureOutput(
        () => exportRunner.run([
          'slice',
          'export',
          'product_feature',
          '--format',
          'github',
        ]),
      );
      expect(exportCommand.exitCode, equals(0));

      // Dirty the local sandbox file the agent improved remotely.
      await view.writeAsString('// stale local content\n');

      final importCommand = SliceCommand(
        projectRoot: projectRoot,
        ghLauncher: (args, {workingDirectory}) async {
          if (args.first == 'git' && args[1] == 'clone') {
            // Fake clone: materialize the "remote" repo into the target.
            final target = args.last;
            await Directory(target).create(recursive: true);
            for (final entity in Directory(
              remoteRepo,
            ).listSync(recursive: true)) {
              if (entity is! File) continue;
              final rel = entity.path.substring(remoteRepo.length + 1);
              final dest = '$target/$rel';
              await File(dest).parent.create(recursive: true);
              await File(dest).writeAsBytes(await entity.readAsBytes());
            }
            // The remote also carries the agent-edited view file.
            final remoteViewDir = '$target/lib/src/presentation/pages/product';
            await Directory(remoteViewDir).create(recursive: true);
            await File(
              '$remoteViewDir/product_view.dart',
            ).writeAsString(remoteContent);
            return ProcessResult(1, 0, '', '');
          }
          return ProcessResult(1, 0, '', '');
        },
      );
      final runner = CommandRunner<void>('zfa', 'test')
        ..addCommand(importCommand);
      final output = await captureOutput(
        () => runner.run([
          'slice',
          'import',
          'product_feature',
          '--from',
          'github',
        ]),
      );

      expect(importCommand.exitCode, equals(0), reason: output);
      expect(
        view.readAsStringSync(),
        contains('agent-edited remotely'),
        reason: 'remote content must overwrite the stale sandbox copy',
      );
      expect(
        File('$sandbox/agent_note.txt').existsSync(),
        isTrue,
        reason: 'remote-only files must land in the sandbox',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
