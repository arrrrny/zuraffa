#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zuraffa/src/exceptions.dart';
import 'package:zuraffa/src/preflight.dart';

const version = '0.3.0';

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    _printHelp();
    exit(0);
  }

  final command = arguments[0];

  try {
    switch (command) {
      case 'generate':
        await _handleGenerate(arguments.skip(1).toList());
        break;
      case 'create':
        await _handleCreate(arguments.skip(1).toList());
        break;
      case 'help':
      case '--help':
      case '-h':
        _printHelp();
        break;
      case 'version':
      case '--version':
      case '-v':
        print('🦒 Zuraffa v$version');
        break;
      default:
        print('❌ Unknown command: $command\n');
        _printHelp();
        exit(1);
    }
  } on ZuraffaException catch (e) {
    // Formatted error from our exception classes
    print(e.toString());
    exit(1);
  } catch (e, stack) {
    // Unexpected errors
    print('❌ Unexpected Error: $e');
    if (arguments.contains('--verbose')) {
      print('\n📋 Stack Trace:');
      print(stack);
    } else {
      print('💡 Run with --verbose for more details');
    }
    exit(1);
  }
}

Future<void> _handleCreate(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Usage: zuraffa create entity <name> [options]');
    exit(1);
  }

  final subcommand = args[0];

  if (subcommand != 'entity') {
    print('❌ Unknown subcommand: $subcommand');
    print('Available: entity');
    exit(1);
  }

  // Parse args
  final parser = ArgParser()
    ..addOption('from-json', abbr: 'j', help: 'JSON file path')
    ..addOption('name', abbr: 'n', help: 'Entity name')
    ..addFlag('interactive', abbr: 'i', help: 'Interactive mode (paste JSON)')
    ..addFlag('no-build-runner', help: 'Skip build_runner', defaultsTo: false)
    ..addFlag('verbose', abbr: 'v', help: 'Verbose output', defaultsTo: false);

  final results = parser.parse(args.skip(1));

  // Get entity name
  String? entityName = results['name'];
  if (entityName == null && results.rest.isNotEmpty) {
    entityName = results.rest[0];
  }

  // Get JSON
  Map<String, dynamic>? json;

  if (results['from-json'] != null) {
    // Read from file
    final jsonPath = results['from-json'] as String;
    final file = File(jsonPath);

    if (!await file.exists()) {
      throw FileException.notFound(jsonPath);
    }

    print('📖 Reading JSON from: $jsonPath');

    try {
      final jsonString = await file.readAsString();
      final decoded = jsonDecode(jsonString);

      if (decoded is! Map<String, dynamic>) {
        throw JsonParseException.notAnObject(decoded);
      }

      json = decoded;
    } on FormatException catch (e) {
      throw JsonParseException.invalidJson(e);
    } on FileSystemException catch (e) {
      throw FileException.cannotRead(jsonPath, e);
    }

  } else if (results['interactive'] == true) {
    // Interactive mode
    print('📋 Paste your JSON (press Ctrl+D when done):');
    final lines = <String>[];
    String? line;
    while ((line = stdin.readLineSync()) != null) {
      lines.add(line!); // line is guaranteed non-null here
    }

    final jsonString = lines.join('\n');
    if (jsonString.trim().isEmpty) {
      throw JsonParseException.emptyJson();
    }

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw JsonParseException.notAnObject(decoded);
      }
      json = decoded;
    } on FormatException catch (e) {
      throw JsonParseException.invalidJson(e);
    }

  } else {
    throw ZuraffaException(
      'Please provide JSON via --from-json or --interactive',
      hint: 'Examples:\n'
          '  zuraffa create entity Product --from-json product.json\n'
          '  zuraffa create entity --interactive',
    );
  }

  // Generate
  print('\n🦒 Zuraffa v$version\n');

  final projectPath = Directory.current.path;

  // Pre-flight checks
  final preflight = PreflightChecker(projectPath);
  await preflight.quickCheck();

  final generator = ZuraffaGenerator(projectPath);

  final result = await generator.generateFromJson(
    json,
    entityName: entityName,
    runBuildRunner: !results['no-build-runner'],
    onProgress: (msg) => print(msg),
  );

  if (result.success) {
    print('\n✅ Generation complete!\n');
    print('📄 Created ${result.entityFiles.length} entity file(s):');
    for (final file in result.entityFiles) {
      print('  ✓ $file');
    }

    if (result.buildYamlCreated) {
      print('\n🔧 Created build.yaml for Morphy configuration');
    }

    if (result.buildRunnerResult != null && result.buildRunnerResult!.success) {
      print('\n🔨 Generated ${result.buildRunnerResult!.generatedFiles.length} .g.dart file(s):');
      for (final file in result.buildRunnerResult!.generatedFiles) {
        print('  ✓ $file');
      }
    }

    print('\n🎉 Done! Your entities are ready to use.');
  } else {
    if (result.buildRunnerResult != null && !result.buildRunnerResult!.success) {
      throw BuildRunnerException.executionFailed(
        result.buildRunnerResult!.exitCode,
        result.buildRunnerResult!.stderr,
      );
    }

    throw ZuraffaException('Generation failed with unknown error');
  }
}

