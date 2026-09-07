/// Vacuous-green detection for the UNIT lane (issue #1259).
///
/// Bug #1259: the engine lane certified vacuous greens — a unit test
/// whose only assertion was the UnimplementedError guard
/// (`expect(result, isNot(isA<UnimplementedError>()))`) passed on any
/// non-throwing body (a func-scaffolded dummy `return 0;`), and `make`
/// certified green with zero declared-contract code anywhere in the
/// project.
///
/// Remediation (issue #1259): green certification refuses unit tests
/// whose assertion set is only the UnimplementedError guard — the
/// unit-lane analogue of the widget lane's scaffolded refusal
/// (`contentIsScaffolded`, issue #912 defect 3). The red surface can
/// START at the guard (the stub throws, the capture returns the error,
/// the guard fails — honest red), but green must require at least one
/// assertion on the observable outcome named by the behavior
/// description.
library;

/// The machine-readable marker the gen test template emits when its
/// assertion set is the UnimplementedError guard only — the unit-lane
/// counterpart of the widget lane's `zfa:tdd: scaffolded` marker.
/// Greppable by the green certification and by human review.
const String vacuousGuardMarker = 'zfa:tdd: vacuous-guard';

/// The comment block the unit test template emits alongside
/// [vacuousGuardMarker], naming the exact remedy.
const String vacuousGuardComment =
    '''// $vacuousGuardMarker (issue #1259): the assertion set below is the
      // UnimplementedError guard ONLY — a green here proves nothing about
      // the behavior (a dummy `return 0;` flips it green with zero
      // declared-contract code). Replace this guard with an assertion on
      // the observable outcome named by the behavior description, remove
      // this marker, and re-run make.''';

/// The guard-shaped expects the detector strips before counting: the
/// capture-guard the gen template emits (`expect(result,
/// isNot(isA<UnimplementedError>()))`) and the throwsA variant the
/// acceptance fixtures use (`expect(x,
/// isNot(throwsA(isA<UnimplementedError>())))`). Both prove only "the
/// subject does not throw UnimplementedError" — the issue's vacuity
/// class.
final RegExp _guardExpect = RegExp(
  r'expect\s*\(\s*[A-Za-z_][A-Za-z0-9_]*\s*,\s*'
  r'isNot\s*\(\s*(?:throwsA\s*\(\s*)?isA\s*<\s*UnimplementedError\s*>'
  r'\s*\(\s*\)\s*\)\s*\)\s*;?',
);

/// Every remaining expectation counts: `expect(`, `expectLater(`,
/// `expectAsync0..6`, the `fail(...)` assertion, and the flutter-test
/// `finds*` wrappers all route through an `expect`-prefixed call in the
/// generated/hand-authored corpus.
final RegExp _anyExpect = RegExp(
  r'\bexpect(?:Later|Async[0-6]?)?\s*\(|\bfail\s*\(',
);

/// Whether [content] is a vacuous-green UNIT test (issue #1259): the
/// assertion set is only the UnimplementedError guard (or empty).
///
/// Two detection layers, mirroring the widget lane's `contentIsScaffolded`:
///   1. the machine-readable [vacuousGuardMarker] the gen template emits
///      with the guard-only assertion set — decisive (a stale marker
///      alongside a since-added real assertion still refuses: the remedy
///      is removing the marker, exactly like the scaffolded lane);
///   2. content-based backstop for hand-authored and legacy-generated
///      tests: strip the guard-shaped expects; zero remaining
///      expectations is a vacuous assertion set.
bool contentIsVacuousGreen(String content) {
  if (content.contains(vacuousGuardMarker)) return true;
  final withoutGuards = content.replaceAll(_guardExpect, '');
  return !_anyExpect.hasMatch(withoutGuards);
}
