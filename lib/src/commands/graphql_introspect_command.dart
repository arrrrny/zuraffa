import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../graphql/graphql_introspection_service.dart';
import '../graphql/graphql_schema_translator.dart';
import '../graphql/graphql_schema.dart';

/// CLI command for introspecting a remote GraphQL endpoint and printing
/// a generation plan (entities, enums, input types).
///
/// Usage:
///   zfa graphql introspect `https://api.example.com/graphql`
///
/// Example:
///   zfa graphql introspect https://api.example.com/graphql
///   zfa graphql introspect http://localhost:3000/shop-api --verbose
class IntrospectCommand extends Command<void> {
  IntrospectCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for generated files',
      defaultsTo: 'lib/src',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Print the generation plan without writing files',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Print detailed type information',
    );
    argParser.addOption(
      'headers',
      help:
          'JSON object of additional HTTP headers to send with the introspection request',
    );
  }

  @override
  String get name => 'introspect';

  @override
  String get description =>
      'Introspect a remote GraphQL endpoint and print a generation plan';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      exitCode = 64;
      print('Usage: zfa graphql introspect <endpoint-url> [options]');
      print('  endpoint-url    The GraphQL endpoint URL to introspect');
      print('');
      print('Options:');
      print('  --output, -o    Output directory (default: lib/src)');
      print('  --dry-run       Print plan without writing files');
      print('  --force, -f     Overwrite existing files');
      print('  --verbose, -v   Show detailed type information');
      print('  --headers       JSON object of additional HTTP headers');
      return;
    }

    final endpoint = argResults!.rest.first;
    final outputDir = argResults!['output'] as String? ?? 'lib/src';
    final dryRun = argResults!['dry-run'] == true;
    final force = argResults!['force'] == true;
    final verbose = argResults!['verbose'] == true;
    final headersStr = argResults!['headers'] as String?;

    // Parse custom headers if provided
    Map<String, String>? customHeaders;
    if (headersStr != null) {
      try {
        final decoded = jsonDecode(headersStr) as Map<String, dynamic>;
        customHeaders = decoded.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      } catch (e) {
        print('Error: --headers must be a valid JSON object. Got: $headersStr');
        return;
      }
    }

    // Validate URL
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      print('Error: Invalid endpoint URL: $endpoint');
      return;
    }

    final isVerbose = verbose;
    if (isVerbose) {
      print('Introspecting: $endpoint');
      if (customHeaders != null) {
        print('Custom headers: ${customHeaders.keys.join(', ')}');
      }
      print('');
    }

    // Introspect the endpoint
    print('Querying GraphQL schema from $endpoint ...');
    final schema = await GraphQLIntrospectionService.introspect(
      url: endpoint,
      headers: customHeaders,
    );

    if (schema == null) {
      print('Failed to introspect schema from $endpoint.');
      print('Possible causes:');
      print('  - The endpoint is not reachable');
      print('  - The endpoint does not support GraphQL introspection');
      print('  - The server returned an error or non-200 status code');
      return;
    }

    // Translate to entity/enum specs
    final translator = GraphQLSchemaTranslator(schema);
    final entitySpecs = translator.extractEntitySpecs();
    final enumSpecs = translator.extractEnumSpecs();

    // Print generation plan
    _printPlan(
      schema: schema,
      entitySpecs: entitySpecs,
      enumSpecs: enumSpecs,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: isVerbose,
    );
  }

  void _printPlan({
    required GqlSchema schema,
    required List<EntitySpec> entitySpecs,
    required List<EnumSpec> enumSpecs,
    required String outputDir,
    required bool dryRun,
    required bool force,
    required bool verbose,
  }) {
    print('');
    print('GraphQL Schema Introspection Results');
    print('=' * 50);

    if (schema.queryTypeName != null) {
      print('  Query root: ${schema.queryTypeName}');
    }
    if (schema.mutationTypeName != null) {
      print('  Mutation root: ${schema.mutationTypeName}');
    }
    if (schema.subscriptionTypeName != null) {
      print('  Subscription root: ${schema.subscriptionTypeName}');
    }

    print('');
    print('Discovered Types');
    print('  Entities (Object types): ${entitySpecs.length}');
    print('  Enums: ${enumSpecs.length}');
    print('  Total types in schema: ${schema.types.length}');

    if (entitySpecs.isEmpty && enumSpecs.isEmpty) {
      print('');
      print('No generatable types found (only built-in/root types present).');
      return;
    }

    // Print entity details
    if (entitySpecs.isNotEmpty) {
      print('');
      print('Entities');
      print('-' * 50);
      for (final spec in entitySpecs) {
        final fieldCount = spec.fields.length;
        final idInfo = 'id: $spec.idField (${spec.idDartType})';
        print('  ${spec.name} ($fieldCount fields, $idInfo)');
        if (verbose) {
          for (final field in spec.fields) {
            final nullability = field.isNullable ? '?' : '';
            final listMarker = field.isList ? '[]' : '';
            final ref = field.referencedEntity != null
                ? ' → ${field.referencedEntity}'
                : field.referencedEnum != null
                ? ' → ${field.referencedEnum}'
                : '';
            print(
              '    ${field.dartType}$nullability$listMarker ${field.name}$ref',
            );
          }
        }
      }
    }

    // Print enum details
    if (enumSpecs.isNotEmpty) {
      print('');
      print('Enums');
      print('-' * 50);
      for (final spec in enumSpecs) {
        print('  ${spec.name} (${spec.values.length} values)');
        if (verbose) {
          for (final val in spec.values) {
            print('    $val');
          }
        }
      }
    }

    // Print generation commands
    print('');
    print('Generation Plan');
    print('-' * 50);
    print('  Output directory: $outputDir');

    for (final spec in entitySpecs) {
      final flag = force ? ' --force' : '';
      print('  zfa entity ${spec.name} --domain graphql$flag');
    }

    for (final spec in enumSpecs) {
      print(
        '  (enum ${spec.name} would be generated as part of entity generation)',
      );
    }

    if (dryRun) {
      print('');
      print('(dry-run: no files written)');
    } else {
      print('');
      print('To generate entities, run the commands above or use:');
      print('  zfa make <EntityName> --domain graphql');
    }
  }
}
