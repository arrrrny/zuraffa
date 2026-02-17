import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/file_utils.dart';

/// Config command - Manage ZFA configuration
class ConfigCommand {
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      _printHelp();
      exit(0);
    }

    final command = args[0];

    switch (command) {
      case 'init':
        await _handleInit(args.skip(1).toList());
        break;
      case 'show':
      case 'get':
        await _handleShow(args.skip(1).toList());
        break;
      case 'set':
        await _handleSet(args.skip(1).toList());
        break;
      case 'help':
      case '--help':
      case '-h':
        _printHelp();
        break;
      default:
        print('❌ Unknown config command: $command\n');
        _printHelp();
        exit(1);
    }
  }

  Future<void> _handleInit(List<String> args) async {
    print('🔧 Initializing ZFA configuration...');

    final projectRoot = args.isEmpty ? null : args[0];

    if (projectRoot != null && !Directory(projectRoot).existsSync()) {
      print('❌ Directory not found: $projectRoot');
      exit(1);
    }

    final root = projectRoot ?? Directory.current.path;
    final configFile = File(p.join(root, '.zfa.json'));

    if (configFile.existsSync()) {
      print('⚠️  Configuration file already exists: ${configFile.path}');
      print('   Use "zfa config set" to update configuration');
      return;
    }

    // Create default config
    final defaultConfig = {
      'zorphyByDefault': true,
      'jsonByDefault': true,
      'compareByDefault': true,
      'filterByDefault': true,
      'defaultEntityOutput': 'lib/src/domain/entities',
      'gqlByDefault': false,
      'buildByDefault': false,
      'appendByDefault': false,
      'formatByDefault': false,
      'routeByDefault': false,
      'diByDefault': false,
      'notes': [
        'Set "zorphyByDefault": false to use manual entity generation',
        'Set "gqlByDefault": true to auto-generate GraphQL for entity operations',
        'Set "buildByDefault": true to auto-run build_runner after entity/cache operations',
        'Set "appendByDefault": true to auto-append to existing repositories/datasources',
        'Set "formatByDefault": true to auto-run dart format after generation',
        'Set "routeByDefault": true to auto-generate routing files with --vpcs/--vpcs',
        'Set "diByDefault": true to auto-generate DI files',
        'Adjust "defaultEntityOutput" to change where entities are created',
      ],
    };

    const encoder = JsonEncoder.withIndent('  ');
    final content = encoder.convert(defaultConfig);
    await FileUtils.writeFile(configFile.path, content, 'config', force: true);

    print('✅ Created configuration file: ${configFile.path}');
    print('');
    print('📋 Current settings:');
    print('  • zorphyByDefault: true (entities use Zorphy)');
    print('  • jsonByDefault: true (entities include JSON serialization)');
    print('  • compareByDefault: true (entities include compareTo)');
    print('  • filterByDefault: false (type-safe filters disabled by default)');
    print('  • defaultEntityOutput: lib/src/domain/entities');
    print('  • gqlByDefault: false (GraphQL generation disabled by default)');
    print(
      '  • buildByDefault: false (build_runner auto-run disabled by default)',
    );
    print('  • appendByDefault: false (append mode disabled by default)');
    print(
      '  • formatByDefault: false (dart format auto-run disabled by default)',
    );
    print('  • routeByDefault: false (auto-routing disabled by default)');
    print('  • diByDefault: false (auto-DI generation disabled by default)');
    print('');
    print('💡 To disable Zorphy by default, edit .zfa.json and set:');
    print('   "zorphyByDefault": false');
    print('');
    print('💡 To enable auto-routing with VPC:');
    print('   zfa config set routeByDefault true');
    print('');
    print('💡 To enable auto-DI generation:');
    print('   zfa config set diByDefault true');
    print('');
    print('💡 To customize these defaults for your project:');
    print('   zfa config set zorphyByDefault false');
  }

  Future<void> _handleShow(List<String> args) async {
    final projectRoot = args.isEmpty ? null : args[0];
    final root = projectRoot ?? Directory.current.path;
    final configFile = File(p.join(root, '.zfa.json'));

    if (!configFile.existsSync()) {
      print('ℹ️  No configuration file found.');
      print('   Run "zfa config init" to create one with defaults.');
      return;
    }

    try {
      final content = configFile.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;

      print('📋 ZFA Configuration (${configFile.path}):');
      print('');

      print('Settings:');
      json.forEach((key, value) {
        if (key != 'notes') {
          print('  • $key: $value');
        }
      });

      if (json.containsKey('notes') && json['notes'] is List) {
        print('');
        print('Notes:');
        final notes = json['notes'] as List;
        for (final note in notes) {
          print('  • $note');
        }
      }
    } catch (e) {
      print('❌ Error reading configuration: $e');
      exit(1);
    }
  }

  Future<void> _handleSet(List<String> args) async {
    if (args.length < 2) {
      print('❌ Usage: zfa config set <key> <value>');
      print('   Example: zfa config set zorphyByDefault false');
      exit(1);
    }

    final key = args[0];
    final value = args[1];

    final projectRoot = Directory.current.path;
    final configFile = File(p.join(projectRoot, '.zfa.json'));

    if (!configFile.existsSync()) {
      print('❌ Configuration file not found.');
      print('   Run "zfa config init" to create one first.');
      exit(1);
    }

    try {
      final content = configFile.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // Parse value based on key
      dynamic parsedValue;
      switch (key) {
        case 'zorphyByDefault':
        case 'jsonByDefault':
        case 'compareByDefault':
        case 'filterByDefault':
        case 'gqlByDefault':
        case 'buildByDefault':
        case 'appendByDefault':
        case 'formatByDefault':
        case 'routeByDefault':
        case 'diByDefault':
          parsedValue = value.toLowerCase() == 'true';
          break;
        case 'defaultEntityOutput':
          parsedValue = value;
          break;
        default:
          print('❌ Unknown configuration key: $key');
          print(
            '   Valid keys: zorphyByDefault, jsonByDefault, compareByDefault, filterByDefault, defaultEntityOutput, gqlByDefault, buildByDefault, appendByDefault, routeByDefault, diByDefault',
          );
          exit(1);
      }

      json[key] = parsedValue;

      const encoder = JsonEncoder.withIndent('  ');
      final newContent = encoder.convert(json);
      await FileUtils.writeFile(
        configFile.path,
        newContent,
        'config',
        force: true,
      );

      print('✅ Updated configuration:');
      print('   • $key: $parsedValue');
    } catch (e) {
      print('❌ Error updating configuration: $e');
      exit(1);
    }
  }

  void _printHelp() {
    print('''
zfa config - Manage ZFA configuration

USAGE:
  zfa config <command> [options]

COMMANDS:
  init                Create default configuration file (.zfa.json)
  show, get           Show current configuration
  set <key> <value>   Update a configuration value
  help                Show this help message

OPTIONS:
  --help, -h          Show this help message

 CONFIGURATION KEYS:
   zorphyByDefault      Use Zorphy for entity generation (default: true)
                        Set to false to use manual entity generation
 
   jsonByDefault        Enable JSON serialization by default (default: true)
   compareByDefault     Enable compareTo by default (default: true)
   gqlByDefault         Enable GraphQL generation by default (default: false)
   buildByDefault       Auto-run build_runner after entity/cache operations (default: false)
   appendByDefault      Auto-append to existing repositories/datasources (default: false)
   formatByDefault      Auto-run dart format after generation (default: false)
   routeByDefault       Auto-generate routing files with VPC (default: false)
   diByDefault          Auto-generate DI files (default: false)
   defaultEntityOutput  Default output directory for entities
                        (default: lib/src/domain/entities)

EXAMPLES:
  # Initialize configuration in current project
  zfa config init

  # Initialize configuration in specific directory
  zfa config init /path/to/project

  # Show current configuration
  zfa config show

  # Disable Zorphy by default
  zfa config set zorphyByDefault false

  # Set custom output directory
  zfa config set defaultEntityOutput lib/src/models

CONFIGURATION FILE:
  Configuration is stored in .zfa.json in your project root:
  {
    "zorphyByDefault": true,
    "jsonByDefault": true,
    "compareByDefault": true,
    "gqlByDefault": false,
    "defaultEntityOutput": "lib/src/domain/entities"
  }

This file is created by "zfa config init" and can be edited manually
or updated with "zfa config set" commands.
''');
  }
}
