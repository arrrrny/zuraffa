import 'dart:io';

/// Migrates v5 `.state.dart` files to v6 Signal Slice pattern.
///
/// Usage:
/// ```bash
/// dart run zuraffa_state:migrate --input=lib/presentation --output=lib/presentation
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

    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.state.dart')) continue;

      try {
        await _migrateFile(entity);
      } catch (e) {
        _errors.add('${entity.path}: $e');
      }
    }
  }

  Future<void> _migrateFile(File file) async {
    final content = await file.readAsString();
    final migrated = _transformStateFile(content);

    if (dryRun) {
      _migratedFiles.add('${file.path} (dry-run)');
      return;
    }

    final relative = file.path.substring(inputDir.length);
    final outputPath = '$outputDir$relative';
    final outputFile = File(outputPath);
    await outputFile.create(recursive: true);
    await outputFile.writeAsString(migrated);
    _migratedFiles.add(outputPath);
  }

  /// Transform a v5 state file into v6 slice pattern.
  String _transformStateFile(String content) {
    // Detect v5 patterns and rewrite
    final buffer = StringBuffer();
    buffer.writeln('// MIGRATED TO V6 SIGNAL SLICES');
    buffer.writeln('// Original: v5 monolithic state');
    buffer.writeln();

    // Extract class name
    final classMatch = RegExp(r'class (\w+)Presenter').firstMatch(content);
    final presenterName = classMatch?.group(1) ?? 'Unknown';

    buffer.writeln("import 'package:zuraffa/zuraffa.dart';");
    buffer.writeln();

    // Generate SlicePresenter subclass
    buffer.writeln('class ${presenterName}Presenter extends SlicePresenter {');
    buffer.writeln('  ${presenterName}Presenter({super.context});');
    buffer.writeln();

    // Detect use case bindings and generate slices
    final useCaseMatches = RegExp(
      r'final (\w+)UseCase\s+(\w+);',
      multiLine: true,
    ).allMatches(content);

    for (final match in useCaseMatches) {
      final typeName = match.group(1)!;
      final fieldName = match.group(2)!;
      final sliceKey = fieldName.replaceAll('UseCase', '').toLowerCase();

      buffer.writeln('  late final $sliceKey = bind<$typeName>(');
      buffer.writeln("    '$sliceKey',");
      buffer.writeln('    $fieldName,');
      buffer.writeln('    ${typeName}Params(), // TODO: provide actual params');
      buffer.writeln('  );');
      buffer.writeln();
    }

    buffer.writeln('}');

    return buffer.toString();
  }
}
