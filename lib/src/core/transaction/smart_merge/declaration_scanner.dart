/// Lightweight top-level declaration scanner for Dart source.
///
/// Uses regex-based pattern matching (no analyzer dependency) to extract
/// top-level declarations (classes, extensions, enums, mixins, functions)
/// and their line ranges. Sufficient for zorphy's generated files where
/// the structure is predictable.
library;

/// A top-level declaration extracted from Dart source.
class Declaration {
  /// The kind of declaration (e.g. 'class', 'extension', 'enum', 'mixin',
  /// 'function', 'typedef').
  final String kind;

  /// The declaration name.
  final String name;

  /// Zero-based start line (inclusive).
  final int startLine;

  /// Zero-based end line (exclusive, for use with `List.sublist`).
  final int endLine;

  /// Whether this declaration shares its physical line with another
  /// top-level declaration (e.g. `class A {} class User {}`). A line-based
  /// replacement of such a declaration would clobber its neighbour, so the
  /// structural merge reports a conflict for it instead of replacing the
  /// whole line (CodeRabbit finding on declaration_scanner.dart:115).
  final bool unsafeLineReplace;

  const Declaration({
    required this.kind,
    required this.name,
    required this.startLine,
    required this.endLine,
    this.unsafeLineReplace = false,
  });

  @override
  String toString() => '$kind $name (lines $startLine..$endLine)';

  @override
  bool operator ==(Object other) =>
      other is Declaration &&
      other.kind == kind &&
      other.name == name &&
      other.startLine == startLine &&
      other.endLine == endLine &&
      other.unsafeLineReplace == unsafeLineReplace;

  @override
  int get hashCode =>
      Object.hash(kind, name, startLine, endLine, unsafeLineReplace);
}

/// Pattern for top-level declarations we care about.
///
/// Matches:
/// - `(abstract |sealed |final |base |interface )?class Name`
/// - `extension Name`
/// - `enum Name`
/// - `mixin Name`
/// - `typedef Name`
/// - top-level `FutureOr<T> name(` or `T name(` functions
final _declPattern = RegExp(
  r'^(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+)?'
  r'(class|extension|enum|mixin|typedef)\s+'
  r'(\$?[A-Za-z_][A-Za-z0-9_\$]*)',
);

/// Pattern for top-level function declarations (simplified).
/// Matches lines like `String doSomething(` or `void main(` at column 0.
final _functionPattern = RegExp(
  r'^(?:[A-Za-z_<][A-Za-z0-9_<>?,\s]*\s+)?'
  r'([A-Za-z_][A-Za-z0-9_]*)\s*\(',
);

/// Extract top-level declarations from [source].
///
/// Returns a list of [Declaration] with their line ranges.
/// Brace-depth tracking determines the end of each declaration.
List<Declaration> extractDeclarationsFromSource(String source) {
  final lines = source.split('\n');
  final declarations = <Declaration>[];

  // Keywords that signal a declaration we should skip (part, import,
  // export, etc.).
  const skipPrefixes = [
    'import ',
    'export ',
    'part ',
    '//',
    '///',
    '/*',
    '* ',
    '@',
    'const ',
    'final ',
    'var ',
    'late ',
  ];

  int i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trimLeft();

    // Skip empty lines.
    if (trimmed.isEmpty) {
      i++;
      continue;
    }

    // Try class/extension/enum/mixin/typedef BEFORE applying skipPrefixes,
    // so that modifier-prefixed declarations (e.g. "final class Foo") are
    // properly recognized.
    final declMatch = _declPattern.firstMatch(trimmed);
    if (declMatch != null) {
      final kind = declMatch.group(1)!;
      final name = declMatch.group(2)!;
      final endLine = _findDeclarationEnd(lines, i);
      declarations.add(
        Declaration(
          kind: kind,
          name: name,
          startLine: i,
          endLine: endLine,
          unsafeLineReplace: _lineHasAnotherDeclaration(declMatch, trimmed),
        ),
      );
      i = endLine;
      continue;
    }

    // Skip non-declaration lines (imports, comments, top-level variables).
    if (skipPrefixes.any((p) => trimmed.startsWith(p))) {
      i++;
      continue;
    }

    // Try top-level function.
    final funcMatch = _functionPattern.firstMatch(trimmed);
    if (funcMatch != null && _looksLikeFunction(lines, i)) {
      final name = funcMatch.group(1)!;
      // Skip known Dart keywords that aren't function names.
      if (const [
        'if',
        'for',
        'while',
        'switch',
        'catch',
        'on',
      ].contains(name)) {
        i++;
        continue;
      }
      final endLine = _findDeclarationEnd(lines, i);
      declarations.add(
        Declaration(
          kind: 'function',
          name: name,
          startLine: i,
          endLine: endLine,
        ),
      );
      i = endLine;
      continue;
    }

    i++;
  }

  return declarations;
}

