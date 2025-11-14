#!/usr/bin/env dart

import 'dart:io';

void main(List<String> arguments) {
  print('🦒 Zuraffa v0.1.0');
  print('AI-First Clean Architecture for Flutter\n');

  if (arguments.isEmpty) {
    _printHelp();
    exit(0);
  }

  final command = arguments[0];

  switch (command) {
    case 'init':
      print('🚧 Coming soon: zuraffa init <project_name>');
      break;
    case 'create':
      print('🚧 Coming soon: zuraffa create usecase <name> --from-json <file>');
      break;
    case 'test':
      print('🚧 Coming soon: zuraffa test generate <file>');
      break;
    case 'help':
    case '--help':
    case '-h':
      _printHelp();
      break;
    case 'version':
    case '--version':
    case '-v':
      print('Zuraffa version 0.1.0');
      break;
    default:
      print('❌ Unknown command: $command\n');
      _printHelp();
      exit(1);
  }
}

void _printHelp() {
  print('''
Usage: zuraffa <command> [options]

Commands:
  init <name>              Create a new Flutter project with Zuraffa
  create usecase <name>    Generate UseCase from JSON
    --from-json <file>     Use JSON file as input
    --from-api <url>       Fetch JSON from API endpoint
  create feature <name>    Generate complete feature (multiple UseCases)
    --interactive          Interactive mode (paste JSON)
  test generate <file>     Generate tests for existing code
  help                     Show this help message
  version                  Show version

Examples:
  zuraffa init zikzak
  zuraffa create usecase GetProduct --from-json product.json
  zuraffa create feature shopping-cart --interactive
  zuraffa test generate lib/domain/usecases/get_product_usecase.dart

Documentation: https://github.com/arrrrny/zuraffa
''');
}
