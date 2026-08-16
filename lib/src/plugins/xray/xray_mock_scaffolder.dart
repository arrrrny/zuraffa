// X-Ray mock scaffolder — injects @XRayMock annotations onto generated
// usecases so the Control Deck has real entries out of the box.
//
// Used by `zfa xray mock <Entity>` (issue #360). Scans the domain
// usecases directory for files matching `*_<entity_snake>_usecase.dart`
// and injects a single `@XRayMock(name: ..., payload: ..., type: ...)`
// annotation above each `class ...UseCase` declaration. Also adds the
// `package:zuraffa_flutter/zuraffa_flutter.dart` import when missing.
//
// The scaffolder is text-based (no AST parsing) because the generated
// usecase files follow a predictable pattern: a single top-level
// `class <Name>UseCase extends UseCase<...>` declaration preceded by
// imports and a header comment.

import 'dart:io';

import 'package:path/path.dart' as p;

/// Result of scaffolding a single usecase file.
class XRayMockScaffoldResult {
  /// The file path that was processed.
  final String path;

  /// `true` if the annotation was injected; `false` if skipped (already
  /// present and `--force` not set, or no class declaration found).
  final bool injected;

  /// `true` if the import was added.
  final bool importAdded;

  /// Human-readable status message.
  final String message;

  const XRayMockScaffoldResult({
    required this.path,
    required this.injected,
    required this.importAdded,
    required this.message,
  });
}

/// Scaffolds `@XRayMock` annotations onto usecase files for [entityName].
///
/// Scans `lib/src/domain/usecases/*/` for files matching
/// `*_<entitySnake>_usecase.dart`. For each file, injects a single
/// `@XRayMock` annotation above the `class ...UseCase` declaration.
///
/// [entityName] — the entity name in PascalCase (e.g. `User`).
/// [entitySnake] — the snake_case form (e.g. `user`). If omitted, derived
///   from [entityName] by lowercasing.
/// [projectRoot] — the project root directory. Defaults to cwd.
/// [domain] — optional domain filter (only scan `usecases/<domain>/`).
/// [force] — overwrite existing `@XRayMock` annotations.
/// [dryRun] — preview without writing.
class XRayMockScaffolder {
  /// The import line added to usecase files when X-Ray mocks are
  /// scaffolded. `zuraffa_flutter` re-exports `XRayMock` from its
  /// barrel, so a single import covers both the annotation and any
  /// future X-Ray types the usecase might need.
  static const String xrayImportLine =
      "import 'package:zuraffa_flutter/zuraffa_flutter.dart';";

  /// Sample payloads per usecase method prefix. The key is the method
  /// prefix in the filename (e.g. `get`, `create`, `update`, `delete`,
  /// `watch`). The value is a map of `name` / `payload` / `type` fields
  /// for the `@XRayMock` annotation.
  ///
  /// These are intentionally generic — the user is expected to customize
  /// them via `zfa xray deck --yaml` or by editing the annotation.
  static const Map<String, Map<String, String>> _samplePayloads = {
    'get': {'name': 'Valid entry', 'payload': 'sample-id', 'type': 'valid'},
    'create': {
      'name': 'Create sample',
      'payload': '{"name":"Sample"}',
      'type': 'valid',
    },
    'update': {
      'name': 'Update sample',
      'payload': '{"id":"sample-id","name":"Updated"}',
      'type': 'valid',
    },
    'delete': {
      'name': 'Delete sample',
      'payload': 'sample-id',
      'type': 'valid',
    },
    'watch': {
      'name': 'Watch sample',
      'payload': 'sample-id',
      'type': 'valid',
    },
  };

  /// Default payload used when the method prefix is not in
  /// [_samplePayloads] (e.g. custom usecases).
  static const Map<String, String> _defaultPayload = {
    'name': 'Sample payload',
    'payload': 'sample',
    'type': 'valid',
  };

  final String projectRoot;

  const XRayMockScaffolder({this.projectRoot = '.'});

  /// Scans for usecase files matching [entitySnake] and scaffolds
  /// `@XRayMock` annotations.
  ///
  /// Returns a list of results, one per processed file.
  List<XRayMockScaffoldResult> scaffold({
    required String entityName,
    String? entitySnake,
    String? domain,
    bool force = false,
    bool dryRun = false,
  }) {
    final snake = entitySnake ?? _toSnakeCase(entityName);
    final usecasesDir = p.join(projectRoot, 'lib', 'src', 'domain', 'usecases');
    final results = <XRayMockScaffoldResult>[];

    final dir = Directory(usecasesDir);
    if (!dir.existsSync()) {
      return results;
    }

    // Collect candidate files.
    final files = <File>[];
    if (domain != null) {
      // Scan only the specified domain.
      final domainDir = Directory(p.join(usecasesDir, domain));
      if (domainDir.existsSync()) {
        files.addAll(
          domainDir
              .listSync()
              .whereType<File>()
              .where(
                (f) =>
                    p.basename(f.path).contains('_${snake}_usecase.dart') ||
                    p.basename(f.path).contains('_${snake}_list_usecase.dart'),
              ),
        );
      }
    } else {
      // Scan all domain subdirectories.
      for (final subDir in dir.listSync().whereType<Directory>()) {
        files.addAll(
          subDir
              .listSync()
              .whereType<File>()
              .where(
                (f) =>
                    p.basename(f.path).contains('_${snake}_usecase.dart') ||
                    p.basename(f.path).contains('_${snake}_list_usecase.dart'),
              ),
        );
      }
    }

    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    for (final file in files) {
      results.add(
        _processFile(
          file: file,
          entityName: entityName,
          force: force,
          dryRun: dryRun,
        ),
      );
    }

    return results;
  }

