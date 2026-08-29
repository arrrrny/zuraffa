/// BarrelResolver (spec 043): selective barrel expansion (FR-005).
///
/// A barrel is a file whose top level holds only export directives. When the
/// walker reaches a barrel import it must NOT pull in every re-exported
/// file: with a `show` clause only the files exporting the shown symbols are
/// included (U13); without one, only files exporting types the importer
/// actually references (U14). Non-barrel files pass through unmodified (U16).
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../../../core/ast/file_parser.dart';

/// Expands barrel imports to only the files the slice needs.
class BarrelResolver {
  /// Creates the resolver with an optional [parser].
  BarrelResolver({FileParser? parser}) : _parser = parser ?? const FileParser();

  final FileParser _parser;

  /// Returns the files an import of [importedPath] should include.
  ///
  /// [importerSource] is the full source of the importing file and
  /// [shownSymbols] the identifiers from the import's `show` clause (empty
  /// when the import has no `show`).
  Future<List<String>> expandImport({
    required String importedPath,
    required String importerSource,
    required List<String> shownSymbols,
  }) async {
    final content = await File(importedPath).readAsString();
    if (!isBarrel(content)) {
      return [p.canonicalize(importedPath)];
    }

    final exports = _exportTargets(content, importedPath);
    final needed = <String>[];
    for (final target in exports) {
      if (await _targetNeeded(
        target: target,
        shownSymbols: shownSymbols,
        importerSource: importerSource,
      )) {
        needed.add(target);
      }
    }
    return needed;
  }

  /// Whether [content] is a barrel file: it has export directives and no
  /// top-level declarations.
  bool isBarrel(String content) {
    final result = _parser.parseSource(content);
    final unit = result.unit;
    if (unit == null) return false;
    final hasExports = unit.directives.any(
      (d) => d is ExportDirective,
    );
    if (!hasExports) return false;
    return unit.declarations.isEmpty;
  }

  List<String> _exportTargets(String content, String barrelPath) {
    final result = _parser.parseSource(content);
    final unit = result.unit;
    if (unit == null) return const [];
    return unit.directives
        .whereType<ExportDirective>()
        .map((directive) => directive.uri.stringValue)
        .whereType<String>()
        .map((uri) => p.canonicalize(p.normalize(p.join(p.dirname(barrelPath), uri))))
        .toList();
  }

  Future<bool> _targetNeeded({
    required String target,
    required List<String> shownSymbols,
    required String importerSource,
  }) async {
    final file = File(target);
    if (!await file.exists()) return false;
    final declared = declaredTopLevelNames(await file.readAsString());
    if (shownSymbols.isNotEmpty) {
      return declared.any(shownSymbols.contains);
    }
    // No show clause: include a target only when the importer references one
    // of its declared names as a whole word.
    for (final name in declared) {
      final pattern = RegExp('\\b${RegExp.escape(name)}\\b');
      if (pattern.hasMatch(importerSource)) {
        return true;
      }
    }
    return false;
  }

  /// Top-level type and function names declared in [content].
  ///
  /// Public because the graph walker reuses it for its project-wide type
  /// index (single naming source of truth).
  List<String> declaredTopLevelNames(String content) {
    final result = _parser.parseSource(content);
    final unit = result.unit;
    if (unit == null) return const [];
    return unit.declarations.map((decl) {
      return switch (decl) {
        ClassDeclaration() => decl.namePart.typeName.lexeme,
        MixinDeclaration() => decl.name.lexeme,
        EnumDeclaration() => decl.namePart.typeName.lexeme,
        ExtensionDeclaration() => decl.name?.lexeme,
        TypeAlias() => decl.name.lexeme,
        FunctionDeclaration() => decl.name.lexeme,
        TopLevelVariableDeclaration() =>
          decl.variables.variables.first.name.lexeme,
        _ => null,
      };
    }).whereType<String>().toList();
  }
}
