import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../../graphql/cache/schema_cache.dart';
import '../../graphql/schema/schema_parser.dart';
import 'slice_orchestrator.dart';

/// CLI command: `zfa graphql` group.
///
/// Hosts the `generate` subcommand.
class GraphqlCommand extends Command<void> {
  @override
  String get name => 'graphql';

  @override
  String get description => 'GraphQL schema commands';

  GraphqlCommand() {
    addSubcommand(GraphqlGenerateCommand());
  }
}

/// CLI command: `zfa graphql generate`
///
/// Generates full-stack Dart code from a GraphQL schema.
///
/// ```bash
/// zfa graphql generate --schema=schema.json --output=lib/graphql
/// ```
class GraphqlGenerateCommand extends Command<void> {
  @override
  String get name => 'generate';

  @override
  String get description => 'Generate Dart code from GraphQL schema';

  @override
  String get invocation => 'zfa graphql generate';

  @override
  ArgParser get argParser => _parser;

  static final ArgParser _parser = ArgParser()
    ..addOption('schema', abbr: 's', help: 'Path to schema.json')
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output directory',
      defaultsTo: 'lib/graphql',
    )
    ..addOption('endpoint', abbr: 'e', help: 'GraphQL endpoint URL')
    ..addFlag('force', abbr: 'f', help: 'Force refresh schema from endpoint')
    ..addFlag(
      'verbose',
      help: 'Print full error stack traces',
      negatable: false,
    );

  @override
  Future<void> run() async {
    final args = argResults!;
    final schemaPath = args['schema'] as String?;
    final outputDir = args['output'] as String? ?? 'lib/graphql';
    final endpoint = args['endpoint'] as String?;
    final forceRefresh = args['force'] as bool? ?? false;

    try {
      // Load schema
      late GraphQLSchema schema;
      if (schemaPath != null) {
        final file = File(schemaPath);
        if (!file.existsSync()) {
          stderr.writeln('Error: Schema file not found: $schemaPath');
          throw _CommandExit('Schema file not found: $schemaPath');
        }
        final json = await file.readAsString();
        schema = SchemaParser.parse(jsonDecode(json) as Map<String, dynamic>);
      } else if (endpoint != null) {
        final cache = SchemaCache(cacheDir: '.zfa_cache');
        schema = await cache.load(
          endpoint: endpoint,
          forceRefresh: forceRefresh,
        );
      } else {
        stderr.writeln('Error: Provide --schema or --endpoint');
        throw _CommandExit('Provide --schema or --endpoint');
      }

      // Generate
      stdout.writeln('🚀 Generating full-stack code from GraphQL schema...');
      stdout.writeln('   Schema: ${schema.types.length} types');

      final orchestrator = SliceOrchestrator(
        schema: schema,
        outputDir: outputDir,
      );
      orchestrator.generateAll();

      stdout.writeln(
        '✅ Generated ${orchestrator.generatedFiles.length} files:',
      );
      for (final file in orchestrator.generatedFiles) {
        stdout.writeln('   $file');
      }
    } on _CommandExit catch (e) {
      throw UsageException(e.message, usage);
    } catch (e, st) {
      stderr.writeln('❌ Error: $e');
      if (args['verbose'] as bool? ?? false) {
        stderr.writeln(st.toString());
      }
      throw UsageException('$e', usage);
    }
  }
}

/// Signal for a controlled exit with a non-zero code.
class _CommandExit implements Exception {
  const _CommandExit(this.message);
  final String message;
}
