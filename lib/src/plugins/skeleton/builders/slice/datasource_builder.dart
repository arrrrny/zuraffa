/// Builds the data sources of a working slice (042, FR-004).
library;

import '../../models/bone.dart';

/// Emits the in-memory mock data source and the Firestore REST firebase data
/// source for one entity. Both stay self-contained: `dart:*` imports and
/// bone-relative entity imports only.
class DataSourceBuilder {
  /// The in-memory mock data source — seeded, zero external services.
  String buildMock(String entity, List<EntityField> fields) {
    final snake = pascalToSnake(entity);
    final sampleArgs = fields
        .where((f) => !f.nullable)
        .map((f) => '${f.name}: ${_sample(f)}')
        .join(', ');
    final hasFields = fields.isNotEmpty;
    final primaryKey = primaryKeyExpr(fields);

    final buffer = StringBuffer();
    buffer.writeln("import '../../entities/$snake.dart';");
    buffer.writeln("import '${snake}_datasource.dart';");
    buffer.writeln();
    buffer.writeln(
      '/// In-memory [${entity}DataSource] seeded with sample data.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// Works with zero external services — ideal for prototyping, tests,',
    );
    buffer.writeln('/// and delegated agent builds (`--di mock`).');
    buffer.writeln(
      'class ${entity}MockDataSource implements ${entity}DataSource {',
    );
    buffer.writeln(
      '  /// Creates the store, optionally pre-seeded with [seed].',
    );
    buffer.writeln('  ${entity}MockDataSource({Map<String, $entity>? seed})');
    buffer.writeln(
      '      : _store = Map<String, $entity>.of(seed ?? const <String, $entity>{}) {',
    );
    buffer.writeln('    _seedSamples();');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  final Map<String, $entity> _store;');
    buffer.writeln();
    buffer.writeln(
      '  /// Seeds one sample instance when the store starts empty.',
    );
    buffer.writeln('  void _seedSamples() {');
    buffer.writeln('    if (_store.isNotEmpty) return;');
    buffer.writeln(
      hasFields
          ? '    final $entity sample = $entity($sampleArgs);'
          : '    final $entity sample = const $entity();',
    );
    buffer.writeln('    _store[_keyOf(sample)] = sample;');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  String _keyOf($entity instance) => $primaryKey;');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln(
      '  Future<$entity?> get${entity}ById(String id) async => _store[id];',
    );
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  Future<List<$entity>> getAll${entity}s() async =>');
    buffer.writeln('      _store.values.toList(growable: false);');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  Future<void> save$entity($entity instance) async {');
    buffer.writeln('    _store[_keyOf(instance)] = instance;');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  Future<void> delete$entity(String id) async {');
    buffer.writeln('    _store.remove(id);');
    buffer.writeln('  }');
    buffer.writeln('}');
    return buffer.toString();
  }

  /// The Firestore REST firebase data source — real credentials, no SDK.
  String buildFirebase(String entity, List<EntityField> fields) {
    final snake = pascalToSnake(entity);
    final primaryKey = primaryKeyExpr(fields);

    final buffer = StringBuffer();
    buffer.writeln("import 'dart:convert';");
    buffer.writeln("import 'dart:io';");
    buffer.writeln();
    buffer.writeln("import '../../entities/$snake.dart';");
    buffer.writeln("import '${snake}_datasource.dart';");
    buffer.writeln();
    buffer.writeln(
      '/// [${entity}DataSource] backed by Firestore over its REST API.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// Uses only `dart:io` [HttpClient] — no firebase_* packages, so the',
    );
    buffer.writeln(
      '/// bone stays self-contained. Requires a project id and API key with',
    );
    buffer.writeln(
      '/// Firestore access; a [StateError] is thrown up-front when the',
    );
    buffer.writeln('/// credentials are blank.');
    buffer.writeln(
      'class ${entity}FirebaseDataSource implements ${entity}DataSource {',
    );
    buffer.writeln(
      '  ${entity}FirebaseDataSource._('
      'this.projectId, this.apiKey, this.idToken, this._client);',
    );
    buffer.writeln();
    buffer.writeln('  /// Creates the data source, guarding credentials.');
    buffer.writeln('  factory ${entity}FirebaseDataSource({');
    buffer.writeln('    required String projectId,');
    buffer.writeln('    required String apiKey,');
    buffer.writeln('    String? idToken,');
    buffer.writeln('  }) {');
    buffer.writeln(
      "    if (projectId.trim().isEmpty || apiKey.trim().isEmpty) {",
    );
    buffer.writeln('      throw StateError(');
    buffer.writeln(
      "        'Firebase credentials missing: $entity data source needs a '",
    );
    buffer.writeln("        'non-empty projectId and apiKey.',");
    buffer.writeln('      );');
    buffer.writeln('    }');
    buffer.writeln(
      '    return ${entity}FirebaseDataSource._('
      'projectId, apiKey, idToken, HttpClient());',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  /// Firestore project id.');
    buffer.writeln('  final String projectId;');
    buffer.writeln();
    buffer.writeln('  /// Firebase API key authorized for [projectId].');
    buffer.writeln('  final String apiKey;');
    buffer.writeln();
    buffer.writeln('  /// Optional Firebase ID token; when non-empty it is sent');
    buffer.writeln('  /// as a `Bearer` `Authorization` header so Firestore');
    buffer.writeln('  /// Security Rules requiring auth are satisfied.');
    buffer.writeln('  final String? idToken;');
    buffer.writeln();
    buffer.writeln('  final HttpClient _client;');
    buffer.writeln();
    buffer.writeln("  static const String _firestoreRoot =");
    buffer.writeln("      'https://firestore.googleapis.com/v1';");
    buffer.writeln();
    buffer.writeln("  String get _collectionPath => '/$snake';");
    buffer.writeln();
    buffer.writeln('  Uri _documentUri(String id) => Uri.parse(');
    buffer.writeln(
      "      '\$_firestoreRoot/projects/\$projectId/databases/(default)/'",
    );
    buffer.writeln("      'documents\$_collectionPath/\$id?key=\$apiKey');");
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  Future<$entity?> get${entity}ById(String id) async {');
    buffer.writeln(
      "    final response = await _request('GET', _documentUri(id));",
    );
    buffer.writeln('    if (response.statusCode == 404) return null;');
    buffer.writeln("    _ensureOk(response, 'get${entity}ById');");
    buffer.writeln(
      '    final document = jsonDecode(response.body) as Map<String, dynamic>;',
    );
    buffer.writeln('    return $entity.fromJson(_entityJson(document));');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  Future<List<$entity>> getAll${entity}s() async {');
    buffer.writeln('    final documents = <Map<String, dynamic>>[];');
    buffer.writeln("    var pageToken = '';");
    buffer.writeln('    do {');
    buffer.writeln('      final uri = Uri.parse(');
    buffer.writeln(
      "        '\$_firestoreRoot/projects/\$projectId/databases/(default)/'",
    );
    buffer.writeln("        'documents\$_collectionPath'");
    buffer.writeln(
      "        '\${pageToken.isEmpty ? \"?key=\$apiKey\" : \"?pageToken=\$pageToken&key=\$apiKey\"}'",
    );
    buffer.writeln('      );');
    buffer.writeln("      final response = await _request('GET', uri);");
    buffer.writeln("      _ensureOk(response, 'getAll${entity}s');");
    buffer.writeln(
      '      final body = jsonDecode(response.body) as Map<String, dynamic>;',
    );
    buffer.writeln("      final batch = body['documents'] as List<dynamic>?;");
    buffer.writeln('      if (batch != null) {');
    buffer.writeln('        for (final document in batch) {');
    buffer.writeln(
      '          documents.add(_entityJson(document as Map<String, dynamic>));',
    );
    buffer.writeln('        }');
    buffer.writeln('      }');
    buffer.writeln("      pageToken = (body['nextPageToken'] as String?) ?? '';");
    buffer.writeln('    } while (pageToken.isNotEmpty);');
    buffer.writeln('    return <$entity>[');
    buffer.writeln('      for (final document in documents)');
    buffer.writeln('        $entity.fromJson(document),');
    buffer.writeln('    ];');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  Future<void> save$entity($entity instance) async {');
    buffer.writeln(
      "    final response = await _request('PATCH', _documentUri(",
    );
    buffer.writeln('          $primaryKey),');
    buffer.writeln("      body: jsonEncode(");
    buffer.writeln(
      "          <String, dynamic>{'fields': _firestoreFields(instance.toJson())}));",
    );
    buffer.writeln("    _ensureOk(response, 'save$entity');");
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  Future<void> delete$entity(String id) async {');
    buffer.writeln(
      "    final response = await _request('DELETE', _documentUri(id));",
    );
    buffer.writeln('    if (response.statusCode == 404) return;');
    buffer.writeln("    _ensureOk(response, 'delete$entity');");
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  Future<_HttpResponse> _request(');
    buffer.writeln('    String method,');
    buffer.writeln('    Uri uri, {');
    buffer.writeln('    String? body,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final request = await _client.openUrl(method, uri);');
    buffer.writeln('    if (body != null) {');
    buffer.writeln(
      "      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');",
    );
    buffer.writeln('      request.add(utf8.encode(body));');
    buffer.writeln('    }');
    buffer.writeln('    final token = idToken;');
    buffer.writeln('    if (token != null && token.isNotEmpty) {');
    buffer.writeln(
      "      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer \$token');",
    );
    buffer.writeln('    }');
    buffer.writeln('    final response = await request.close();');
    buffer.writeln(
      '    final responseBody = await response.transform(utf8.decoder).join();',
    );
    buffer.writeln(
      '    return _HttpResponse(response.statusCode, responseBody);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  void _ensureOk(_HttpResponse response, String operation) {',
    );
    buffer.writeln(
      '    if (response.statusCode < 200 || response.statusCode >= 300) {',
    );
    buffer.writeln('      throw StateError(');
    buffer.writeln(
      "        'Firestore \$operation failed: HTTP \${response.statusCode} '",
    );
    buffer.writeln("        '\${response.body}',");
    buffer.writeln('      );');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Map<String, dynamic> _entityJson(Map<String, dynamic> document) {',
    );
    buffer.writeln(
      "    final fields = document['fields'] as Map<String, dynamic>?;",
    );
    buffer.writeln('    if (fields == null) return const <String, dynamic>{};');
    buffer.writeln('    return <String, dynamic>{');
    buffer.writeln('      for (final entry in fields.entries)');
    buffer.writeln(
      '        entry.key: _unwrapValue(entry.value as Map<String, dynamic>),',
    );
    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Map<String, dynamic> _firestoreFields(Map<String, dynamic> json) {',
    );
    buffer.writeln('    return <String, dynamic>{');
    buffer.writeln('      for (final entry in json.entries)');
    buffer.writeln('        entry.key: _wrapValue(entry.value),');
    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  Object? _unwrapValue(Map<String, dynamic> value) {');
    buffer.writeln(
      "    if (value.containsKey('stringValue')) return value['stringValue'];",
    );
    buffer.writeln("    if (value.containsKey('integerValue')) {");
    buffer.writeln("      return int.tryParse('\${value['integerValue']}');");
    buffer.writeln('    }');
    buffer.writeln("    if (value.containsKey('doubleValue')) {");
    buffer.writeln("      return double.tryParse('\${value['doubleValue']}');");
    buffer.writeln('    }');
    buffer.writeln(
      "    if (value.containsKey('booleanValue')) return value['booleanValue'];",
    );
    buffer.writeln("    if (value.containsKey('timestampValue')) {");
    buffer.writeln("      return value['timestampValue'];");
    buffer.writeln('    }');
    buffer.writeln("    if (value.containsKey('arrayValue')) {");
    buffer.writeln(
      "      final array = value['arrayValue'] as Map<String, dynamic>?;",
    );
    buffer.writeln("      final values = array?['values'] as List<dynamic>?;");
    buffer.writeln('      return <dynamic>[');
    buffer.writeln('        for (final item in values ?? const <dynamic>[])');
    buffer.writeln('          _unwrapValue(item as Map<String, dynamic>),');
    buffer.writeln('      ];');
    buffer.writeln('    }');
    buffer.writeln("    if (value.containsKey('mapValue')) {");
    buffer.writeln(
      "      final map = value['mapValue'] as Map<String, dynamic>?;",
    );
    buffer.writeln(
      "      final inner = map?['fields'] as Map<String, dynamic>?;",
    );
    buffer.writeln('      return <String, dynamic>{');
    buffer.writeln('        for (final entry in inner?.entries ??');
    buffer.writeln('            const <MapEntry<String, dynamic>>[])');
    buffer.writeln(
      '          entry.key: _unwrapValue(entry.value as Map<String, dynamic>),',
    );
    buffer.writeln('      };');
    buffer.writeln('    }');
    buffer.writeln('    return null;');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  Map<String, dynamic> _wrapValue(Object? value) {');
    buffer.writeln(
      "    if (value == null) return const <String, dynamic>{'nullValue': null};",
    );
    buffer.writeln(
      "    if (value is String) return <String, dynamic>{'stringValue': value};",
    );
    buffer.writeln(
      "    if (value is bool) return <String, dynamic>{'booleanValue': value};",
    );
    buffer.writeln(
      "    if (value is int) return <String, dynamic>{'integerValue': '\$value'};",
    );
    buffer.writeln(
      "    if (value is num) return <String, dynamic>{'doubleValue': '\$value'};",
    );
    buffer.writeln('    if (value is List) {');
    buffer.writeln('      return <String, dynamic>{');
    buffer.writeln("        'arrayValue': <String, dynamic>{");
    buffer.writeln(
      "          'values': [for (final item in value) _wrapValue(item)],",
    );
    buffer.writeln('        },');
    buffer.writeln('      };');
    buffer.writeln('    }');
    buffer.writeln('    if (value is Map) {');
    buffer.writeln('      return <String, dynamic>{');
    buffer.writeln("        'mapValue': <String, dynamic>{");
    buffer.writeln("          'fields': <String, dynamic>{");
    buffer.writeln('            for (final entry in value.entries)');
    buffer.writeln("              '\${entry.key}': _wrapValue(entry.value),");
    buffer.writeln('          },');
    buffer.writeln('        },');
    buffer.writeln('      };');
    buffer.writeln('    }');
    buffer.writeln("    return <String, dynamic>{'stringValue': '\$value'};");
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('class _HttpResponse {');
    buffer.writeln('  const _HttpResponse(this.statusCode, this.body);');
    buffer.writeln();
    buffer.writeln('  final int statusCode;');
    buffer.writeln('  final String body;');
    buffer.writeln('}');
    return buffer.toString();
  }

  /// The primary-key expression for store keys / Firestore document ids.
  ///
  /// References a generated-code variable named [varName]. Prefers the first
  /// non-nullable `String` field, falls back to the first non-nullable field,
  /// and uses a generated timestamp for field-less entities.
  String primaryKeyExpr(List<EntityField> fields, [String varName = 'instance']) {
    if (fields.isEmpty) {
      return r"'auto-${DateTime.now().microsecondsSinceEpoch}'";
    }
    final nonNullableStrings = fields.where(
      (f) => !f.nullable && f.type == 'String',
    );
    if (nonNullableStrings.isNotEmpty) {
      return '$varName.${nonNullableStrings.first.name}';
    }
    final nonNullable = fields.where((f) => !f.nullable);
    if (nonNullable.isNotEmpty) {
      return "'\${$varName.${nonNullable.first.name}}'";
    }
    return "'\${$varName.${fields.first.name}}'";
  }

  String _sample(EntityField field) {
    switch (field.type) {
      case 'String':
        return "'sample'";
      case 'int':
        return '1';
      case 'double':
        return '1.5';
      case 'num':
        return '1';
      case 'bool':
        return 'true';
      case 'List<String>':
        return "const <String>['sample']";
      case 'Map<String, dynamic>':
        return "const <String, dynamic>{'sample': true}";
      case 'DateTime':
        return 'DateTime.utc(2026, 1, 1)';
    }
    throw ArgumentError('unsupported field type: ${field.type}');
  }
}
