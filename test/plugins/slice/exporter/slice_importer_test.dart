/// Tests for SliceImporter (U63, U64; gate T084).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U63: Import pulls the exported repo's contents over the local sandbox,
///        overwriting sandbox files
///   U64: Import on a slice with no `exportedTo` fails with an error telling
///        the user to export first
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/exporter/slice_importer.dart';
import 'package:zuraffa/src/plugins/slice/generators/manifest_writer.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_depth.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_file.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_manifest.dart';

void main() {
  late Directory tmpDir;
  late String projectRoot;
  late String sandbox;
  late String remoteRepo;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('slice_importer_');
    projectRoot = tmpDir.path;
    sandbox = p.join(projectRoot, '.zuraffa', 'slices', 'test_slice');
    await Directory(p.join(sandbox, 'lib', 'src')).create(recursive: true);
    // An old sandbox file that the "remote" will overwrite.
    await File(
      p.join(sandbox, 'lib', 'src', 'view.dart'),
    ).writeAsString('// OLD sandbox content\n');
    // The exported repo's on-disk state, used by the fake clone seam.
    remoteRepo = p.join(tmpDir.path, 'remote_repo');
    await Directory(p.join(remoteRepo, 'lib', 'src')).create(recursive: true);
    await File(
      p.join(remoteRepo, 'lib', 'src', 'view.dart'),
    ).writeAsString('// NEW remote content\n');
    await File(
      p.join(remoteRepo, 'lib', 'src', 'new_widget.dart'),
    ).writeAsString('class NewWidget {}\n');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Future<void> writeManifest({String? exportedTo}) async {
    final manifest = SliceManifest(
      name: 'test_slice',
      createdAt: DateTime(2026, 8, 30),
      depth: SliceDepth.feature,
      entries: const ['lib/src/view.dart'],
      projectRoot: projectRoot,
      packageName: 'zik_zak',
      branch: 'master',
      exportedTo: exportedTo,
      boundaries: const [],
      files: const [
        SliceFile(
          relativePath: 'lib/src/view.dart',
          ownership: FileOwnership.owned,
          hashAtCut: 'abc',
          layer: 'view',
        ),
      ],
    );
    await ManifestWriter().write(manifest, sandbox);
  }

  /// Fakes `git clone <url> <target>` by copying the remote layout over.
  Future<ProcessResult> fakeClone(
    List<String> args, {
    String? workingDirectory,
  }) async {
    if (args.first == 'git' && args[1] == 'clone') {
      final target = args.last;
      await _copyTree(remoteRepo, target);
      return ProcessResult(1, 0, '', '');
    }
    return ProcessResult(1, 0, '', '');
  }

  group('SliceImporter (FR-019)', () {
    test(
      'U63: pulls the exported repo over the sandbox, overwriting files',
      () async {
        await writeManifest(
          exportedTo: 'https://github.com/owner/test-slice.git',
        );
        final importer = SliceImporter(ghLauncher: fakeClone);

        final result = await importer.importSlice(
          sliceName: 'test_slice',
          projectRoot: projectRoot,
        );

        expect(result.success, isTrue);
        expect(
          File(p.join(sandbox, 'lib', 'src', 'view.dart')).readAsStringSync(),
          contains('NEW remote content'),
          reason: 'remote files must overwrite sandbox files',
        );
        expect(
          File(p.join(sandbox, 'lib', 'src', 'new_widget.dart')).existsSync(),
          isTrue,
          reason: 'remote-only files must be added to the sandbox',
        );
      },
    );

    test('U64: no exportedTo fails telling the user to export first', () async {
      await writeManifest(exportedTo: null);
      final importer = SliceImporter(ghLauncher: fakeClone);

      final result = await importer.importSlice(
        sliceName: 'test_slice',
        projectRoot: projectRoot,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('export'));
      expect(
        File(p.join(sandbox, 'lib', 'src', 'view.dart')).readAsStringSync(),
        contains('OLD sandbox content'),
        reason: 'the sandbox must be untouched',
      );
    });

    test('a missing slice fails cleanly naming the slice', () async {
      final importer = SliceImporter(ghLauncher: fakeClone);

      final result = await importer.importSlice(
        sliceName: 'ghost',
        projectRoot: projectRoot,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('ghost'));
    });
  });
}

Future<void> _copyTree(String from, String to) async {
  await Directory(to).create(recursive: true);
  for (final entity in Directory(from).listSync(recursive: true)) {
    if (entity is! File) continue;
    if (p.basename(entity.path) == '.git' ||
        entity.path.contains('${p.separator}.git${p.separator}')) {
      continue;
    }
    final rel = p.relative(entity.path, from: from);
    final target = p.join(to, rel);
    await File(target).parent.create(recursive: true);
    await File(target).writeAsBytes(await entity.readAsBytes());
  }
}
