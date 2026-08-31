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

/// One barrel export the slice kept, carrying the verbatim directive text
/// (including any `show`/`hide` combinator) so the cut can re-emit the
/// filtered barrel faithfully instead of re-exporting the whole target file
/// (FR-005).
class BarrelExport {
  /// Creates the kept-export record.
  const BarrelExport({
    required this.targetPath,
    required this.directiveText,
    this.show = const [],
    this.hide = const [],
  });

  /// Absolute path of the exported target file.
  final String targetPath;

  /// Verbatim `export 'uri' [show/hide ...];` text, preserving combinators.
  final String directiveText;

  /// Names exposed by an export-level `show` clause (empty when absent).
  final List<String> show;

  /// Names removed by an export-level `hide` clause (empty when absent).
  final List<String> hide;
}

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
  ///
  /// Each returned [BarrelExport] carries the original export directive's
  /// verbatim text (with its `show`/`hide` combinator) so the cut can re-emit
  /// the filtered barrel instead of dumping the whole target file (FR-005).
  Future<List<BarrelExport>> expandImport({
    required String importedPath,
    required String importerSource,
    required List<String> shownSymbols,
  }) async {
    final content = await File(importedPath).readAsString();
    if (!isBarrel(content)) {
      return [
        BarrelExport(
          targetPath: p.canonicalize(importedPath),
          directiveText: '',
        ),
      ];
    }

    final exports = _exportBarrels(content, importedPath);
    final needed = <BarrelExport>[];
    for (final export in exports) {
      if (await _targetNeeded(
        export: export,
        shownSymbols: shownSymbols,
        importerSource: importerSource,
      )) {
        needed.add(export);
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
    final hasExports = unit.directives.any((d) => d is ExportDirective);
    if (!hasExports) return false;
    return unit.declarations.isEmpty;
  }

  List<BarrelExport> _exportBarrels(String content, String barrelPath) {
    final result = _parser.parseSource(content);
    final unit = result.unit;
    if (unit == null) return const [];
    return unit.directives
        .whereType<ExportDirective>()
        .map((directive) {
          final uri = directive.uri.stringValue;
          if (uri == null) return null;
          final showNames = <String>[];
          final hideNames = <String>[];
          for (final combinator in directive.combinators) {
            if (combinator is ShowCombinator) {
              showNames.addAll(
                combinator.shownNames.map((n) => n.token.lexeme),
              );
            } else if (combinator is HideCombinator) {
              hideNames.addAll(
                combinator.hiddenNames.map((n) => n.token.lexeme),
              );
            }
          }
          final targetPath = p.canonicalize(
            p.normalize(p.join(p.dirname(barrelPath), uri)),
          );
          return BarrelExport(
            targetPath: targetPath,
            directiveText: _directiveText(uri, showNames, hideNames),
            show: showNames,
            hide: hideNames,
          );
        })
        .whereType<BarrelExport>()
        .toList();
  }

  Future<bool> _targetNeeded({
    required BarrelExport export,
    required List<String> shownSymbols,
    required String importerSource,
  }) async {
    final file = File(export.targetPath);
    if (!await file.exists()) return false;
    final declared = declaredTopLevelNames(await file.readAsString());
    // Apply the export-level show/hide combinator: only the names left visible
    // by it can justify pulling the target into the slice (A3, A4).
    bool visible(String name) {
      if (export.show.isNotEmpty && !export.show.contains(name)) return false;
      if (export.hide.isNotEmpty && export.hide.contains(name)) return false;
      return true;
    }

    final exportLevelFiltered = declared.where(visible).toList();
    if (shownSymbols.isNotEmpty) {
      return exportLevelFiltered.any(shownSymbols.contains);
    }
    // No show clause: include a target only when the importer references one
    // of its visible declared names as a whole word.
    for (final name in exportLevelFiltered) {
      final pattern = RegExp('\\b${RegExp.escape(name)}\\b');
      if (pattern.hasMatch(importerSource)) {
        return true;
      }
    }
    return false;
  }

  /// Builds the verbatim `export 'uri' [show/hide ...];` text for a barrel
  /// target, preserving the combinator so the cut can re-emit a faithful
  /// filtered barrel (FR-005).
  String _directiveText(String uri, List<String> show, List<String> hide) {
    final buffer = StringBuffer()..write("export '$uri'");
    if (show.isNotEmpty) {
      buffer.write(' show ${show.join(', ')}');
    } else if (hide.isNotEmpty) {
      buffer.write(' hide ${hide.join(', ')}');
    }
    buffer.write(';');
    return buffer.toString();
  }

  /// Top-level type and function names declared in [content].
  ///
  /// Public because the graph walker reuses it for its project-wide type
  /// index (single naming source of truth).
  List<String> declaredTopLevelNames(String content) {
    final result = _parser.parseSource(content);
    final unit = result.unit;
    if (unit == null) return const [];
    return unit.declarations
        .map((decl) {
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
        })
        .whereType<String>()
        .toList();
  }
}
