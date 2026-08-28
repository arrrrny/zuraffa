import 'package:test/test.dart';
import 'package:zuraffa/src/agent/ui_render/vocabulary_narrowing.dart';
import 'package:zuraffa/src/agent/ui_render/ui_vocabulary_schema.dart';

void main() {
  group('vocabularyNarrowing', () {
    test('returns base schema when mission type is null', () {
      final narrowed = vocabularyNarrowing(null, UiVocabularySchema.base);
      expect(identical(narrowed, UiVocabularySchema.base), isTrue,
          reason: 'no narrowing for null mission type');
    });

    test('returns base schema when mission type has no config', () {
      final narrowed = vocabularyNarrowing(
        'unknown_type',
        UiVocabularySchema.base,
      );
      expect(identical(narrowed, UiVocabularySchema.base), isTrue);
    });

    test('returns narrowed schema when mission type is configured', () {
      const listing = UiVocabularySchema(
        allowedNodeTypes: {'root', 'card', 'text', 'button'},
        allowedStyleTokens: {'primary', 'secondary'},
        nodeCap: 32,
        schemaVersion: '1.0.0-listing',
        missionType: 'listing',
      );
      const config = VocabularyNarrowingConfig({'listing': listing});

      final narrowed = vocabularyNarrowing(
        'listing',
        UiVocabularySchema.base,
        config: config,
      );
      expect(identical(narrowed, listing), isTrue);
      expect(narrowed.missionType, 'listing');
    });
  });

  group('VocabularyNarrowingConfig', () {
    test('hasNarrowingFor returns true for configured types', () {
      const listing = UiVocabularySchema(
        allowedNodeTypes: {'card'},
        allowedStyleTokens: {'primary'},
        nodeCap: 32,
      );
      const config = VocabularyNarrowingConfig({'listing': listing});

      expect(config.hasNarrowingFor('listing'), isTrue);
      expect(config.hasNarrowingFor('chat'), isFalse);
      expect(config.hasNarrowingFor(null), isFalse);
    });

    test('resolve returns narrowed schema for known mission type', () {
      const listing = UiVocabularySchema(
        allowedNodeTypes: {'card'},
        allowedStyleTokens: {'primary'},
        nodeCap: 32,
      );
      const config = VocabularyNarrowingConfig({'listing': listing});

      expect(identical(config.resolve('listing'), listing), isTrue);
      // Unknown mission type falls back to base.
      expect(identical(config.resolve('chat'), UiVocabularySchema.base), isTrue);
      // Null mission type also falls back to base.
      expect(identical(config.resolve(null), UiVocabularySchema.base), isTrue);
    });
  });

  group('narrowed schema validation (FR-005 acceptance 2)', () {
    test('vocabulary_narrowing_restricts_tool_schema', () {
      // US4 acceptance 1: "the ui.render tool input schema is narrowed to
      // exclude non-card nodes."
      const listing = UiVocabularySchema(
        allowedNodeTypes: {'root', 'card', 'text', 'button'},
        allowedStyleTokens: {'primary', 'secondary'},
        nodeCap: 32,
        schemaVersion: '1.0.0-listing',
        missionType: 'listing',
      );
      const config = VocabularyNarrowingConfig({'listing': listing});

      final active = vocabularyNarrowing(
        'listing',
        UiVocabularySchema.base,
        config: config,
      );

      // The narrowed schema excludes non-card nodes that the base allows.
      expect(active.allowedNodeTypes.contains('image'), isFalse);
      expect(active.allowedNodeTypes.contains('list'), isFalse);
      expect(active.allowedNodeTypes.contains('row'), isFalse);
      expect(active.allowedNodeTypes.contains('card'), isTrue);
      expect(active.allowedNodeTypes.contains('button'), isTrue);
    });

    test('vocabulary_narrowing_rejects_out_of_subset_node', () {
      const listing = UiVocabularySchema(
        allowedNodeTypes: {'root', 'card', 'text', 'button'},
        allowedStyleTokens: {'primary', 'secondary'},
        nodeCap: 32,
        schemaVersion: '1.0.0-listing',
        missionType: 'listing',
      );
      const config = VocabularyNarrowingConfig({'listing': listing});

      final active = vocabularyNarrowing(
        'listing',
        UiVocabularySchema.base,
        config: config,
      );

      // A tree containing an `image` node (out of subset) is rejected.
      const tree = UiNode(type: 'root', children: [
        UiNode(type: 'card', children: [
          UiNode(type: 'image'),
        ]),
      ]);
      final result = active.validate(tree);
      expect(result.valid, isFalse);
      expect(
        result.errors.any((e) =>
            e.kind == ValidationErrorKind.unknownNodeType &&
            e.nodeName == 'image'),
        isTrue,
        reason: 'image is out of the listing subset',
      );
    });

    test('a tree that lives within the narrowed subset is accepted', () {
      const listing = UiVocabularySchema(
        allowedNodeTypes: {'root', 'card', 'text', 'button'},
        allowedStyleTokens: {'primary', 'secondary'},
        nodeCap: 32,
        schemaVersion: '1.0.0-listing',
        missionType: 'listing',
      );
      const config = VocabularyNarrowingConfig({'listing': listing});

      final active = vocabularyNarrowing(
        'listing',
        UiVocabularySchema.base,
        config: config,
      );

      const tree = UiNode(type: 'root', children: [
        UiNode(type: 'card', styleToken: 'primary', children: [
          UiNode(type: 'text', props: {'label': 'Offer'}),
          UiNode(type: 'button', actionId: 'select_offer'),
        ]),
      ]);
      final result = active.validate(tree);
      expect(result.valid, isTrue, reason: '$result');
    });
  });
}
