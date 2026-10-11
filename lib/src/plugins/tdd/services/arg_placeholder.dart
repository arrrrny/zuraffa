/// `_argN()` placeholder detection — the non-scalar-param hand-delta
/// seam surfaced (issue #1323, spec 991).
///
/// Issue #1323: a declared Layer Contract param the behavior test writer
/// cannot scalar-literalize emits an `_argN()` placeholder helper whose
/// body throws `UnimplementedError('provide a representative argument for
/// <target> (declared param N: <type>)')`. The red is honest, but when
/// make's generation plan leaves the target test still failing, make
/// dead-ended in the generic `generation-error` — the stop output never
/// named the remedy, and the remedy (hand-editing the generated test)
/// only existed inside a thrown exception message mid-test-output.
///
/// Remediation (spec 991): make detects the placeholder as the failure
/// cause and stops `hand-delta-required` naming the EXACT edit. The
/// detection is TWO-SIGNAL (FR-001):
///   (a) the generated test file carries the named marker helper —
///       a GENERATED, deterministic marker;
///   (b) the failing transcript carries the placeholder's message token.
/// Both must agree before the hand-delta diagnosis is reported, so a
/// still-failing red with an unrelated cause keeps the honest generic
/// `generation-error`.
///
/// The lesson the red classifier paid for holds here too: the grammar
/// lives in ONE place, never scattered across call sites.
library;

/// The message token every generated `_argN()` placeholder helper throws
/// with — the transcript signal (b) of the two-signal detection, and the
/// substring the writer's helper bodies are guaranteed to carry.
const String argPlaceholderMessageToken =
    'provide a representative argument for';

/// The helper-marker grammar (signal a): the writer's
/// `_captureInvocation` emits, inside the test closure,
/// `<Type> _arg<N>() => throw UnimplementedError('provide a
/// representative argument for <target> (declared param <N>: <type>)');`
/// — captured groups: N, target, declared index, declared type.
// NOTE: a NON-raw string — the token interpolates into the pattern (the
// analyzer's prefer_interpolation_to_compose_strings also wants that);
// every regex backslash is therefore doubled.
final RegExp _argHelperMarker = RegExp(
  '^\\s*[\\w<>?, ]*\\s?_arg(\\d+)\\(\\)\\s*=>\\s*throw\\s+'
  "UnimplementedError\\('\\s*"
  '$argPlaceholderMessageToken '
  '(.+?) \\(declared param (\\d+): (.+?)\\)',
  multiLine: true,
);

/// One detected `_argN()` placeholder: the helper's index (the `_argN`
/// numbering), the target the message names, and the DECLARED type the
/// remedy must name (`Object` for the issue's repro).
class ArgPlaceholderHit {
  const ArgPlaceholderHit({
    required this.index,
    required this.target,
    required this.declaredType,
  });

  /// The placeholder's index — `_arg0()` is index 0.
  final int index;

  /// The target the helper's message names (`subject_u6`).
  final String target;

  /// The declared parameter type (`Object`, `AuthRequest`, ...).
  final String declaredType;

  @override
  String toString() =>
      'ArgPlaceholderHit(_arg$index(), target: $target, '
      'declared: $declaredType)';
}

/// Parse the FIRST (lowest-index) placeholder helper from [testContent]
/// — the content-only probe the run driver uses (it has no failing
/// transcript; the make child already asserted signal (b) before
/// reporting the outcome).
ArgPlaceholderHit? argPlaceholderHitInContent(String testContent) {
  final matches = _argHelperMarker.allMatches(testContent).toList();
  if (matches.isEmpty) return null;
  matches.sort(
    (a, b) => int.parse(a.group(1)!).compareTo(int.parse(b.group(1)!)),
  );
  final m = matches.first;
  return ArgPlaceholderHit(
    index: int.parse(m.group(1)!),
    target: m.group(2)!,
    declaredType: m.group(4)!,
  );
}

/// The two-signal diagnosis (spec 991 FR-001): the placeholder is the
/// failure cause only when the test file carries the helper marker AND
/// the failing transcript names it. Null means "not the placeholder" —
/// the caller keeps its generic stop.
ArgPlaceholderHit? argPlaceholderHitOf({
  required String testContent,
  required String runOutput,
}) {
  if (!runOutput.contains(argPlaceholderMessageToken)) return null;
  return argPlaceholderHitInContent(testContent);
}

/// make's exact-edit remedy (spec 991 FR-002 / AC-1): the placeholder,
/// the test path, the declared type, and the re-run command —
/// "replace _arg0() in test/tdd/<feature>/u6_test.dart with a
/// representative Object — then re-run zfa tdd make U6".
String argPlaceholderRemedy({
  required int index,
  required String testPath,
  required String declaredType,
  required String behaviorId,
}) =>
    'replace _arg$index() in $testPath with a representative '
    '$declaredType — then re-run zfa tdd make $behaviorId';

/// The #1308-parity named hand step for the run driver's stop output and
/// the lane journal: the hand-step token, what to write (the exact edit)
/// and where (the generated test file), then the re-run make command.
/// [index] is the DETECTED placeholder's index — the writer numbers
/// `_argN()` by param position, so the first placeholder of a contract
/// with scalar params before the non-scalar one is NOT `_arg0()`.
String argPlaceholderHandStepViolation({
  required int index,
  required String behaviorId,
  required String testPath,
  required String declaredType,
}) =>
    'hand-step=$behaviorId:hand — '
    '${argPlaceholderRemedy(index: index, testPath: testPath, declaredType: declaredType, behaviorId: behaviorId)} (issue #1323)';
