import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/shadcn/vocabulary/payload_validator.dart';
import 'package:zuraffa/src/plugins/shadcn/vocabulary/ui_node_registry.dart';

void main() {
  late Directory tempDir;
  late UiPayloadValidator validator;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('zfa_ui_validate_');
    validator = UiPayloadValidator(NodeRegistry.builtInsOnly());
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Map<String, dynamic> payload(
    Map<String, dynamic> tree, {
    String? schemaVersion,
  }) => {'schemaVersion': ?schemaVersion, 'tree': tree};

  Map<String, dynamic> node(
    String type, {
    Map<String, Object?>? props,
    List<Map<String, dynamic>>? children,
    String? styleToken,
    String? actionId,
  }) => {
    'type': type,
    'props': ?props,
    'children': ?children,
    'styleToken': ?styleToken,
    'actionId': ?actionId,
  };

  group('UiPayloadValidator', () {
    test('valid payload passes (US-3 scenario 1)', () {
      final result = validator.validate(
        payload(
          node(
            'card',
            children: [
              node('text', props: {'value': 'Hello'}),
              node(
                'button',
                props: {'label': 'Select', 'variant': 'primary'},
                actionId: 'product.select_offer',
              ),
            ],
          ),
        ),
      );
      expect(result.valid, true, reason: '${result.errors}');
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('unknown node identified by name and position (US-3 scenario 2)', () {
      final result = validator.validate(
        payload(node('card', children: [node('text'), node('ghost_node')])),
      );
      expect(result.valid, false);
      final error = result.errors.firstWhere(
        (e) => e.kind == ValidationErrorCategory.unknownNode,
      );
      expect(error.message, contains('ghost_node'));
      expect(error.path, contains('card'));
      expect(error.path, contains('ghost_node'));
    });

    test('bad token reports offender and allowed set', () {
      final result = validator.validate(
        payload(node('card', styleToken: 'sparkly')),
      );
      expect(result.valid, false);
      final error = result.errors.firstWhere(
        (e) => e.kind == ValidationErrorCategory.badToken,
      );
      expect(error.message, contains('sparkly'));
      expect(error.message, contains('primary'));
    });

    test(
      'raw color detected in styleToken with token suggestion (US-3 scenario 4)',
      () {
        final result = validator.validate(
          payload(node('card', styleToken: '#ff0000')),
        );
        expect(result.valid, false);
        final error = result.errors.firstWhere(
          (e) => e.kind == ValidationErrorCategory.rawColor,
        );
        expect(error.message, contains('#ff0000'));
        expect(error.message.toLowerCase(), contains('token'));
      },
    );

    test('raw color detected in prop values', () {
      final result = validator.validate(
        payload(
          node(
            'card',
            children: [
              node('text', props: {'value': 'hi', 'color': 'rgb(255, 0, 0)'}),
            ],
          ),
        ),
      );
      expect(result.valid, false);
      expect(
        result.errors.any((e) => e.kind == ValidationErrorCategory.rawColor),
        true,
      );
    });

    test('depth cap pinpoints the deep path', () {
      Map<String, dynamic> deep = node('text');
      for (var i = 0; i < 15; i++) {
        deep = node('container', children: [deep]);
      }
      final result = validator.validate(payload(deep));
      expect(result.valid, false);
      final error = result.errors.firstWhere(
        (e) => e.kind == ValidationErrorCategory.depthCap,
      );
      expect(error.message, contains('depth'));
    });

    test('a tree exactly at maxDepth with empty children is accepted', () {
      final registry = NodeRegistry.builtInsOnly();
      // maxDepth nodes deep, deepest one carrying an empty children list —
      // the cap must count depth, not the presence of a children key.
      Map<String, dynamic> tree = node('container', children: []);
      for (var i = 0; i < registry.maxDepth - 1; i++) {
        tree = node('container', children: [tree]);
      }
      final result = UiPayloadValidator(registry).validate(payload(tree));
      expect(
        result.errors.where((e) => e.kind == ValidationErrorCategory.depthCap),
        isEmpty,
        reason: 'depth $registry.maxDepth is the maximum, not a violation',
      );
    });

    test('a non-string schemaVersion is ignored, not a crash', () {
      // The payload is user-supplied JSON; a numeric schemaVersion used to
      // escape as an uncaught CastError instead of a validation result.
      final result = validator.validate({
        'schemaVersion': 1,
        'tree': node('text', props: {'value': 'hi'}),
      });
      expect(result.valid, true);
      expect(result.errors, isEmpty);
    });

    test('count cap reports actual vs cap', () {
      final children = List.generate(
        300,
        (i) => node('text', props: {'value': 'n$i'}),
      );
      final result = validator.validate(
        payload(node('list', children: children)),
      );
      expect(result.valid, false);
      final error = result.errors.firstWhere(
        (e) => e.kind == ValidationErrorCategory.countCap,
      );
      expect(error.message, contains('301')); // 300 children + the list node
    });

    test('invalid action id reports the grammar (US-3 scenario 5)', () {
      final result = validator.validate(
        payload(
          node('button', props: {'label': 'Go'}, actionId: 'Select Offer!'),
        ),
      );
      expect(result.valid, false);
      final error = result.errors.firstWhere(
        (e) => e.kind == ValidationErrorCategory.invalidAction,
      );
      expect(error.message, contains('Select Offer!'));
      expect(error.message, contains('a-z'));
    });

    test('valid dotted action id passes', () {
      final result = validator.validate(
        payload(
          node(
            'button',
            props: {'label': 'Go'},
            actionId: 'product.select_offer',
          ),
        ),
      );
      expect(result.valid, true, reason: '${result.errors}');
    });

    test('invalid nesting pinpoints parent/child and the constraint', () {
      final result = validator.validate(
        payload(node('select', children: [node('card')])),
      );
      expect(result.valid, false);
      final error = result.errors.firstWhere(
        (e) => e.kind == ValidationErrorCategory.invalidNesting,
      );
      expect(error.message, contains('select'));
      expect(error.message, contains('card'));
      expect(error.message, contains('option'));
    });

    test('children count cap (per-node max) is a nesting violation', () {
      // text allows no children.
      final result = validator.validate(
        payload(node('text', children: [node('text')])),
      );
      expect(result.valid, false);
      expect(
        result.errors.any(
          (e) => e.kind == ValidationErrorCategory.invalidNesting,
        ),
        true,
      );
    });

    test(
      'all violations reported in one pass (SC-003, zero false negatives)',
      () {
        final result = validator.validate(
          payload(
            node(
              'card',
              children: [
                node('ghost_node'),
                node(
                  'text',
                  styleToken: 'neon',
                  children: [node('button', actionId: 'BAD ACTION')],
                ),
              ],
            ),
          ),
        );
        expect(result.valid, false);
        expect(
          result.errors.any(
            (e) => e.kind == ValidationErrorCategory.unknownNode,
          ),
          true,
        );
        expect(
          result.errors.any((e) => e.kind == ValidationErrorCategory.badToken),
          true,
        );
        expect(
          result.errors.any(
            (e) => e.kind == ValidationErrorCategory.invalidNesting,
          ),
          true,
        );
        expect(
          result.errors.any(
            (e) => e.kind == ValidationErrorCategory.invalidAction,
          ),
          true,
        );
      },
    );

    test('invalid JSON surfaces a parse error with path (Edge Cases)', () {
      final file = File('${tempDir.path}/bad.json')
        ..writeAsStringSync('{not json');
      expect(
        () => validator.validateFile(file.path),
        throwsA(
          isA<UiPayloadParseException>().having(
            (e) => e.message,
            'message',
            allOf(contains('bad.json'), contains('JSON')),
          ),
        ),
      );
    });

    test('pin mismatch is a warning, not an error (US-5 scenario 3)', () {
      final result = validator.validate(
        payload(node('text', props: {'value': 'x'}), schemaVersion: '0.9.0'),
      );
      expect(result.valid, true);
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first, contains('0.9.0'));
      expect(result.warnings.first, contains(validator.schemaVersion));
    });

    test('payload with composite from a registry validates', () {
      final dir = Directory('${tempDir.path}/.zfa/ui/components')
        ..createSync(recursive: true);
      File('${dir.path}/offer_card.json').writeAsStringSync(
        jsonEncode({
          'name': 'offer_card',
          'category': 'composite',
          'props': {
            'title': {'type': 'string'},
          },
          'children': {'min': 0, 'max': 4},
        }),
      );
      final registry = NodeRegistry.load(projectRoot: tempDir.path);
      final compositeValidator = UiPayloadValidator(registry);
      final result = compositeValidator.validate(
        payload(
          node(
            'offer_card',
            props: {'title': 'Sale'},
            children: [
              node('text', props: {'value': 'y'}),
            ],
          ),
        ),
      );
      expect(result.valid, true, reason: '${result.errors}');
    });
  });
}
