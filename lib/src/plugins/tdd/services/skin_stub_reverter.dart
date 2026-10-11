/// The stub-revert red witness (issue #1005) — the cycle-side replacer
/// that turns ONLY a hand-written view's view-builder function into the
/// inert stub so the paired test fails (RED) while every other
/// declaration in the file keeps compiling.
///
/// The mutation-audit pattern (spec 044 FR-021/FR-022, the
/// `SourceRestorer` contract): capture the hand-written bytes, stub the
/// builder, run the test, restore byte-exact. The TEST file is never
/// touched; the replacement scope is exactly the view-builder function
/// the immutable test calls (`subject.<name>()`) — found by the cycle
/// in the TEST source, never named by the author.
library;

/// The stub the red witness replaces the view-builder with.
const String kSkinRedWitnessStubMessage =
    'zfa tdd run-skin: temporary inert stub - the issue #1005 red '
    'witness; the hand-written bytes are restored verbatim after the '
    'run';

/// Replace [functionName]'s declaration in [source] with the inert
/// throwing stub; null when no view-builder declaration is found.
///
/// Handles both body shapes (parens depth-matched for the parameter
/// list, braces/brackets depth-matched for the body), and preserves the
/// declaration's ORIGINAL return type (a Flutter view-builder returns
/// `Widget`; a pure-Dart fixture view returns its view class — the
/// paired test's call site only needs the symbol to keep existing):
///
/// ```dart
/// Widget loginView() => const LoginView();          // expression body
/// LoginView loginView({LoginViewState? s}) { ... }   // block body
/// ```
///
/// The replacement is the declaration text ONLY — doc comments and
/// annotations above it survive (they document the hand-edit, not the
/// body), and everything after the body (the hand-written classes)
/// survives untouched so the file still compiles for the RED run.
String? stubViewBuilder(String source, String functionName) {
  final decl = findViewBuilderDeclaration(source, functionName);
  if (decl == null) return null;
  final stub =
      "${decl.returnType} $functionName() => throw UnimplementedError("
      "'$kSkinRedWitnessStubMessage');";
  return source.replaceRange(decl.start, decl.end, stub);
}

/// The located extent of one view-builder declaration.
class ViewBuilderSpan {
  const ViewBuilderSpan(this.start, this.end, this.returnType);

  /// Offset of the declaration's return-type token.
  final int start;

  /// Offset just past the body's closing `;` or `}`.
  final int end;

  /// The declaration's return type, verbatim (`Widget`, `LoginView`,
  /// …) — the stub keeps it so the file still compiles.
  final String returnType;
}

/// Locate [functionName]'s top-level `<ReturnType> <name>(...)`
/// declaration in [source] (a top-level, zero-indentation declaration
/// preferred; any first occurrence as fallback — a nested same-named
/// function is still the callable the file compiles). Returns the span
/// covering the declaration through the end of its body, or null when
/// no match.
ViewBuilderSpan? findViewBuilderDeclaration(
  String source,
  String functionName,
) {
  final pattern = RegExp(
    '([A-Za-z_][A-Za-z0-9_<>?,.]*)[\\t ]+$functionName[\\t ]*\\(',
  );
  // Prefer a top-level declaration (start of line, no indentation).
  final topLevel = RegExp(
    '^([A-Za-z_][A-Za-z0-9_<>?,.]*)[\\t ]+$functionName[\\t ]*\\(',
    multiLine: true,
  );
  final m = topLevel.firstMatch(source) ?? pattern.firstMatch(source);
  if (m == null) return null;
  final returnType = m.group(1)!;
  final start = m.start;
  // Skip to the `(`.
  final openParen = source.indexOf('(', m.start);
  if (openParen < 0) return null;
  final closeParen = _matchDelimiters(source, openParen, '(', ')');
  if (closeParen < 0) return null;
  var i = closeParen + 1;
  // Skip whitespace (and line continuations) to the body.
  while (i < source.length &&
      (source[i] == ' ' ||
          source[i] == '\t' ||
          source[i] == '\n' ||
          source[i] == '\r')) {
    i++;
  }
  if (i >= source.length) return null;
  if (source[i] == '=') {
    // Expression body `=> expr;` — find the terminating `;` outside
    // any delimiter nesting or string literal.
    final semi = _findTerminator(source, i, ';');
    if (semi < 0) return null;
    return ViewBuilderSpan(start, semi + 1, returnType);
  }
  if (source[i] == '{') {
    // Block body `{ ... }` — brace-matched, then optional `;`.
    final close = _matchDelimiters(source, i, '{', '}');
    if (close < 0) return null;
    var end = close + 1;
    while (end < source.length &&
        (source[end] == ' ' ||
            source[end] == '\t' ||
            source[end] == '\n' ||
            source[end] == '\r')) {
      end++;
    }
    if (end < source.length && source[end] == ';') end++;
    return ViewBuilderSpan(start, end, returnType);
  }
  return null;
}

/// Index of [closer] at depth zero from [openIdx] (the index of
/// [opener]); -1 when unbalanced. String literals are skipped.
int _matchDelimiters(String source, int openIdx, String opener, String closer) {
  var depth = 0;
  var i = openIdx;
  while (i < source.length) {
    final ch = source[i];
    if (ch == '"' || ch == "'") {
      final end = _skipString(source, i);
      if (end < 0) return -1;
      i = end;
      continue;
    }
    if (ch == '/' && i + 1 < source.length && source[i + 1] == '/') {
      final nl = source.indexOf('\n', i);
      if (nl < 0) return -1;
      i = nl + 1;
      continue;
    }
    if (ch == '/' && i + 1 < source.length && source[i + 1] == '*') {
      final close = source.indexOf('*/', i + 2);
      if (close < 0) return -1;
      i = close + 2;
      continue;
    }
    if (ch == opener) depth++;
    if (ch == closer) {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return -1;
}

/// Index just past a string literal starting at [start]; -1 when
/// unterminated. Handles raw, simple, and triple-quoted literals
/// (interpolation braces inside a string do NOT count for depth).
int _skipString(String source, int start) {
  final ch = source[start];
  // Triple-quoted literal?
  final triple = source.startsWith(ch * 3, start);
  final quote = triple ? ch * 3 : ch;
  var i = start + quote.length;
  // Raw string: r'...' / r"""...""".
  if (start > 0 && source[start - 1] == 'r') {
    // Raw strings carry no escapes; find the closing quote.
    final close = source.indexOf(quote, i);
    return close < 0 ? -1 : close + quote.length;
  }
  while (i < source.length) {
    if (source[i] == '\\') {
      i += 2;
      continue;
    }
    if (source.startsWith(quote, i)) return i + quote.length;
    if (!triple && source[i] == '\n') return -1; // unterminated
    i++;
  }
  return -1;
}

/// Index of [terminator] at nesting depth zero from [from], skipping
/// strings and nested `()`/`[]`/`{}`; -1 when not found.
int _findTerminator(String source, int from, String terminator) {
  var depth = 0;
  var i = from;
  while (i < source.length) {
    final ch = source[i];
    if (ch == '"' || ch == "'") {
      final end = _skipString(source, i);
      if (end < 0) return -1;
      i = end;
      continue;
    }
    if (ch == '(' || ch == '[' || ch == '{') depth++;
    if (ch == ')' || ch == ']' || ch == '}') depth--;
    if (depth == 0 && source.startsWith(terminator, i)) return i;
    i++;
  }
  return -1;
}
