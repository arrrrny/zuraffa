/// Strict parser for skin-contract.v1 JSON (issue #1164).
///
/// Every failure names the offending section/key — never a silent
/// default (#1111: unknown fields are contract drift, not future
/// proofing). The parser walks the same [SkinContractFieldSpec] tables
/// the schema generator walks.
library;

import 'dart:convert';

import 'skin_contract.dart';

/// A parse failure naming the offending section and key.
class SkinContractParseException implements Exception {
  final String message;
  SkinContractParseException(this.message);

  @override
  String toString() => message;
}

/// Parses contract JSON text into a [SkinContract].
SkinContract parseSkinContractJson(String source) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    throw SkinContractParseException(
      'skin contract: invalid JSON: ${error.message}',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw SkinContractParseException(
      'skin contract: top level must be a JSON object',
    );
  }
  return parseSkinContract(decoded);
}

/// Parses decoded contract JSON into a [SkinContract].
SkinContract parseSkinContract(Map<String, dynamic> json) {
  final version = json['schemaVersion'];
  if (version is! String) {
    throw SkinContractParseException(
      'skin contract: schemaVersion: missing (required string)',
    );
  }
  if (version != SkinContract.schemaVersionV1) {
    throw SkinContractParseException(
      'skin contract: schemaVersion: '
      'unsupported version "$version" '
      '(expected "${SkinContract.schemaVersionV1}")',
    );
  }
  final unknown = json.keys
      .where(
        (k) => k != 'schemaVersion' && !SkinContract.sections.containsKey(k),
      )
      .toList();
  if (unknown.isNotEmpty) {
    throw SkinContractParseException(
      'skin contract: unknown field(s) '
      '${unknown.map((k) => '"$k"').join(', ')}',
    );
  }

  return SkinContract(
    schemaVersion: version,
    routes: [
      for (final row in _rows(json, 'routes'))
        ContractRoute(
          path: _string(row, 'path', 'routes', fields: ContractRoute.fields),
          view: _string(row, 'view', 'routes', fields: ContractRoute.fields),
        ),
    ],
    states: [
      for (final row in _rows(json, 'states'))
        ContractState(
          view: _string(row, 'view', 'states'),
          loading: _bool(row, 'loading', 'states'),
          error: _enum(row, 'error', 'states', ContractState.fields),
          empty: _bool(row, 'empty', 'states'),
        ),
    ],
    platformRows: [
      for (final row in _rows(json, 'platformRows'))
        ContractPlatformRow(
          view: _string(row, 'view', 'platformRows'),
          mobile: _bool(row, 'mobile', 'platformRows'),
          ios: _bool(row, 'ios', 'platformRows'),
          android: _bool(row, 'android', 'platformRows'),
          macos: _bool(row, 'macos', 'platformRows'),
        ),
    ],
    stateRows: [
      for (final row in _rows(json, 'stateRows'))
        ContractStateRow(
          view: _string(row, 'view', 'stateRows'),
          row: _string(row, 'row', 'stateRows'),
          kind: _enum(row, 'kind', 'stateRows', ContractStateRow.fields),
        ),
    ],
  );
}

// -- helpers -------------------------------------------------------------

List<Map<String, dynamic>> _rows(Map<String, dynamic> json, String section) {
  final value = json[section];
  if (value == null) {
    throw SkinContractParseException(
      'skin contract: $section: missing (required list)',
    );
  }
  if (value is! List) {
    throw SkinContractParseException('skin contract: $section: must be a list');
  }
  final fields = SkinContract.sections[section]!;
  return [
    for (final (index, item) in value.indexed)
      _row(item, section, index, fields),
  ];
}

Map<String, dynamic> _row(
  dynamic item,
  String section,
  int index,
  List<SkinContractFieldSpec> fields,
) {
  final where = '$section[$index]';
  if (item is! Map<String, dynamic>) {
    throw SkinContractParseException(
      'skin contract: $where: must be an object',
    );
  }
  for (final field in fields) {
    if (field.required && !item.containsKey(field.name)) {
      throw SkinContractParseException(
        'skin contract: $where: missing "${field.name}"',
      );
    }
  }
  final unknown = item.keys
      .where((k) => !fields.any((f) => f.name == k))
      .toList();
  if (unknown.isNotEmpty) {
    throw SkinContractParseException(
      'skin contract: $where: unknown field(s) '
      '${unknown.map((k) => '"$k"').join(', ')}',
    );
  }
  return item;
}

String _string(
  Map<String, dynamic> row,
  String key,
  String section, {
  List<SkinContractFieldSpec> fields = const [],
}) {
  final value = row[key];
  if (value is! String) {
    throw SkinContractParseException(
      'skin contract: $section: "$key" must be a string',
    );
  }
  for (final spec in fields) {
    if (spec.name == key && spec.pattern != null) {
      if (!RegExp(spec.pattern!).hasMatch(value)) {
        throw SkinContractParseException(
          'skin contract: $section: '
          '"$key" value "$value" does not match ${spec.pattern}',
        );
      }
    }
  }
  return value;
}

bool _bool(Map<String, dynamic> row, String key, String section) {
  final value = row[key];
  if (value is! bool) {
    throw SkinContractParseException(
      'skin contract: $section: "$key" must be a boolean',
    );
  }
  return value;
}

String _enum(
  Map<String, dynamic> row,
  String key,
  String section,
  List<SkinContractFieldSpec> fields,
) {
  final value = _string(row, key, section);
  final spec = fields.firstWhere((f) => f.name == key);
  if (spec.values != null && !spec.values!.contains(value)) {
    throw SkinContractParseException(
      'skin contract: $section: "$key" '
      'value "$value" not in [${spec.values!.join(", ")}]',
    );
  }
  return value;
}
