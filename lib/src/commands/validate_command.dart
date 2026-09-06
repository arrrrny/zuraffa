import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../cli/exit_protocol.dart';
import '../models/generator_config.dart';

class ValidateCommand extends Command<void> {
  @override
  String get name => 'validate';

  @override
  String get description => 'Validate JSON configuration file';

  @override
  Future<void> run() async {
    final args = argResults?.rest ?? [];
    if (args.isEmpty) {
      // SPEC 917: missing required input is a usage error (canonical 2),
      // never a lying exit 0 — and it closes with the machine-actionable fix.
      print('❌ Usage: zfa validate <json-file>');
      print(
        ExitProtocol.fixLine(
          'pass the config file: `zfa validate <path/to/config.json>` '
          '(generate one with `zfa initialize`)',
        ),
      );
      exitCode = ExitProtocol.usage;
      return;
    }

    final file = File(args[0]);
    if (!file.existsSync()) {
      // SPEC 917: an honest runtime failure exits 1 (NOT a raw exit() —
      // that would kill the test isolate instead of unwinding; set the
      // exitCode global the CliRunner honors) and ends with the fix line.
      print(
        jsonEncode({'valid': false, 'error': 'File not found: ${args[0]}'}),
      );
      print(
        ExitProtocol.fixLine(
          'check the path (missing file: ${args[0]}) — list candidates with '
          '`zfa config show` or re-run from the project root',
        ),
      );
      exitCode = ExitProtocol.failure;
      return;
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
      print(
        ExitProtocol.fixLine(
          'fix the JSON in ${args[0]} (error above), or regenerate the '
          'config with `zfa initialize`',
        ),
      );
      exitCode = ExitProtocol.failure;
      return;
    }
  }
}
