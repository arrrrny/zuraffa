#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zuraffa/src/exceptions.dart';
import 'package:zuraffa/src/preflight.dart';

const version = '0.1.3';

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    _printHelp();
    exit(0);
  }

  final command = arguments[0];

  try {
    switch (command) {
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

void _printHelp() {
  print('''
🦒 Zuraffa v$version
AI-First Clean Architecture for Flutter

Usage: zuraffa <command> [options]

Commands:
  create entity <name> [options]
    --from-json, -j <file>    Read JSON from file
    --interactive, -i          Paste JSON interactively
    --name, -n <name>         Entity name (optional)
    --no-build-runner         Skip running build_runner
    --verbose, -v             Show detailed output

  help, --help, -h            Show this help
  version, --version, -v      Show version

Examples:
  # From JSON file
  zuraffa create entity Product --from-json product.json

  # Interactive mode
  zuraffa create entity --interactive

  # Custom name
  zuraffa create entity --from-json api-response.json --name PriceComparison

Documentation: https://github.com/arrrrny/zuraffa
For Humanity. For ZikZak. For AI Agents. 🦒
''');
}
