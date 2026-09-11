/// Born-green hand transition detection (issue #1411).
///
/// Bug #1411: the designed hand-step flow (guide §5a item 1, issues
/// #1259/#1308) prescribes "replace the vacuous-guard test with real
/// assertions, hand-implement the subject, re-run `zfa tdd run`". When
/// the hand step is completed BEFORE the pipeline's first pass, no red
/// evidence exists in cycle-log.md: verify-red grades the already-
/// passing test unexpected-green (no evidence) and make refuses
/// not-certified-red — a catch-22 with no supported ordering for
/// "hand-implemented before first red certification".
///
/// Remediation (issue #1411): make's `--born-green` transition — the
/// no-prior-red analogue of verify-red's `--re-certify` (issue #1162).
/// The transition certifies green ONLY from the DESIGNED hand step's
/// honest end state, attested by the machine-greppable
/// `U<n>:hand` header: a `//` comment line the hand author adds when
/// completing the step (the run driver's hand-off message and make's
/// refusal name the exact line). The token is the unit-lane sibling of
/// the `zfa:tdd: scaffolded` (issue #912 defect 3) and
/// `zfa:tdd: vacuous-guard` (issue #1259) markers, so the green
/// certification, the run driver, and human review key on the same
/// greppable surface.
library;

/// The token prefix every TDD machine marker shares (`zfa:tdd:`) — the
/// attestation header is `zfa:tdd: <behaviorId>:hand`.
const String bornGreenHandTokenPrefix = 'zfa:tdd:';

/// The exact attestation header line the hand author adds to the test
/// when completing the designed hand step (issue #1411). Rendered
/// verbatim by the run driver's hand-off message and make's refusal so
/// the copy step is mechanical.
String handStepHeader(String behaviorId) =>
    '// $bornGreenHandTokenPrefix $behaviorId:hand — hand step completed '
    'before first red certification (issue #1411)';

/// Whether [content] carries the [behaviorId] attestation header (issue
/// #1411). Content-keyed like [contentCarriesVacuousGuardMarker] — the
/// probe runs on the CURRENT test bytes, so a header for a DIFFERENT
/// behavior never satisfies this one, and the `:hand` suffix pins the
/// match to the exact id (`U4:hand` does not match a `U40:hand`
/// header). Case-insensitive on the token for hand-authored tolerance.
bool contentCarriesHandStepHeader(String content, String behaviorId) {
  if (behaviorId.isEmpty) return false;
  final pattern = RegExp(
    '${RegExp.escape(bornGreenHandTokenPrefix)}\\s*'
    '${RegExp.escape(behaviorId)}:hand',
    caseSensitive: false,
  );
  return pattern.hasMatch(content);
}
