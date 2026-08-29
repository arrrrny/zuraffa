import 'dart:convert';
import 'dart:io';

import '../graphql_schema.dart';
import '../introspection/introspection_client.dart';
import '../schema/schema_parser.dart';
import '../sdl/sdl_printer.dart';

/// A cached schema artifact set: the introspection data, the parsed schema,
/// and the file locations it was loaded from.
class CachedSchema {
  const CachedSchema({
    required this.name,
    required this.data,
    required this.schema,
    required this.jsonFile,
    this.sdlFile,
  });

  /// Cache name (the `<name>` in `.zfa/graphql/<name>/`).
  final String name;

  /// The introspection `data` object (contains `__schema`).
  final Map<String, dynamic> data;

  /// Parsed schema model.
  final GqlSchema schema;

  /// File the JSON artifact was read from.
  final File jsonFile;

  /// File the SDL artifact was read from (null when only JSON existed).
  final File? sdlFile;
}

/// Caches and loads GraphQL introspection schemas.
///
/// Spec 037 layout — every named schema is persisted under
/// `.zfa/graphql/<name>/` with BOTH artifacts (FR-001):
/// - `<name>.schema.json`  — the raw introspection result envelope
/// - `<name>.schema.graphql` — the SDL rendering
/// plus flat compatibility copies `.zfa/graphql/<name>.schema.json` /
/// `.zfa/graphql/<name>.schema.graphql` (US-1 scenario 1 path notation).
///
/// Each successful pull/write rotates the previous JSON to
/// `<name>.schema.prev.json` so `zfa graphql diff <name>` can compare the
/// two most recent versions (US-2 flow: pull → mutate → re-pull → diff).
///
/// The legacy single-file API (`load`/`save`/`hasCache` addressing
/// `<cacheDir>/schema.json`) is preserved for existing callers.
class SchemaCache {
  SchemaCache({required this.cacheDir});

  /// Cache root, e.g. `.zfa/graphql`.
  final String cacheDir;

  // ------------------------------------------------------------------
  // Path helpers (spec 037 per-name layout)
  // ------------------------------------------------------------------

  String _dirJsonFor(String name) => '$cacheDir/$name/$name.schema.json';
  String _dirSdlFor(String name) => '$cacheDir/$name/$name.schema.graphql';
  String _dirPrevJsonFor(String name) =>
      '$cacheDir/$name/$name.schema.prev.json';
  String _flatJsonFor(String name) => '$cacheDir/$name.schema.json';
  String _flatSdlFor(String name) => '$cacheDir/$name.schema.graphql';

  // ------------------------------------------------------------------
  // Per-name API (spec 037)
  // ------------------------------------------------------------------

  /// Fetches a schema via introspection and persists both artifacts.
  ///
  /// [endpoint] is required unless a [transport] is injected (tests and
  /// fixture-driven flows). Nothing is written until the fetch AND the
  /// schema parse both succeed — no partial artifacts on failure (US-1
  /// scenario 3).
  Future<CachedSchema> pull(
    String name, {
    Uri? endpoint,
    Map<String, String>? headers,
    IntrospectionTransport? transport,
  }) async {
    if (endpoint == null && transport == null) {
      throw SchemaCacheError(
        "Cannot pull schema '$name': provide --endpoint (or a transport).",
      );
    }
    final client = IntrospectionClient(transport: transport);
    final data = await client.fetch(
      endpoint ?? Uri.parse('fixture://$name'),
      headers: headers,
    );
    return _persist(name, data);
  }

  /// Persists an already-fetched introspection result (envelope with
  /// `data.__schema`, or the bare data object) without any network access.
  Future<CachedSchema> write(String name, Map<String, dynamic> json) {
    return _persist(name, _normalizeEnvelope(json));
  }

  /// Reads the current cached schema for [name].
  ///
  /// Throws [SchemaCacheError] naming the expected file when the schema is
  /// not cached or the artifact is corrupt — never returns null on failure
  /// (FR-002).
  Future<CachedSchema> read(String name) async {
    final jsonFile = File(_dirJsonFor(name));
    if (!await jsonFile.exists()) {
      final flat = File(_flatJsonFor(name));
      if (await flat.exists()) {
        return _loadFrom(flat, name);
      }
      throw SchemaCacheError(
        "No cached schema named '$name' "
        '(expected ${jsonFile.path} or ${flat.path}). '
        'Run `zfa graphql pull` first.',
      );
    }
    return _loadFrom(jsonFile, name);
  }

  /// Reads the previous version of [name]'s schema, or null when only one
  /// version has ever been pulled.
  Future<CachedSchema?> readPrevious(String name) async {
    final prevFile = File(_dirPrevJsonFor(name));
    if (!await prevFile.exists()) {
      final legacy = File('$cacheDir/$name/$name.schema.json.prev');
      if (!await legacy.exists()) return null;
      return _loadFrom(legacy, name);
    }
    return _loadFrom(prevFile, name);
  }

  /// Whether a current schema artifact exists for [name].
  Future<bool> hasSchema(String name) async {
    if (await File(_dirJsonFor(name)).exists()) return true;
    return File(_flatJsonFor(name)).exists();
  }