Future<void> _handleGenerate(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Usage: zuraffa generate <EntityName> --from-json <file> [options]');
    exit(1);
  }

  final entityName = args[0];

  // Parse args
  final parser = ArgParser()
    ..addOption('from-json', abbr: 'j', help: 'JSON file path', mandatory: true)
    ..addFlag('crud', help: 'Include Create/Update/Delete usecases (default: Get/GetProducts only)', defaultsTo: false)
    ..addFlag('value-object', help: 'Generate as Value Object (no id required, no repository/usecases)', defaultsTo: false)
    ..addFlag('no-build-runner', help: 'Skip build_runner', defaultsTo: false)
    ..addFlag('verbose', abbr: 'v', help: 'Verbose output', defaultsTo: false);

  final results = parser.parse(args.skip(1));

  // Read JSON
  final jsonPath = results['from-json'] as String;
  final file = File(jsonPath);

  if (!await file.exists()) {
    throw FileException.notFound(jsonPath);
  }

  print('📖 Reading JSON from: $jsonPath');

  Map<String, dynamic> json;
  try {
    final jsonString = await file.readAsString();
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw JsonParseException.notAnObject(decoded);
    }

    json = decoded;
  } on FormatException catch (e) {
    throw JsonParseException.invalidJson(e);
  } on FileSystemException catch (e) {
    throw FileException.cannotRead(jsonPath, e);
  }

  // Generate full-stack
  print('\n🦒 Zuraffa v$version - Full-Stack Generator\n');

  final projectPath = Directory.current.path;

  // Pre-flight checks
  final preflight = PreflightChecker(projectPath);
  await preflight.quickCheck();

  final generator = FullStackGenerator(projectPath);
  final isValueObjectFlag = results['value-object'] as bool;

  final result = await generator.generateFromJson(
    json,
    entityName: entityName,
    runBuildRunner: !results['no-build-runner'],
    includeCrud: results['crud'] as bool,
    isValueObject: isValueObjectFlag,
    onProgress: (msg) => print(msg),
  );

  // Determine if it's actually a value object (auto-detected or forced)
  final hasIdField = result.schema.fields.any((f) => f.name == 'id' && (f.type == 'String' || f.type == 'int'));
  final isActuallyValueObject = isValueObjectFlag || !hasIdField;

  if (result.success) {
    if (isActuallyValueObject) {
      print('\n✅ Value Object generation complete!\n');
      print('📦 Generated ${result.totalFiles} files:\n');

      print('  📄 Value Object (${result.entityFiles.length}):');
      for (final file in result.entityFiles) {
        print('    ✓ $file');
      }

      print('\n  🧪 Tests (${result.testFiles.length}):');
      for (final file in result.testFiles) {
        print('    ✓ $file');
      }

      if (result.buildYamlCreated) {
        print('\n  🔧 Created build.yaml');
      }

      if (result.buildRunnerResult != null && result.buildRunnerResult!.success) {
        print('\n  🔨 Generated ${result.buildRunnerResult!.generatedFiles.length} .g.dart file(s)');
      }

      print('\n🎉 Done! Your Value Object is ready.');
      print('   Value Object: ${result.entityName}');
      print('   Type: Immutable data structure (no id)');
      print('   Tests: ${result.testFiles.length} files (TDD Ready!)');
      print('\n💡 Run: dart test');
    } else {
      print('\n✅ Full-stack generation complete!\n');
      print('📦 Generated ${result.totalFiles} files:\n');

      print('  📄 Entities (${result.entityFiles.length}):');
      for (final file in result.entityFiles) {
        print('    ✓ $file');
      }

      print('\n  🌐 DataSources (${result.datasourceFiles.length}):');
      for (final file in result.datasourceFiles) {
        print('    ✓ $file');
      }

      print('\n  🗄️  Repositories (${result.repositoryFiles.length}):');
      for (final file in result.repositoryFiles) {
        print('    ✓ $file');
      }

      print('\n  ⚙️  UseCases (${result.usecaseFiles.length}):');
      for (final file in result.usecaseFiles) {
        print('    ✓ $file');
      }

      print('\n  🧪 Tests (${result.testFiles.length}):');
      for (final file in result.testFiles) {
        print('    ✓ $file');
      }

      if (result.buildYamlCreated) {
        print('\n  🔧 Created build.yaml');
      }

      if (result.buildRunnerResult != null && result.buildRunnerResult!.success) {
        print('\n  🔨 Generated ${result.buildRunnerResult!.generatedFiles.length} .g.dart file(s)');
      }

      print('\n🎉 Done! Your full-stack Clean Architecture is ready.');
      print('   Entity: ${result.entityName}');
      print('   Pattern: Result<T, Failure>');
      print('   Cache: First (network → local)');
      print('   Tests: ${result.testFiles.length} files (TDD Ready!)');
      print('\n💡 Run: dart test');
    }
  } else {
    if (result.buildRunnerResult != null && !result.buildRunnerResult!.success) {
      throw BuildRunnerException.executionFailed(
        result.buildRunnerResult!.exitCode,
        result.buildRunnerResult!.stderr,
      );
    }

    throw ZuraffaException('Full-stack generation failed');
  }
}

