/// The subject-shape predicate for the #1162 drift-guard fail-open.
///
/// Issue #1036's skip guard refuses an already-green skip whenever the
/// subject file's sha256 no longer matches the certified evidence — the
/// born-green placeholder class (a make rewrote the subject to a vacuous
/// scaffold whose test passes without exercising the scenario). Issue
/// #1162 exposed the other side of that rule: a HAND-IMPLEMENTED subject
/// (exactly what the generated test header instructs: "Replace the
/// subject's stub body with real implementation") also drifts from the
/// certified red hash, and the refusal dead-ends the loop — its two
/// remedies (git checkout, verify-red) cannot close a bug feature.
///
/// The discriminator is CONTENT: the born-green class is the pipeline's
/// OWN placeholder shapes, which are known and enumerable —
///
///   1. the scaffolded marker (`zfa:tdd: scaffolded`, the widget-test
///      template's placeholder finders);
///   2. a subject that still throws `UnimplementedError` (a stub whose
///      paired test passes is vacuous by definition);
///   3. the func-scaffold rewrite class: a subject whose function bodies
///      are ALL vacuous scaffolds — `return '<functionName>';`,
///      `return 0;`, `return 0.0;`, `return true;`, `return;`, an empty
///      body, or the arrow-literal equivalents (`=> 0;` et al).
///
/// Everything else is a hand implementation: the scenario assertions the
/// certified red exercised genuinely execute against it, so the guard
/// may fail open (issue #1162). A subject with a real body plus a small
/// vacuous helper is NOT a placeholder (only ALL parsed bodies vacuous
/// classify); a compose-shaped body (the anchor list) is NOT a placeholder
/// (compose is the sanctioned pipeline); an unparseable subject is NOT a
/// placeholder (the predicate never guesses).
library;

import 'widget_scaffold.dart' show scaffoldedMarker;

/// An actual `throw UnimplementedError(...)` statement in executable code.
final RegExp _unimplementedThrow = RegExp(
  r'throw[ \t]+(?:const[ \t]+)?UnimplementedError\s*\(',
);

/// One function declaration the body parser understands:
/// `<returnType> <name>() => <expr>;` or `<returnType> <name>() {`.
final RegExp _functionDecl = RegExp(
  r'^[ \t]*(?:[A-Za-z_][A-Za-z0-9_<>, ?\n]*?[ \t]+)?'
  r'([A-Za-z_][A-Za-z0-9_]*)[ \t]*\([ \t]*\)[ \t]*'
  r'(?:=>[ \t]*([^;\n]+);[ \t]*$|\{)[ \t]*$',
  multiLine: true,
);

/// Whether [raw] — a subject artifact's content — is one of the pipeline's
/// born-green placeholder shapes. See the library doc for the class list.
bool subjectIsBornGreenPlaceholder(String raw) {
  // 1. The widget-test scaffold's placeholder marker.
  if (raw.contains(scaffoldedMarker)) return true;

  // 2. A subject that still throws: a stub whose paired test passes is
  //    the born-green class proper.
  if (_unimplementedThrow.hasMatch(raw)) return true;

  // 3. The func-scaffold rewrite class: every parsed function body is one
  //    of the vacuous scaffold bodies. Requires at least one parsed body —
  //    an unparseable subject never classifies (the predicate never
  //    guesses at shapes it does not recognize).
  final matches = _functionDecl.allMatches(raw).toList();
  if (matches.isEmpty) return false;
  var parsedAny = false;
  for (final m in matches) {
    final name = m.group(1)!;
    final arrowBody = m.group(2);
    if (arrowBody != null) {
      parsedAny = true;
      if (!_arrowBodyIsVacuous(arrowBody.trim(), name)) return false;
      continue;
    }
    final body = _blockBodyAfter(raw, m.end);
    if (body == null) return false; // unparseable block — never guesses
    parsedAny = true;
    if (!_blockStatementsAreVacuous(body, name)) return false;
  }
  return parsedAny;
}

/// The arrow-body vacuous set: literal constants and the function's own
/// name (the func scaffold's `return '<name>';` shape).
bool _arrowBodyIsVacuous(String expr, String functionName) {
  final e = expr.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (e == '0' || e == '0.0' || e == 'true' || e == 'false' || e == "''") {
    return true;
  }
  return e == "'$functionName'";
}

/// The block body starting right after a `{` declaration match, up to the
/// balancing `}`. Null when the braces never balance (unparseable).
String? _blockBodyAfter(String raw, int start) {
  final open = raw.indexOf('{', start - 1);
  if (open < 0) return null;
  var depth = 0;
  for (var i = open; i < raw.length; i++) {
    final c = raw[i];
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return raw.substring(open + 1, i);
    }
  }
  return null;
}

/// Whether every statement in a block body is one of the vacuous scaffold
/// statements (comments and blank lines ignored). An empty body is
/// vacuous (the void scaffold); a SECOND statement (e.g. compose's anchor
/// list) makes the body non-vacuous — compose is the sanctioned pipeline.
bool _blockStatementsAreVacuous(String body, String functionName) {
  final stripped = _stripComments(body);
  final statements = stripped
      .split(';')
      .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (statements.isEmpty) return true; // the empty void scaffold
  if (statements.length != 1) return false;
  final s = statements.single;
  const literals = ['0', '0.0', 'true', 'false', "''"];
  for (final lit in literals) {
    if (s == 'return $lit') return true;
  }
  if (s == 'return') return true; // bare `return;`
  return s == "return '$functionName'";
}

/// Strip `//` line comments and `/* */` block comments from [raw].
String _stripComments(String raw) {
  final withoutBlock = raw.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return withoutBlock
      .split('\n')
      .map((line) {
        final idx = line.indexOf('//');
        return idx >= 0 ? line.substring(0, idx) : line;
      })
      .join('\n');
}
