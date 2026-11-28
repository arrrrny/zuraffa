/// Identifies and classifies line ranges in a Dart source file.
///
/// The merge engine treats the file as a sequence of **regions**:
///
/// - **Generated region**: bracketed by
///   `// GENERATED - DO NOT EDIT` (start) and
///   `// END GENERATED` (end). The content inside is safe to replace.
///
/// - **Preserved region**: bracketed by
///   `// @preserve` (start) and
///   `// @end-preserve` (end). The content inside must survive
///   regeneration even if it falls inside a generated region.
///
/// - **User region**: everything else. Never touched by the merge
///   engine.
///
/// Regions may nest. A `@preserve` inside a `GENERATED` block takes
/// priority — the preserved lines are extracted before the generated
/// block is replaced, then spliced back in.
library;

import 'declaration_scanner.dart';

class RegionParser {
  /// Marker that begins a generated (replaceable) region.
  static const String generatedStart = '// GENERATED - DO NOT EDIT';

  /// Marker that ends a generated region.
  static const String generatedEnd = '// END GENERATED';

  /// Marker that begins a preserved (immutable) region.
  static const String preserveStart = '// @preserve';

  /// Marker that ends a preserved region.
  static const String preserveEnd = '// @end-preserve';

  /// Parse [source] into a list of [SourceRegion]s.
  ///
  /// Lines are 0-based. Each region covers [startLine, endLine).
  static List<SourceRegion> parse(String source) {
    final lines = source.split('\n');
    final regions = <SourceRegion>[];
    // Lines whose leading `//` is a genuine line comment — a marker that
    // appears inside a string literal or block comment is NOT a marker
    // (CodeRabbit finding on region_parser.dart:50).
    final commentLines = _lineCommentLines(lines);

    // Stack for nested generated regions.
    final genStack = <_Marker>[];
    // Stack for nested preserved regions (within a generated block).
    final preserveStack = <_Marker>[];

    for (int i = 0; i < lines.length; i++) {
      if (!commentLines.contains(i)) continue;
      final trimmed = lines[i].trim();

      // Check for preserve start (only meaningful inside generated).
      if (trimmed.startsWith(preserveStart) &&
          !trimmed.startsWith(preserveEnd)) {
        preserveStack.add(_Marker(i, _MarkerType.preserveStart));
        continue;
      }
      if (trimmed.startsWith(preserveEnd)) {
        if (preserveStack.isNotEmpty) {
          final start = preserveStack.removeLast();
          regions.add(
            SourceRegion(
              startLine: start.line,
              endLine: i + 1,
              type: RegionType.preserved,
              content: lines.sublist(start.line, i + 1).join('\n'),
            ),
          );
        }
        continue;
      }

      // Check for generated block markers.
      if (trimmed.startsWith(generatedStart) &&
          !trimmed.startsWith(generatedEnd)) {
        genStack.add(_Marker(i, _MarkerType.generatedStart));
        continue;
      }
      if (trimmed.startsWith(generatedEnd)) {
        if (genStack.isNotEmpty) {
          final start = genStack.removeLast();
          regions.add(
            SourceRegion(
              startLine: start.line,
              endLine: i + 1,
              type: RegionType.generated,
              content: lines.sublist(start.line, i + 1).join('\n'),
            ),
          );
        }
        continue;
      }
    }

    // Anything not covered by a region is implicitly user code.
    // We don't create explicit user regions — the merge engine treats
    // gaps between regions as user code.

    regions.sort((a, b) => a.startLine.compareTo(b.startLine));
    return regions;
  }

  /// Extract preserved regions from a generated block's content.
  ///
  /// When a generated block is about to be replaced, this extracts
  /// any `@preserve`...`@end-preserve` regions so they can be
  /// spliced into the replacement. Only the OUTERMOST block is emitted
  /// when preserve markers nest, so an inner block is never duplicated.
  /// Each block records the name of the top-level declaration that
  /// encloses it (when any) so the splice can restore it to the correct
  /// declaration rather than the last brace in the replacement.
  static List<PreservedBlock> extractPreservedBlocks(String blockContent) {
    final lines = blockContent.split('\n');
    final blocks = <PreservedBlock>[];
    final stack = <int>[];
    final commentLines = _lineCommentLines(lines);

    for (int i = 0; i < lines.length; i++) {
      if (!commentLines.contains(i)) continue;
      final trimmed = lines[i].trim();
      if (trimmed.startsWith(preserveStart) &&
          !trimmed.startsWith(preserveEnd)) {
        stack.add(i);
      } else if (trimmed.startsWith(preserveEnd) && stack.isNotEmpty) {
        final start = stack.removeLast();
        // Only emit the outermost block: when the closing marker empties
        // the stack, this block encloses any inner preserved blocks, so
        // emitting both would duplicate the inner content.
        if (stack.isEmpty) {
          blocks.add(
            PreservedBlock(
              content: lines.sublist(start, i + 1).join('\n'),
              enclosingDeclaration: _enclosingDeclaration(lines, start),
            ),
          );
        }
      }
    }

    return blocks;
  }