void _printHelp() {
  print('''
🦒 Zuraffa v$version
AI-First Clean Architecture for Flutter

Usage: zuraffa <command> [options]

Commands:
  generate <EntityName> --from-json <file>
    Generate complete Clean Architecture stack (RECOMMENDED!)
    --from-json, -j <file>    JSON file path (required)
    --crud                    Include Create/Update/Delete usecases
    --value-object            Force Value Object (even if id exists)
    --no-build-runner         Skip build_runner
    --verbose, -v             Verbose output

    🎯 Auto-Detection (AI-First!):
      • JSON with id field (String/int) → Entity (full stack)
      • JSON without id field → Value Object (entity + tests)
      • --value-object flag → Force Value Object

    Entity (auto-detected if id exists):
      ✓ Entity (with Morphy, requires id field)
      ✓ DataSources (Remote/Local/Mock)
      ✓ Repository (cache-first logic)
      ✓ UseCases (Get/GetProducts with ProductFilter)
      ✓ With --crud: Create/Update/Delete usecases

    Value Object (auto-detected if no id):
      ✓ Value Object (with Morphy, no id needed)
      ✓ Tests only (no repository/usecases)

  create entity <name> [options]
    Generate entities only
    --from-json, -j <file>    Read JSON from file
    --interactive, -i          Paste JSON interactively
    --name, -n <name>         Entity name (optional)
    --no-build-runner         Skip running build_runner
    --verbose, -v             Show detailed output

  help, --help, -h            Show this help
  version, --version, -v      Show version

Examples:
  # 🚀 Auto-detect Entity (JSON has id field)
  zuraffa generate Product --from-json product.json
  # → Generates full stack (Entity detected!)

  # 🧬 Auto-detect Value Object (JSON has NO id field)
  zuraffa generate Review --from-json review.json
  # → Generates only entity + tests (Value Object detected!)

  # Force Value Object (even if JSON has id)
  zuraffa generate Address --from-json address.json --value-object
  # → Ignores id field, generates Value Object

  # Full-stack with CRUD operations
  zuraffa generate Product --from-json product.json --crud

  # Entity only
  zuraffa create entity Product --from-json product.json

  # Interactive mode
  zuraffa create entity --interactive

Documentation: https://github.com/arrrrny/zuraffa
For Humanity. For ZikZak. For AI Agents. 🦒
''');
}
