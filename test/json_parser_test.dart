import 'package:test/test.dart';
import 'package:zuraffa/src/json_parser.dart';

void main() {
  late JsonParser parser;

  setUp(() {
    parser = JsonParser();
  });

  group('JsonParser - Primitive Types', () {
    test('should infer String type', () {
      final json = {'name': 'iPhone'};
      final schema = parser.parseJson(json);

      expect(schema.fields.length, 1);
      expect(schema.fields[0].name, 'name');
      expect(schema.fields[0].type, 'String');
      expect(schema.fields[0].isNullable, false);
      expect(schema.fields[0].isPrimitive, true);
    });

    test('should infer int type', () {
      final json = {'quantity': 42};
      final schema = parser.parseJson(json);

      expect(schema.fields[0].type, 'int');
      expect(schema.fields[0].isPrimitive, true);
    });

    test('should infer double type', () {
      final json = {'price': 99.99};
      final schema = parser.parseJson(json);

      expect(schema.fields[0].type, 'double');
      expect(schema.fields[0].isPrimitive, true);
    });

    test('should infer bool type', () {
      final json = {'inStock': true};
      final schema = parser.parseJson(json);

      expect(schema.fields[0].type, 'bool');
      expect(schema.fields[0].isPrimitive, true);
    });

    test('should infer DateTime from ISO 8601', () {
      final json = {'createdAt': '2025-11-14T12:34:56Z'};
      final schema = parser.parseJson(json);

      expect(schema.fields[0].type, 'DateTime');
      expect(schema.fields[0].isPrimitive, true);
    });

    test('should infer DateTime from ISO 8601 with milliseconds', () {
      final json = {'updatedAt': '2025-11-14T12:34:56.123Z'};
      final schema = parser.parseJson(json);

      expect(schema.fields[0].type, 'DateTime');
    });

    test('should treat date-only string as String', () {
      final json = {'date': '2025-11-14'};
      final schema = parser.parseJson(json);

      expect(schema.fields[0].type, 'String');
    });

    test('should mark null fields as nullable', () {
      final json = {'discount': null};
      final schema = parser.parseJson(json);

      expect(schema.fields[0].isNullable, true);
    });
  });

  group('JsonParser - Lists', () {
    test('should infer List<String>', () {
      final json = {'tags': ['electronics', 'phone']};
      final schema = parser.parseJson(json);

      expect(schema.fields[0].type, 'List<String>');
    });

    test('should infer List<int>', () {
      final json = {'counts': [1, 2, 3]};
      final schema = parser.parseJson(json);

      expect(schema.fields[0].type, 'List<int>');
    });

    test('should infer List<double>', () {
      final json = {'ratings': [4.5, 4.8, 5.0]};
      final schema = parser.parseJson(json);

      expect(schema.fields[0].type, 'List<double>');
    });

    test('should handle empty list as List<dynamic>', () {
      final json = {'items': []};
      final schema = parser.parseJson(json);

      expect(schema.fields[0].type, 'List<dynamic>');
    });

    test('should handle mixed types as List<dynamic>', () {
      final json = {'mixed': [1, 'two', 3.0]};
      final schema = parser.parseJson(json);

      expect(schema.fields[0].type, 'List<dynamic>');
    });
  });

  group('JsonParser - Nested Objects', () {
    test('should create nested entity for object', () {
      final json = {
        'id': 'order-1',
        'customer': {
          'id': 'cust-1',
          'name': 'John',
        },
      };
      final schema = parser.parseJson(json, entityName: 'Order');

      expect(schema.fields.length, 2);
      expect(schema.fields[1].name, 'customer');
      expect(schema.fields[1].type, 'Customer');
      expect(schema.fields[1].isPrimitive, false);

      expect(schema.nestedEntities.length, 1);
      expect(schema.nestedEntities[0].name, 'Customer');
      expect(schema.nestedEntities[0].fields.length, 2);
    });

    test('should create nested entity for array of objects', () {
      final json = {
        'id': 'order-1',
        'items': [
          {'productId': 'p1', 'quantity': 2},
          {'productId': 'p2', 'quantity': 1},
        ],
      };
      final schema = parser.parseJson(json, entityName: 'Order');

      expect(schema.fields[1].name, 'items');
      expect(schema.fields[1].type, 'List<Item>'); // Singularized

      expect(schema.nestedEntities.length, 1);
      expect(schema.nestedEntities[0].name, 'Item');
      expect(schema.nestedEntities[0].fields.length, 2);
    });

    test('should handle deeply nested objects', () {
      final json = {
        'order': {
          'customer': {
            'address': {
              'street': '123 Main St',
            },
          },
        },
      };
      final schema = parser.parseJson(json);

      expect(schema.nestedEntities.length, 1);
      expect(schema.nestedEntities[0].nestedEntities.length, 1);
      expect(schema.nestedEntities[0].nestedEntities[0].nestedEntities.length, 1);
    });
  });

  group('JsonParser - Complex Schemas', () {
    test('should parse ZikZak price comparison JSON', () {
      final json = {
        'comparisonId': 'cmp-123',
        'query': 'iPhone 15 Pro',
        'results': [
          {
            'merchant': 'Amazon',
            'price': 999.99,
            'currency': 'USD',
            'inStock': true,
            'shipping': {
              'cost': 0.0,
              'estimatedDays': 2,
            },
            'lastChecked': '2025-11-14T12:00:00Z',
          },
        ],
      };

      final schema = parser.parseJson(json, entityName: 'PriceComparison');

      expect(schema.name, 'PriceComparison');
      expect(schema.fields.length, 3);
      expect(schema.fields[0].type, 'String'); // comparisonId
      expect(schema.fields[1].type, 'String'); // query
      expect(schema.fields[2].type, 'List<Result>'); // results

      expect(schema.nestedEntities.length, 1);
      expect(schema.nestedEntities[0].name, 'Result');
      expect(schema.nestedEntities[0].fields.length, 6);
      expect(schema.nestedEntities[0].fields[5].type, 'DateTime'); // lastChecked

      expect(schema.nestedEntities[0].nestedEntities.length, 1);
      expect(schema.nestedEntities[0].nestedEntities[0].name, 'Shipping');
    });
  });

  // Naming utilities are tested implicitly through nested entity tests
}
