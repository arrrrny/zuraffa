/// ScaffoldAttemptForecast — the #1689 pre-flight: predict what the
/// plan's func pass will scaffold, and refuse the make attempt when the
/// prediction provably cannot satisfy the paired test.
///
/// On a unit behavior whose generated test carries a scenario-derived
/// value assertion (post-#1679, `expect(result, equals(5))`), make's
/// func pass still scaffolds a #1517 zero-value dummy (`return 0;`-
/// class body), then runs the target test, watches it fail, restores
/// the certified-red stub, and stops `generation-error` — 30–40s of
/// provably wasted work: a zero-value scaffold can NEVER satisfy an
/// `equals(<scenario literal ≠ zero>)` assertion, and the func pass has
/// no path to a smarter body. The recovery the stop prescribes is the
/// hand step — which is where the flow was always going to end for this
/// behavior class. The forecast lets make stop there IMMEDIATELY (the
/// same honest stop, minus the doomed attempt).
///
/// The prediction is FAITHFUL to what func writes, by construction:
///
/// - the subject must be gen's provenance-marked stub whose declaration
///   matches [SubjectProvenance.funcRewritableStubPattern] — the exact
///   pattern func matches (the same groups: return type, function name,
///   params); a hand-authored file is never predicted over;
/// - the stub must be PARAMETRIZED — the #1679 scenario class is
///   parametrized by construction (the declared contract's params carry
///   the scenario's Given values), while the legacy NO-ARG stub takes
///   the description-derived body (`deriveSubjectSignature`), a
///   different scaffold this forecast must not speak for;
/// - the dummy literal mirrors `func_command._declaredStubBody`
///   verbatim (`int` → `0`, `double` → `0.0`, `bool` → `true`,
///   `String` → the function's own name); every other declared return
///   (`void`, `num`, nullable tokens, entities) keeps the still-red
///   `UnimplementedError` branch — NOT a zero value, not this gate's
///   class.
///
/// Self-removal (the issue's constraint 4): the forecast keys on the
/// scaffold being a zero-value LITERAL — when func grows real
/// generation for scalar declared returns, the predicted dummy stops
/// existing and the gate goes silent with no code change in the gate.
///
/// Pure functions over source text — no I/O, no analyzer.
library;

import 'subject_provenance.dart';

/// What the plan's func pass will scaffold, and the paired test's first
/// value assertion that scaffold provably cannot satisfy.
class ScaffoldAttemptForecast {
  const ScaffoldAttemptForecast({
    required this.returnType,
    required this.functionName,
    required this.dummyLiteral,
    required this.expectedLiteral,
  });

  /// The declared return type token the stub carries (`int`).
  final String returnType;

  /// The stub's function name — preserved verbatim by the func pass
  /// (the paired test calls `subject.<name>` and must keep compiling).
  final String functionName;

  /// The zero-value dummy the scaffold installs, as a Dart source
  /// literal (`0`, `0.0`, `true`, `'<name>'`).
  final String dummyLiteral;

  /// The first provably-unsatisfiable assertion literal found in the
  /// paired test, as a Dart source literal (`5`, `'Hello Alice'`).
  final String expectedLiteral;
}

/// The zero-value dummy literal the func pass scaffolds for a declared
/// return type — `func_command._declaredStubBody`'s exact vocabulary,
/// as a Dart source literal. Null when the scaffold for [returnType] is
/// NOT a literal dummy: `void`'s empty body and every still-red
/// `UnimplementedError` branch (`num`, nullable tokens, entities, and
/// anything else) is not a zero value and never predicts a refusal.
String? funcScaffoldDummyLiteral(String returnType, String functionName) {
  switch (returnType) {
    case 'int':
      return '0';
    case 'double':
      return '0.0';
    case 'bool':
      return 'true';
    case 'String':
      return "'$functionName'";
    default:
      return null;
  }
}

/// One `equals(<literal>)` argument in the paired test's assertion set.
/// Numbers and booleans verbatim, strings single-quoted — the writer's
/// own literal vocabulary (`behavior_test_writer._literalExpression`).
final RegExp _equalsLiteralArg = RegExp(
  r"equals\(\s*(-?\d+(?:\.\d+)?|true|false|'[^'\r\n]*')\s*\)",
);

