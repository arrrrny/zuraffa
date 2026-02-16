import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../models/generator_config.dart';

class ValidateCommand extends Command<void> {
  @override
  String get name => 'validate';

  @override
  String get description => 'Validate JSON configuration file';

  @override
  Future<void> run() async {
    final args = argResults!.rest;
    if (args.isEmpty) {
      print('❌ Usage: zfa validate <json-file>');
      exit(1);
    }

    final file = File(args[0]);
    if (!file.existsSync()) {
      print(
        jsonEncode({'valid': false, 'error': 'File not found: ${args[0]}'}),
      );
      exit(1);
    }

    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final config = GeneratorConfig.fromJson(json, json['name'] ?? 'Unknown');
      print(
        jsonEncode({
          'valid': true,
          'name': config.name,
          'methods': config.methods,
          'repo': config.repo,
          'domain': config.domain,
          'usecases': config.usecases,
          'variants': config.variants,
        }),
      );
    } catch (e) {
      print(jsonEncode({'valid': false, 'error': e.toString()}));
      exit(1);
    }
  }
}
