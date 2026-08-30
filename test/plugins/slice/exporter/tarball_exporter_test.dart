/// Tests for TarballExporter (U57) and GithubExporter (U59-U62).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U57: The archive contains the mirrored sandbox tree, the filtered
///        `pubspec.yaml`, `main_slice.dart`, and `SLICE.md`
///   U59: Creates a private repo, pushes the sandbox as the initial commit,
///        and uses `SLICE.md` as the README
///   U60: A given `--repo` value is honored; without one a name is
///        generated from the project and slice names
///   U61: The repo URL is recorded in the manifest's `exportedTo` field
///   U62: An unauthenticated `gh` CLI fails with a clear auth error naming
///        the fix
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/exporter/github_exporter.dart';
import 'package:zuraffa/src/plugins/slice/exporter/tarball_exporter.dart';

void main() {
  late Directory tmpDir;
  late String sandbox;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('slice_export_');
    sandbox = (await Directory('${tmpDir.path}/sandbox').create()).path;
    // A minimal sandbox tree.
    final view = File('$sandbox/lib/src/view.dart');
    await view.parent.create(recursive: true);
    await view.writeAsString('class View {}\n');
    await File('$sandbox/main_slice.dart').writeAsString('void main() {}\n');
    await File('$sandbox/SLICE.md').writeAsString('# Slice\n');
    await File('$sandbox/slice.yaml').writeAsString('name: test\n');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('TarballExporter (FR-017)', () {
    test(
      'U57: the archive contains the tree, pubspec, entry, and SLICE.md',
      () async {
        final exporter = TarballExporter();

        final archivePath = await exporter.export(
          sandboxDir: sandbox,
          outputPath: '${tmpDir.path}/test_slice.tar.gz',
          pubspecContent: 'name: zik_zak\n',
        );

        final bytes = File(archivePath).readAsBytesSync();
        final archive = TarDecoder().decodeBytes(
          GZipDecoder().decodeBytes(bytes),
        );
        final names = archive.files.map((f) => f.name).toSet();

        expect(names, contains('lib/src/view.dart'));
        expect(names, contains('pubspec.yaml'));
        expect(names, contains('main_slice.dart'));
        expect(names, contains('SLICE.md'));
        expect(names, contains('slice.yaml'));

        // The pubspec in the archive is the FILTERED one.
        final pubspecEntry = archive.files.singleWhere(
          (f) => f.name == 'pubspec.yaml',
        );
        expect(
          String.fromCharCodes(pubspecEntry.content as List<int>),
          contains('zik_zak'),
        );
      },
    );
  });

  group('GithubExporter (FR-018)', () {
    test(
      'U59: creates a private repo, pushes, and uses SLICE.md as README',
      () async {
        final commands = <List<String>>[];
        final exporter = GithubExporter(
          ghLauncher: (args, {workingDirectory}) async {
            commands.add(args);
            if (args.first == 'auth') {
              return _result(0, 'Logged in to github.com');
            }
            if (args.first == 'repo' && args[1] == 'view') {
              return _result(
                0,
                'name:  owner/my-repo\nurl:   https://github.com/owner/my-repo',
              );
            }
            return _result(0, '');
          },
        );

        final result = await exporter.export(
          sandboxDir: sandbox,
          repo: 'owner/my-repo',
          packageName: 'zik_zak',
          sliceName: 'test_slice',
        );

        expect(result.repoUrl, equals('https://github.com/owner/my-repo'));
        // Auth checked first.
        expect(commands.first, contains('auth'));
        // The push includes a README.md staged from SLICE.md.
        final sandboxFiles = Directory(sandbox)
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.path)
            .toSet();
        expect(
          sandboxFiles.any((f) => f.endsWith('README.md')),
          isTrue,
          reason: 'SLICE.md is copied to README.md for the repo',
        );
      },
    );

    test(
      'U60: a given repo is honored; a missing one is auto-generated',
      () async {
        var seenRepoName = '';
        final exporter = GithubExporter(
          ghLauncher: (args, {workingDirectory}) async {
            if (args.first == 'repo' && args[1] == 'create') {
              seenRepoName = args[2];
            }
            if (args.first == 'repo' && args[1] == 'view') {
              return _result(0, 'url: https://github.com/owner/$seenRepoName');
            }
            return _result(0, '');
          },
        );

        await exporter.export(
          sandboxDir: sandbox,
          repo: 'owner/explicit-repo',
          packageName: 'zik_zak',
          sliceName: 'test_slice',
        );
        expect(seenRepoName, equals('owner/explicit-repo'));

        await exporter.export(
          sandboxDir: sandbox,
          repo: null,
          packageName: 'zik_zak',
          sliceName: 'profile_feature',
        );
        expect(seenRepoName, equals('zik-zak-slice-profile-feature'));
      },
    );

    test(
      'U61: the repo URL is returned for the manifest exportedTo field',
      () async {
        final exporter = GithubExporter(
          ghLauncher: (args, {workingDirectory}) async {
            if (args.first == 'repo' && args[1] == 'view') {
              return _result(0, 'url: https://github.com/owner/the-slice');
            }
            return _result(0, '');
          },
        );

        final result = await exporter.export(
          sandboxDir: sandbox,
          repo: 'owner/the-slice',
          packageName: 'zik_zak',
          sliceName: 'test_slice',
        );

        expect(result.repoUrl, equals('https://github.com/owner/the-slice'));
      },
    );

    test('U62: an unauthenticated gh fails with a clear auth error', () async {
      final exporter = GithubExporter(
        ghLauncher: (args, {workingDirectory}) async {
          if (args.first == 'auth') {
            return _result(1, 'You are not logged into any GitHub hosts.');
          }
          return _result(0, '');
        },
      );

      final result = await exporter.export(
        sandboxDir: sandbox,
        repo: 'owner/repo',
        packageName: 'zik_zak',
        sliceName: 'test_slice',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('gh auth login'));
    });
  });
}

ProcessResult _result(int code, String stdout) =>
    ProcessResult(1, code, stdout, '');
