import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_deck_barrel_writer.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xray_barrel_writer_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('XRayDeckBarrelWriter', () {
    test('creates the barrel when it does not exist', () {
      final writer = XRayDeckBarrelWriter(projectRoot: tempDir.path);
      final deckPath = p.join(
        tempDir.path,
        'lib',
        'src',
        'xray',
        'user_xray_deck.dart',
      );

      final result = writer.update(
        entityName: 'User',
        deckFilePath: deckPath,
        registerFunctionName: 'registerUserXRayDeck',
      );

      expect(result.created, isTrue);
      expect(result.importAdded, isTrue);
      expect(result.callAdded, isTrue);
      expect(File(writer.barrelPath).existsSync(), isTrue);

      final content = File(writer.barrelPath).readAsStringSync();
      expect(content, contains('void registerAllXRayDecks()'));
      expect(content, contains('registerUserXRayDeck();'));
      expect(content, contains("import 'user_xray_deck.dart';"));
    });

    test('appends to an existing barrel idempotently', () {
      final writer = XRayDeckBarrelWriter(projectRoot: tempDir.path);
      final deckPath = p.join(
        tempDir.path,
        'lib',
        'src',
        'xray',
        'user_xray_deck.dart',
      );

      // First write.
      writer.update(
        entityName: 'User',
        deckFilePath: deckPath,
        registerFunctionName: 'registerUserXRayDeck',
      );

      // Second write for a different entity.
      final productDeckPath = p.join(
        tempDir.path,
        'lib',
        'src',
        'xray',
        'product_xray_deck.dart',
      );
      final result = writer.update(
        entityName: 'Product',
        deckFilePath: productDeckPath,
        registerFunctionName: 'registerProductXRayDeck',
      );

      expect(result.created, isFalse);
      expect(result.importAdded, isTrue);
      expect(result.callAdded, isTrue);

      final content = File(writer.barrelPath).readAsStringSync();
      expect(content, contains('registerUserXRayDeck();'));
      expect(content, contains('registerProductXRayDeck();'));
      expect(content, contains("import 'user_xray_deck.dart';"));
      expect(content, contains("import 'product_xray_deck.dart';"));
    });

    test('is idempotent for the same entity', () {
      final writer = XRayDeckBarrelWriter(projectRoot: tempDir.path);
      final deckPath = p.join(
        tempDir.path,
        'lib',
        'src',
        'xray',
        'order_xray_deck.dart',
      );

      // First write.
      writer.update(
        entityName: 'Order',
        deckFilePath: deckPath,
        registerFunctionName: 'registerOrderXRayDeck',
      );

      // Second write for the same entity.
      final result = writer.update(
        entityName: 'Order',
        deckFilePath: deckPath,
        registerFunctionName: 'registerOrderXRayDeck',
      );

      expect(result.importAdded, isFalse);
      expect(result.callAdded, isFalse);
      expect(result.message, contains('already up to date'));

      // Only one import + one call.
      final content = File(writer.barrelPath).readAsStringSync();
      expect(
        "import 'order_xray_deck.dart';".allMatches(content).length,
        equals(1),
      );
      expect(
        'registerOrderXRayDeck();'.allMatches(content).length,
        equals(1),
      );
    });

    test('dry-run does not create the barrel', () {
      final writer = XRayDeckBarrelWriter(projectRoot: tempDir.path);
      final deckPath = p.join(
        tempDir.path,
        'lib',
        'src',
        'xray',
        'item_xray_deck.dart',
      );

      final result = writer.update(
        entityName: 'Item',
        deckFilePath: deckPath,
        registerFunctionName: 'registerItemXRayDeck',
        dryRun: true,
      );

      expect(result.created, isTrue);
      expect(result.message, contains('would create'));
      expect(File(writer.barrelPath).existsSync(), isFalse);
    });

    test('barrel path respects outputDir', () {
      final writer = XRayDeckBarrelWriter(
        projectRoot: tempDir.path,
        outputDir: 'lib/custom',
      );
      expect(
        writer.barrelPath,
        equals(p.join(tempDir.path, 'lib', 'custom', 'xray', 'xray_decks.dart')),
      );
    });
  });
}
