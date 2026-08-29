/// Tests for AgentReadmeGenerator (U35, U36).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U35: `SLICE.md` marks owned files as modifiable and shared files as
///        modify-with-caution
///   U36: `SLICE.md` contains the run command with the correct `-t` path and
///        the boundary interface list
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/agent_readme_generator.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_boundary.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_depth.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_file.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_manifest.dart';

void main() {
  late AgentReadmeGenerator generator;

  setUp(() {
    generator = AgentReadmeGenerator();
  });

  SliceManifest sampleManifest() => SliceManifest(
    name: 'product_feature',
    createdAt: DateTime.utc(2026, 8, 30),
    depth: SliceDepth.feature,
    entries: const [
      'lib/src/presentation/pages/product/product_view.dart',
    ],
    projectRoot: '/home/dev/zikzak',
    packageName: 'zik_zak',
    branch: 'main',
    exportedTo: null,
    files: const [
      SliceFile(
        relativePath: 'lib/src/presentation/pages/product/product_view.dart',
        ownership: FileOwnership.owned,
        hashAtCut: 'hash1',
        layer: 'presentation',
      ),
      SliceFile(
        relativePath: 'lib/src/presentation/pages/product/product_state.dart',
        ownership: FileOwnership.owned,
        hashAtCut: 'hash2',
        layer: 'presentation',
      ),
      SliceFile(
        relativePath: 'lib/src/domain/entities/product/product.dart',
        ownership: FileOwnership.shared,
        hashAtCut: 'hash3',
        layer: 'domain',
      ),
      SliceFile(
        relativePath: 'lib/src/presentation/widgets/primary_button.dart',
        ownership: FileOwnership.shared,
        hashAtCut: 'hash4',
        layer: 'presentation',
      ),
    ],
    boundaries: const [
      SliceBoundary(
        typeName: 'ProductRepository',
        interfaceFile: 'lib/src/domain/repositories/product_repository.dart',
        diRegistrationFile: 'lib/src/di/repositories/product_repository_di.dart',
        mockStrategy: 'auto',
      ),
    ],
  );

  group('AgentReadmeGenerator SLICE.md (FR-007)', () {
    test('U35: owned files are modifiable, shared files are caution',
        () {
      final content = generator.generate(manifest: sampleManifest());

      expect(content, contains('## Files you may modify'));
      expect(content, contains('product_view.dart'));
      expect(content, contains('product_state.dart'));
      expect(content, contains('## Files shared with other features'));
      expect(content, contains('product.dart'));
      expect(content, contains('primary_button.dart'));
      // Ownership sections carry the guidance wording (FR-007/FR-010).
      expect(content, contains('shared'));
      expect(content.toLowerCase(), contains('caution'));
    });

    test('U36: contains the run command with the correct -t path', () {
      final content = generator.generate(manifest: sampleManifest());

      expect(
        content,
        contains(
          'flutter run -t .zuraffa/slices/product_feature/main_slice.dart',
        ),
      );
    });

    test('U36: lists the boundary interfaces with their mocks', () {
      final content = generator.generate(manifest: sampleManifest());

      expect(content, contains('ProductRepository'));
      expect(content, contains('MockProductRepository'));
      expect(
        content,
        contains('lib/src/domain/repositories/product_repository.dart'),
      );
    });

    test('describes the merge-back workflow', () {
      final content = generator.generate(manifest: sampleManifest());

      expect(content, contains('zfa slice merge product_feature'));
    });
  });
}