  /// Lists all cached schema names (per-name dirs first, then flat files).
  List<String> listSchemas() {
    final names = <String>{};
    final root = Directory(cacheDir);
    if (root.existsSync()) {
      for (final entity in root.listSync()) {
        final base = entity.uri.pathSegments.last;
        if (entity is Directory && base.isNotEmpty) {
          names.add(base);
        } else if (base.endsWith('.schema.json')) {
          names.add(base.substring(0, base.length - '.schema.json'.length));
        }
      }
    }
    return names.toList()..sort();
  }

  Future<CachedSchema> _loadFrom(File file, String name) async {
    final Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('root is not a JSON object');
      }
      envelope = decoded;
    } on FormatException catch (e) {
      throw SchemaCacheError(
        'Cached schema at ${file.path} is corrupted (invalid JSON): $e',
      );
    } on TypeError catch (e) {
      throw SchemaCacheError(
        'Cached schema at ${file.path} has unexpected structure: $e',
      );
    }

    final data = _extractData(envelope);
    final sdlFile = File(
      file.path.replaceAll('.schema.json', '.schema.graphql'),
    );
    return CachedSchema(
      name: name,
      data: data,
      schema: GqlSchema.fromIntrospection(data),
      jsonFile: file,
      sdlFile: await sdlFile.exists() ? sdlFile : null,
    );
  }

  /// Fetch → validate → write pipeline shared by [pull] and [write].
  ///
  /// [json] may be the full response envelope (`{'data': {...}}`) or the
  /// bare data map; the artifact is always written in envelope form.
  Future<CachedSchema> _persist(String name, Map<String, dynamic> json) async {
    final envelope = _normalizeEnvelope(json);
    final data = _extractData(envelope);

    final GqlSchema schema;
    try {
      schema = GqlSchema.fromIntrospection(data);
    } catch (e) {
      throw SchemaCacheError(
        "Pulled schema for '$name' is malformed and was NOT written: $e",
      );
    }

    // Rotate previous version (if any) BEFORE overwriting.
    final dirJson = File(_dirJsonFor(name));
    if (await dirJson.exists()) {
      await _atomicWrite(
        File(_dirPrevJsonFor(name)),
        await dirJson.readAsString(),
      );
    }

    final sdl = SdlPrinter(schema).printSchema();
    final prettyJson = const JsonEncoder.withIndent('  ').convert(envelope);

    // Canonical per-name directory layout (FR-001).
    await _atomicWrite(dirJson, prettyJson);
    await _atomicWrite(File(_dirSdlFor(name)), sdl);
    // Flat compatibility copies (US-1 scenario 1 notation).
    await _atomicWrite(File(_flatJsonFor(name)), prettyJson);
    await _atomicWrite(File(_flatSdlFor(name)), sdl);

    return CachedSchema(
      name: name,
      data: data,
      schema: schema,
      jsonFile: dirJson,
      sdlFile: File(_dirSdlFor(name)),
    );
  }

  /// Normalizes a raw argument to the full envelope form
  /// `{'data': {...}}` (accepts either the envelope or the bare data map).
  Map<String, dynamic> _normalizeEnvelope(Map<String, dynamic> json) {
    if (json.containsKey('__schema')) {
      return {'data': json};
    }
    // Already an envelope (has a 'data' object) — pass through.
    final inner = json['data'];
    if (inner is Map && inner.containsKey('__schema')) {
      return json;
    }
    return json;
  }

  /// Accepts either `{'data': {...}}` or the bare data map; returns the
  /// data map with `__schema`.
  Map<String, dynamic> _extractData(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is Map<String, dynamic> && data.containsKey('__schema')) {
      return data;
    }
    if (envelope.containsKey('__schema')) {
      return envelope;
    }
    throw SchemaCacheError(
      'Introspection JSON has no data.__schema object — refusing to cache '
      'a malformed schema.',
    );
  }

  Future<void> _atomicWrite(File file, String content) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content);
    await tmp.rename(file.path);
  }

  // ------------------------------------------------------------------
  // Legacy single-file API (pre-037 callers; <cacheDir>/schema.json)
  // ------------------------------------------------------------------

  /// Load schema from cache or fetch from endpoint (legacy single-file
  /// layout used by `zfa graphql generate`).
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
      final client = IntrospectionClient();
      final data = await client.fetch(Uri.parse(endpoint), headers: headers);
      await _saveCache(cacheFile, {'data': data});
      return SchemaParser.parse({'data': data});
    }

    throw SchemaCacheError(
      'No schema available. Provide endpoint or ensure cache exists at '
      '${cacheFile.path}',
    );
  }

  /// Save a raw introspection JSON to the legacy single-file cache.
  Future<void> save(Map<String, dynamic> introspectionJson) async {
    final cacheFile = File('$cacheDir/schema.json');
    await cacheFile.create(recursive: true);
    await cacheFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(introspectionJson),
    );
  }

  /// Whether a legacy single-file cached schema exists.
  Future<bool> hasCache() async {
    return File('$cacheDir/schema.json').exists();
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
