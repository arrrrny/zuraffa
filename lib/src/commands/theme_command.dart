/// `zfa theme` — design-token ingestion + a11y contrast gates (issue #817).
///
/// `theme import <tokens.json>` parses a W3C design-token document
/// (color/typography/spacing), writes a generated constants file, and runs
/// a WCAG AA contrast matrix over the colour pairs, failing (exit 1) when
/// any pair falls below the AA threshold with the failing pair named.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../cli/services/theme_importer.dart';

class ThemeCommand extends Command<void> {
  ThemeCommand() {
    addSubcommand(ThemeImportCommand());
  }

  @override
  String get name => 'theme';

  @override
  String get description =>
      'Import W3C design tokens into code with a11y contrast gates '
      '(issue #817).';

  @override
  String get invocation => 'zfa theme import <tokens.json> [options]';

  @override
  Future<void> run() async {
    printUsage();
  }
}

class ThemeImportCommand extends Command<void> {
  ThemeImportCommand() {
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Report everything but write nothing.',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite an existing generated file.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'App root to write the generated theme into. Defaults to the '
          'current working directory.',
    );
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output path for the generated tokens file.',
    );
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Emit a JSON summary as the final stdout line.',
    );
  }

  @override
  String get name => 'import';

  @override
  String get description =>
      'Import W3C design tokens (color/typography/spacing) into a '
      'generated theme constants file, with WCAG AA contrast gates.';

  @override
  String get invocation => 'zfa theme import <tokens.json> [options]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      usageException('Tokens file is required: zfa theme import <tokens.json>');
    }
    final tokensPath = rest.first;
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = (projectFlag != null && projectFlag.isNotEmpty)
        ? p.absolute(projectFlag)
        : Directory.current.path;
    final outputFlag = argResults?['output'] as String?;
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final force = argResults?['force'] as bool? ?? false;
    final jsonOut = argResults?['json'] as bool? ?? false;

    try {
      final result = await ThemeImporter().import(
        tokensPath,
        projectRoot: projectRoot,
        outputPath: outputFlag,
        dryRun: dryRun,
        force: force,
      );
      for (final line in result.reportLines) {
        print(line);
      }
      if (result.violations.isNotEmpty) {
        for (final v in result.violations) {
          print('FAIL: $v');
        }
      }
      print(result.summaryLine);
      if (jsonOut) {
        print(result.jsonSummary);
      }
      if (result.violations.isNotEmpty) {
        exitCode = 1;
      }
    } catch (e) {
      print('❌ Failed to import theme tokens: $e');
      exitCode = 1;
    }
  }
}
