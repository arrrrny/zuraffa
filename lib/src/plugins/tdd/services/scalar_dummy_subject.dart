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
/// Two documented boundaries calibrate the class:
///
/// - The literal set (`0`, `0.0`, `true`, `false`, a quoted string) is
///   exactly the writers' dummy vocabulary — the GENERATED surface the
///   gate certifies. Hand-written placeholder literals outside that
///   vocabulary (`return 1;`, `return -1;`, `return 42;`,
///   `return '';`) pass undetected; widening the set is a follow-up if
///   the goal becomes the whole placeholder family.
/// - A legitimately constant PARAMETRIZED function
///   (`int clampLevel(int level) => 0;`) IS matched and is refused — the
///   deliberate complement of the parameterless exemption below: a
///   per-input contract whose body ignores its inputs is exactly the
///   vacuity the gate exists for.
///
/// A parameterless constant (`int zero() => 0;`) is NOT the class: a
/// no-input contract fully implemented by a constant is a legitimate
/// implementation (and the #1259 suite's own pins depend on the
/// distinction). Pure functions over source text — no I/O.
library;

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
/// Refusal = scalar dummy body ∧ type-only assertion set. The verdict
/// is master's #1667 policy (step-3c's type-only strip refuses the same
/// pairs) with the pair probe of #1679: a `return 0;` body satisfies
/// any `isA<T>()` check, so a green over it proves nothing. The class is
/// refused whether or not the test carries the [vacuousGuardMarker] —
/// the marker is the machine-readable seam the author removes with the
/// value assertion, and a legacy marker-less type-only test is the same
/// vacuous shape. Gen derives the discriminating `equals(...)`
/// assertion whenever the spec's scenario names a derivable value, so a
/// type-only test over such a spec is the stale/under-derived theater
/// the gate refuses; when the spec carries no derivable example, the
/// author writes the outcome-VALUE assertion by hand (the refusal names
/// the marker and both artifact paths). The pair's declared routing and
/// the spec's scenarios do NOT exempt it (the pre-merge #1310-floor
/// exemption certified dummy greens master's #1667 flipped to
/// refusals).
bool scalarDummyGreenMustRefuse({
  required String subjectSource,
  required String testSource,
}) =>
    contentCarriesScalarDummyBody(subjectSource) &&
    contentIsTypeOnlyAssertion(testSource);

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
