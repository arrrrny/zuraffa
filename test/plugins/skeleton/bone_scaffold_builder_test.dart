/// Tests for BoneScaffoldBuilder (U15-U16).
///
/// Behaviors traced to test-list.md:
///   U15: emits domain/, data/, presentation/ placeholder files
///   U16: the barrel entry point exports every entity stub
///
/// Uses temporary directories; cleans up after.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/builders/bone_scaffold_builder.dart';
import 'package:zuraffa/src/plugins/skeleton/models/bone.dart';

void main() {
  late BoneScaffoldBuilder builder;
  late Directory tmpDir;

  setUp(() async {
    builder = BoneScaffoldBuilder();
    tmpDir = await Directory.systemTemp.createTemp('bone_scaffold_test_');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Bone makeBone({List<String> entities = const ['Product']}) {
    final entityStubs = entities
        .map(
          (e) => EntityStub(
            name: e,
            sourcePath: 'lib/entities/${_toSnake(e)}.dart',
          ),
        )
        .toList();

    final manifest = BoneManifest(
      version: 1,
      feature: 'test-feature',
      generatedAt: '2026-08-29T12:00:00.000Z',
      specVersion: 'sha256:${'a' * 64}',
      entities: entities,
      dependencies: [],
      layers: ['domain', 'data', 'presentation'],
    );

    return Bone(
      featureSlug: 'test-feature',
      featureName: 'TestFeature',
      rootDir: '${tmpDir.path}/test-feature',
      manifest: manifest,
      entityStubs: entityStubs,
      layers: [
        const LayerPlaceholder(layer: 'domain', path: 'domain/'),
        const LayerPlaceholder(layer: 'data', path: 'data/'),
        const LayerPlaceholder(layer: 'presentation', path: 'presentation/'),
      ],
    );
  }

  group('BoneScaffoldBuilder.build', () {
    test(
      'U15: emits domain/, data/, presentation/ placeholder files',
      () async {
        final bone = makeBone();
        final boneDir = '${tmpDir.path}/test-feature';

        await builder.build(bone, boneDir);

        for (final layer in ['domain', 'data', 'presentation']) {
          final dir = Directory('$boneDir/$layer');
          expect(await dir.exists(), isTrue, reason: '$layer/ directory must exist');
        }
      },
    );

    test(
      'U16: the barrel entry point exports every entity stub',
      () async {
        final bone = makeBone(entities: ['Product', 'CartItem']);
        final boneDir = '${tmpDir.path}/test-feature';

        await builder.build(bone, boneDir);

        final barrel = File('$boneDir/lib/test_feature.dart');
        expect(await barrel.exists(), isTrue, reason: 'barrel must exist');

        final content = barrel.readAsStringSync();
        expect(content, contains("export 'entities/product.dart'"));
        expect(content, contains("export 'entities/cart_item.dart'"));
      },
    );
    test(
      'U14-verify: barrel exports entities using snake_case paths derived from PascalCase names',
      () async {
        // Path derivation lives in BoneGenerator._toSnake (bone_generator.dart).
        // This test verifies the scaffold builder uses those paths in the barrel.
        final bone = makeBone(entities: ['CartItem', 'OrderItem']);
        final boneDir = '${tmpDir.path}/test-feature';

        await builder.build(bone, boneDir);

        final barrel = File('$boneDir/lib/test_feature.dart');
        final content = barrel.readAsStringSync();

        // CartItem → cart_item.dart, OrderItem → order_item.dart
        expect(
          content,
          contains("export 'entities/cart_item.dart'"),
          reason: 'CartItem path must be lib/entities/cart_item.dart',
        );
        expect(
          content,
          contains("export 'entities/order_item.dart'"),
          reason: 'OrderItem path must be lib/entities/order_item.dart',
        );
      },
    );

    test(
      'U17: emits one test-package scaffold per entity importing the bone barrel',
      () async {
        final bone = makeBone(entities: ['Product', 'CartItem']);
        final boneDir = '${tmpDir.path}/test-feature';

        await builder.build(bone, boneDir);

        // One test file per entity.
        final productTest = File('$boneDir/test/product_test.dart');
        final cartItemTest = File('$boneDir/test/cart_item_test.dart');

        expect(await productTest.exists(), isTrue,
            reason: 'product_test.dart must exist');
        expect(await cartItemTest.exists(), isTrue,
            reason: 'cart_item_test.dart must exist');

        // Each test imports the barrel.
        final productContent = productTest.readAsStringSync();
        expect(productContent, contains("import '../lib/test_feature.dart'"));

        final cartItemContent = cartItemTest.readAsStringSync();
        expect(cartItemContent, contains("import '../lib/test_feature.dart'"));
      },
    );
  });
}

String _toSnake(String name) {
  final result = name
      .replaceAll('-', '_')
      .replaceAllMapped(RegExp(r'([A-Z])'), (m) => '_${m.group(1)!.toLowerCase()}');
  return result.startsWith('_') ? result.substring(1) : result;
}
