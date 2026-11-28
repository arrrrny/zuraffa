/// Top-level entry point for the AST-based smart regeneration.
///
/// Orchestrates the full pipeline:
/// 1. Parse existing file regions (GENERATED / @preserve markers).
/// 2. Run AST diff to detect changes.
/// 3. Apply merge strategy to produce final content.
/// 4. Return [MergeResult] with content, diff, and conflicts.
library;

import 'package:dart_style/dart_style.dart';

import 'ast_diff.dart';
import 'declaration_scanner.dart';
import 'merge_strategy.dart';
import 'merge_types.dart';
import 'region_parser.dart';

class MergeOrchestrator {
  static final DartFormatter _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  /// Merge [existingContent] with [generatedContent] using [mode].
  static MergeResult merge({
    required String existingContent,
    required String generatedContent,
    MergeMode mode = MergeMode.smart,
    String? filePath,
  }) {
    // Force mode: just return the generated content directly.
    if (mode == MergeMode.force) {
      final formatted = safeFormat(generatedContent);
      return MergeResult(
        content: formatted,
        hasChanges: formatted != existingContent,
        diffSummary: existingContent.isEmpty
            ? ''
            : simpleDiff(existingContent, formatted),
        conflicts: const [],
      );
    }

    // No existing file.
    if (existingContent.isEmpty) {
      return MergeResult(
        content: safeFormat(generatedContent),
        hasChanges: true,
        diffSummary: '(new file)',
        conflicts: const [],
      );
    }

    // Smart merge: parse regions from existing file.
    final regions = RegionParser.parse(existingContent);

    // A malformed marker structure (interleaved/unclosed preserve or
    // generated markers) would silently drop preserved content when a
    // generated region is replaced. Report a conflict and leave the file
    // unchanged rather than corrupt it (CodeRabbit finding on
    // region_parser.dart:65).
    if (RegionParser.hasMalformedMarkers(existingContent)) {
      return MergeResult(
        content: existingContent,
        hasChanges: false,
        diffSummary: '',
        conflicts: [
          MergeConflict(
            message:
                'Existing file has interleaved or unclosed preserve/'
                'generated markers',
            line: 0,
            existingContent: existingContent,
            generatedContent: generatedContent,
            suggestion:
                'Fix the marker structure (every @preserve needs @end-preserve '
                'and every GENERATED needs END GENERATED, with no preserve '
                'block straddling a generated boundary) before regenerating.',
          ),
        ],
      );
    }

    final diffEntries = AstDiff.diff(
      existingSource: existingContent,
      generatedSource: generatedContent,
      filePath: filePath,
    );

    if (regions.isEmpty && diffEntries.isEmpty) {
      return MergeResult.unchanged(existingContent);
    }

    if (regions.isNotEmpty) {
      return MergeStrategy.merge(
        existingContent: existingContent,
        generatedContent: generatedContent,
        regions: regions,
      );
    }

    // No markers: structural merge.
    return structuralMerge(
      existingContent: existingContent,
      generatedContent: generatedContent,
      diffEntries: diffEntries,
    );
  }

