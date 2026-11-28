import 'package:test/test.dart';
import 'package:zuraffa/src/commands/initialize_command.dart';
import 'package:zuraffa/src/utils/zorphy_annotations.dart';

/// The entity `zfa init` scaffolds must be a source the zorphy v3 builder
/// accepts. The template once emitted the v2 shape (`@Zorphy(json: ...)`,
/// `with _$X`, `part 'x.zorphy.dart'`), which v3 cannot compile: every
/// property pinned here is one the builder or the identity resolver reads.
void main() {
  const entityName = 'Product';
  late String src;

  setUpAll(() {
    src = InitializeCommand.generateEntityContent(entityName);
  });

  group('InitializeCommand.generateEntityContent (zorphy v3)', () {
    test('is a @ZorphyEntity whose principalKey names a declared field', () {
      expect(src, contains('@ZorphyEntity(principalKey: #id)'));
      expect(src, contains('String get id;'));
      expect(zorphyArchetypeOf(src), 'ZorphyEntity');
      expect(zorphySymbolArgument(src, 'ZorphyEntity', 'principalKey'), 'id');
    });

    test('declares the colocated part emitted by the v3 builder', () {
      expect(src, contains("part 'product.zorphy.dart';"));
      expect(src, isNot(contains('_br_/')));
    });

    test('carries none of the v2 surface', () {
      for (final v2 in [
        '@Zorphy(',
        'with _\$',
        '_br_/',
        'FromJson(',
        'package:zorphy_annotation/zorphy.dart',
      ]) {
        expect(src, isNot(contains(v2)), reason: v2);
      }
    });

    test('declares the sample fields as abstract getters', () {
      expect(src, contains('abstract class \$Product'));
      for (final field in [
        'String get name;',
        'String? get description;',
        'double get price;',
        'String? get category;',
        'bool get isActive;',
        'DateTime get createdAt;',
        'DateTime? get updatedAt;',
      ]) {
        expect(src, contains(field));
      }
    });
  });
}
