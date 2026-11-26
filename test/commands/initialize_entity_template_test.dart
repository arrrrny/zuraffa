import 'package:test/test.dart';
import 'package:zuraffa/src/commands/initialize_command.dart';
import 'package:zuraffa/src/config/zfa_config.dart';
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

    test('declares the build_runner shared part for its own library path', () {
      final snake = 'product';
      expect(
        src,
        contains(
          "part '${sharedPartUri('${ZfaConfig.fixedEntityOutput}/$snake/$snake.dart')}'",
        ),
      );
    });

    test('carries none of the v2 surface', () {
      for (final v2 in [
        '@Zorphy(',
        'with _\$',
        '.zorphy.dart',
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
