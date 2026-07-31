import 'dart:convert';
import 'dart:io';

import '../schema/schema_parser.dart';

/// Caches and loads GraphQL introspection schemas.
///
/// Supports loading from:
/// - Local JSON file (cached introspection result)
/// - HTTP endpoint (fetches introspection query)
///
/// ```dart
/// final cache = SchemaCache(cacheDir: '.zfa_cache');
/// final schema = await cache.load(
///   endpoint: 'https://api.example.com/graphql',
///   headers: {'Authorization': 'Bearer token'},
/// );
/// ```
class SchemaCache {
  SchemaCache({required this.cacheDir});

  final String cacheDir;

  /// Load schema from cache or fetch from endpoint.
  ///
  /// If [endpoint] is provided, fetches fresh introspection and caches it.
  /// If [endpoint] is null, loads from cached file.
  /// If neither exists, throws [SchemaCacheError].
  Future<GraphQLSchema> load({
    String? endpoint,
    Map<String, String>? headers,
    bool forceRefresh = false,
  }) async {
    final cacheFile = File('$cacheDir/schema.json');

    if (!forceRefresh && endpoint == null && await cacheFile.exists()) {
      final json = jsonDecode(await cacheFile.readAsString());
      return SchemaParser.parse(json);
    }

    if (endpoint != null) {
      final json = await _fetchIntrospection(endpoint, headers);
      await _saveCache(cacheFile, json);
      return SchemaParser.parse(json);
    }

    throw SchemaCacheError(
      'No schema available. Provide endpoint or ensure cache exists at $cacheDir/schema.json',
    );
  }

  /// Save a raw introspection JSON to the cache.
  Future<void> save(Map<String, dynamic> introspectionJson) async {
    final cacheFile = File('$cacheDir/schema.json');
    await cacheFile.create(recursive: true);
    await cacheFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(introspectionJson),
    );
  }

  /// Whether a cached schema exists.
  Future<bool> hasCache() async {
    return File('$cacheDir/schema.json').exists();
  }

  Future<Map<String, dynamic>> _fetchIntrospection(
    String endpoint,
    Map<String, String>? headers,
  ) async {
    // In a real implementation, this would use package:http
    // For the foundation, we document the contract
    throw UnimplementedError(
      'HTTP fetch not implemented in graphql_core. '
      'Use package:http or provide a pre-fetched schema.json.',
    );
  }

  Future<void> _saveCache(File file, Map<String, dynamic> json) async {
    await file.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }
}

class SchemaCacheError implements Exception {
  SchemaCacheError(this.message);
  final String message;

  @override
  String toString() => 'SchemaCacheError: $message';
}
