import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_json_builder.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_mock_json_int_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates valid JSON array with all field types', () async {
    final entityDir = Directory(
      '$outputDir/domain/entities/catalog/full_typed',
    );
    await entityDir.create(recursive: true);
    final entityFile = File('${entityDir.path}/full_typed.dart');
    await entityFile.writeAsString('''class FullTyped {
  final String stringField;
  final int intField;
  final double doubleField;
  final bool boolField;
  final DateTime dateTimeField;
  final List<String> listField;
  final Map<String, int> mapField;

  const FullTyped({
    required this.stringField,
    required this.intField,
    required this.doubleField,
    required this.boolField,
    required this.dateTimeField,
    required this.listField,
    required this.mapField,
  });
}''');

    final builder = MockJsonBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'FullTyped',
        generateMockJson: true,
        outputDir: outputDir,
        force: true,
      ),
    );

    final jsonFile = files.firstWhere(
      (f) => f.type == 'mock_json' && f.action != 'skipped',
    );

    final jsonContent = File(jsonFile.path).readAsStringSync();

    final List<dynamic> parsed = jsonDecode(jsonContent) as List<dynamic>;
    expect(parsed.length, 3);

    final first = parsed[0] as Map<String, dynamic>;
    expect(first.containsKey('stringField'), true);
    expect(first.containsKey('intField'), true);
    expect(first.containsKey('doubleField'), true);
    expect(first.containsKey('boolField'), true);
    expect(first.containsKey('dateTimeField'), true);
    expect(first.containsKey('listField'), true);
    expect(first.containsKey('mapField'), true);

    expect(first['stringField'] is String, true);
    expect(first['intField'] is int, true);
    expect(first['doubleField'] is double, true);
    expect(first['boolField'] is bool, true);
    expect(first['dateTimeField'] is String, true);
    expect(first['listField'] is List, true);
    expect(first['mapField'] is Map, true);

    final helperFile = files.firstWhere((f) => f.type == 'mock_json_helper');
    expect(helperFile.action, isNot('skipped'));
  });

  test('generates nested entity JSON recursively', () async {
    final orderDir = Directory('$outputDir/domain/entities/checkout/order');
    await orderDir.create(recursive: true);
    final orderFile = File('${orderDir.path}/order.dart');
    await orderFile.writeAsString('''class Order {
  final String id;
  final List<OrderItem> items;
  const Order({required this.id, required this.items});
}''');

    final itemDir = Directory('$outputDir/domain/entities/checkout/order_item');
    await itemDir.create(recursive: true);
    final itemFile = File('${itemDir.path}/order_item.dart');
    await itemFile.writeAsString('''class OrderItem {
  final String productId;
  final int quantity;
  const OrderItem({required this.productId, required this.quantity});
}''');

    final builder = MockJsonBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'Order',
        generateMockJson: true,
        outputDir: outputDir,
        force: true,
      ),
    );

    final orderJsonFiles = files.where(
      (f) =>
          f.type == 'mock_json' &&
          f.path.contains('order.mock.json') &&
          f.action != 'skipped',
    );
    expect(orderJsonFiles.isNotEmpty, true);

    final itemJsonFiles = files.where(
      (f) =>
          f.type == 'mock_json' &&
          f.path.contains('order_item.mock.json') &&
          f.action != 'skipped',
    );
    expect(itemJsonFiles.isNotEmpty, true);

    final orderContent = File(orderJsonFiles.first.path).readAsStringSync();
    expect(orderContent.contains('"items"'), true);
    expect(orderContent.contains('productId'), true);
  });

  test('folder convention separates entities by domain', () async {
    final catalogDir = Directory('$outputDir/domain/entities/catalog/config');
    await catalogDir.create(recursive: true);
    await File('${catalogDir.path}/config.dart').writeAsString(
      'class Config { final String key; const Config({required this.key}); }',
    );

    final checkoutDir = Directory('$outputDir/domain/entities/checkout/config');
    await checkoutDir.create(recursive: true);
    await File('${checkoutDir.path}/config.dart').writeAsString(
      'class Config { final String value; const Config({required this.value}); }',
    );

    final builder = MockJsonBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );

    final catalogFiles = await builder.generate(
      GeneratorConfig(
        name: 'Config',
        generateMockJson: true,
        mockJsonDomain: 'catalog',
        outputDir: outputDir,
        force: true,
      ),
    );

    final checkoutFiles = await builder.generate(
      GeneratorConfig(
        name: 'Config',
        generateMockJson: true,
        mockJsonDomain: 'checkout',
        outputDir: outputDir,
        force: true,
      ),
    );

    final catalogJson = catalogFiles.firstWhere(
      (f) => f.type == 'mock_json' && f.action != 'skipped',
    );
    final checkoutJson = checkoutFiles.firstWhere(
      (f) => f.type == 'mock_json' && f.action != 'skipped',
    );

    expect(catalogJson.path, contains('catalog'));
    expect(catalogJson.path, contains('config.mock.json'));
    expect(checkoutJson.path, contains('checkout'));
    expect(checkoutJson.path, contains('config.mock.json'));
    expect(catalogJson.path, isNot(checkoutJson.path));
  });

  test('polymorphic entities include _type discriminator in JSON', () async {
    final baseDir = Directory(
      '$outputDir/domain/entities/payments/payment_method',
    );
    await baseDir.create(recursive: true);
    final baseFile = File('${baseDir.path}/payment_method.dart');
    await baseFile.writeAsString('''@Zorphy(explicitSubTypes: [CreditCard])
class PaymentMethod {
  final String id;
  const PaymentMethod({required this.id});
}''');

    final ccDir = Directory('$outputDir/domain/entities/payments/credit_card');
    await ccDir.create(recursive: true);
    final ccFile = File('${ccDir.path}/credit_card.dart');
    await ccFile.writeAsString('''class CreditCard extends PaymentMethod {
  final String cardNumber;
  const CreditCard({required String id, required this.cardNumber}) : super(id: id);
}''');

    final builder = MockJsonBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'PaymentMethod',
        generateMockJson: true,
        outputDir: outputDir,
        force: true,
      ),
    );

    final jsonFile = files.firstWhere(
      (f) =>
          f.type == 'mock_json' && f.path.contains('payment_method.mock.json'),
      orElse: () => throw StateError('PaymentMethod JSON not found'),
    );

    final content = File(jsonFile.path).readAsStringSync();
    final List<dynamic> parsed = jsonDecode(content);

    bool hasType = false;
    for (final item in parsed) {
      if (item is Map<String, dynamic> && item.containsKey('_type')) {
        hasType = true;
        break;
      }
    }
    expect(hasType, true);

    final helperFile = files.firstWhere(
      (f) =>
          f.type == 'mock_json_helper' &&
          f.path.contains('payment_method_mock_json.dart'),
      orElse: () => throw StateError('Helper not found'),
    );

    final helperContent = File(helperFile.path).readAsStringSync();
    expect(helperContent.contains('_type'), true);
    expect(helperContent.contains('switch'), true);
  });

  test('enum fields are serialized as enum value names', () async {
    final enumDir = Directory('$outputDir/domain/entities/enums');
    await enumDir.create(recursive: true);
    final enumFile = File('${enumDir.path}/status.dart');
    await enumFile.writeAsString('enum Status { active, pending, cancelled }');

    final entityDir = Directory('$outputDir/domain/entities/catalog/product');
    await entityDir.create(recursive: true);
    final entityFile = File('${entityDir.path}/product.dart');
    await entityFile.writeAsString(
      '''import '../../../domain/entities/enums/status.dart';
class Product { final String id; final Status status; const Product({required this.id, required this.status}); }''',
    );

    final builder = MockJsonBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'Product',
        generateMockJson: true,
        outputDir: outputDir,
        force: true,
      ),
    );

    final jsonFile = files.firstWhere(
      (f) => f.type == 'mock_json' && f.action != 'skipped',
      orElse: () => throw StateError('No JSON file generated'),
    );

    final content = File(jsonFile.path).readAsStringSync();
    expect(
      content.contains('active') ||
          content.contains('pending') ||
          content.contains('cancelled'),
      true,
    );
  });

  test('nullable fields include null values at position 3', () async {
    final entityDir = Directory('$outputDir/domain/entities/catalog/product');
    await entityDir.create(recursive: true);
    final entityFile = File('${entityDir.path}/product.dart');
    await entityFile.writeAsString(
      'class Product { final String id; final String? description; const Product({required this.id, this.description}); }',
    );

    final builder = MockJsonBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'Product',
        generateMockJson: true,
        outputDir: outputDir,
        force: true,
      ),
    );

    final jsonFile = files.firstWhere(
      (f) => f.type == 'mock_json' && f.action != 'skipped',
    );

    final content = File(jsonFile.path).readAsStringSync();
    final List<dynamic> parsed = jsonDecode(content);

    bool hasNull = false;
    for (final item in parsed) {
      if (item is Map<String, dynamic> && item['description'] == null) {
        hasNull = true;
        break;
      }
    }
    expect(hasNull, true);
  });
}