/// The kinds an assertion literal can have, for the value-aware
/// comparison: two literals of DIFFERENT kinds are provably unequal in
/// Dart (`0 == '5'` is false), same-kind literals compare by value —
/// with Dart `num` equality across the int/double split (`0 == 0.0`
/// is true, so an `int` dummy DOES satisfy `equals(0.0)`).
enum _LiteralKind { number, boolean, string }

(_LiteralKind, Object)? _parseLiteral(String source) {
  if (source == 'true' || source == 'false') {
    return (_LiteralKind.boolean, source == 'true');
  }
  final number = num.tryParse(source);
  if (number != null) return (_LiteralKind.number, number);
  if (source.length >= 2 && source.startsWith("'") && source.endsWith("'")) {
    return (_LiteralKind.string, source.substring(1, source.length - 1));
  }
  return null;
}

/// Whether [a] and [b] are provably UNEQUAL as Dart values — the
/// comparison the fire/silent decision hangs on. Unparseable literals
/// never reach here (the caller skips them: never refuse on absence of
/// evidence).
bool _provablyUnequal(String a, String b) {
  final parsedA = _parseLiteral(a);
  final parsedB = _parseLiteral(b);
  if (parsedA == null || parsedB == null) return false;
  final (kindA, valueA) = parsedA;
  final (kindB, valueB) = parsedB;
  if (kindA != kindB) return true;
  return valueA != valueB;
}

/// The forecast behind make's #1689 fast stop — ONE predicate so make
/// and any later surface cannot disagree (the #1651 single-sourcing
/// precedent). Null — the gate stays SILENT, the attempt runs exactly
/// as before — unless EVERY condition holds:
///
/// 1. the subject is gen's provenance-marked stub matching
///    [SubjectProvenance.funcRewritableStubPattern] (func's own rewrite
///    shape — the same pattern, the same groups);
/// 2. the stub is parametrized (the scenario class) — the legacy no-arg
///    stub's description-derived body is a different scaffold;
/// 3. the declared return scaffolds a literal dummy (the #1517
///    vocabulary);
/// 4. the paired test carries a value assertion
///    (`equals(<literal>)`) whose literal is PROVABLY different from
///    the dummy — a differing kind, or a same-kind value that compares
///    unequal. An assertion the comparator cannot parse is never
///    treated as discriminating (fail-open: the attempt runs).
///
/// Constraint 3 of the issue falls out of condition 4: a non-scenaried
/// behavior's assertion set (the UnimplementedError guard, the
/// type-only + marker fallback) carries no `equals(<literal>)` value
/// assertion, so its attempts are never skipped — the vacuous-green
/// preflight and the placeholder refusal own those classes.
ScaffoldAttemptForecast? forecastMakeAttempt({
  required String subjectSource,
  required String testSource,
}) {
  if (!subjectSource.contains(kGenProvenanceMarker)) return null;
  final stub = SubjectProvenance.funcRewritableStubPattern.firstMatch(
    subjectSource,
  );
  if (stub == null) return null;
  final params = (stub.group(3) ?? '').trim();
  if (params.isEmpty) return null; // the legacy no-arg class
  final returnType = stub.group(1)!;
  final functionName = stub.group(2)!;
  final dummy = funcScaffoldDummyLiteral(returnType, functionName);
  if (dummy == null) return null;
  for (final match in _equalsLiteralArg.allMatches(testSource)) {
    final expected = match.group(1)!;
    if (_provablyUnequal(expected, dummy)) {
      return ScaffoldAttemptForecast(
        returnType: returnType,
        functionName: functionName,
        dummyLiteral: dummy,
        expectedLiteral: expected,
      );
    }
  }
  return null;
}

/// The single-sourced `--> fix:` remedy for the would-never-pass stop —
/// make's fast stop prints the SAME line any later surface would (the
/// #1483/#1626 single-sourcing precedent). Names BOTH artifact paths
/// project-relative so the author knows exactly what to implement and
/// which test proves it, and prescribes the hand step the doomed
/// attempt's own stop always ended at: implement the subject, re-run
/// make — the re-run's drift check certifies the implemented subject.
String wouldNeverPassRemedy({
  required String behaviorId,
  required String subjectPath,
  required String testPath,
}) =>
    'hand-implement the subject at $subjectPath — the func pass has no '
    'smarter body for this behavior class (its #1517 scaffold is the '
    "declared type's zero value, and the paired test $testPath asserts "
    "the scenario's concrete outcome) — then re-run `zfa tdd make "
    '$behaviorId`; the re-run\'s drift check certifies the implemented '
    'subject (issue #1689).';
