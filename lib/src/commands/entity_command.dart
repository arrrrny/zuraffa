import 'dart:io';

/// Entity Command - Delegates to Zorphy CLI for entity generation
///
/// This command provides a convenient wrapper around Zorphy's CLI,
/// allowing users to create entities, enums, and manage them through
/// the zfa CLI.
class EntityCommand {
  /// Execute the entity command by delegating to zorphy CLI
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      _printHelp();
      exit(0);
    }

    final subCommand = args[0];
    final subArgs = args.skip(1).toList();

    try {
      await _executeZorphy(subCommand, subArgs);
    } catch (e) {
      print('❌ Error executing entity command: $e');
      exit(1);
    }
  }

  /// Execute zorphy CLI with the given command and arguments
  Future<void> _executeZorphy(String command, List<String> args) async {
    // Check if we're in a Dart/Flutter project
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      print('❌ Error: pubspec.yaml not found in current directory.');
      print('   Please run this command from your Flutter/Dart project root.');
      exit(1);
    }

    final pubspecContent = await pubspecFile.readAsString();
    final hasZorphyAnnotation = pubspecContent.contains('zorphy_annotation:');

    if (!hasZorphyAnnotation) {
      print('⚠️  Warning: zorphy_annotation not found in pubspec.yaml');
      print('');
      print('Entity generation requires the zorphy_annotation package.');
      print('Generated entities will have warnings without it.');
      print('');
      print('To add it, run:');
      print('  dart pub add zorphy_annotation');
      print('');
      print('Or add manually to pubspec.yaml:');
      print('');
      print('  dependencies:');
      print('    zorphy_annotation: ^1.0.0');
      print('');
      print('Continue anyway? (y/N): ');

      final response = stdin.readLineSync()?.toLowerCase().trim();
      if (response != 'y' && response != 'yes') {
        print('Cancelled.');
        exit(0);
      }
      print('');
    }

    // Build the zorphy CLI command
    final zorphyArgs = [command, ...args];

    print('🦒 Running Zorphy: zorphy_cli ${zorphyArgs.join(' ')}');
    print('   (Zorphy is bundled with ZFA - no setup required!)');
    print('');

    // Run zorphy CLI as a subprocess using the bundled version
    final process = await Process.start('dart', [
      'run',
      'zorphy:zorphy_cli',
      ...zorphyArgs,
    ], mode: ProcessStartMode.inheritStdio);

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      print('\n❌ Zorphy CLI exited with code $exitCode');
      exit(exitCode);
    }

    print('\n✅ Entity command completed successfully!');
    print('');
    print('📝 Don\'t forget to run code generation:');
    print('   zfa build');
    print('');
  }

  /// Print help for the entity command
  void _printHelp() {
    print('''
zfa entity - Zorphy Entity Generation Commands

USAGE:
  zfa entity <subcommand> [options]

NOTE:
  Zorphy is bundled with ZFA - no additional installation needed!
  However, your project needs zorphy_annotation for generated entities:

    dart pub add zorphy_annotation

SUBCOMMANDS:
  create      Create a new Zorphy entity with fields
  new         Quick-create a simple entity (basic defaults)
  enum        Create a new Zorphy enum
  add-field   Add field(s) to an existing entity
  from-json   Create entity/ies from JSON file
  list        List all Zorphy entities
  help        Show this help message

CREATE COMMAND:
  zfa entity create [options]
  Options:
    -n, --name              Entity name (required)
    -o, --output            Output base directory (default: lib/src/domain/entities)
    --json                  Enable JSON serialization (default: true)
    --copywith-fn           Enable function-based copyWith (default: false)
    --compare               Enable compareTo (default: true)
    --sealed                Create sealed class (default: false)
    --non-sealed            Create non-sealed class (default: false)
    -f, --fields            Interactive field prompts (default: true)
    --field                 Add one or more fields ("name:type" or "id:int,name:String")
    --extends               Interface to extend (e.g., BaseEntity)
    --subtype               Explicit subtypes (e.g., Dog,Cat)

ENUM COMMAND:
  zfa entity enum [options]
  Options:
    -n, --name              Enum name (required)
    -o, --output            Output base directory (default: lib/src/domain/entities)
    --value                 Enum values (comma-separated)

NEW COMMAND:
  zfa entity new [options]
  Options:
    -n, --name              Entity name (required)
    -o, --output            Output base directory (default: lib/src/domain/entities)
    --json                  Enable JSON (default: true)

ADD-FIELD COMMAND:
  zfa entity add-field [options]
  Options:
    -n, --name              Entity name (required)
    -o, --output            Output base directory (default: lib/src/domain/entities)
    --field                 Add one or more fields ("name:type" or "name:type?")

FROM-JSON COMMAND:
  zfa entity from-json <file.json> [options]
  Options:
    --name                  Entity name (inferred from file if not provided)
    -o, --output            Output base directory (default: lib/src/domain/entities)
    --json                  Enable JSON serialization (default: true)
    --prefix-nested         Prefix nested entities with parent name (default: true)

LIST COMMAND:
  zfa entity list [options]
  Options:
    -o, --output            Directory to search (default: lib/src/domain/entities)

EXAMPLES:
  # Interactive entity creation
  zfa entity create -n User

  # Create with fields (basic types)
  zfa entity create -n User --field name:String --field age:int --field email:String?

  # Create with multiple fields and generic types
  zfa entity create -n Order --field "customer:Customer,status:OrderStatus,items:List<OrderItem>,data:Map<String, dynamic>"

  # Create enum
  zfa entity enum -n OrderStatus --value pending,processing,shipped,delivered

  # Create nested entity
  zfa entity create -n Address --field street:String --field city:String --field zipCode:String

  # Quick create simple entity
  zfa entity new -n Product

  # Add field to existing entity
  zfa entity add-field -n User --field phone:String?

  # Create from JSON
  zfa entity from-json user_data.json

  # List entities
  zfa entity list

FIELD TYPES:
  Basic types: String, int, double, bool, num, DateTime
  Nullable types: Add ? after type (e.g., String?, int?)
  Generic types: List<Type>, Set<Type>, Map<KeyType, ValueType>
  Custom types: Any other class name
  Zorphy Objects: TypeName (e.g., User, Address). Automatically detected and prefixed.
  Enums: TypeName (will be imported from enums/index.dart)

BULK OPERATION:
  Multiple fields can be added in a single --field flag using commas:
  --field "id:String,name:String,data:Map<String, dynamic>"
  (Commas inside Map or List generics are safely handled)

  Examples:
    name:String              → String field
    age:int?                 → Nullable int field
    tags:List<String>        → List of strings
    order:Order              → Order entity (auto-prefixed with \$)
    status:OrderStatus       → OrderStatus enum
    metadata:Map<String, dynamic> → Map field (internal commas handled)

  Note: \$ and \$\$ prefixes are now handled automatically by the CLI.
  You can still use them manually if you prefer.

For more information, visit: https://github.com/arrrrny/zorphy
''');
  }
}
