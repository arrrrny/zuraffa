import 'package:test/test.dart';
import 'package:zuraffa/src/entity_generator.dart';
import 'package:zuraffa/src/json_parser.dart';

void main() {
  late MorphyEntityGenerator generator;

  setUp(() {
    generator = MorphyEntityGenerator();
  });

  group('MorphyEntityGenerator - Primitives', () {
    test('should generate entity with primitive fields', () {
      final schema = EntitySchema(
        name: 'Product',
        fields: [
          FieldSchema(name: 'id', type: 'String', isNullable: false, isPrimitive: true),
          FieldSchema(name: 'name', type: 'String', isNullable: false, isPrimitive: true),
          FieldSchema(name: 'price', type: 'double', isNullable: false, isPrimitive: true),
          FieldSchema(name: 'inStock', type: 'bool', isNullable: false, isPrimitive: true),
        ],
        nestedEntities: [],
      );

      final code = generator.generateEntity(schema);

      expect(code, contains('@morphy'));
      expect(code, contains('@Morphy(generateJson: true)'));
      expect(code, contains('abstract class \$Product {'));
      expect(code, contains('String get id;'));
      expect(code, contains('String get name;'));
      expect(code, contains('double get price;'));
      expect(code, contains('bool get inStock;'));
      expect(code, isNot(contains('\$String'))); // No $ for primitives
    });

    test('should handle nullable fields', () {
      final schema = EntitySchema(
        name: 'Product',
        fields: [
          FieldSchema(name: 'discount', type: 'double', isNullable: true, isPrimitive: true),
        ],
        nestedEntities: [],
      );

      final code = generator.generateEntity(schema);

      expect(code, contains('double? get discount;'));
    });

    test('should handle DateTime type', () {
      final schema = EntitySchema(
        name: 'Order',
        fields: [
          FieldSchema(name: 'createdAt', type: 'DateTime', isNullable: false, isPrimitive: true),
        ],
        nestedEntities: [],
      );

      final code = generator.generateEntity(schema);

      expect(code, contains('DateTime get createdAt;'));
      expect(code, isNot(contains('\$DateTime'))); // No $ for DateTime
    });
  });

  group('MorphyEntityGenerator - Lists', () {
    test('should handle List of primitives without $', () {
      final schema = EntitySchema(
        name: 'Product',
        fields: [
          FieldSchema(name: 'tags', type: 'List<String>', isNullable: false, isPrimitive: false),
          FieldSchema(name: 'ratings', type: 'List<double>', isNullable: false, isPrimitive: false),
        ],
        nestedEntities: [],
      );

      final code = generator.generateEntity(schema);

      expect(code, contains('List<String> get tags;'));
      expect(code, contains('List<double> get ratings;'));
      expect(code, isNot(contains('List<\$String>'))); // No $ for primitives in List
    });

    test('should handle List of entities with $', () {
      final schema = EntitySchema(
        name: 'Order',
        fields: [
          FieldSchema(name: 'items', type: 'List<OrderItem>', isNullable: false, isPrimitive: false),
        ],
        nestedEntities: [],
      );

      final code = generator.generateEntity(schema);

      expect(code, contains('List<\$OrderItem> get items;')); // WITH $ for entities
    });
  });

  group('MorphyEntityGenerator - Nested Entities', () {
    test('should use $ prefix for nested entity references', () {
      final schema = EntitySchema(
        name: 'Order',
        fields: [
          FieldSchema(name: 'id', type: 'String', isNullable: false, isPrimitive: true),
          FieldSchema(name: 'customer', type: 'Customer', isNullable: false, isPrimitive: false),
        ],
        nestedEntities: [],
      );

      final code = generator.generateEntity(schema);

      expect(code, contains('\$Customer get customer;')); // WITH $ prefix
    });

    test('should generate all nested entities', () {
      final schema = EntitySchema(
        name: 'Order',
        fields: [
          FieldSchema(name: 'customer', type: 'Customer', isNullable: false, isPrimitive: false),
        ],
        nestedEntities: [
          EntitySchema(
            name: 'Customer',
            fields: [
              FieldSchema(name: 'id', type: 'String', isNullable: false, isPrimitive: true),
              FieldSchema(name: 'name', type: 'String', isNullable: false, isPrimitive: true),
            ],
            nestedEntities: [],
          ),
        ],
      );

      final files = generator.generateAllEntities(schema);

      expect(files.length, 2);
      expect(files.keys, contains('lib/src/domain/entities/order.dart'));
      expect(files.keys, contains('lib/src/domain/entities/customer.dart'));
      expect(files['lib/src/domain/entities/customer.dart'], contains('abstract class \$Customer'));
    });
  });

  group('MorphyEntityGenerator - Complex Schema', () {
    test('should generate ZikZak price comparison entities correctly', () {
      final schema = EntitySchema(
        name: 'PriceComparison',
        fields: [
          FieldSchema(name: 'comparisonId', type: 'String', isNullable: false, isPrimitive: true),
          FieldSchema(name: 'query', type: 'String', isNullable: false, isPrimitive: true),
          FieldSchema(name: 'results', type: 'List<Result>', isNullable: false, isPrimitive: false),
        ],
        nestedEntities: [
          EntitySchema(
            name: 'Result',
            fields: [
              FieldSchema(name: 'merchant', type: 'String', isNullable: false, isPrimitive: true),
              FieldSchema(name: 'price', type: 'double', isNullable: false, isPrimitive: true),
              FieldSchema(name: 'shipping', type: 'Shipping', isNullable: false, isPrimitive: false),
              FieldSchema(name: 'lastChecked', type: 'DateTime', isNullable: false, isPrimitive: true),
            ],
            nestedEntities: [
              EntitySchema(
                name: 'Shipping',
                fields: [
                  FieldSchema(name: 'cost', type: 'double', isNullable: false, isPrimitive: true),
                  FieldSchema(name: 'estimatedDays', type: 'int', isNullable: false, isPrimitive: true),
                ],
                nestedEntities: [],
              ),
            ],
          ),
        ],
      );

      final files = generator.generateAllEntities(schema);

      expect(files.length, 3);

      // Main entity
      final mainEntity = files['lib/src/domain/entities/price_comparison.dart']!;
      expect(mainEntity, contains('abstract class \$PriceComparison'));
      expect(mainEntity, contains('List<\$Result> get results;')); // $ in List

      // Nested entity
      final resultEntity = files['lib/src/domain/entities/result.dart']!;
      expect(resultEntity, contains('abstract class \$Result'));
      expect(resultEntity, contains('\$Shipping get shipping;')); // $ for nested
      expect(resultEntity, contains('DateTime get lastChecked;')); // No $ for DateTime

      // Deeply nested entity
      final shippingEntity = files['lib/src/domain/entities/shipping.dart']!;
      expect(shippingEntity, contains('abstract class \$Shipping'));
      expect(shippingEntity, contains('double get cost;'));
      expect(shippingEntity, contains('int get estimatedDays;'));
    });
  });

  group('MorphyEntityGenerator - File Paths', () {
    test('should convert PascalCase to snake_case for file paths', () {
      expect(generator.getFilePath('Product'), 'lib/src/domain/entities/product.dart');
      expect(generator.getFilePath('PriceComparison'), 'lib/src/domain/entities/price_comparison.dart');
      expect(generator.getFilePath('OrderItem'), 'lib/src/domain/entities/order_item.dart');
    });
  });
}
