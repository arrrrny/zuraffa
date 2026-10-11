/// JSON Schema generator for adaptive-skin-contract.v1 (issue #1004).
///
/// The schema is GENERATED from the model — the same field tables and
/// patterns the parser walks — so model, parser, and schema cannot
/// drift (#1111 FR-005: the schema is emitted from the model, never
/// hand-maintained). The plan writes the contract JSON into
/// `04-SKIN.md` shaped by this schema; tests validate the emitted
/// block against it.
library;

import 'adaptive_skin_contract.dart';

/// The `$defs` name of the route row schema.
const String adaptiveRouteDefName = 'adaptiveRoute';

/// Builds the JSON Schema (draft 2020-12) for
/// adaptive-skin-contract.v1.
Map<String, dynamic> adaptiveSkinContractSchema() {
  return {
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    'title': 'zuraffa adaptive skin contract',
    'type': 'object',
    'additionalProperties': false,
    'required': _requiredKeys,
    'properties': {
      'schemaVersion': {'const': AdaptiveSkinContract.schemaVersionV1},
      'adaptiveSlots': {
        'type': 'array',
        'items': {
          'type': 'string',
          'pattern': AdaptiveSkinContract.namePattern,
        },
      },
      'platformOverrides': _platformOverridesSchema(),
      'states': {
        'type': 'array',
        'items': {
          'type': 'string',
          'pattern': AdaptiveSkinContract.namePattern,
        },
      },
      'routes': {
        'type': 'array',
        'items': {
          // The ref points at the route def; the def name is
          // concatenated (not interpolated — `\$defs` and `$ref` both
          // collide with Dart's `$` interpolation) so the pointer can
          // never drift from the $defs key.
          r'$ref': '#/\$defs/$adaptiveRouteDefName',
        },
      },
    },
    r'$defs': {adaptiveRouteDefName: _routeSchema()},
  };
}

const List<String> _requiredKeys = [
  'schemaVersion',
  'adaptiveSlots',
  'platformOverrides',
  'states',
  'routes',
];

/// `platformOverrides`: a map of platform -> (override key -> value).
/// The platform names and override keys walk the model's name
/// pattern; the override values are free-form strings.
Map<String, dynamic> _platformOverridesSchema() => {
  'type': 'object',
  'additionalProperties': {
    'type': 'object',
    'additionalProperties': {'type': 'string'},
  },
};

/// The route row schema, generated from [AdaptiveRouteContract.fields]
/// — the same table the parser's name validation uses.
Map<String, dynamic> _routeSchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': [
    for (final field in AdaptiveRouteContract.fields)
      if (field.required) field.name,
  ],
  'properties': {
    for (final field in AdaptiveRouteContract.fields)
      field.name: {
        'type': switch (field.type) {
          AdaptiveContractFieldType.string => 'string',
        },
        if (field.pattern != null) 'pattern': field.pattern,
      },
  },
};
