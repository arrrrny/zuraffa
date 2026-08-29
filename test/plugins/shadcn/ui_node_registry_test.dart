import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/shadcn/vocabulary/ui_node_registry.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('zfa_ui_registry_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('NodeRegistry built-ins', () {
    test('covers the full built-in component set', () {
      final registry = NodeRegistry.builtInsOnly();
      const expected = {
        'root',
        'container',
        'card',
        'text',
        'heading',
        'button',
        'input',
        'textarea',
        'checkbox',
        'switch',
        'select',
        'option',
        'image',
        'avatar',
        'badge',
        'list',
        'row',
        'column',
        'divider',
        'progress',
        'slider',
        'tooltip',
        'alert',
        'label',
      };
      for (final name in expected) {
        expect(
          registry.contains(name),
          true,
          reason: 'built-in "$name" missing from the vocabulary',
        );
      }
    });

    test('definitions carry typed props with enums and defaults', () {
      final registry = NodeRegistry.builtInsOnly();
      final button = registry.definition('button');
      expect(button, isNotNull);
      expect(button!.props, contains('label'));
      expect(button.props, contains('variant'));
      final variant = button.props['variant']!;
      expect(variant.type, 'enum');
      expect(
        variant.enumValues,
        containsAll(['primary', 'secondary', 'outline', 'ghost', 'danger']),
      );
      expect(button.props['label']!.type, 'string');
    });

    test('definitions carry children constraints', () {
      final registry = NodeRegistry.builtInsOnly();
      final card = registry.definition('card')!;
      expect(card.children.max, greaterThan(0));
      final text = registry.definition('text')!;
      expect(text.children.max, 0, reason: 'leaf node must not allow children');
      final select = registry.definition('select')!;
      expect(select.children.allowedChildTypes, isNotNull);
      expect(select.children.allowedChildTypes, contains('option'));
    });

    test('reserved names equal the built-in key set (FR-007)', () {
      final registry = NodeRegistry.builtInsOnly();
      expect(registry.reservedNames, equals(registry.builtInNames.toSet()));
      expect(registry.reservedNames, contains('card'));
    });

    test('structural defaults: maxDepth and maxNodes', () {
      final registry = NodeRegistry.builtInsOnly();
      expect(registry.maxDepth, greaterThan(0));
      expect(registry.maxNodes, greaterThan(0));
    });
  });

  group('NodeRegistry composite loading', () {
    test(
      'composites load from .zfa/ui/components/*.json as first-class entries',
      () {
        final dir = Directory('${tempDir.path}/.zfa/ui/components')
          ..createSync(recursive: true);
        File('${dir.path}/offer_card.json').writeAsStringSync(
          jsonEncode({
            'name': 'offer_card',
            'category': 'composite',
            'props': {
              'title': {'type': 'string'},
              'discount': {'type': 'number'},
            },
            'children': {'min': 0, 'max': 4},
          }),
        );

        final registry = NodeRegistry.load(projectRoot: tempDir.path);
        expect(registry.contains('offer_card'), true);
        expect(registry.isComposite('offer_card'), true);
        expect(
          registry.definition('offer_card')!.props['title']!.type,
          'string',
        );
        // Built-ins still present.
        expect(registry.contains('card'), true);
      },
    );

    test('missing components directory yields empty composite set', () {
      final registry = NodeRegistry.load(projectRoot: tempDir.path);
      expect(registry.compositeNames, isEmpty);
      expect(registry.contains('card'), true);
    });

    test('malformed registration surfaces a clear error', () {
      final dir = Directory('${tempDir.path}/.zfa/ui/components')
        ..createSync(recursive: true);
      File('${dir.path}/broken.json').writeAsStringSync('{not json');

      expect(
        () => NodeRegistry.load(projectRoot: tempDir.path),
        throwsA(
          isA<NodeRegistryException>().having(
            (e) => e.message,
            'message',
            allOf(contains('broken.json'), contains('JSON')),
          ),
        ),
      );
    });

    test('registration without a name surfaces a clear error', () {
      final dir = Directory('${tempDir.path}/.zfa/ui/components')
        ..createSync(recursive: true);
      File(
        '${dir.path}/anon.json',
      ).writeAsStringSync(jsonEncode({'props': {}}));

      expect(
        () => NodeRegistry.load(projectRoot: tempDir.path),
        throwsA(
          isA<NodeRegistryException>().having(
            (e) => e.message,
            'message',
            allOf(contains('anon.json'), contains('name')),
          ),
        ),
      );
    });
  });
}
