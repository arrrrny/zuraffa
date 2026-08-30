/// Tests for SliceManifest serialization (U1, U2, U3).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U1: A manifest with files, boundaries, hashes, and depth round-trips
///       through write→read unchanged
///   U2: A manifest with empty files/boundaries and null `exportedTo`
///       round-trips unchanged
///   U3: Reading a missing or corrupt `slice.yaml` fails with an error naming
///       the slice directory
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/manifest_writer.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_boundary.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_depth.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_file.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_manifest.dart';

void main() {
  late Directory tmpDir;
  late ManifestWriter writer;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('slice_manifest_test_');
    writer = ManifestWriter();
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  SliceManifest fullManifest() => SliceManifest(
    name: 'profile_feature',
    createdAt: DateTime.utc(2026, 8, 30, 10, 30, 0),
    depth: SliceDepth.feature,
    entries: const ['lib/src/presentation/pages/profile/profile_view.dart'],
    projectRoot: '/home/dev/zikzak',
    packageName: 'zik_zak',
    branch: '043-slice-plugin',
    exportedTo: null,
    files: const [
      SliceFile(
        relativePath: 'lib/src/presentation/pages/profile/profile_view.dart',
        ownership: FileOwnership.owned,
        hashAtCut: 'a1b2c3d4e5f6',
        layer: 'presentation',
      ),
      SliceFile(
        relativePath: 'lib/src/domain/entities/profile/profile.dart',
        ownership: FileOwnership.shared,
        hashAtCut: '0123456789abcdef',
        layer: 'domain',
      ),
    ],
    boundaries: const [
      SliceBoundary(
        typeName: 'ProductRepository',
        interfaceFile: 'lib/src/domain/repositories/product_repository.dart',
        diRegistrationFile:
            'lib/src/di/repositories/product_repository_di.dart',
        mockStrategy: 'auto',
      ),
    ],
  );

  group('SliceManifest round-trip (FR-004)', () {
    test('U1: a full manifest round-trips through write then read', () async {
      final manifest = fullManifest();
      await writer.write(manifest, tmpDir.path);

      final read = await writer.read(tmpDir.path);

      expect(read.name, equals('profile_feature'));
      expect(read.createdAt, equals(DateTime.utc(2026, 8, 30, 10, 30, 0)));
      expect(read.depth, equals(SliceDepth.feature));
      expect(
        read.entries,
        equals(['lib/src/presentation/pages/profile/profile_view.dart']),
      );
      expect(read.projectRoot, equals('/home/dev/zikzak'));
      expect(read.packageName, equals('zik_zak'));
      expect(read.branch, equals('043-slice-plugin'));
      expect(read.exportedTo, isNull);
      expect(read.files, hasLength(2));
      expect(read.files.first.relativePath, contains('profile_view.dart'));
      expect(read.files.first.ownership, equals(FileOwnership.owned));
      expect(read.files.first.hashAtCut, equals('a1b2c3d4e5f6'));
      expect(read.files.first.layer, equals('presentation'));
      expect(read.files[1].ownership, equals(FileOwnership.shared));
      expect(read.boundaries, hasLength(1));
      expect(read.boundaries.first.typeName, equals('ProductRepository'));
      expect(
        read.boundaries.first.diRegistrationFile,
        equals('lib/src/di/repositories/product_repository_di.dart'),
      );
      expect(read.boundaries.first.mockStrategy, equals('auto'));
    });

    test('U2: an empty manifest with null exportedTo round-trips', () async {
      final manifest = SliceManifest(
        name: 'empty_slice',
        createdAt: DateTime.utc(2026, 8, 29, 8, 0, 0),
        depth: SliceDepth.view,
        entries: const [],
        projectRoot: '/proj',
        packageName: 'app',
        branch: 'main',
        exportedTo: null,
        files: const [],
        boundaries: const [],
      );
      await writer.write(manifest, tmpDir.path);

      final read = await writer.read(tmpDir.path);

      expect(read.name, equals('empty_slice'));
      expect(read.depth, equals(SliceDepth.view));
      expect(read.entries, isEmpty);
      expect(read.files, isEmpty);
      expect(read.boundaries, isEmpty);
      expect(read.exportedTo, isNull);
    });

    test(
      'exportedTo round-trips when set (github export records it)',
      () async {
        final manifest = fullManifest().copyWith(
          exportedTo:
              'https://github.com/arrrrny/zik-zak-slice-profile-feature',
        );
        await writer.write(manifest, tmpDir.path);

        final read = await writer.read(tmpDir.path);

        expect(
          read.exportedTo,
          equals('https://github.com/arrrrny/zik-zak-slice-profile-feature'),
        );
      },
    );

    test('copyWith can clear exportedTo back to null', () {
      final manifest = fullManifest().copyWith(
        exportedTo: 'https://github.com/arrrrny/zik-zak-slice-profile-feature',
      );

      expect(manifest.copyWith(exportedTo: null).exportedTo, isNull);
    });
  });

  group('SliceManifest failure modes (FR-012)', () {
    test(
      'U3: reading a missing slice.yaml names the slice directory',
      () async {
        final missing = '${tmpDir.path}/no_such_slice';

        await expectLater(
          () => writer.read(missing),
          throwsA(
            isA<SliceManifestError>().having(
              (e) => e.message,
              'message',
              contains('no_such_slice'),
            ),
          ),
        );
      },
    );

    test(
      'U3: reading a corrupt slice.yaml names the slice directory',
      () async {
        await File(
          '${tmpDir.path}/slice.yaml',
        ).writeAsString('files: [unclosed');

        await expectLater(
          () => writer.read(tmpDir.path),
          throwsA(
            isA<SliceManifestError>().having(
              (e) => e.message,
              'message',
              allOf(contains('slice.yaml'), contains('corrupt')),
            ),
          ),
        );
      },
    );

    test(
      'U3: invalid ownership values are rejected instead of defaulting',
      () async {
        await File('${tmpDir.path}/slice.yaml').writeAsString('''
name: bad_slice
createdAt: "2026-08-30T10:30:00.000Z"
depth: feature
projectRoot: /tmp/project
packageName: app
branch: main
entries: []
files:
  - path: lib/src/domain/entities/profile/profile.dart
    ownership: invalid
    hashAtCut: deadbeef
    layer: domain
boundaries: []
generatedFiles: []
''');

        await expectLater(
          () => writer.read(tmpDir.path),
          throwsA(
            isA<SliceManifestError>().having(
              (e) => e.message,
              'message',
              contains('invalid file ownership'),
            ),
          ),
        );
      },
    );

    test(
      'U3: invalid mock strategies are rejected instead of defaulting',
      () async {
        await File('${tmpDir.path}/slice.yaml').writeAsString('''
name: bad_slice
createdAt: "2026-08-30T10:30:00.000Z"
depth: feature
projectRoot: /tmp/project
packageName: app
branch: main
entries: []
files: []
boundaries:
  - typeName: ProductRepository
    interfaceFile: lib/src/domain/repositories/product_repository.dart
    diRegistrationFile: null
    mockStrategy: nope

generatedFiles: []
''');

        await expectLater(
          () => writer.read(tmpDir.path),
          throwsA(
            isA<SliceManifestError>().having(
              (e) => e.message,
              'message',
              contains('invalid mock strategy'),
            ),
          ),
        );
      },
    );
  });
}
