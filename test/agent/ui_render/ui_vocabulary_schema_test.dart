import 'package:test/test.dart';
import 'package:zuraffa/src/agent/ui_render/ui_vocabulary_schema.dart';

void main() {
  group('UiVocabularySchema', () {
    group('validate', () {
      test('valid tree passes', () {
        const tree = UiNode(
          type: 'root',
          children: [
            UiNode(
              type: 'card',
              styleToken: 'primary',
              children: [
                UiNode(type: 'text', props: {'label': 'Hello'}),
                UiNode(type: 'button', actionId: 'tap_1'),
              ],
            ),
          ],
        );
        final result = UiVocabularySchema.base.validate(tree);
        expect(result.valid, isTrue, reason: '$result');
      });

      test('empty_tree_rejected — root with no children and no props', () {
        const tree = UiNode(type: 'root');
        final result = UiVocabularySchema.base.validate(tree);
        expect(result.valid, isFalse);
        expect(
          result.errors.any((e) => e.kind == ValidationErrorKind.emptyTree),
          isTrue,
          reason: 'should include an emptyTree error',
        );
      });

      test('unknown node type is flagged', () {
        const tree = UiNode(
          type: 'root',
          children: [UiNode(type: 'mystery_widget')],
        );
        final result = UiVocabularySchema.base.validate(tree);
        expect(result.valid, isFalse);
        expect(
          result.errors.any(
            (e) =>
                e.kind == ValidationErrorKind.unknownNodeType &&
                e.nodeName == 'mystery_widget',
          ),
          isTrue,
        );
      });

      test('invalid style token is flagged', () {
        const tree = UiNode(
          type: 'root',
          children: [UiNode(type: 'card', styleToken: 'rainbow')],
        );
        final result = UiVocabularySchema.base.validate(tree);
        expect(result.valid, isFalse);
        expect(
          result.errors.any(
            (e) =>
                e.kind == ValidationErrorKind.invalidToken &&
                e.badToken == 'rainbow',
          ),
          isTrue,
        );
      });

      test('cap overflow is flagged', () {
        final children = List<UiNode>.generate(
          10,
          (i) => const UiNode(type: 'text'),
        );
        final schema = const UiVocabularySchema(
          allowedNodeTypes: {'root', 'text'},
          allowedStyleTokens: {},
          nodeCap: 5,
        );
        final tree = UiNode(type: 'root', children: children);
        final result = schema.validate(tree);
        expect(result.valid, isFalse);
        expect(
          result.errors.any((e) => e.kind == ValidationErrorKind.capOverflow),
          isTrue,
          reason: 'tree has 11 nodes, cap is 5',
        );
      });

      test('multiple errors surface in a single pass', () {
        const tree = UiNode(
          type: 'root',
          children: [
            UiNode(type: 'mystery_widget'),
            UiNode(type: 'card', styleToken: 'rainbow'),
          ],
        );
        final result = UiVocabularySchema.base.validate(tree);
        expect(result.valid, isFalse);
        expect(result.errors.length, greaterThanOrEqualTo(2));
      });
    });
  });
}
