import 'dart:io';
import 'package:args/command_runner.dart';
import 'commands/generate_command.dart';
import 'commands/schema_command.dart';
import 'commands/validate_command.dart';
import 'commands/create_command.dart';
import 'commands/config_command.dart';
import 'commands/initialize_command.dart';
import 'commands/entity_command.dart';
import 'commands/plugin_command.dart';
import 'commands/make_command.dart';
import 'commands/doctor_command.dart';
import 'core/plugin_system/plugin_registry.dart';
import 'version.dart';

import 'plugins/di/di_plugin.dart';
import 'plugins/route/route_plugin.dart';
import 'plugins/view/view_plugin.dart';
import 'plugins/controller/controller_plugin.dart';
import 'plugins/presenter/presenter_plugin.dart';
import 'plugins/usecase/usecase_plugin.dart';
import 'plugins/repository/repository_plugin.dart';
import 'plugins/datasource/datasource_plugin.dart';
import 'plugins/service/service_plugin.dart';
import 'plugins/test/test_plugin.dart';
import 'plugins/state/state_plugin.dart';
import 'plugins/provider/provider_plugin.dart';
import 'plugins/mock/mock_plugin.dart';
import 'plugins/cache/cache_plugin.dart';
import 'plugins/graphql/graphql_plugin.dart';
import 'plugins/observer/observer_plugin.dart';

Future<void> run(List<String> args) async {
  if (args.isEmpty) {
    _printHelp();
    exit(0);
  }

  // 1. Initialize CommandRunner with description
  final runner = CommandRunner('zfa', 'Zuraffa Code Generator')
    ..argParser.addFlag(
      'version',
      negatable: false,
      abbr: 'v',
      help: 'Print version',
    );

  // 2. Register Modular Plugin Commands
  // Note: In the future, this should iterate over a registry
  final routePlugin = RoutePlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final diPlugin = DiPlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final viewPlugin = ViewPlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final controllerPlugin = ControllerPlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final presenterPlugin = PresenterPlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final useCasePlugin = UseCasePlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final repositoryPlugin = RepositoryPlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final dataSourcePlugin = DataSourcePlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final servicePlugin = ServicePlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final testPlugin = TestPlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final statePlugin = StatePlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final providerPlugin = ProviderPlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final mockPlugin = MockPlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final cachePlugin = CachePlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final graphqlPlugin = GraphqlPlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  final observerPlugin = ObserverPlugin(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
  );

  // Register plugins in the registry for MakeCommand to find them
  PluginRegistry.instance.register(routePlugin);
  PluginRegistry.instance.register(diPlugin);
  PluginRegistry.instance.register(viewPlugin);
  PluginRegistry.instance.register(controllerPlugin);
  PluginRegistry.instance.register(presenterPlugin);
  PluginRegistry.instance.register(useCasePlugin);
  PluginRegistry.instance.register(repositoryPlugin);
  PluginRegistry.instance.register(dataSourcePlugin);
  PluginRegistry.instance.register(servicePlugin);
  PluginRegistry.instance.register(testPlugin);
  PluginRegistry.instance.register(statePlugin);
  PluginRegistry.instance.register(providerPlugin);
  PluginRegistry.instance.register(mockPlugin);
  PluginRegistry.instance.register(cachePlugin);
  PluginRegistry.instance.register(graphqlPlugin);
  PluginRegistry.instance.register(observerPlugin);

  runner.addCommand(routePlugin.createCommand());
  runner.addCommand(diPlugin.createCommand());
  runner.addCommand(viewPlugin.createCommand());
  runner.addCommand(controllerPlugin.createCommand());
  runner.addCommand(presenterPlugin.createCommand());
  runner.addCommand(useCasePlugin.createCommand());
  runner.addCommand(repositoryPlugin.createCommand());
  runner.addCommand(dataSourcePlugin.createCommand());
  runner.addCommand(servicePlugin.createCommand());
  runner.addCommand(testPlugin.createCommand());
  runner.addCommand(statePlugin.createCommand());
  runner.addCommand(providerPlugin.createCommand());
  runner.addCommand(mockPlugin.createCommand());
  runner.addCommand(cachePlugin.createCommand());
  runner.addCommand(graphqlPlugin.createCommand());
  runner.addCommand(observerPlugin.createCommand());
  runner.addCommand(MakeCommand(PluginRegistry.instance));
  runner.addCommand(DoctorCommand());

  // 3. Dispatch
  // If the command is one of our new modular commands, let CommandRunner handle it.
  if (args.isNotEmpty && runner.commands.keys.contains(args[0])) {
    try {
      await runner.run(args);
    } catch (e) {
      if (e is UsageException) {
        print(e);
        exit(64);
      } else {
        print('❌ Error: $e');
        exit(1);
      }
    }
    return;
  }

  // 4. Fallback to Legacy Switch for existing commands
  // TODO: Migrate these to CommandRunner commands
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
        break;
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
      case 'plugin':
        await PluginCommand().execute(args.skip(1).toList());
        break;
      case 'build':
        await _handleBuild(args.skip(1).toList());
        break;
      case 'help':
      case '--help':
      case '-h':
        _printHelp();
        // Also show modular commands help
        print('\nMODULAR COMMANDS:');
        runner.printUsage();
        break;
      case 'version':
      case '--version':
      case '-v':
        print('zfa v$version');
        print('Zuraffa Code Generator');
        break;
      default:
        // If it looks like a flag but no command, show help
        if (command.startsWith('-')) {
          print('zfa v$version');
          print('Zuraffa Code Generator');
          return;
        }
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
  doctor              Check your environment and dependencies
  plugin              Manage plugins (list, enable, disable)
  schema              Output JSON schema for configuration
  validate <file>     Validate JSON configuration file
  graphql             Introspect GraphQL schema and generate entities + usecases
  view <Name>         Generate an additional view for existing VPC
  test <UseCaseName>  Generate tests for existing usecases
  di <UseCaseName>    Generate DI registration for existing usecases

MODULAR COMMANDS:
  route <Name>        Generate route definitions (standalone)

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

EXAMPLES - MODULAR:
  zfa route Product --methods=get,create           # Generate only route definitions

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
''');
}
