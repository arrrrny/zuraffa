import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../graphql/cache/schema_cache.dart';
import '../graphql/introspection/introspection_client.dart';

/// `zfa graphql pull` — fetch a GraphQL schema via introspection and cache
/// it locally (spec 037 FR-001).
///
/// Usage:
///   zfa graphql pull --endpoint=https://api.example.com/graphql
///   zfa graphql pull --endpoint=... --name=vendure --dir=.zfa/graphql
class PullCommand extends Command<void> {
  PullCommand() {
    argParser.addOption(
      'endpoint',
      abbr: 'e',
      help: 'GraphQL endpoint URL to introspect',
    );
    argParser.addOption(
      'name',
      abbr: 'n',
      help: 'Cache name (default: derived from the endpoint host)',
    );
    argParser.addOption(
      'dir',
      help: 'Cache root directory (default: .zfa/graphql)',
    );
    argParser.addOption(
      'headers',
      help: 'JSON object of additional HTTP headers for the request',
    );
  }

  @override
  String get name => 'pull';

  @override
  String get description =>
      'Fetch a GraphQL schema via introspection and cache it '
      '(SDL + introspection JSON)';

  @override
  Future<void> run() async {
    final endpointArg = argResults?['endpoint'] as String?;
    if (endpointArg == null || endpointArg.isEmpty) {
      print(
        '❌ Error: --endpoint is required. '
        'Usage: zfa graphql pull --endpoint=<url> [--name=<name>]',
      );
      print(usage);
      exitCode = 64;
      return;
    }

    final endpoint = Uri.tryParse(endpointArg);
    if (endpoint == null || !endpoint.hasScheme || !endpoint.hasAuthority) {
      print('❌ Error: invalid endpoint URL: $endpointArg');
      exitCode = 64;
      return;
    }

    Map<String, String>? headers;
    final headersArg = argResults?['headers'] as String?;
    if (headersArg != null) {
      try {
        final decoded = jsonDecode(headersArg) as Map<String, dynamic>;
        headers = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        print(
          '❌ Error: --headers must be a valid JSON object. '
          'Got: $headersArg',
        );
        exitCode = 64;
        return;
      }
    }

    final nameArg = argResults?['name'] as String?;
    final cacheName = _sanitizeName(
      nameArg ?? _nameFromEndpoint(endpoint) ?? 'default',
    );

    final cacheDir = (argResults?['dir'] as String?) ?? '.zfa/graphql';
    final cache = SchemaCache(cacheDir: cacheDir);

    print('Pulling GraphQL schema from $endpointArg ...');
    try {
      final cached = await cache.pull(
        cacheName,
        endpoint: endpoint,
        headers: headers,
      );
      final typeCount = cached.schema.types.length;
      final sdlPath = cached.sdlFile?.path ?? '$cacheDir/$cacheName.graphql';
      print('');
      print("✅ Schema '$cacheName' cached ($typeCount types)");
      print('   JSON: ${cached.jsonFile.path}');
      print('   SDL:  $sdlPath');
      print('');
      print('Diff against the previous version with:');
      print('   zfa graphql diff $cacheName --dir=$cacheDir');
    } on IntrospectionException catch (e) {
      print('❌ Error pulling schema from $endpointArg:');
      print('   $e');
      exitCode = 1;
    } on SchemaCacheError catch (e) {
      print('❌ Error caching schema: $e');
      exitCode = 1;
    }
  }

  static String? _nameFromEndpoint(Uri endpoint) {
    final host = endpoint.host;
    if (host.isEmpty) return null;
    return host;
  }

  static String _sanitizeName(String raw) {
    final sanitized = raw.replaceAll(RegExp(r'[^0-9a-zA-Z_-]'), '-');
    return sanitized.isEmpty ? 'default' : sanitized;
  }
}