  /// Whether the existing file has interleaved or unclosed preserve/
  /// generated marker pairs that would silently drop preserved content
  /// when a generated region is replaced (CodeRabbit finding on
  /// region_parser.dart:65).
  ///
  /// A well-formed file has every `@preserve` closed by `@end-preserve`
  /// and every `GENERATED` closed by `END GENERATED`, with no preserve
  /// block straddling a generated boundary. Returns `true` when the marker
  /// structure is malformed.
  static bool hasMalformedMarkers(String source) {
    final lines = source.split('\n');
    final commentLines = _lineCommentLines(lines);
    final genStack = <int>[];
    final preserveStack = <int>[];

    for (int i = 0; i < lines.length; i++) {
      if (!commentLines.contains(i)) continue;
      final trimmed = lines[i].trim();
      if (trimmed.startsWith(preserveStart) &&
          !trimmed.startsWith(preserveEnd)) {
        preserveStack.add(i);
      } else if (trimmed.startsWith(preserveEnd)) {
        if (preserveStack.isEmpty) return true; // unmatched preserve-end
        preserveStack.removeLast();
      } else if (trimmed.startsWith(generatedStart) &&
          !trimmed.startsWith(generatedEnd)) {
        genStack.add(i);
      } else if (trimmed.startsWith(generatedEnd)) {
        if (genStack.isEmpty) return true; // unmatched generated-end
        // A preserve opened inside this generated block is still open when
        // the generated block closes — the preserve straddles the boundary
        // and its content would be dropped on replacement
        // (CodeRabbit region_parser.dart:65).
        if (preserveStack.isNotEmpty) return true;
        genStack.removeLast();
      }
    }
    // Any marker left open at EOF is malformed.
    return genStack.isNotEmpty || preserveStack.isNotEmpty;
  }

  /// The set of line indices whose first non-whitespace characters are a
  /// genuine `//` line comment — i.e. the `//` is not inside a string
  /// literal (single, double, or triple-quoted, possibly spanning lines) or
  /// a block comment. Markers are only recognized on these lines, so the
  /// same text inside a string or block comment is ignored
  /// (CodeRabbit finding on region_parser.dart:50).
  static Set<int> _lineCommentLines(List<String> lines) {
    final result = <int>{};
    bool inBlockComment = false;
    String? stringDelim;

    for (int i = 0; i < lines.length; i++) {
      final runes = lines[i].runes.toList();
      int j = 0;
      bool leadingWs = true;
      bool isCommentLine = false;
      while (j < runes.length) {
        final ch = runes[j];

        if (inBlockComment) {
          if (ch == 0x2A && j + 1 < runes.length && runes[j + 1] == 0x2F) {
            inBlockComment = false;
            j += 2;
            continue;
          }
          j++;
          continue;
        }

        if (stringDelim != null) {
          final delim = stringDelim;
          if (delim.length == 3) {
            if (_matchesRunesAt(runes, j, delim)) {
              j += 3;
              stringDelim = null;
              continue;
            }
          } else {
            if (ch == 0x5C) {
              j += 2;
              continue;
            }
            if (ch == delim.codeUnitAt(0)) {
              j++;
              stringDelim = null;
              continue;
            }
          }
          j++;
          leadingWs = false;
          continue;
        }

        // Not in string/comment.
        if (ch == 0x2F && j + 1 < runes.length && runes[j + 1] == 0x2F) {
          // Line comment — a marker is genuine only when the comment is the
          // first token on the line (only whitespace before it).
          if (leadingWs) isCommentLine = true;
          break;
        }
        if (ch == 0x2F && j + 1 < runes.length && runes[j + 1] == 0x2A) {
          inBlockComment = true;
          j += 2;
          leadingWs = false;
          continue;
        }
        if (ch == 0x27 || ch == 0x22) {
          final triple = ch == 0x27 ? "'''" : '"""';
          if (_matchesRunesAt(runes, j, triple)) {
            stringDelim = triple;
            j += 3;
          } else {
            stringDelim = ch == 0x27 ? "'" : '"';
            j++;
          }
          leadingWs = false;
          continue;
        }
        if (ch != 0x20 && ch != 0x09) leadingWs = false;
        j++;
      }
      if (isCommentLine) result.add(i);
    }
    return result;
  }

  /// The name of the top-level declaration whose line range contains
  /// [line], or `null` when the line is not inside any declaration.
  static String? _enclosingDeclaration(List<String> lines, int line) {
    final decls = extractDeclarationsFromSource(lines.join('\n'));
    for (final d in decls) {
      if (line >= d.startLine && line < d.endLine) return d.name;
    }
    return null;
  }

  /// Whether [runes] contains [needle] starting at index [at].
  static bool _matchesRunesAt(List<int> runes, int at, String needle) {
    final n = needle.runes.toList();
    if (at + n.length > runes.length) return false;
    for (int k = 0; k < n.length; k++) {
      if (runes[at + k] != n[k]) return false;
    }
    return true;
  }
}

/// A contiguous region of source lines classified by its role.
class SourceRegion {
  final int startLine;
  final int endLine;
  final RegionType type;
  final String content;

  const SourceRegion({
    required this.startLine,
    required this.endLine,
    required this.type,
    required this.content,
  });
}

/// Type of a [SourceRegion].
enum RegionType {
  /// Code inside `// GENERATED - DO NOT EDIT` ... `// END GENERATED`.
  generated,

  /// Code inside `// @preserve` ... `// @end-preserve`.
  preserved,
}

/// A preserved block extracted from a generated region.
///
/// These are spliced back into the replacement generated content.
/// [enclosingDeclaration] is the name of the top-level declaration the
/// block lived in (e.g. `A`), or `null` for a top-level preserve block,
/// so the splice can restore it to the matching declaration rather than
/// the last brace of the replacement.
class PreservedBlock {
  final String content;
  final String? enclosingDeclaration;

  const PreservedBlock({required this.content, this.enclosingDeclaration});
}

enum _MarkerType { generatedStart, preserveStart }

class _Marker {
  final int line;
  final _MarkerType type;
  const _Marker(this.line, this.type);
}
