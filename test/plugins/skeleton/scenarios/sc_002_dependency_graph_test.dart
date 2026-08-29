/// SC-002 acceptance test: inter-bone dependency resolution end-to-end.
///
/// Behaviors traced to test-list.md:
///   A3: bone depending on another records dependency in manifest and
///       includes or links the dependent stub
///   A4: feature B references A's entity → B's manifest lists A with shared entity
///   A5: circular dependency → generation fails naming cycle members, no output
///   A6: no cross-references → dependencies: []
///
/// Drives BoneGenerator with a specs root to test resolver integration.
/// Uses fixture spec directories; never touches the repo's real specs/.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/generators/bone_generator.dart';

import '../helpers/copy_fixture.dart';

void main() {
  late Directory tmpDir;
  late Directory specsRoot;
  late BoneGenerator generator;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('sc_002_dep_test_');
    specsRoot = await Directory('${tmpDir.path}/specs').create();
    generator = BoneGenerator();
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('SC-002: dependency graph (A3, A4, A5, A6)', () {
    test(
      'A4: B references A\'s entity → B\'s manifest lists A with shared entity',
      () async {
        await copyFixture('feature-a', specsRoot.path);
        await copyFixture('feature-b', specsRoot.path);

        final outputDir = '${tmpDir.path}/bones';
        final boneDir = await generator.generate(
          specPath: File('${specsRoot.path}/feature-b/spec.md'),
          outputDir: outputDir,
          specsRoot: specsRoot.path,
        );

        final manifestContent =
            await File('$boneDir/bone.yaml').readAsString();

        // Feature B depends on feature-a.
        expect(
          manifestContent,
          contains('bone: feature-a'),
          reason: 'B\'s manifest must declare dependency on feature-a',
        );
        // Shared entity is Product.
        expect(
          manifestContent,
          contains('Product'),
          reason: 'dependency must name the shared entity Product',
        );
      },
    );

    test(
      'A3: three-feature chain — C depends on B depends on A; manifest reflects the chain',
      () async {
        // feature-a declares Product (no deps)
        // feature-b declares Order, references Product from feature-a
        // feature-c declares Review, references Order from feature-b
        await copyFixture('feature-a', specsRoot.path);
        await copyFixture('feature-b', specsRoot.path);
        await copyFixture('feature-c', specsRoot.path);

        final outputDir = '${tmpDir.path}/bones';

        // Generate feature-c: it should depend on feature-b.
        final boneDirC = await generator.generate(
          specPath: File('${specsRoot.path}/feature-c/spec.md'),
          outputDir: outputDir,
          specsRoot: specsRoot.path,
        );

        final manifestC =
            await File('$boneDirC/bone.yaml').readAsString();

        // feature-c depends on feature-b (via Order reference).
        expect(
          manifestC,
          contains('bone: feature-b'),
          reason: 'C\'s manifest must declare dependency on feature-b',
        );
        // The shared entity is Order.
        expect(
          manifestC,
          contains('Order'),
          reason: 'dependency must name the shared entity Order',
        );

        // Generate feature-b: it should depend on feature-a.
        final boneDirB = await generator.generate(
          specPath: File('${specsRoot.path}/feature-b/spec.md'),
          outputDir: outputDir,
          specsRoot: specsRoot.path,
        );

        final manifestB =
            await File('$boneDirB/bone.yaml').readAsString();

        // feature-b depends on feature-a (via Product reference).
        expect(
          manifestB,
          contains('bone: feature-a'),
          reason: 'B\'s manifest must declare dependency on feature-a',
        );

        // Verify the chain order: A is standalone, B depends on A,
        // C depends on B. No circular dependency.
        expect(manifestC, isNot(contains('bone: feature-a')),
            reason: 'C depends on B, not directly on A');
      },
    );

    test(
      'A5: circular dependency fails generation naming cycle members, no output',
      () async {
        await copyFixture('cycle-a', specsRoot.path);
        await copyFixture('cycle-b', specsRoot.path);

        final outputDir = '${tmpDir.path}/bones';

        expect(
          () => generator.generate(
            specPath: File('${specsRoot.path}/cycle-a/spec.md'),
            outputDir: outputDir,
            specsRoot: specsRoot.path,
          ),
          throwsA(
            isA<BoneGenerationError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('cycle'),
                anyOf(contains('cycle-a'), contains('cycle-b')),
              ),
            ),
          ),
        );

        // No partial output left behind.
        expect(
          await Directory('$outputDir/cycle-a').exists(),
          isFalse,
          reason: 'no partial bone directory on cycle failure',
        );
      },
    );

    test(
      'A6: no cross-references → dependencies: []',
      () async {
        await copyFixture('standalone', specsRoot.path);

        final outputDir = '${tmpDir.path}/bones';
        final boneDir = await generator.generate(
          specPath: File('${specsRoot.path}/standalone/spec.md'),
          outputDir: outputDir,
          specsRoot: specsRoot.path,
        );

        final manifestContent =
            await File('$boneDir/bone.yaml').readAsString();
        expect(
          manifestContent,
          contains('dependencies: []'),
          reason: 'standalone bone must have empty dependencies',
        );
      },
    );
  });
}