  /// Structural merge for files without region markers.
  ///
  /// Walks the EXISTING file and replaces each generated declaration
  /// in place, preserving every other line — imports, top-level
  /// variables and user declarations — so user-owned source is never
  /// dropped when a generated declaration changes. Generated
  /// declarations absent from the existing file are appended.
  static MergeResult structuralMerge({
    required String existingContent,
    required String generatedContent,
    required List<DiffEntry> diffEntries,
  }) {
    if (existingContent.trimRight() == generatedContent.trimRight()) {
      return MergeResult.unchanged(existingContent);
    }

    final existingLines = existingContent.split('\n');
    final generatedLines = generatedContent.split('\n');

    final existingDecls = extractDeclarationsFromSource(existingContent);
    final generatedDecls = extractDeclarationsFromSource(generatedContent);
    final generatedByName = {
      for (final d in generatedDecls) '${d.kind}:${d.name}': d,
    };

    // Directives (import/export/part) the generated content requires but
    // the existing file lacks. A generated declaration that references a
    // new type needs its import merged in, or the output cannot resolve it
    // (CodeRabbit finding on merge_orchestrator.dart:119). Conflicting
    // directives (same path, different form) are reported as a conflict
    // rather than silently dropped.
    final directiveMerge = _mergeDirectives(
      existingContent: existingContent,
      generatedContent: generatedContent,
    );

    final buffer = StringBuffer();
    final directiveConflicts = directiveMerge.conflicts;
    int cursor = 0;
    for (final decl in existingDecls) {
      // Preserve the existing lines before this declaration (imports,
      // top-level variables, comments).
      if (cursor < decl.startLine) {
        buffer.write(existingLines.sublist(cursor, decl.startLine).join('\n'));
        buffer.writeln();
      }
      final gen = generatedByName['${decl.kind}:${decl.name}'];
      if (gen != null && decl.unsafeLineReplace) {
        // This declaration shares its physical line with another
        // declaration; a line-based replacement would clobber the
        // neighbour. Keep the existing line verbatim and report a conflict
        // (CodeRabbit finding on declaration_scanner.dart:115).
        buffer.write(
          existingLines.sublist(decl.startLine, decl.endLine).join('\n'),
        );
        directiveConflicts.add(
          MergeConflict(
            message:
                '${decl.kind} ${decl.name} shares a line with another '
                'declaration; cannot replace it without clobbering its '
                'neighbour',
            line: decl.startLine,
            existingContent: existingLines
                .sublist(decl.startLine, decl.endLine)
                .join('\n'),
            generatedContent: generatedLines
                .sublist(gen.startLine, gen.endLine)
                .join('\n'),
            suggestion:
                'Put each top-level declaration on its own line, then '
                'regenerate; the generated change was not applied to avoid '
                'deleting the adjacent declaration.',
          ),
        );
      } else if (gen != null) {
        buffer.write(
          generatedLines.sublist(gen.startLine, gen.endLine).join('\n'),
        );
      } else {
        // User declaration — keep it verbatim.
        buffer.write(
          existingLines.sublist(decl.startLine, decl.endLine).join('\n'),
        );
      }
      buffer.writeln();
      cursor = decl.endLine;
    }
    // Preserve any trailing existing lines after the last declaration.
    if (cursor < existingLines.length) {
      buffer.write(existingLines.sublist(cursor).join('\n'));
    }

    // Append generated declarations that have no existing counterpart.
    final existingNames = {
      for (final d in existingDecls) '${d.kind}:${d.name}',
    };
    for (final d in generatedDecls) {
      if (existingNames.contains('${d.kind}:${d.name}')) continue;
      buffer.writeln();
      buffer.write(generatedLines.sublist(d.startLine, d.endLine).join('\n'));
    }

    var merged = buffer.toString();
    // Inject any missing generated directives into the directive section.
    if (directiveMerge.missing.isNotEmpty) {
      merged = _injectDirectives(merged, directiveMerge.missing);
    }

    return MergeResult(
      content: safeFormat(merged),
      hasChanges: true,
      diffSummary: AstDiff.buildSummary(diffEntries),
      conflicts: directiveConflicts,
    );
  }