  XRayMockScaffoldResult _processFile({
    required File file,
    required String entityName,
    required bool force,
    required bool dryRun,
  }) {
    final content = file.readAsStringSync();
    final fileName = p.basename(file.path);

    // Detect the method prefix from the filename (get, create, update, ...).
    final methodPrefix = fileName.split('_').first;
    final payload = _samplePayloads[methodPrefix] ?? _defaultPayload;

    // Check if @XRayMock is already present.
    final hasXRayMock = RegExp(r'@XRayMock\s*[(<]').hasMatch(content);
    if (hasXRayMock && !force) {
      return XRayMockScaffoldResult(
        path: file.path,
        injected: false,
        importAdded: false,
        message: 'already has @XRayMock (use --force to overwrite)',
      );
    }

    // Find the class declaration to inject above.
    // Pattern: optional leading annotations/keywords, then `class <Name>UseCase`.
    final classPattern = RegExp(
      r'^(\s*)((?:@\w+(?:\([^)]*\))?\s*)*)class\s+(\w+UseCase)\s+extends',
      multiLine: true,
    );
    final match = classPattern.firstMatch(content);
    if (match == null) {
      return XRayMockScaffoldResult(
        path: file.path,
        injected: false,
        importAdded: false,
        message: 'no `class ...UseCase extends` declaration found',
      );
    }

    final indent = match.group(1) ?? '';
    final className = match.group(3)!;

    // Build the @XRayMock annotation line.
    final escapedName = payload['name']!.replaceAll("'", r"\'");
    final escapedPayload = payload['payload']!.replaceAll("'", r"\'");
    final escapedType = payload['type']!.replaceAll("'", r"\'");
    final annotationLine =
        '$indent@XRayMock(name: \'$escapedName\', '
        'payload: \'$escapedPayload\', type: \'$escapedType\')';

    // If --force and @XRayMock already present, replace the existing one.
    String newContent;
    if (hasXRayMock && force) {
      // Remove existing @XRayMock(...) line(s).
      // Match the complete annotation including nested parentheses.
      final xrayLinePattern = RegExp(
        r'^\s*@XRayMock\s*\([^\n]*\)\s*\n',
        multiLine: true,
      );
      newContent = content.replaceAll(xrayLinePattern, '');
      // Re-find the class declaration (offsets shifted after removal).
      final newMatch = RegExp(
        r'^(\s*)((?:@\w+(?:\([^)]*\))?\s*)*)class\s+(\w+UseCase)\s+extends',
        multiLine: true,
      ).firstMatch(newContent);
      if (newMatch == null) {
        return XRayMockScaffoldResult(
          path: file.path,
          injected: false,
          importAdded: false,
          message: 'class declaration vanished after removing old @XRayMock',
        );
      }
      final insertPos = newMatch.start + newMatch.group(1)!.length;
      newContent =
          '${newContent.substring(0, insertPos)}'
          '$annotationLine\n'
          '${newContent.substring(insertPos)}';
    } else {
      // Insert the annotation above the class declaration.
      final insertPos = match.start + indent.length;
      newContent =
          '${content.substring(0, insertPos)}'
          '$annotationLine\n'
          '${content.substring(insertPos)}';
    }

    // Add the import if missing.
    var importAdded = false;
    if (!newContent.contains(xrayImportLine)) {
      // Insert after the last import line.
      final importPattern = RegExp(
        r'^(import\s+[^\n]+\n)+',
        multiLine: true,
      );
      final importMatch = importPattern.firstMatch(newContent);
      if (importMatch != null) {
        final insertAt = importMatch.end;
        newContent =
            '${newContent.substring(0, insertAt)}'
            '$xrayImportLine\n'
            '${newContent.substring(insertAt)}';
        importAdded = true;
      } else {
        // No imports found — prepend.
        newContent = '$xrayImportLine\n\n$newContent';
        importAdded = true;
      }
    }

    if (!dryRun) {
      file.writeAsStringSync(newContent);
    }

    return XRayMockScaffoldResult(
      path: file.path,
      injected: true,
      importAdded: importAdded,
      message: dryRun
          ? 'would inject @XRayMock on $className'
          : 'injected @XRayMock on $className',
    );
  }

  /// Converts a PascalCase name to snake_case.
  static String _toSnakeCase(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char.toUpperCase() == char && char.toLowerCase() != char) {
        if (i > 0) buffer.write('_');
        buffer.write(char.toLowerCase());
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}
