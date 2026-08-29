import 'package:test/test.dart';
import 'package:zuraffa/src/agent/plugin/schema_deriver.dart';

void main() {
  group('SchemaDeriver — SC-002 type matrix', () {
    const deriver = SchemaDeriver();

    test('derive(String) → {"type":"string"}', () {
      expect(deriver.derive('String'), {'type': 'string'});
    });

    test('derive(int) → {"type":"integer"}', () {
      expect(deriver.derive('int'), {'type': 'integer'});
    });

    test('derive(double) → {"type":"number"}', () {
      expect(deriver.derive('double'), {'type': 'number'});
    });

    test('derive(num) → {"type":"number"}', () {
      expect(deriver.derive('num'), {'type': 'number'});
    });

    test('derive(bool) → {"type":"boolean"}', () {
      expect(deriver.derive('bool'), {'type': 'boolean'});
    });

    test('derive(DateTime) → {"type":"string","format":"date-time"}', () {
      expect(deriver.derive('DateTime'), {
        'type': 'string',
        'format': 'date-time',
      });
    });

    test('derive(List<String>) → {"type":"array","items":{...string}}', () {
      expect(deriver.derive('List<String>'), {
        'type': 'array',
        'items': {'type': 'string'},
      });
    });

    test('derive(List<int>) → array of integer', () {
      expect(deriver.derive('List<int>'), {
        'type': 'array',
        'items': {'type': 'integer'},
      });
    });

    test('derive(Map<String, int>) → object with additionalProperties', () {
      expect(deriver.derive('Map<String, int>'), {
        'type': 'object',
        'additionalProperties': {'type': 'integer'},
      });
    });

    test('derive(String?) → nullable string', () {
      expect(deriver.derive('String?'), {'type': 'string', 'nullable': true});
    });

    test('derive(List<String>?) → nullable array', () {
      expect(deriver.derive('List<String>?'), {
        'type': 'array',
        'items': {'type': 'string'},
        'nullable': true,
      });
    });

    test('derive(enum) → {"type":"string","enum":[...]}', () {
      const d = SchemaDeriver.withEntities(
        knownEntities: {},
        knownEnums: {
          'Status': ['draft', 'published', 'archived'],
        },
      );
      expect(d.derive('Status'), {
        'type': 'string',
        'enum': ['draft', 'published', 'archived'],
      });
    });

    test('derive(nested entity) → inlined nested object schema', () {
      const d = SchemaDeriver.withEntities(
        knownEntities: {
          'Address': [
            EntityFieldSpec(
              name: 'street',
              typeRef: 'String',
              isRequired: true,
            ),
            EntityFieldSpec(name: 'zip', typeRef: 'String', isRequired: true),
          ],
        },
        knownEnums: {},
      );
      final schema = d.derive('Address');
      expect(schema['type'], 'object');
      expect((schema['properties'] as Map)['street'], {'type': 'string'});
      expect((schema['properties'] as Map)['zip'], {'type': 'string'});
      expect(schema['required'], ['street', 'zip']);
    });

    test('derive(SignalResult<T>) → unwraps to schema of T', () {
      expect(const SchemaDeriver().derive('SignalResult<Listing>'), {
        'type': 'object',
        'description':
            'Unresolvable type Listing — schema inferred as open object',
      });
    });

    test('derive(Future<T>) → unwraps to schema of T', () {
      expect(const SchemaDeriver().derive('Future<Listing>'), {
        'type': 'object',
        'description':
            'Unresolvable type Listing — schema inferred as open object',
      });
    });

    test('derive(unresolvable generic) → open-object with documentation', () {
      final schema = const SchemaDeriver().derive('Foo<Bar>');
      expect(schema['type'], 'object');
      expect(
        (schema['description'] as String).contains('Unresolvable type'),
        isTrue,
      );
    });

    test('cycle: nested entity referencing itself → \$ref', () {
      const d = SchemaDeriver.withEntities(
        knownEntities: {
          'Node': [
            EntityFieldSpec(name: 'value', typeRef: 'String', isRequired: true),
            EntityFieldSpec(name: 'next', typeRef: 'Node', isRequired: false),
          ],
        },
        knownEnums: {},
      );
      final schema = d.derive('Node');
      expect(schema['type'], 'object');
      final props = schema['properties'] as Map;
      expect(props['next'], {'\$ref': '#/definitions/Node'});
    });
  });
}