  /// The generated directives (import/export/part lines) that the existing
  /// file is missing, plus any conflicts where a generated directive shares
  /// a path with a differently-spelled existing one.
  static _DirectiveMerge _mergeDirectives({
    required String existingContent,
    required String generatedContent,
  }) {
    final existingDirectives = _directives(existingContent);
    final generatedDirectives = _directives(generatedContent);

    final existingPaths = {
      for (final d in existingDirectives) _directivePath(d),
    };
    final existingForms = {for (final d in existingDirectives) d.trim()};

    final missing = <String>[];
    final conflicts = <MergeConflict>[];
    final seenMissing = <String>{};
    for (final d in generatedDirectives) {
      final path = _directivePath(d);
      if (existingPaths.contains(path)) {
        // Same path already imported — a different spelling is a conflict,
        // an identical line is a no-op.
        if (!existingForms.contains(d.trim())) {
          final existingForm = existingDirectives
              .firstWhere((e) => _directivePath(e) == path)
              .trim();
          conflicts.add(
            MergeConflict(
              message:
                  'Conflicting directive for "$path": existing '
                  '"$existingForm" vs generated "${d.trim()}"',
              line: 0,
              existingContent: existingContent,
              generatedContent: d.trim(),
              suggestion:
                  'Reconcile the import/export form manually; the generated '
                  'form was not merged to avoid duplicate directives.',
            ),
          );
        }
        continue;
      }
      if (seenMissing.add(d.trim())) missing.add(d);
    }
    return _DirectiveMerge(missing: missing, conflicts: conflicts);
  }

  /// The directive lines (import/export/part) in [source], in source order.
  static List<String> _directives(String source) => [
    for (final line in source.split('\n'))
      if (() {
        final t = line.trimLeft();
        return t.startsWith('import ') ||
            t.startsWith('export ') ||
            t.startsWith('part ');
      }())
        line,
  ];

  /// The path/URI a directive targets, used to detect duplicate imports of
  /// the same library in different forms.
  static String _directivePath(String directive) {
    final firstQuote = directive.indexOf("'");
    final secondQuote = directive.indexOf("'", firstQuote + 1);
    if (firstQuote >= 0 && secondQuote > firstQuote) {
      return directive.substring(firstQuote + 1, secondQuote);
    }
    return directive.trim();
  }

  /// Insert [directives] after the last existing directive in [source] (or
  /// at the top when the file has none), keeping the directive section
  /// contiguous.
  static String _injectDirectives(String source, List<String> directives) {
    final lines = source.split('\n');
    int lastDirective = -1;
    for (int i = 0; i < lines.length; i++) {
      final t = lines[i].trimLeft();
      if (t.startsWith('import ') ||
          t.startsWith('export ') ||
          t.startsWith('part ')) {
        lastDirective = i;
      }
    }
    final insertAt = lastDirective >= 0 ? lastDirective + 1 : 0;
    lines.insertAll(insertAt, directives);
    return lines.join('\n');
  }

  /// Format Dart source.
  ///
  /// A formatter failure is RE-THROWN, never swallowed: returning the
  /// unformatted buffer as a "successful" merge lets `SmartMergeWriter`
  /// write a file that does not parse (CodeRabbit finding on
  /// merge_orchestrator.dart:157). The writer already rethrows merge
  /// failures and leaves the existing file untouched, so propagating the
  /// failure routes through that same safe path.
  static String safeFormat(String source) {
    return _formatter.format(source);
  }

  /// Generate a simple line-level diff between two strings.
  static String simpleDiff(String old, String nu) {
    final oldLines = old.split('\n');
    final newLines = nu.split('\n');
    final buffer = StringBuffer();
    final maxLen = oldLines.length > newLines.length
        ? oldLines.length
        : newLines.length;
    for (int i = 0; i < maxLen; i++) {
      final o = i < oldLines.length ? oldLines[i] : null;
      final n = i < newLines.length ? newLines[i] : null;
      if (o == n) continue;
      if (o == null) {
        buffer.writeln('+ $n');
      } else if (n == null) {
        buffer.writeln('- $o');
      } else {
        buffer.writeln('- $o');
        buffer.writeln('+ $n');
      }
    }
    return buffer.toString().trimRight();
  }
}

/// Result of merging generated directives into the existing file's
/// directive section: the directives to inject and any conflicts found.
class _DirectiveMerge {
  final List<String> missing;
  final List<MergeConflict> conflicts;

  const _DirectiveMerge({required this.missing, required this.conflicts});
}