/// Walk forward from [startLine] tracking brace depth to find where
/// the declaration ends. Returns the line index **after** the closing
/// brace (exclusive, for use with `List.sublist`).
///
/// For brace-less declarations (e.g. typedefs, expression-bodied
/// functions), returns [startLine + 1] when a semicolon is encountered
/// before any opening body brace.
///
/// The scan is lexical: braces inside string literals and comments are
/// ignored, and a `{` that appears inside a parameter list (while the
/// paren depth is non-zero) is a named-parameter brace, not the body —
/// so an expression-bodied function such as
/// `String helper({required String v}) => v.trim();` ends at its `;`
/// rather than at the parameter brace.
int _findDeclarationEnd(List<String> lines, int startLine) {
  int depth = 0;
  int parenDepth = 0;
  bool foundOpen = false;
  // An arrow (`=>`) body is expression-bodied: it has no `{...}` body
  // brace, so a `{` after the arrow is a set/map literal or a nested
  // expression, NOT the function body. The declaration ends at the
  // terminating `;` once every nested expression has closed
  // (CodeRabbit finding on declaration_scanner.dart:258).
  bool arrowBody = false;
  bool inBlockComment = false;
  // Active string delimiter: null when not in a string, otherwise one of
  // `'`, `"`, `'''`, `"""`. Triple-quoted delimiters persist across lines.
  String? stringDelim;

  for (int i = startLine; i < lines.length; i++) {
    final runes = lines[i].runes.toList();
    int j = 0;
    while (j < runes.length) {
      final ch = runes[j];

      if (inBlockComment) {
        if (ch == 0x2A && j + 1 < runes.length && runes[j + 1] == 0x2F) {
          // */
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
            // backslash escape — skip the escaped rune
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
        continue;
      }

      // Line comment — rest of the line is ignored.
      if (ch == 0x2F && j + 1 < runes.length && runes[j + 1] == 0x2F) {
        break;
      }
      // Block comment start.
      if (ch == 0x2F && j + 1 < runes.length && runes[j + 1] == 0x2A) {
        inBlockComment = true;
        j += 2;
        continue;
      }
      // String start.
      if (ch == 0x27 || ch == 0x22) {
        final triple = ch == 0x27 ? "'''" : '"""';
        if (_matchesRunesAt(runes, j, triple)) {
          stringDelim = triple;
          j += 3;
        } else {
          stringDelim = ch == 0x27 ? "'" : '"';
          j++;
        }
        continue;
      }

      // Arrow `=>` at the top level (outside any parameter list) marks an
      // expression-bodied declaration.
      if (ch == 0x3D &&
          j + 1 < runes.length &&
          runes[j + 1] == 0x3E &&
          parenDepth == 0 &&
          !foundOpen) {
        arrowBody = true;
        j += 2;
        continue;
      }

      if (ch == 0x28) {
        // (
        parenDepth++;
      } else if (ch == 0x29) {
        // )
        if (parenDepth > 0) parenDepth--;
      } else if (ch == 0x7B) {
        // '{' — only a body brace when not inside a parameter list AND
        // the declaration is not expression-bodied (a `{` after `=>` is a
        // set/map literal).
        if (parenDepth == 0) {
          depth++;
          if (!arrowBody) foundOpen = true;
        }
      } else if (ch == 0x7D) {
        // '}'
        if (parenDepth == 0 && depth > 0) depth--;
      } else if (ch == 0x3B && !foundOpen && parenDepth == 0 && depth <= 0) {
        // ';' before any block body (or closing every arrow-body
        // expression) — brace-less / expression-bodied declaration ends.
        return i + 1;
      }
      j++;
    }
    if (foundOpen && depth <= 0) {
      // Return the line after the closing brace.
      return i + 1;
    }
  }

  // Unterminated brace or declaration — return end of file.
  return lines.length;
}

/// Whether [trimmed] (a single physical line) contains a SECOND top-level
/// declaration keyword after the one already matched by [first]. Used to
/// flag a declaration that shares its line with another — a line-based
/// replacement would clobber the neighbour, so the structural merge reports
/// a conflict instead (CodeRabbit finding on declaration_scanner.dart:115).
bool _lineHasAnotherDeclaration(RegExpMatch first, String trimmed) {
  final after = trimmed.substring(first.end).trimLeft();
  if (after.isEmpty) return false;
  // A second declaration on the same line: `class A {} class User {}`. The
  // anchored `_declPattern`/`_functionPattern` only match at column 0, so
  // search the remainder for an unanchored declaration keyword.
  return _secondDeclPattern.hasMatch(after);
}

/// Unanchored search for a declaration keyword appearing mid-line (the
/// neighbour in a shared-line declaration).
final _secondDeclPattern = RegExp(
  r'(?:^|[\s{};])'
  r'(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+)?'
  r'(class|extension|enum|mixin|typedef)\s+'
  r'\$?[A-Za-z_][A-Za-z0-9_\$]*',
);

/// Whether [runes] contains [needle] starting at index [at].
bool _matchesRunesAt(List<int> runes, int at, String needle) {
  final n = needle.runes.toList();
  if (at + n.length > runes.length) return false;
  for (int k = 0; k < n.length; k++) {
    if (runes[at + k] != n[k]) return false;
  }
  return true;
}

/// Heuristic: check whether line at [lineIndex] looks like a top-level
/// function definition (not a method call, assignment, etc.).
bool _looksLikeFunction(List<String> lines, int lineIndex) {
  final trimmed = lines[lineIndex].trim();

  // Must contain '(' — functions have parameter lists.
  if (!trimmed.contains('(')) return false;

  // Must NOT start with return/throw/await/yield — those are statements.
  if (const [
    'return ',
    'return;',
    'throw ',
    'throw;',
    'await ',
    'yield ',
  ].any((p) => trimmed.startsWith(p))) {
    return false;
  }

  // Must NOT be an assignment (contains '=' before '(').
  final parenIdx = trimmed.indexOf('(');
  final eqIdx = trimmed.indexOf('=');
  if (eqIdx >= 0 && eqIdx < parenIdx) return false;

  // Should NOT be a function call (starts with lowercase and has
  // no return type). Real top-level functions typically have a type.
  if (parenIdx > 0 &&
      trimmed.substring(0, parenIdx).trim().split(' ').length < 2) {
    // Only one word before '(' — likely a call, not a definition.
    // Exception: constructors and operators.
    return false;
  }

  return true;
}
