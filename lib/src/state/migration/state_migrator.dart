import 'dart:io';

import 'package:path/path.dart' as p;

/// Migrates v5 `.state.dart` files to v6 Signal Slice pattern.
///
/// Usage:
/// ```bash
/// zfa migrate state --input=lib/presentation --output=lib/presentation
/// ```
class StateMigrator {
  StateMigrator({
    required this.inputDir,
    required this.outputDir,
    this.dryRun = false,
  });

  final String inputDir;
  final String outputDir;
  final bool dryRun;

  final List<String> _migratedFiles = [];
  final List<String> _errors = [];

  List<String> get migratedFiles => List.unmodifiable(_migratedFiles);
  List<String> get errors => List.unmodifiable(_errors);

  /// Run the migration.
  Future<void> run() async {
    final dir = Directory(inputDir);
    if (!dir.existsSync()) {
      throw StateError('Input directory does not exist: $inputDir');
    }

    final sameDir = p.equals(p.normalize(inputDir), p.normalize(outputDir));

    await for (final entity
        in dir.list(recursive: true, followLinks: false).handleError((
          Object e,
          StackTrace st,
        ) {
          _errors.add('Directory listing error: $e');
        })) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.state.dart')) continue;

      try {
        await _migrateFile(entity, sameDir: sameDir);
      } catch (e) {
        _errors.add('${entity.path}: $e');
      }
    }
  }

  Future<void> _migrateFile(File file, {required bool sameDir}) async {
    final content = await file.readAsString();
    final migrated = _transformStateFile(content);

    if (dryRun) {
      _migratedFiles.add('${file.path} (dry-run)');
      return;
    }

    // Prevent destructive migration when writing back over the source.
    if (sameDir) {
      // Create a backup before replacing any source file.
      final backupPath = '${file.path}.bak';
      await File(backupPath).writeAsString(content);
    }

    final relative = p.relative(file.path, from: inputDir);
    final outputPath = p.join(outputDir, relative);
    final outputFile = File(outputPath);
    await outputFile.create(recursive: true);
    await outputFile.writeAsString(migrated);
    _migratedFiles.add(outputPath);
  }

  /// Transform a v5 state file into v6 slice pattern.
  String _transformStateFile(String content) {
    // Extract class name — throw if not found so the file is recorded as an error.
    final classMatch = RegExp(r'class (\w+)Presenter').firstMatch(content);
    if (classMatch == null) {
      throw StateError('No <Name>Presenter class found to migrate.');
    }
    final presenterName = classMatch.group(1)!;

    final lines = <String>[
      '// MIGRATED TO V6 SIGNAL SLICES',
      '// Original: v5 monolithic state',
      '',
      "import 'package:zuraffa/zuraffa.dart';",
      '',
      'class ${presenterName}Presenter extends SlicePresenter {',
      '  ${presenterName}Presenter({super.context});',
      '',
    ];

    // Detect use case bindings and generate slices
    final useCaseMatches = RegExp(
      r'final (\w+)UseCase\s+(\w+);',
      multiLine: true,
    ).allMatches(content);

    final usedKeys = <String>{};
    for (final match in useCaseMatches) {
      final typeName = match.group(1)!;
      final fieldName = match.group(2)!;
      // Derive semantic slice key from the field name.
      final rawKey = _deriveSliceKey(fieldName);
      final sliceKey = _camelToLower(rawKey);
      if (sliceKey.isEmpty || usedKeys.contains(sliceKey)) {
        _errors.add('Skipped duplicate/invalid slice key "$sliceKey".');
        continue;
      }
      usedKeys.add(sliceKey);

      lines.add('  late final $sliceKey = bind<$typeName>(');
      lines.add("    '$sliceKey',");
      lines.add('    $fieldName,');
      lines.add('    ${typeName}Params(), // TODO: provide actual params');
      lines.add('  );');
      lines.add('');
    }

    lines.add('}');

    return '${lines.join('\n')}\n';
  }

  /// Strip 'UseCase' suffix and common action prefixes to produce a semantic key.
  String _deriveSliceKey(String fieldName) {
    var raw = fieldName.replaceAll('UseCase', '');
    raw = raw.replaceFirst(RegExp(r'^(get|fetch|load|retrieve|query)'), '');
    if (raw.isEmpty) {
      raw = fieldName.replaceAll('UseCase', '');
    }
    return raw;
  }

  /// Converts a camelCase identifier to a lowercase snake/key (first word).
  String _camelToLower(String name) {
    final first = RegExp(r'^[A-Z]').firstMatch(name);
    if (first == null) return name.toLowerCase();
    final lower = first.group(0)!.toLowerCase();
    return name.replaceFirst(RegExp(r'^[A-Z]'), lower);
  }
}
