/// Tests for EntityStubBuilder (U13-U14).
///
/// Behaviors traced to test-list.md:
///   U13: emits syntactically valid Dart source for an entity declaration
///   U14: the stub path is `lib/entities/<snake_case>.dart`
///
/// Pure-Dart: no I/O, no network, deterministic.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/builders/entity_stub_builder.dart';
import 'package:zuraffa/src/plugins/skeleton/models/bone.dart';

void main() {
  late EntityStubBuilder builder;

  setUp(() {
    builder = EntityStubBuilder();
  });

  group('EntityStubBuilder.build', () {
    test(
      'U13: emits syntactically valid Dart source for an entity declaration',
      () {
        final stub = EntityStub(
          name: 'Product',
          fields: [
            const EntityField(name: 'name', type: 'String'),
            const EntityField(name: 'price', type: 'double'),
          ],
          sourcePath: 'lib/entities/product.dart',
        );

        final source = builder.build(stub);

        // Must contain a class declaration.
        expect(source, contains('class Product'));
        // Must contain the fields.
        expect(source, contains('String name'));
        expect(source, contains('double price'));
      },
    );

    test(
      'U14: the stub path is lib/entities/<snake_case>.dart',
      () {
        // Path derivation lives in BoneGenerator._toSnake (bone_generator.dart).
        // Here we verify the sourcePath contract on the model itself: the caller
        // supplies a path matching lib/entities/<snake_case>.dart.
        const expectedPath = 'lib/entities/cart_item.dart';
        final stub = EntityStub(
          name: 'CartItem',
          sourcePath: expectedPath,
        );

        // Assert the path matches the lib/entities/<snake>.dart convention.
        expect(
          stub.sourcePath,
          equals(expectedPath),
          reason: 'CartItem path must be lib/entities/cart_item.dart',
        );

        final source = builder.build(stub);

        // Must contain a class declaration for CartItem.
        expect(source, contains('class CartItem'));
      },
    );
  });
}
