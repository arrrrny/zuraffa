/// JSON Schema generator for skin-contract.v1 (issue #1164).
///
/// The schema is GENERATED from the model's [SkinContractFieldSpec]
/// tables — the same tables the parser walks — so model, parser, and
/// schema cannot drift (#1111 FR-005: the schema is emitted from the
/// model, never hand-maintained).
library;

import 'skin_contract.dart';

/// Builds the JSON Schema (draft 2020-12) for skin-contract.v1.
Map<String, dynamic> skinContractSchema() {
  return {
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    'title': 'zuraffa skin contract',
    'type': 'object',
    'additionalProperties': false,
    'required': ['schemaVersion', ...SkinContract.sections.keys],
    'properties': {
      'schemaVersion': {'const': SkinContract.schemaVersionV1},
      for (final entry in SkinContract.sections.entries)
        entry.key: {
          'type': 'array',
          'items': {r'$ref': '#/\$defs/${skinContractDefName(entry.key)}'},
        },
    },
    r'$defs': {
      for (final entry in SkinContract.sections.entries)
        skinContractDefName(entry.key): _objectSchema(entry.value),
    },
  };
}

String skinContractDefName(String section) =>
    'contract${section[0].toUpperCase()}${section.substring(1)}';

Map<String, dynamic> _objectSchema(List<SkinContractFieldSpec> fields) {
  return {
    'type': 'object',
    'additionalProperties': false,
    'required': [
      for (final field in fields)
        if (field.required) field.name,
    ],
    'properties': {for (final field in fields) field.name: _fieldSchema(field)},
  };
}

Map<String, dynamic> _fieldSchema(SkinContractFieldSpec field) {
  final schema = <String, dynamic>{
    'type': switch (field.type) {
      SkinContractFieldType.string => 'string',
      SkinContractFieldType.boolean => 'boolean',
    },
  };
  if (field.values != null) schema['enum'] = field.values;
  if (field.pattern != null) schema['pattern'] = field.pattern;
  return schema;
}
