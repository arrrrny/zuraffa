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

  const Declaration({
    required this.kind,
    required this.name,
    required this.startLine,
    required this.endLine,
  });

  @override
  String toString() => '$kind $name (lines $startLine..$endLine)';

  @override
  bool operator ==(Object other) =>
      other is Declaration &&
      other.kind == kind &&
      other.name == name &&
      other.startLine == startLine &&
      other.endLine == endLine;

  @override
  int get hashCode => Object.hash(kind, name, startLine, endLine);
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
        Declaration(kind: kind, name: name, startLine: i, endLine: endLine),
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
/// For brace-less declarations (e.g. typedefs), returns [startLine + 1]
/// when a semicolon is encountered before any opening brace.
///
/// **Limitation:** Does not ignore braces inside string literals or comments,
/// so unusual constructs may confuse the scanner.
int _findDeclarationEnd(List<String> lines, int startLine) {
  int depth = 0;
  bool foundOpen = false;

  for (int i = startLine; i < lines.length; i++) {
    for (final ch in lines[i].runes) {
      if (ch == 0x7B) {
        // '{'
        depth++;
        foundOpen = true;
      } else if (ch == 0x7D) {
        // '}'
        depth--;
      } else if (ch == 0x3B && !foundOpen) {
        // ';' before any '{'
        // Brace-less declaration (e.g. typedef) — end after this line.
        return i + 1;
      }
    }
    if (foundOpen && depth <= 0) {
      // Return the line after the closing brace.
      return i + 1;
    }
  }

  // Unterminated brace or declaration — return end of file.
  return lines.length;
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
