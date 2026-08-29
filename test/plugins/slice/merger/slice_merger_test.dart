/// Tests for SliceMerger (U41, U42, U43, U44, U67, U68).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U41: Merge copies back only files classified safe_copy
///   U42: A modified `shared` file requires confirmation before it is
///        overwritten
///   U43: A conflicted file is not copied, is reported, and the sandbox is
///        preserved
///   U44: A merge with zero modifications reports "no changes" and deletes
///        the slice directory
///   U67: A file the agent created inside the sandbox is copied to its
///        mirrored project path and listed in the merge report
///   U68: A file the agent deleted from the sandbox is deleted in the
///        project; a deleted `shared` file requires confirmation
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/manifest_writer.dart';
import 'package:zuraffa/src/plugins/slice/merger/slice_merger.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_depth.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_file.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_manifest.dart';

void main() {
  late Directory tmpDir;
  late String projectRoot;
  late String sandbox;
  late ManifestWriter writer;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('slice_merger_');
    final projectDir = await Directory('${tmpDir.path}/project').create();
    projectRoot = projectDir.path;
    sandbox = (await Directory('${tmpDir.path}/sandbox').create()).path;
    writer = ManifestWriter();
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Future<File> putFile(String base, String rel, String content) async {
    final file = File(p.join(base, rel));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  String hashOf(File file) =>
      sha256.convert(file.readAsBytesSync()).toString();

  SliceManifest buildManifest(List<SliceFile> files) => SliceManifest(
    name: 'test_slice',
    createdAt: DateTime.utc(2026, 8, 30),
    depth: SliceDepth.feature,
    entries: const ['lib/src/presentation/pages/product/product_view.dart'],
    projectRoot: projectRoot,
    packageName: 'zik_zak',
    branch: 'master',
    exportedTo: null,
    files: files,
    boundaries: const [],
    generatedFiles: const ['main_slice.dart', 'SLICE.md', 'slice.yaml'],
  );

  group('SliceMerger (FR-008)', () {
    test('U41: merge copies back only safe-copy files', () async {
      final view = await putFile(
        projectRoot,
        'lib/src/presentation/pages/product/product_view.dart',
        'original',
      );
      final state = await putFile(
        projectRoot,
        'lib/src/presentation/pages/product/product_state.dart',
        'original',
      );
      final viewHash = hashOf(view);
      final stateHash = hashOf(state);

      // Agent modifies only the view.
      await putFile(
        sandbox,
        'lib/src/presentation/pages/product/product_view.dart',
        'agent edit',
      );
      await putFile(
        sandbox,
        'lib/src/presentation/pages/product/product_state.dart',
        'original',
      );

      final manifest = buildManifest([
        SliceFile(
          relativePath: 'lib/src/presentation/pages/product/product_view.dart',
          ownership: FileOwnership.owned,
          hashAtCut: viewHash,
          layer: 'presentation',
        ),
        SliceFile(
          relativePath: 'lib/src/presentation/pages/product/product_state.dart',
          ownership: FileOwnership.owned,
          hashAtCut: stateHash,
          layer: 'presentation',
        ),
      ]);

      final report = await SliceMerger().merge(
        manifest: manifest,
        sandboxDir: sandbox,
        projectRoot: projectRoot,
        confirmSharedOverwrite: (_) => true,
        confirmSharedDelete: (_) => true,
      );

      expect(report.copied, [
        'lib/src/presentation/pages/product/product_view.dart',
      ]);
      expect(
        File(view.path).readAsStringSync(),
        equals('agent edit'),
      );
      expect(
        File(state.path).readAsStringSync(),
        equals('original'),
      );
      // Successful merge cleans up the sandbox.
      expect(Directory(sandbox).existsSync(), isFalse);
    });

    test('U42: a modified shared file requires confirmation', () async {
      final widget = await putFile(
        projectRoot,
        'lib/src/presentation/widgets/primary_button.dart',
        'original',
      );

      await putFile(
        sandbox,
        'lib/src/presentation/widgets/primary_button.dart',
        'agent edit',
      );

      final manifest = buildManifest([
        SliceFile(
          relativePath: 'lib/src/presentation/widgets/primary_button.dart',
          ownership: FileOwnership.shared,
          hashAtCut: hashOf(widget),
          layer: 'presentation',
        ),
      ]);

      // Denied: nothing is copied, the sandbox survives, the report warns.
      final denied = await SliceMerger().merge(
        manifest: manifest,
        sandboxDir: sandbox,
        projectRoot: projectRoot,
        confirmSharedOverwrite: (_) => false,
        confirmSharedDelete: (_) => true,
      );

      expect(denied.copied, isEmpty);
      expect(denied.unconfirmedShared, hasLength(1));
      expect(
        File(widget.path).readAsStringSync(),
        equals('original'),
      );
      expect(Directory(sandbox).existsSync(), isTrue);

      // Confirmed: the file is copied back.
      final granted = await SliceMerger().merge(
        manifest: manifest,
        sandboxDir: sandbox,
        projectRoot: projectRoot,
        confirmSharedOverwrite: (_) => true,
        confirmSharedDelete: (_) => true,
      );

      expect(granted.copied, hasLength(1));
      expect(
        File(widget.path).readAsStringSync(),
        equals('agent edit'),
      );
    });

    test('U43: a conflicted file is not copied and the sandbox survives',
        () async {
      final view = await putFile(
        projectRoot,
        'lib/src/presentation/pages/product/product_view.dart',
        'changed in main',
      );

      await putFile(
        sandbox,
        'lib/src/presentation/pages/product/product_view.dart',
        'changed by agent',
      );

      final manifest = buildManifest([
        SliceFile(
          relativePath: 'lib/src/presentation/pages/product/product_view.dart',
          ownership: FileOwnership.owned,
          hashAtCut: 'old-hash',
          layer: 'presentation',
        ),
      ]);
      // main hash differs from cut hash -> conflict (hashOf(view) != 'old-hash')
      expect(hashOf(view), isNot(equals('old-hash')));

      final report = await SliceMerger().merge(
        manifest: manifest,
        sandboxDir: sandbox,
        projectRoot: projectRoot,
        confirmSharedOverwrite: (_) => true,
        confirmSharedDelete: (_) => true,
      );

      expect(report.conflicts, hasLength(1));
      expect(report.copied, isEmpty);
      expect(
        File(view.path).readAsStringSync(),
        equals('changed in main'),
        reason: 'the main project must never be silently overwritten',
      );
      expect(Directory(sandbox).existsSync(), isTrue);
    });

    test('U44: zero modifications reports no changes and deletes the slice',
        () async {
      final view = await putFile(
        projectRoot,
        'lib/src/presentation/pages/product/product_view.dart',
        'original',
      );
      await putFile(
        sandbox,
        'lib/src/presentation/pages/product/product_view.dart',
        'original',
      );
      // Harness files present; they must not count as changes.
      await putFile(sandbox, 'main_slice.dart', 'generated');
      await putFile(sandbox, 'slice.yaml', 'generated');

      final manifest = buildManifest([
        SliceFile(
          relativePath: 'lib/src/presentation/pages/product/product_view.dart',
          ownership: FileOwnership.owned,
          hashAtCut: hashOf(view),
          layer: 'presentation',
        ),
      ]);

      final report = await SliceMerger().merge(
        manifest: manifest,
        sandboxDir: sandbox,
        projectRoot: projectRoot,
        confirmSharedOverwrite: (_) => true,
        confirmSharedDelete: (_) => true,
      );

      expect(report.noChanges, isTrue);
      expect(report.message, contains('No changes to merge'));
      expect(Directory(sandbox).existsSync(), isFalse);
    });

    test('U67: an agent-created file is copied back and reported', () async {
      final view = await putFile(
        projectRoot,
        'lib/src/presentation/pages/product/product_view.dart',
        'original',
      );
      await putFile(
        sandbox,
        'lib/src/presentation/pages/product/product_view.dart',
        'original',
      );
      // The agent adds a brand-new file inside the mirrored tree.
      await putFile(
        sandbox,
        'lib/src/presentation/pages/product/product_card.dart',
        'brand new',
      );
      // ...and harness files that must NOT be copied back.
      await putFile(sandbox, 'main_slice.dart', 'generated');
      await putFile(sandbox, 'SLICE.md', 'generated');
      await putFile(sandbox, 'slice.yaml', 'generated');

      final manifest = buildManifest([
        SliceFile(
          relativePath: 'lib/src/presentation/pages/product/product_view.dart',
          ownership: FileOwnership.owned,
          hashAtCut: hashOf(view),
          layer: 'presentation',
        ),
      ]);

      final report = await SliceMerger().merge(
        manifest: manifest,
        sandboxDir: sandbox,
        projectRoot: projectRoot,
        confirmSharedOverwrite: (_) => true,
        confirmSharedDelete: (_) => true,
      );

      expect(report.created, [
        'lib/src/presentation/pages/product/product_card.dart',
      ]);
      expect(
        File(
          p.join(projectRoot, 'lib/src/presentation/pages/product/product_card.dart'),
        ).readAsStringSync(),
        equals('brand new'),
      );
      expect(
        File(p.join(projectRoot, 'main_slice.dart')).existsSync(),
        isFalse,
        reason: 'harness files never leak into the project',
      );
    });

    test('U68: an agent-deleted file is removed; shared needs confirmation',
        () async {
      final state = await putFile(
        projectRoot,
        'lib/src/presentation/pages/product/product_state.dart',
        'original',
      );
      final widget = await putFile(
        projectRoot,
        'lib/src/presentation/widgets/primary_button.dart',
        'original',
      );
      // Agent deleted BOTH files from the sandbox (no sandbox copies).

      final manifest = buildManifest([
        SliceFile(
          relativePath: 'lib/src/presentation/pages/product/product_state.dart',
          ownership: FileOwnership.owned,
          hashAtCut: hashOf(state),
          layer: 'presentation',
        ),
        SliceFile(
          relativePath: 'lib/src/presentation/widgets/primary_button.dart',
          ownership: FileOwnership.shared,
          hashAtCut: hashOf(widget),
          layer: 'presentation',
        ),
      ]);

      final report = await SliceMerger().merge(
        manifest: manifest,
        sandboxDir: sandbox,
        projectRoot: projectRoot,
        confirmSharedOverwrite: (_) => true,
        confirmSharedDelete: (path) => !path.contains('primary_button'),
      );

      // Owned deletion applied.
      expect(report.deleted, [
        'lib/src/presentation/pages/product/product_state.dart',
      ]);
      expect(
        File(state.path).existsSync(),
        isFalse,
      );
      // Shared deletion NOT confirmed -> kept, reported.
      expect(File(widget.path).existsSync(), isTrue);
      expect(report.unconfirmedShared, contains(contains('primary_button')));
    });
  });
}
