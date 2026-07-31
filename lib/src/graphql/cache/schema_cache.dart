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
  /// Returns cached schema by default when available.
  /// If [forceRefresh] is true, bypasses cache and fetches from [endpoint].
  /// If no cache exists, fetches from [endpoint] if provided.
  /// If neither exists, throws [SchemaCacheError].
  Future<GraphQLSchema> load({
    String? endpoint,
    Map<String, String>? headers,
    bool forceRefresh = false,
  }) async {
    final cacheFile = File('$cacheDir/schema.json');

    if (!forceRefresh && await cacheFile.exists()) {
      try {
        final json = jsonDecode(await cacheFile.readAsString());
        if (json is! Map<String, dynamic>) {
          throw FormatException('Cache root is not a JSON object');
        }
        return SchemaParser.parse(json);
      } on FormatException catch (e) {
        throw SchemaCacheError('Cache file is corrupted (invalid JSON): $e');
      } on TypeError catch (e) {
        throw SchemaCacheError('Cache file has unexpected structure: $e');
      }
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
