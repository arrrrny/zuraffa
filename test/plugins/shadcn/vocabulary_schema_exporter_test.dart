import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/shadcn/vocabulary/ui_node_registry.dart';
import 'package:zuraffa/src/plugins/shadcn/vocabulary/vocabulary_schema_exporter.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('zfa_ui_export_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('VocabularySchemaExporter', () {
    test(
      'export shape: schemaVersion + components + rules + tokens + grammar',
      () {
        final export = VocabularySchemaExporter(
          NodeRegistry.builtInsOnly(),
        ).export();

        expect(export['schemaVersion'], isA<String>());
        expect(
          RegExp(
            r'^\d+\.\d+\.\d+$',
          ).hasMatch(export['schemaVersion'] as String),
          true,
          reason: 'schemaVersion must be semver-compatible',
        );

        final components = export['components'] as Map<String, dynamic>;
        expect(components.keys, containsAll(['card', 'button', 'text']));
        // Every component definition is a self-contained JSON-Schema object.
        final card = components['card'] as Map<String, dynamic>;
        expect(card['type'], 'object');
        expect(card, contains('properties'));
        expect(card, contains('required'));
        expect(card, contains('children'));
        // Props carried as JSON-Schema properties.
        expect(card['properties'], isA<Map<String, dynamic>>());

        final rules = export['structuralRules'] as Map<String, dynamic>;
        expect(rules['maxDepth'], greaterThan(0));
        expect(rules['maxNodes'], greaterThan(0));

        expect(export['styleTokens'], isA<List<dynamic>>());
        expect(export['styleTokens'] as List, contains('primary'));

        final grammar = export['actionIdGrammar'] as Map<String, dynamic>;
        expect(grammar['pattern'], isA<String>());

        final nesting = export['nestingRules'] as Map<String, dynamic>;
        expect(nesting.keys, isNotEmpty);
      },
    );

    test('diff-stable: consecutive exports are byte-identical (SC-001)', () {
      final exporter = VocabularySchemaExporter(NodeRegistry.builtInsOnly());
      final first = exporter.exportJson();
      final second = exporter.exportJson();
      expect(second, equals(first));

      // Also stable across two exporter instances.
      final third = VocabularySchemaExporter(
        NodeRegistry.builtInsOnly(),
      ).exportJson();
      expect(third, equals(first));
    });

    test('version bump changes the export (US-5 scenario 2)', () {
      final v1 = VocabularySchemaExporter(
        NodeRegistry.builtInsOnly(),
      ).exportJson();
      final v2 = VocabularySchemaExporter(
        NodeRegistry.builtInsOnly(),
        schemaVersion: '2.0.0',
      ).exportJson();
      expect(v2, isNot(equals(v1)));
      final decoded = jsonDecode(v2) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], '2.0.0');
    });

    test('empty registry produces a minimal valid schema (Edge Cases)', () {
      final registry = NodeRegistry.empty();
      final export = VocabularySchemaExporter(registry).export();
      expect(export['schemaVersion'], isA<String>());
      expect(export['components'], isEmpty);
      expect(export['structuralRules'], isNotNull);
    });

    test(
      'composites appear alongside built-ins in the export (US-2 scenario 2)',
      () {
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
        final export = VocabularySchemaExporter(registry).export();
        final components = export['components'] as Map<String, dynamic>;
        expect(components.keys, contains('offer_card'));
        expect(components.keys, contains('card'));
        final composite = components['offer_card'] as Map<String, dynamic>;
        expect(
          (composite['properties'] as Map<String, dynamic>).keys,
          contains('title'),
        );
      },
    );
  });

  group('UiRenderInputSchema (SC-004)', () {
    test('ui.render tree input schema derives from the export as-is', () {
      final export = VocabularySchemaExporter(
        NodeRegistry.builtInsOnly(),
      ).export();

      final toolSchema = UiRenderInputSchema.fromExport(export);
      final nodeSchema = toolSchema['tree'] as Map<String, dynamic>;

      // The node-type enum comes straight from the exported components.
      final typeEnum =
          ((nodeSchema['properties'] as Map<String, dynamic>)['type']
                  as Map<String, dynamic>)['enum']
              as List<dynamic>;
      expect(typeEnum, contains('card'));
      expect(typeEnum, contains('button'));
      expect(typeEnum.length, (export['components'] as Map).length);

      // Style token enum and action grammar flow through unchanged.
      final styleEnum =
          ((nodeSchema['properties'] as Map<String, dynamic>)['styleToken']
                  as Map<String, dynamic>)['enum']
              as List<dynamic>;
      expect(styleEnum, contains('primary'));
      final actionPattern =
          ((nodeSchema['properties'] as Map<String, dynamic>)['actionId']
              as Map<String, dynamic>)['pattern'];
      expect(actionPattern, (export['actionIdGrammar'] as Map)['pattern']);

      // A consumer validates trees against the derived schema.
      expect(
        UiRenderInputSchema.validateTree(toolSchema, {
          'type': 'card',
          'children': [
            {
              'type': 'text',
              'props': {'value': 'hi'},
            },
          ],
        }),
        isNull,
        reason: 'valid tree must pass the derived input schema',
      );
      final violation = UiRenderInputSchema.validateTree(toolSchema, {
        'type': 'ghost_node',
      });
      expect(violation, isNotNull);
      expect(violation, contains('ghost_node'));
    });

    test('derived schema carries structuralRules and enforces maxDepth', () {
      final registry = NodeRegistry.builtInsOnly();
      final export = VocabularySchemaExporter(registry).export();
      final toolSchema = UiRenderInputSchema.fromExport(export);

      // SC-004: the rules must survive the derivation, otherwise validateTree
      // has no cap to enforce and silently accepts trees the authoritative
      // UiPayloadValidator rejects.
      final rules = toolSchema['structuralRules'] as Map<String, dynamic>;
      expect(rules['maxDepth'], registry.maxDepth);
      expect(rules['maxNodes'], registry.maxNodes);

      // A tree deeper than the vocabulary's cap is rejected, naming the real
      // cap rather than the old hardcoded 64 fallback.
      Map<String, dynamic> deep = {
        'type': 'text',
        'props': {'value': 'hi'},
      };
      for (var i = 0; i < registry.maxDepth + 3; i++) {
        deep = {
          'type': 'container',
          'children': [deep],
        };
      }
      final tooDeep = UiRenderInputSchema.validateTree(toolSchema, deep);
      expect(tooDeep, isNotNull);
      expect(tooDeep, contains('maxDepth ${registry.maxDepth}'));

      // The recursive child reference must resolve to the published node.
      final childrenSchema =
          ((toolSchema['tree'] as Map<String, dynamic>)['properties']
                  as Map<String, dynamic>)['children']
              as Map<String, dynamic>;
      expect((childrenSchema['items'] as Map)[r'$ref'], '#/tree');
    });
  });
}
