/// ScalarDummySubject — the placeholder-body detector + shared remedy
/// (issue #1651).
///
/// The func pass (#1517) scaffolds scalar declared returns to literal
/// dummy bodies (`int add(int a, int b) { return 0; }`), and `tdd wire`
/// defaults to the same literal forms (#1500). A test whose assertion
/// set is TYPE-ONLY (`expect(result, isA<int>())` — the post-#1259
/// generated shape) passes on such a body, and the engine certified a
/// terminal `result=complete` on subjects that implement nothing
/// (#1259's class, reopened).
///
/// The detector recognizes the literal-constant class over a
/// PARAMETRIZED scalar signature — the exact shape the issue reports.
/// A parameterless constant (`int zero() => 0;`) is NOT the class: a
/// no-input contract fully implemented by a constant is a legitimate
/// implementation (and the #1259 suite's own pins depend on the
/// distinction). Pure functions over source text — no I/O.
library;

import 'scenario_example.dart';
import 'vacuous_guard.dart';

/// The scalar dummy forms the func pass and wire defaults emit, anchored
/// on a parametrized scalar signature so real per-input implementations
/// (`a + b`) never match:
///
/// - block body: `int f(int a) { return 0; }` (the func scaffold shape);
/// - arrow body: `double f(int a) => 0.0;` (the compact hand form).
///
/// The literal set is exactly the writers' dummy vocabulary: `0` (int/
/// num), `0.0` (double), `true`/`false` (bool), and a quoted string.
final RegExp _scalarDummyFunction = RegExp(
  r"\b(?:int|double|num|bool|String)\s+[A-Za-z_][A-Za-z0-9_]*\s*\(\s*[^)]+?\)\s*"
  r"(?:=>\s*(?:0|0\.0|true|false|'[^']*')\s*;"
  r"|\{\s*return\s+(?:0|0\.0|true|false|'[^']*')\s*;\s*\})",
);

/// Whether [subjectSource] carries a parametrized scalar function whose
/// body is a literal constant — the placeholder class `make` refuses to
/// certify green over (issue #1651). Unreadable/partial content simply
/// does not match: the detector never refuses on absence of evidence.
bool contentCarriesScalarDummyBody(String subjectSource) =>
    _scalarDummyFunction.hasMatch(subjectSource);

/// The gate decision behind make's placeholder refusal AND the run
/// driver's placeholder stop (issue #1651) — ONE predicate so the two
/// surfaces never disagree about a pair.
///
/// Refusal = scalar dummy body ∧ type-only assertion set ∧ NOT the
/// #1310 floor. The floor is the reconciliation with the #1310
/// dead-end removal (plan_traces_cell_1310 U6): a DECLARED-ROUTED pair
/// whose spec scenario carries NO derivable value for the declared
/// return asserts the declared outcome TYPE — the best derivable
/// surface — and that class must keep certifying over a dummy
/// `=> false;` body. When the spec's scenario DOES name a derivable
/// outcome (the #1651 repro: `Given 2 and 3 ... Then the sum 5`),
/// remediation 1 derives the discriminating `equals(...)` assertion at
/// gen time — a type-only test over that spec is the stale or
/// under-derived theater the gate refuses. Not declared-routed at all
/// (criterion-only traces, no spec) is the scaffold class — refuse.
///
/// [scenarios] are the feature spec's parsed acceptance scenarios
/// (empty when the spec is absent or unreadable — fail-open, the floor
/// stands: the gate refuses only on positive evidence).
bool scalarDummyGreenMustRefuse({
  required String subjectSource,
  required String testSource,
  required ({String method, String returnType})? declared,
  required List<ScenarioExample> scenarios,
}) {
  if (!contentCarriesScalarDummyBody(subjectSource)) return false;
  if (!contentIsTypeOnlyAssertion(testSource)) return false;
  final method = declared?.method;
  final returnType = declared?.returnType;
  if (method == null || returnType == null) return true;
  final scenario = ScenarioResolver.firstForTarget(scenarios, target: method);
  if (scenario == null) return false;
  return ScenarioResolver.expectedForType(returnType, scenario.thenValues) !=
      null;
}

/// The single-sourced `--> fix:` remedy for the placeholder-green stop —
/// make's refusal and the run driver's stop arm print the SAME line so
/// the loop's advice cannot drift (the #1483/#1626 single-sourcing
/// precedent). Names BOTH artifact paths project-relative so the author
/// knows exactly what to replace and which test proves it.
String scalarDummyGreenRemedy({
  required String behaviorId,
  required String testPath,
  required String subjectPath,
}) =>
    'replace the placeholder body in $subjectPath with the real '
    'implementation — the paired test $testPath must discriminate the '
    'scenario\'s concrete outcome (a `return 0;` dummy passes a type-only '
    'assertion, issue #1651) — then re-run `zfa tdd make $behaviorId`.';
