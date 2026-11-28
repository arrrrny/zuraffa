import 'package:test/test.dart';
import 'package:zuraffa/src/utils/zorphy_annotations.dart';

/// The v3 archetype vocabulary, as source text. Every scan that reads
/// entity sources (identity resolution, the build.yaml guard, the
/// build-relevance fingerprint) goes through this module — before it
/// existed, three separate regexes matched only v2 names that no longer
/// exist, and each scan was silently dead against the annotations the
/// generator itself emits.
void main() {
  const entity = '''
import 'package:zorphy_annotation/zorphy_annotation.dart';

part '../_br_/invoice.part.dart';

@ZorphyEntity(principalKey: #sku)
abstract class \$Invoice {
  String get sku;
}
''';

  group('the vocabulary', () {
    test('is exactly the five v3 class archetypes', () {
      expect(zorphyArchetypeNames, {
        'ZorphyEntity',
        'ZorphyState',
        'ZorphyUnion',
        'ZorphyIntent',
        'ZorphyValue',
      });
    });

    test('member annotations extend, never replace, the archetypes', () {
      expect(zorphyAnnotationNames, containsAll(zorphyArchetypeNames));
      expect(zorphyAnnotationNames.difference(zorphyArchetypeNames), {
        'ZorphyDomainBool',
        'ZorphyMock',
      });
    });
  });

  group('declaresZorphyArchetype', () {
    test('each archetype is recognised', () {
      for (final name in zorphyArchetypeNames) {
        expect(
          declaresZorphyArchetype('@$name()\nabstract class \$A {}'),
          isTrue,
          reason: '@$name must count as an archetype',
        );
      }
    });

    test('reads the annotation the entity scaffold writes', () {
      expect(declaresZorphyArchetype(entity), isTrue);
      expect(zorphyArchetypeOf(entity), 'ZorphyEntity');
    });

    test('member annotations alone do not make a class an archetype', () {
      expect(
        declaresZorphyArchetype(
          'class A {\n  @ZorphyDomainBool()\n  final bool ok = false;\n}',
        ),
        isFalse,
      );
      expect(
        hasZorphyAnnotation('@ZorphyMock()\nabstract class \$A {}'),
        isTrue,
      );
    });

    test('runtime classes that share the prefix are not archetypes', () {
      for (final src in [
        '@ZorphyField<String, String>()',
        '@ZorphyLens<A, String>()',
        'ZorphyFilter<String> f = ZorphyEquals();',
        'ZorphyEquals<A, String>()',
      ]) {
        expect(declaresZorphyArchetype(src), isFalse, reason: src);
        expect(hasZorphyAnnotation(src), isFalse, reason: src);
      }
    });

    test('the removed v2 names are not annotations any more', () {
      for (final src in [
        '@Zorphy()',
        '@Zorphy(generateJson: true)',
        '@ZValueObject',
      ]) {
        expect(declaresZorphyArchetype(src), isFalse, reason: src);
        expect(hasZorphyAnnotation(src), isFalse, reason: src);
      }
    });

    test('a comment mentioning an archetype classifies nothing', () {
      expect(
        declaresZorphyArchetype(
          '/// not @ZorphyValue()\nabstract class \$A {}',
        ),
        isFalse,
      );
      expect(
        declaresZorphyArchetype('/* @ZorphyUnion() */\nabstract class \$A {}'),
        isFalse,
      );
    });

    test('a class with no archetype has none', () {
      expect(zorphyArchetypeOf('abstract class \$A {}'), isNull);
    });
  });

  group('zorphySymbolArgument', () {
    test('reads a symbol argument off a multi-line annotation', () {
      expect(
        zorphySymbolArgument(
          '@ZorphyEntity(\n  principalKey: #id,\n)\nabstract class \$A {}',
          'ZorphyEntity',
          'principalKey',
        ),
        'id',
      );
      expect(
        zorphySymbolArgument(entity, 'ZorphyEntity', 'principalKey'),
        'sku',
      );
    });

    test('is null without the annotation or without the argument', () {
      expect(
        zorphySymbolArgument(entity, 'ZorphyValue', 'principalKey'),
        isNull,
      );
      expect(
        zorphySymbolArgument(
          '@ZorphyEntity()\nabstract class \$A {}',
          'ZorphyEntity',
          'principalKey',
        ),
        isNull,
      );
    });
  });

  group('sharedPartUri', () {
    test("mirrors the library's own path under build_runner's _br_", () {
      // The exact URI the zorphy scaffold writes for this library.
      expect(
        sharedPartUri('lib/src/domain/entities/note/note.dart'),
        '../../../../_br_/src/domain/entities/note/note.part.dart',
      );
      expect(sharedPartUri('lib/a/b.dart'), '../_br_/a/b.part.dart');
      expect(sharedPartPath('lib/a/b.dart'), 'lib/_br_/a/b.part.dart');
    });

    test('a library outside lib/ gets its part at the package root', () {
      expect(sharedPartUri('tool/gen.dart'), '../_br_/tool/gen.part.dart');
      expect(sharedPartPath('tool/gen.dart'), '_br_/tool/gen.part.dart');
    });

    test('a library directly under lib/ needs no parent hop', () {
      expect(sharedPartUri('lib/app.dart'), '_br_/app.part.dart');
    });

    test('accepts a native separator and normalizes dot segments', () {
      expect(
        sharedPartUri(r'lib\src\domain\.\entities\note\note.dart'),
        '../../../../_br_/src/domain/entities/note/note.part.dart',
      );
    });
  });

  group('stripComments', () {
    test('removes line and block comments', () {
      expect(stripComments('a // tail\n/* block\n block */ b'), 'a \n b');
    });
  });
}
