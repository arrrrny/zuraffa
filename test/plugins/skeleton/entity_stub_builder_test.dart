/// Tests for EntityStubBuilder (real entity emission, 042 working slice).
///
/// Behaviors traced to specs/042-bone-working-slice/tdd/test-list.md:
///   042-U9:  emits final fields + const constructor
///   042-U10: fromJson coerces String/int/double/bool/List/Map/DateTime
///   042-U11: toJson inverts fromJson (round-trippable)
///   042-U12: copyWith overrides only provided fields
///   042-U13: validate flags blank/missing required fields
///   042-U14: nullable fields skipped by validate
///   042-U15: field-less entity emits valid empty-args shape
///
/// Legacy 020 behaviors U13/U14 (empty stub emission) were retired by this
/// feature: the seed issue #592 explicitly calls empty stubs inadequate.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/builders/entity_stub_builder.dart';
import 'package:zuraffa/src/plugins/skeleton/models/bone.dart';

void main() {
  late EntityStubBuilder builder;

  setUp(() {
    builder = EntityStubBuilder();
  });

  group('EntityStubBuilder.build (042 real entities)', () {
    test('042-U9: emits final fields + const constructor', () {
      final source = builder.build(
        const EntityStub(
          name: 'User',
          fields: [
            EntityField(name: 'id', type: 'String'),
            EntityField(name: 'displayName', type: 'String'),
            EntityField(name: 'email', type: 'String', nullable: true),
          ],
          sourcePath: 'entities/user.dart',
        ),
      );

      expect(source, contains('class User'));
      expect(source, contains('final String id;'));
      expect(source, contains('final String displayName;'));
      expect(source, contains('final String? email;'));
      expect(source, contains('const User({'));
      expect(source, contains('required this.id'));
      expect(source, contains('required this.displayName'));
      expect(source, contains('this.email'));
      expect(source, isNot(contains('required this.email')));
      // Not an empty stub anymore.
      expect(source, isNot(contains('class User {}')));
    });

    test('042-U10: fromJson coerces every supported type', () {
      final source = builder.build(
        const EntityStub(
          name: 'Everything',
          fields: [
            EntityField(name: 's', type: 'String'),
            EntityField(name: 'i', type: 'int'),
            EntityField(name: 'd', type: 'double'),
            EntityField(name: 'n', type: 'num'),
            EntityField(name: 'b', type: 'bool'),
            EntityField(name: 'l', type: 'List<String>'),
            EntityField(name: 'm', type: 'Map<String, dynamic>'),
            EntityField(name: 'dt', type: 'DateTime'),
            EntityField(name: 'opt', type: 'int', nullable: true),
            EntityField(name: 'optd', type: 'double', nullable: true),
          ],
          sourcePath: 'entities/everything.dart',
        ),
      );

      expect(source, contains('factory Everything.fromJson'));
      expect(source, contains("json['s'] as String"));
      expect(source, contains('as num).toInt()'));
      expect(source, contains('as num).toDouble()'));
      expect(source, contains("json['n'] as num"));
      expect(source, contains("json['b'] as bool"));
      expect(source, contains('whereType<String>()'));
      expect(source, contains("Map<String, dynamic>.from("));
      expect(source, contains('DateTime.parse('));
      expect(source, contains('as num?)?.toInt()'));
      expect(source, contains('as num?)?.toDouble()'));
    });

    test('042-U11: toJson inverts fromJson', () {
      final source = builder.build(
        const EntityStub(
          name: 'User',
          fields: [
            EntityField(name: 'id', type: 'String'),
            EntityField(name: 'createdAt', type: 'DateTime'),
            EntityField(name: 'email', type: 'String', nullable: true),
          ],
          sourcePath: 'entities/user.dart',
        ),
      );

      expect(source, contains("Map<String, dynamic> toJson()"));
      expect(source, contains("'id': id"));
      expect(source, contains('toIso8601String()'));
    });

    test('042-U12: copyWith overrides only provided fields', () {
      final source = builder.build(
        const EntityStub(
          name: 'User',
          fields: [
            EntityField(name: 'id', type: 'String'),
            EntityField(name: 'displayName', type: 'String'),
          ],
          sourcePath: 'entities/user.dart',
        ),
      );

      expect(source, contains('User copyWith({'));
      expect(source, contains('String? id'));
      expect(source, contains('id ?? this.id'));
      expect(source, contains('displayName ?? this.displayName'));
    });

    test('042-U13: validate flags blank required fields', () {
      final source = builder.build(
        const EntityStub(
          name: 'User',
          fields: [
            EntityField(name: 'id', type: 'String'),
            EntityField(name: 'displayName', type: 'String'),
          ],
          sourcePath: 'entities/user.dart',
        ),
      );

      expect(source, contains('List<String> validateUser(User instance)'));
      expect(source, contains("instance.id.trim().isEmpty"));
      expect(source, contains("'id must not be blank'"));
      expect(source, contains("'displayName must not be blank'"));
    });

    test('042-U14: nullable fields are skipped by validate', () {
      final source = builder.build(
        const EntityStub(
          name: 'User',
          fields: [
            EntityField(name: 'id', type: 'String'),
            EntityField(name: 'email', type: 'String', nullable: true),
          ],
          sourcePath: 'entities/user.dart',
        ),
      );

      expect(source, isNot(contains('email must not be blank')));
      expect(source, isNot(contains('instance.email.trim()')));
    });

    test(
      '042-U15: field-less entity emits valid fromJson/toJson/validate shape',
      () {
        final source = builder.build(
          const EntityStub(
            name: 'Product',
            sourcePath: 'entities/product.dart',
          ),
        );

        expect(source, contains('class Product'));
        expect(source, contains('const Product()'));
        expect(source, contains('factory Product.fromJson'));
        expect(source, contains('toJson()'));
        expect(source, contains('validateProduct(Product instance)'));
        expect(source, isNot(contains('class Product {}')));
      },
    );
  });
}
