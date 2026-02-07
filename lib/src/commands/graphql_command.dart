import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:args/args.dart';
import '../graphql/graphql_introspection_service.dart';
import '../graphql/graphql_schema_translator.dart';
import '../graphql/graphql_entity_emitter.dart';
import '../models/generator_config.dart';
import '../models/generator_result.dart';
import '../models/generated_file.dart';
import '../generator/code_generator.dart';
import '../utils/logger.dart';
import '../utils/string_utils.dart';
import 'generate_command.dart';

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
    final entitiesStr = results['entities'] as String? ?? results['include'] as String?;
    final queriesStr = results['queries'] as String?;
    final mutationsStr = results['mutations'] as String?;
    final domain = results['domain'] as String?;
    final excludeStr = results['exclude'] as String?;
    final authToken = results['auth'] as String?;
    final repo = results['repo'] as String?;
    final service = results['service'] as String?;
    final generateData = results['data'] == true;
    final useZorphy = results['zorphy'] == true;
    final dryRun = results['dry-run'] == true;
    final displayStr = results['display'] as String?;
    final force = results['force'] == true;
    final verbose = results['verbose'] == true;

    if (queriesStr != null || mutationsStr != null) {
      if (domain == null || domain.isEmpty) {
        print('❌ Error: --domain is required when specifying --queries or --mutations');
        exit(1);
      }
    }

    final queryNames = queriesStr?.split(',').map((s) => s.trim()).toSet();
    final mutationNames = mutationsStr?.split(',').map((s) => s.trim()).toSet();
    
    // If specific operations are requested, but no entities are requested,
    // default entities to an empty set to avoid pulling in the whole schema.
    Set<String>? include;
    if (entitiesStr != null) {
      include = entitiesStr.split(',').map((s) => s.trim()).toSet();
    } else if (queryNames != null || mutationNames != null) {
      include = {};
    }

    final exclude = excludeStr?.split(',').map((s) => s.trim()).toSet();
    final display = displayStr?.split(',').map((s) => s.trim()).toSet();

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
    final requestedEntitySpecs = translator.extractEntitySpecs(
      include: include,
      exclude: exclude,
    );
    final enumSpecs = translator.extractEnumSpecs(
      include: include,
      exclude: exclude,
    );
    final operationSpecs = translator.extractOperationSpecs(
      includeQueries: queryNames,
      includeMutations: mutationNames,
    );

    if (verbose) {
      print('📦 Found ${requestedEntitySpecs.length} entities, ${enumSpecs.length} enums, and ${operationSpecs.length} operations');
    }

    if (display != null && display.isNotEmpty) {
      print('\n🔍 Available GraphQL Schema Items:');
      
      if (display.contains('entities') || display.contains('all')) {
        final allTranslatorEntities = translator.extractEntitySpecs();
        print('\n📦 Entities (${allTranslatorEntities.length}):');
        for (final e in allTranslatorEntities) {
          print('  - ${e.name}');
        }
      }
      
      if (display.contains('queries') || display.contains('all')) {
        final allQueries = translator.extractOperationSpecs();
        final queries = allQueries.where((o) => o.type == 'query').toList();
        print('\n🔍 Queries (${queries.length}):');
        for (final q in queries) {
          print('  - ${q.name}');
        }
      }
      
      if (display.contains('mutations') || display.contains('all')) {
        final allMutations = translator.extractOperationSpecs();
        final mutations = allMutations.where((o) => o.type == 'mutation').toList();
        print('\n⚡ Mutations (${mutations.length}):');
        for (final m in mutations) {
          print('  - ${m.name}');
        }
      }
      
      exit(0);
    }

    if (requestedEntitySpecs.isEmpty && enumSpecs.isEmpty && (operationSpecs.isEmpty)) {
      print('⚠️  No entities, enums, or operations found matching the filters');
      exit(0);
    }

    // Step 2.5: Collect all referenced entities and enums recursively
    final allEntityNames = <String>{};
    final allEnumNames = <String>{};
    final processedEntities = <String>{};
    
    void collectReferences(String entityName) {
      if (processedEntities.contains(entityName)) return;
      processedEntities.add(entityName);
      allEntityNames.add(entityName);
      
      // Find the entity spec
      final specs = translator.extractEntitySpecs(
        include: {entityName},
      );
      
      if (specs.isEmpty) return;
      final entitySpec = specs.first;
      
      // Collect referenced entities and enums from fields
      for (final field in entitySpec.fields) {
        if (field.referencedEntity != null) {
          collectReferences(field.referencedEntity!);
        }
        if (field.referencedEnum != null) {
          allEnumNames.add(field.referencedEnum!);
        }
      }
    }
    
    // Start with requested entities
    for (final spec in requestedEntitySpecs) {
      collectReferences(spec.name);
    }

    // Also include entities and enums referenced in operations
    for (final op in operationSpecs) {
      if (op.returnEntityType != null) {
        collectReferences(op.returnEntityType!);
      }
      // Return fields (nested entities)
      for (final field in op.returnFields) {
        if (field.referencedEntity != null) {
          collectReferences(field.referencedEntity!);
        }
        if (field.referencedEnum != null) {
          allEnumNames.add(field.referencedEnum!);
        }
      }
      // Arguments (potential enums or input objects)
      for (final arg in op.args) {
        final rawTypeName = arg.gqlType.replaceAll('[', '').replaceAll(']', '').replaceAll('!', '');
        final typeRef = translator.schema.types[rawTypeName];
        if (typeRef != null) {
          if (typeRef.isEnum) {
            allEnumNames.add(typeRef.name);
          } else if (typeRef.isInputObject) {
            collectReferences(typeRef.name);
          }
        }
      }
    }

    // Also include explicitly requested enums
    for (final spec in enumSpecs) {
      allEnumNames.add(spec.name);
    }
    
    // Get all entity specs including referenced ones
    final allEntitySpecs = translator.extractEntitySpecs(
      include: allEntityNames.isEmpty && include == null ? null : allEntityNames,
    );
    
    // Get all enum specs (filtered if include was provided, otherwise all matching filters)
    final allEnumSpecs = translator.extractEnumSpecs(
      include: allEnumNames.isEmpty && include == null ? null : allEnumNames,
    );
    
    if (verbose && allEntitySpecs.length > requestedEntitySpecs.length) {
      print('📦 Including ${allEntitySpecs.length - requestedEntitySpecs.length} referenced entities');
      print('   Total: ${allEntitySpecs.length} entities and ${allEnumSpecs.length} enums');
    }

    // Step 3: Generate enums first (entities may reference them)
    final emitter = GraphQLEntityEmitter(
      outputDir: outputDir,
      useZorphy: useZorphy,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    final allFiles = <GeneratedFile>[];
    final generatedEnums = <String>[];
    for (final enumSpec in allEnumSpecs) {
      final snakeName = StringUtils.camelToSnake(enumSpec.name);
      final expectedPath = path.join(
        outputDir,
        'domain',
        'entities',
        'enums',
        '$snakeName.dart',
      );
      final exists = File(expectedPath).existsSync();

      final filePath = await emitter.generateEnum(enumSpec);
      if (filePath != null) {
        generatedEnums.add(enumSpec.name);
        allFiles.add(GeneratedFile(
          path: filePath,
          type: 'enum',
          action: exists ? 'updated' : 'created',
        ));
      }
    }

    // Step 4: Generate entities (all including referenced)
    final generatedEntities = <String>[];
    for (final entitySpec in allEntitySpecs) {
      final snakeName = StringUtils.camelToSnake(entitySpec.name);
      final expectedPath = path.join(
        outputDir,
        'domain',
        'entities',
        snakeName,
        '$snakeName.dart',
      );
      final exists = File(expectedPath).existsSync();

      final filePath = await emitter.generateEntity(entitySpec);
      if (filePath != null) {
        generatedEntities.add(entitySpec.name);
        allFiles.add(GeneratedFile(
          path: filePath,
          type: 'entity',
          action: exists ? 'updated' : 'created',
        ));
      }
    }

    // Step 5: Generate usecases
    final generatedUsecases = <String>[];
    // 5.1: Generate standard CRUD usecases for entities (legacy behavior, but kept if no operations specified)
    if (operationSpecs.isEmpty) {
      for (final entitySpec in requestedEntitySpecs) {
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
          allFiles.addAll(result.files);
          if (verbose) {
            CliLogger.printResult(result);
          }
        }
      }
    }

    // 5.2: Generate custom usecases and operations from GraphQL operations
    final generateCmd = GenerateCommand();
    for (final opSpec in operationSpecs) {
      // Generate the GraphQL string file
      final snakeName = StringUtils.camelToSnake(opSpec.name);
      final opType = opSpec.type;
      final domainDir = domain ?? 'graphql';
      final expectedOpPath = path.join(
        outputDir,
        'data',
        'data_sources',
        domainDir,
        'graphql',
        '${snakeName}_$opType.dart',
      );
      final opExists = File(expectedOpPath).existsSync();

      final opPath = await emitter.generateOperation(opSpec, domain: domain);
      if (opPath != null) {
        allFiles.add(GeneratedFile(
          path: opPath,
          type: 'graphql',
          action: opExists ? 'updated' : 'created',
        ));
      }

      // Compose the 'zfa generate' command arguments
      final genArgs = <String>[
        opSpec.operationName,
        '--domain=$domain',
        if (repo != null) '--repo=$repo',
        if (service != null) '--service=$service',
        '--type=usecase',
        '--params=${opSpec.args.isNotEmpty ? '${opSpec.operationName}Params' : 'NoParams'}',
        '--returns=${opSpec.returnType}',
        if (generateData) '--data',
        '--append',
        if (useZorphy) '--zorphy',
        '--gql',
        '--gql-type=${opSpec.type}',
        '--gql-name=${opSpec.name}',
        '--gql-returns=${opSpec.returnFields.map((f) => f.name).join(',')}',
        if (dryRun) '--dry-run',
        if (force) '--force',
        if (verbose) '--verbose',
        '--output=$outputDir',
        '--quiet',
      ];

      print('🚀 Composing: zfa generate ${genArgs.where((a) => a != '--quiet').join(' ')}');

      // Execute via GenerateCommand to ensure all rules and logic are applied
      try {
        final result =
            await generateCmd.execute(genArgs, exitOnCompletion: false);

        if (result.success) {
          generatedUsecases.add(opSpec.operationName);
          allFiles.addAll(result.files);
        }
      } catch (e) {
        if (verbose) {
          print('⚠️  Generation failed for ${opSpec.name}: $e');
        }
      }
    }

    // Final unified summary
    if (allFiles.isNotEmpty) {
      // Deduplicate files by path
      final seenPaths = <String>{};
      final uniqueFiles = allFiles.where((f) => seenPaths.add(f.path)).toList();

      final megaResult = GeneratorResult(
        success: true,
        name: 'GraphQL Introspection',
        files: uniqueFiles,
        errors: [],
        nextSteps: [
          if (operationSpecs.isNotEmpty)
            'Business logic generated in domain layer',
          if (generateData)
            'Ensure GraphQL providers are correctly implemented in data layer',
          if (useZorphy) 'Run build: zfa build',
          'Register dependencies with DI container if using --di',
        ],
      );
      CliLogger.printResult(megaResult);
    }

    if (generatedEnums.isEmpty &&
        generatedEntities.isEmpty &&
        generatedUsecases.isEmpty) {
      print('ℹ️  No changes detected.');
    }
    if (dryRun) {
      print('');
      print('ℹ️  DRY RUN SUMMARY:');
      if (generatedEnums.isNotEmpty) print('  - Would write ${generatedEnums.length} enums');
      if (generatedEntities.isNotEmpty) print('  - Would write ${generatedEntities.length} entities');
      if (operationSpecs.isNotEmpty) {
        print('  - Would write ${operationSpecs.length} GraphQL operation files');
        if (repo != null || service != null) {
          print('  - Would generate/update functional layers using: zfa generate ...');
        } else {
          print('  - Skipping functional layers (UseCases/Repo/Service) because --repo or --service was not provided');
        }
      }
      if (generatedUsecases.isNotEmpty) print('  - Would generate UseCases for: ${generatedUsecases.join(', ')}');
      print('\nℹ️  No files were actually modified.');
    }

    // Next steps
    print('');
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
        'entities',
        help: 'Entities to generate (comma-separated)',
      )
      ..addOption(
        'queries',
        help: 'Queries to generate (comma-separated)',
      )
      ..addOption(
        'mutations',
        help: 'Mutations to generate (comma-separated)',
      )
      ..addOption(
        'domain',
        help: 'Domain name for queries and mutations',
      )
      ..addOption(
        'include',
        help: 'Types to include (legacy, use --entities instead)',
      )
      ..addOption(
        'exclude',
        help: 'Types to exclude (comma-separated)',
      )
      ..addOption(
        'auth',
        help: 'Bearer authentication token',
      )
      ..addOption(
        'display',
        abbr: 'd',
        help: 'Display available items from schema (entities, queries, mutations, all)',
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
      )
      ..addOption(
        'repo',
        help: 'Repository name to inject (required for UseCase generation)',
      )
      ..addOption(
        'service',
        help: 'Service name to inject (alternative to --repo)',
      )
      ..addFlag(
        'data',
        help: 'Generate Data sources (DataSource/DataRepository)',
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
  --auth=<token>          Bearer authentication token
  --entities=<list>       Entities to generate (e.g., Order,Product)
  --queries=<list>        Specific GraphQL queries to import as UseCases
  --mutations=<list>      Specific GraphQL mutations to import as UseCases
  --domain=<name>         Domain for queries/mutations (e.g., order, catalog)
  --repo=<name>           Repository name to inject (e.g., Order, User)
  --service=<name>        Service name to inject (alternative to --repo)
  --data                  Generate functional Data layer (DataSource/DataRepo)
  --exclude=<types>       Types to exclude (comma-separated)
  --include=<types>       Types to include (legacy, use --entities)
  --zorphy                Use Zorphy annotations (default: true)
  --dry-run               Preview without writing files
  -f, --force             Overwrite existing files
  -v, --verbose           Verbose output
  -d, --display=<list>    List available items (entities,queries,mutations,all)

EXAMPLES:
  # Basic introspection (deprecated behavior, generates standard CRUD)
  zfa graphql --url=https://api.example.com/graphql

  # Import specific queries and mutations into a domain (Definition files only)
  zfa graphql -u https://api.example.com/graphql --queries=getProducts --domain=catalog

  # Full integration: Create GraphQL strings + UseCase + Repo + Data layer
  zfa graphql -u url --queries=GetOrder --domain=order --repo=Order --data
  
  # Import entities and specific operations
  zfa graphql -u url --entities=Order --queries=GetOrder --mutations=CreateOrder --domain=order --repo=Order --data

  # With authentication
  zfa graphql --url=https://api.example.com/graphql --auth=your-token

  # List available queries and entities
  zfa graphql -u url -d queries,entities
''');
  }
}
