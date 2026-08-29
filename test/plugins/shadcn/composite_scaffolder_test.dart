import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/shadcn/vocabulary/composite_scaffolder.dart';
import 'package:zuraffa/src/plugins/shadcn/vocabulary/ui_node_registry.dart';
import 'package:zuraffa/src/plugins/shadcn/vocabulary/vocabulary_schema_exporter.dart';

void main() {
  late Directory tempDir;
  late NodeRegistry registry;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('zfa_ui_scaffold_');
    registry = NodeRegistry.load(projectRoot: tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('CompositeScaffolder', () {
    test('scaffold writes node entity, renderer extension and registration',
        () async {
      final result = await CompositeScaffolder().scaffold(
        'OfferCard',
        projectRoot: tempDir.path,
        registry: registry,
      );

      expect(result.writtenFiles, hasLength(3));

      final entity =
          File('${tempDir.path}/lib/src/ui/nodes/offer_card_node.dart');
      final renderer =
          File('${tempDir.path}/lib/src/ui/renderers/offer_card_renderer.dart');
      final registration =
          File('${tempDir.path}/.zfa/ui/components/offer_card.json');

      expect(entity.existsSync(), true, reason: 'node entity missing');
      expect(renderer.existsSync(), true, reason: 'renderer missing');
      expect(registration.existsSync(), true, reason: 'registration missing');

      final entitySource = entity.readAsStringSync();
      expect(entitySource, contains('class OfferCardNode'));
      expect(entitySource, contains('UiNode'));

      final rendererSource = renderer.readAsStringSync();
      expect(rendererSource, contains('OfferCard'));

      final registrationJson =
          jsonDecode(registration.readAsStringSync()) as Map<String, dynamic>;
      expect(registrationJson['name'], 'offer_card');
    });

    test('scaffolded composite is a first-class vocabulary entry (SC-002)',
        () async {
      await CompositeScaffolder().scaffold(
        'OfferCard',
        projectRoot: tempDir.path,
        registry: registry,
      );

      final reloaded = NodeRegistry.load(projectRoot: tempDir.path);
      expect(reloaded.contains('offer_card'), true);
      expect(reloaded.isComposite('offer_card'), true);

      // Appears in the export alongside built-ins.
      final export = VocabularySchemaExporter(reloaded).export();
      expect(
        (export['components'] as Map).keys,
        contains('offer_card'),
      );
    });

    test('payload referencing the composite validates (US-2 scenario 3)',
        () async {
      await CompositeScaffolder().scaffold(
        'OfferCard',
        projectRoot: tempDir.path,
        registry: registry,
      );
      final reloaded = NodeRegistry.load(projectRoot: tempDir.path);
      final export = VocabularySchemaExporter(reloaded).export();
      // The composite node type is part of the allowed vocabulary.
      final components = export['components'] as Map;
      expect(components.containsKey('offer_card'), true);
    });

    test('reserved built-in names rejected with the reserved list (FR-007)',
        () async {
      expect(
        () => CompositeScaffolder().scaffold(
          'Card',
          projectRoot: tempDir.path,
          registry: registry,
        ),
        throwsA(isA<CompositeScaffoldException>().having(
          (e) => e.message,
          'message',
          allOf(contains('Card'), contains('reserved'), contains('button')),
        )),
      );
    });

    test('existing registration conflict rejected (Edge Cases)', () async {
      await CompositeScaffolder().scaffold(
        'OfferCard',
        projectRoot: tempDir.path,
        registry: registry,
      );
      expect(
        () => CompositeScaffolder().scaffold(
          'OfferCard',
          projectRoot: tempDir.path,
          registry: registry,
        ),
        throwsA(isA<CompositeScaffoldException>().having(
          (e) => e.message,
          'message',
          allOf(contains('OfferCard'), contains('exists')),
        )),
      );
    });

    test('force overwrites an existing composite', () async {
      await CompositeScaffolder().scaffold(
        'OfferCard',
        projectRoot: tempDir.path,
        registry: registry,
      );
      final result = await CompositeScaffolder().scaffold(
        'OfferCard',
        projectRoot: tempDir.path,
        registry: registry,
        force: true,
      );
      expect(result.writtenFiles, hasLength(3));
    });

    test('invalid names rejected', () async {
      expect(
        () => CompositeScaffolder().scaffold(
          'offerCard',
          projectRoot: tempDir.path,
          registry: registry,
        ),
        throwsA(isA<CompositeScaffoldException>().having(
          (e) => e.message,
          'message',
          contains('PascalCase'),
        )),
      );
    });
  });
}
