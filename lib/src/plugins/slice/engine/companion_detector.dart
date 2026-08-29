/// CompanionDetector (spec 043): .g.dart/.freezed.dart discovery (FR-006).
///
/// Two discovery paths, unioned:
///  1. Conventional: sibling files named `<source>.g.dart` /
///     `<source>.freezed.dart` that exist on disk are companions.
///  2. Declared: `part 'x.g.dart';` directives name expected companions; a
///     declared companion missing from disk records a warning (U18) but
///     never blocks the source file from being sliced.
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../../../core/ast/file_parser.dart';

/// Companion file extensions the detector knows about.
const companionExtensions = ['.g.dart', '.freezed.dart'];

/// The companions found for one source file.
class CompanionResult {
  /// Creates the result.
  const CompanionResult({required this.companions, required this.warnings});

  /// Existing companion file paths (canonicalized).
  final List<String> companions;

  /// Warnings for expected-but-missing companions.
  final List<String> warnings;
}

/// Finds generated companion files for source files.
class CompanionDetector {
  /// Creates the detector with an optional [parser].
  CompanionDetector({FileParser? parser}) : _parser = parser ?? const FileParser();

  final FileParser _parser;

  /// Detects companions for [sourcePath] given its [sourceContent].
  CompanionResult detectCompanions(String sourcePath, String sourceContent) {
    final dir = p.dirname(sourcePath);
    final baseName = p.basenameWithoutExtension(sourcePath);

    final companions = <String>[];
    final warnings = <String>[];

    // Conventional discovery: siblings on disk.
    for (final extension in companionExtensions) {
      final candidate = p.canonicalize(p.join(dir, '$baseName$extension'));
      if (File(candidate).existsSync()) {
        companions.add(candidate);
      }
    }

    // Declared discovery: part directives naming generated parts.
    final declared = _declaredCompanionParts(sourceContent);
    for (final partUri in declared) {
      final partPath = p.canonicalize(p.normalize(p.join(dir, partUri)));
      if (companions.contains(partPath)) continue;
      if (File(partPath).existsSync()) {
        companions.add(partPath);
      } else {
        warnings.add(
          'Expected companion "$partUri" for '
          '"${p.basename(sourcePath)}" is missing — the source file is '
          'included anyway; run build_runner in the source project if the '
          'generated code is needed.',
        );
      }
    }

    return CompanionResult(companions: companions, warnings: warnings);
  }

  List<String> _declaredCompanionParts(String source) {
    final result = _parser.parseSource(source);
    final unit = result.unit;
    if (unit == null) return const [];
    return unit.directives
        .whereType<PartDirective>()
        .map((directive) => directive.uri.stringValue)
        .whereType<String>()
        .where((uri) => companionExtensions.any(uri.endsWith))
        .toList();
  }
}
