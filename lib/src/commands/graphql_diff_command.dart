import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../graphql/cache/schema_cache.dart';
import '../graphql/diff/schema_diff.dart';
import '../graphql/graphql_schema.dart';

/// `zfa graphql diff <name>` — compare the freshly cached schema for
/// `<name>` against the previously cached version and report breaking vs
/// non-breaking changes (spec 037 FR-003/FR-004).
///
/// Exit codes (FR-004):
/// - 0 — no breaking changes (identical, or only non-breaking changes)
/// - 1 — one or more breaking changes
/// - 1 — usage problems (unknown name, no previous version, bad files)
///
/// Usage:
///   `zfa graphql diff <name> [--dir=.zfa/graphql]`
///   `zfa graphql diff <name> --old=<file> --new=<file>`
class DiffCommand extends Command<void> {
  DiffCommand() {
    argParser.addOption(
      'dir',
      help: 'Cache root directory (default: .zfa/graphql)',
    );
    argParser.addOption(
      'old',
      help:
          'Explicit old schema JSON file (overrides the cached previous '
          'version)',
    );
    argParser.addOption(
      'new',
      help:
          'Explicit new schema JSON file (overrides the cached current '
          'version)',
    );
  }

  @override
  String get name => 'diff';

  @override
  String get description =>
      'Diff two cached schema versions and report breaking changes '
      '(exit 1 when breaking changes exist)';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      print(
        '❌ Error: a schema name is required. '
        'Usage: zfa graphql diff <name> [--dir=<cache-dir>]',
      );
      print(usage);
      exitCode = 64;
      return;
    }
    final schemaName = rest.first;

    final cacheDir = (argResults?['dir'] as String?) ?? '.zfa/graphql';
    final oldPath = argResults?['old'] as String?;
    final newPath = argResults?['new'] as String?;

    final GqlSchema oldSchema;
    final GqlSchema newSchema;

    if (oldPath != null && newPath != null) {
      try {
        oldSchema = _schemaFromFile(oldPath);
        newSchema = _schemaFromFile(newPath);
      } on FileSystemException catch (e) {
        print('❌ Error: cannot read schema file: ${e.path ?? e}');
        exitCode = 1;
        return;
      } on FormatException catch (e) {
        print('❌ Error: schema file is not valid JSON: $e');
        exitCode = 1;
        return;
      }
    } else {
      if (oldPath != null || newPath != null) {
        print('❌ Error: --old and --new must be provided together.');
        exitCode = 64;
        return;
      }

      final cache = SchemaCache(cacheDir: cacheDir);

      // Current version first — unknown names get the actionable error.
      try {
        newSchema = (await cache.read(schemaName)).schema;
      } on SchemaCacheError catch (e) {
        final available = cache.listSchemas();
        print('❌ Error: $e');
        if (available.isEmpty) {
          print(
            '   No cached schemas found under $cacheDir. '
            'Run `zfa graphql pull` first.',
          );
        } else {
          print('   Cached schemas: ${available.join(', ')}');
        }
        exitCode = 1;
        return;
      }

      final previous = await cache.readPrevious(schemaName);
      if (previous == null) {
        print(
          "❌ Error: no previous version of schema '$schemaName' found in "
          '$cacheDir. Pull the schema again (zfa graphql pull '
          '--endpoint=... --name=$schemaName) or pass --old/--new files '
          'explicitly.',
        );
        exitCode = 1;
        return;
      }
      oldSchema = previous.schema;
    }

    final diff = SchemaDiffer.diff(oldSchema, newSchema);

    print('Schema diff for \'$schemaName\'');
    print('');

    if (diff.changes.isEmpty) {
      print('✅ No breaking changes detected — the schemas are identical.');
      exitCode = 0;
      return;
    }

    final breaking = diff.breakingChanges;
    final nonBreaking = diff.nonBreakingChanges;

    if (breaking.isNotEmpty) {
      print('BREAKING CHANGES (${breaking.length}):');
      for (final change in breaking) {
        print('  ${change.describe()}');
      }
      print('');
    }
    if (nonBreaking.isNotEmpty) {
      print('Non-breaking changes (${nonBreaking.length}):');
      for (final change in nonBreaking) {
        print('  ${change.describe()}');
      }
      print('');
    }

    print(
      'Summary: ${breaking.length} breaking, '
      '${nonBreaking.length} non-breaking.',
    );
    if (diff.hasBreaking) {
      print('❌ Breaking changes detected — regenerating code is required.');
      exitCode = 1;
    } else {
      print('✅ No breaking changes detected.');
      exitCode = 0;
    }
  }

  static GqlSchema _schemaFromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', path);
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('schema root is not a JSON object');
    }
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return GqlSchema.fromIntrospection(data);
    }
    return GqlSchema.fromIntrospection(decoded);
  }
}
