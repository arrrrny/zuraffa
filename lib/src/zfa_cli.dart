import 'dart:io';
import 'commands/generate_command.dart';
import 'commands/schema_command.dart';
import 'commands/validate_command.dart';
import 'commands/create_command.dart';
import 'commands/config_command.dart';
import 'commands/initialize_command.dart';
import 'commands/entity_command.dart';
import 'commands/graphql_command.dart';
import 'commands/plugin_command.dart';
import 'commands/view_command.dart';
import 'commands/test_command.dart';
import 'commands/di_command.dart';

const version = '2.8.0';

Future<void> run(List<String> args) async {
  if (args.isEmpty) {
    _printHelp();
    exit(0);
  }

  final command = args[0];

  try {
    switch (command) {
      case 'generate':
        await GenerateCommand().execute(args.skip(1).toList());
        break;
      case 'schema':
        SchemaCommand().execute();
        break;
      case 'validate':
        await ValidateCommand().execute(args.skip(1).toList());
        break;
      case 'create':
        await CreateCommand().execute(args.skip(1).toList());
      case 'config':
        await ConfigCommand().execute(args.skip(1).toList());
        break;
      case 'initialize':
      case 'init':
        await InitializeCommand().execute(args.skip(1).toList());
        break;
      case 'entity':
        await EntityCommand().execute(args.skip(1).toList());
        break;
      case 'graphql':
        await GraphQLCommand().execute(args.skip(1).toList());
        break;
      case 'plugin':
        await PluginCommand().execute(args.skip(1).toList());
        break;
      case 'view':
        await ViewCommand().execute(args.skip(1).toList());
        break;
      case 'test':
        await TestCommand().execute(args.skip(1).toList());
        break;
      case 'di':
        await DiCommand().execute(args.skip(1).toList());
        break;
      case 'build':
        await _handleBuild(args.skip(1).toList());
        break;
      case 'help':
      case '--help':
      case '-h':
        _printHelp();
        break;
      case 'version':
      case '--version':
      case '-v':
        print('zfa v$version');
        print('Zuraffa Code Generator');
        break;
      default:
        print('❌ Unknown command: $command\n');
        _printHelp();
        exit(1);
    }
  } catch (e, stack) {
    print('❌ Error: $e');
    if (args.contains('--verbose') || args.contains('-v')) {
      print('\nStack trace:\n$stack');
    }
    exit(1);
  }
}

/// Handle the build command - run build_runner
Future<void> _handleBuild(List<String> args) async {
  final watch = args.contains('-w') || args.contains('--watch');
  final clean = args.contains('-c') || args.contains('--clean');

  print('🔨 Building generated code...');

  if (clean) {
    print('🧹 Cleaning before build...');
  }

  if (watch) {
    print('👀 Watching for changes...');
    print('Press Ctrl+C to stop\n');
  }

  // Run build_runner
  final buildArgs = ['run', 'build_runner'];
  if (clean) buildArgs.add('clean');
  buildArgs.add('build');
  if (watch) buildArgs.add('--watch');

  final process = await Process.start(
    'dart',
    buildArgs,
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    print('\n❌ Build failed with exit code $exitCode');
    exit(exitCode);
  }

  print('\n✅ Build complete!');
}

void _printHelp() {
  print('''
zfa - Zuraffa Code Generator v$version

USAGE:
  zfa <command> [options]

CLEAN ARCHITECTURE COMMANDS:
  generate <Name>     Generate Clean Architecture code for an entity or usecase
  initialize          Initialize a test entity to quickly try out Zuraffa
  create              Create architecture folders or pages
  config              Manage ZFA configuration (.zfa.json)
  plugin              Manage plugins (list, enable, disable)
  schema              Output JSON schema for configuration
  validate <file>     Validate JSON configuration file
  graphql             Introspect GraphQL schema and generate entities + usecases
  view <Name>         Generate an additional view for existing VPC
  test <UseCaseName>  Generate tests for existing usecases
  di <UseCaseName>    Generate DI registration for existing usecases

ENTITY GENERATION COMMANDS (powered by Zorphy):
  entity create       Create a new Zorphy entity with fields
  entity new          Quick-create a simple entity
  entity enum         Create a new enum
  entity add-field    Add field(s) to an existing entity
  entity from-json    Create entity/ies from JSON file
  entity list         List all Zorphy entities

BUILD COMMANDS:
  build               Run code generation (build_runner)
    -w, --watch       Watch for changes
    -c, --clean       Clean before build

HELP:
  help                Show this help message
  version             Show version

EXAMPLES - CONFIGURATION:
  zfa config init                                   # Create .zfa.json with defaults
  zfa config show                                   # Show current configuration
  zfa config set useZorphyByDefault false          # Disable Zorphy by default

EXAMPLES - CLEAN ARCHITECTURE:
  zfa initialize                                    # Create sample Product entity
  zfa generate Product --methods=get,getList        # Generate Clean Architecture
  zfa generate OrderUseCase --custom --returns=Order --zorphy

EXAMPLES - ADDITIONAL VIEW:
  zfa view Payment --domain=checkout --presenter=CheckoutPresenter
  zfa view Payment --domain=checkout --presenter=CheckoutPresenter --state

EXAMPLES - GENERATE TESTS:
  zfa test CreateCustomer                          # Generate test for CreateCustomerUseCase
  zfa test CreateCustomer --domain=customer        # Specify domain folder
  zfa test CreateCustomer --force                  # Overwrite existing test

EXAMPLES - GENERATE DI:
  zfa di CreateCustomer                            # Generate DI for CreateCustomerUseCase
  zfa di CreateCustomer --domain=customer          # Specify domain folder
  zfa di CreateCustomer --force                    # Overwrite existing DI
  zfa di CreateCustomer --use-mock                 # Use mock datasource

EXAMPLES - ENTITY GENERATION:
  zfa entity create User --field name:String --field email:String?
  zfa entity enum Status --value active,inactive,pending
  zfa entity from-json user_data.json
  zfa entity list

EXAMPLES - GRAPHQL:
  zfa graphql --url=https://api.example.com/graphql
  zfa graphql --url=https://api.example.com/graphql --auth=token
  zfa graphql --url=https://api.example.com/graphql --include=User,Product

EXAMPLES - BUILD:
  zfa build                # Run build_runner once
  zfa build --watch        # Watch for changes
  zfa build --clean        # Clean and rebuild

For detailed help on each command:
  zfa generate --help
  zfa view --help
  zfa test --help
  zfa di --help
  zfa entity --help
  zfa graphql --help
  zfa initialize --help
  zfa create --help

Documentation: https://zuraffa.com/docs
Zorphy Docs: https://github.com/arrrrny/zorphy
''');
}
