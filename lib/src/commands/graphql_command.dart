import 'dart:io';
import 'package:args/args.dart';
import '../graphql/graphql_introspection_service.dart';
import '../graphql/graphql_schema_translator.dart';
import '../graphql/graphql_entity_emitter.dart';
import '../models/generator_config.dart';
import '../generator/code_generator.dart';
import '../utils/logger.dart';

/// Command for introspecting a GraphQL schema and generating entities + usecases.
class GraphQLCommand {
  Future<void> execute(List<String> args) async {
    if (args.isEmpty || args[0] == '--help' || args[0] == '-h') {
      _printHelp();
      exit(0);
    }

    final parser = _buildParser();
    final ArgResults results;
    try {
      results = parser.parse(args);
    } on FormatException catch (e) {
      print('❌ ${e.message}');
      print('\nRun: zfa graphql --help for usage information');
      exit(1);
    }

    final url = results['url'] as String?;
    if (url == null || url.isEmpty) {
      print('❌ Error: --url is required');
      print('\nUsage: zfa graphql --url=<endpoint> [options]');
      exit(1);
    }

    final outputDir = results['output'] as String;
    final methodsStr = results['methods'] as String;
    final methods = methodsStr.split(',').map((s) => s.trim()).toList();
    final includeStr = results['include'] as String?;
    final excludeStr = results['exclude'] as String?;
    final authToken = results['auth'] as String?;
    final skipUsecases = results['skip-usecases'] == true;
    final useZorphy = results['zorphy'] == true;
    final dryRun = results['dry-run'] == true;
    final force = results['force'] == true;
    final verbose = results['verbose'] == true;

    final include = includeStr?.split(',').map((s) => s.trim()).toSet();
    final exclude = excludeStr?.split(',').map((s) => s.trim()).toSet();

    // Build headers
    final headers = <String, String>{};
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    if (verbose) {
      print('🔍 Introspecting GraphQL schema from: $url');
    }

    // Step 1: Introspect
    final schema = await GraphQLIntrospectionService.introspect(
      url: url,
      headers: headers.isNotEmpty ? headers : null,
    );

    if (schema == null) {
      print('❌ Failed to introspect GraphQL schema');
      print('   Check the URL and authentication token');
      exit(1);
    }

    if (verbose) {
      print('✅ Schema fetched successfully');
      print('   Types: ${schema.types.length}');
    }

    // Step 2: Translate
    final translator = GraphQLSchemaTranslator(schema);
    final entitySpecs = translator.extractEntitySpecs(
      include: include,
      exclude: exclude,
    );
    final enumSpecs = translator.extractEnumSpecs(
      include: include,
      exclude: exclude,
    );

    if (verbose) {
      print('📦 Found ${entitySpecs.length} entities and ${enumSpecs.length} enums');
    }

    if (entitySpecs.isEmpty && enumSpecs.isEmpty) {
      print('⚠️  No entities or enums found matching the filters');
      exit(0);
    }

    // Step 3: Generate enums first (entities may reference them)
    final emitter = GraphQLEntityEmitter(
      outputDir: outputDir,
      useZorphy: useZorphy,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    final generatedEnums = <String>[];
    for (final enumSpec in enumSpecs) {
      final path = await emitter.generateEnum(enumSpec);
      if (path != null) {
        generatedEnums.add(enumSpec.name);
      }
    }

    // Step 4: Generate entities
    final generatedEntities = <String>[];
    for (final entitySpec in entitySpecs) {
      final path = await emitter.generateEntity(entitySpec);
      if (path != null) {
        generatedEntities.add(entitySpec.name);
      }
    }

    // Step 5: Generate usecases (reuse CodeGenerator)
    final generatedUsecases = <String>[];
    if (!skipUsecases) {
      for (final entitySpec in entitySpecs) {
        final config = GeneratorConfig(
          name: entitySpec.name,
          methods: methods,
          idField: entitySpec.idField,
          idType: entitySpec.idDartType,
          queryField: entitySpec.idField,
          queryFieldType: entitySpec.idDartType,
          generateRepository: true,
          useZorphy: useZorphy,
        );

        final generator = CodeGenerator(
          config: config,
          outputDir: outputDir,
          dryRun: dryRun,
          force: force,
          verbose: verbose,
        );

        final result = await generator.generate();

        if (result.success) {
          generatedUsecases.add(entitySpec.name);
          if (verbose) {
            CliLogger.printResult(result);
          }
        } else {
          print('⚠️  Failed to generate usecases for ${entitySpec.name}');
          for (final error in result.errors) {
            print('   $error');
          }
        }
      }
    }

    // Summary
    print('');
    print('✅ GraphQL introspection complete!');
    print('');
    if (generatedEnums.isNotEmpty) {
      print('📋 Enums: ${generatedEnums.join(', ')}');
    }
    if (generatedEntities.isNotEmpty) {
      print('📦 Entities: ${generatedEntities.join(', ')}');
    }
    if (generatedUsecases.isNotEmpty) {
      print('🔧 UseCases generated for: ${generatedUsecases.join(', ')}');
    }
    if (dryRun) {
      print('');
      print('ℹ️  Dry run - no files were written');
    }

    // Next steps
    print('');
    print('Next steps:');
    if (useZorphy) {
      print('  1. Run: dart run build_runner build');
    }
    if (!skipUsecases) {
      print('  2. Implement DataSource classes for each entity');
      print('  3. Register dependencies with DI container');
    }
  }

  ArgParser _buildParser() {
    return ArgParser()
      ..addOption(
        'url',
        abbr: 'u',
        help: 'GraphQL endpoint URL (required)',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output directory',
        defaultsTo: 'lib/src',
      )
      ..addOption(
        'methods',
        abbr: 'm',
        help: 'CRUD methods to generate (comma-separated)',
        defaultsTo: 'get,getList,create,update,delete',
      )
      ..addOption(
        'include',
        help: 'Types to include (comma-separated)',
      )
      ..addOption(
        'exclude',
        help: 'Types to exclude (comma-separated)',
      )
      ..addOption(
        'auth',
        help: 'Bearer authentication token',
      )
      ..addFlag(
        'skip-usecases',
        help: 'Only generate entities (skip usecases)',
        defaultsTo: false,
      )
      ..addFlag(
        'zorphy',
        help: 'Use Zorphy annotations for entities',
        defaultsTo: true,
      )
      ..addFlag(
        'dry-run',
        help: 'Preview without writing files',
        defaultsTo: false,
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite existing files',
        defaultsTo: false,
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Verbose output',
        defaultsTo: false,
      );
  }

  void _printHelp() {
    print('''
zfa graphql - Introspect GraphQL schema and generate entities + usecases

USAGE:
  zfa graphql --url=<endpoint> [options]

OPTIONS:
  -u, --url=<url>         GraphQL endpoint URL (required)
  -o, --output=<dir>      Output directory (default: lib/src)
  -m, --methods=<list>    CRUD methods to generate (default: get,getList,create,update,delete)
  --include=<types>       Types to include (comma-separated)
  --exclude=<types>       Types to exclude (comma-separated)
  --auth=<token>          Bearer authentication token
  --skip-usecases         Only generate entities (skip usecases)
  --zorphy                Use Zorphy annotations (default: true)
  --dry-run               Preview without writing files
  -f, --force             Overwrite existing files
  -v, --verbose           Verbose output

EXAMPLES:
  # Basic introspection
  zfa graphql --url=https://api.example.com/graphql

  # With authentication
  zfa graphql --url=https://api.example.com/graphql --auth=your-token

  # Only specific types
  zfa graphql --url=https://api.example.com/graphql --include=User,Product,Order

  # Exclude internal types
  zfa graphql --url=https://api.example.com/graphql --exclude=Query,Mutation,Subscription

  # Only generate entities (no usecases)
  zfa graphql --url=https://api.example.com/graphql --skip-usecases

  # Custom methods
  zfa graphql --url=https://api.example.com/graphql --methods=get,getList,watch

  # Preview without writing
  zfa graphql --url=https://api.example.com/graphql --dry-run --verbose
''');
  }
}
