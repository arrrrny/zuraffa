/// Skin plan author format contract (issue #1405): strict `^W\d+$` id
/// emission plus the plan-time id validator.
///
/// Real-world rebuild (zik_zak → zik_zak_v2) hit this on the login
/// feature: the SKIN lane's `## Lanes` declaration carried behavior
/// sentences the authoring LLM had split mid-fragment at commas, and the
/// skin plan author ingested the fragments verbatim as row ids —
///
/// ```text
/// | Sign In header and subtitle | skin behavior declared in ## Lanes | ...
/// | W1 (renders the login screen pixel-perfect | ... |
/// ```
///
/// Eight of nine skin behaviors were machine-unreachable (only the one
/// cleanly-parsed id, `W2`, ever got a generated test) and the skin lane
/// sat stuck at 0/1. The author's contract is now:
///
/// 1. **Strict W-id emission** — the id column carries only `^W\d+$`; a
///    declaration token that starts with the W-id followed by leaked
///    prose or an unmatched paren is sanitized (prose remainder moves to
///    the behavior column), so no row id is ever a sentence fragment and
///    never truncated mid-sentence.
/// 2. **Plan-time validation** — a token with no `W\d+` pattern at all is
///    not a W-behavior: the plan validator refuses it (the malformed
///    outer-loop table is never ingested), at plan time, before any
///    artifact is written — never at gen/run time.
/// 3. **Backward compatibility** — clean `W1..Wn` ids pass through
///    byte-identically; CORE/BOTH lanes and the derivation algorithm are
///    untouched.
///
/// Pure: no filesystem access, byte-identical output for identical input.
library;

/// The skin plan author's id emission + validation contract.
abstract final class SkinPlanAuthor {
  /// The only id shape the skin plan's W rows carry (`W1`, `W12`).
  static final RegExp strictWId = RegExp(r'^W\d+$');

  /// The leading W-id inside a prose-contaminated declaration token
  /// (`W1 (renders ...` → `W1`). Anchored at the start: a W mention
  /// mid-prose (`the W1 button`) is NOT an id — guessing ids out of
  /// mid-sentence prose would fabricate behavior identity, so such
  /// tokens are refused, never rescued.
  static final RegExp _leadingWId = RegExp(r'^W\d+');

  static final RegExp _anyWId = RegExp(r'W\d+');

  static final RegExp _whitespace = RegExp(r'\s');

  /// The sanitized (strict id, behavior-column prose) pair for one
  /// declared skin behavior token, or null when the token carries no
  /// W-behavior at all (the caller's validator refuses it — a null here
  /// must never be silently dropped).
  ///
  /// - `W2` → `(id: 'W2', prose: '')` (already strict — pass-through).
  /// - `W1 (renders the login screen pixel-perfect` →
  ///   `(id: 'W1', prose: 'renders the login screen pixel-perfect')`
  ///   (the issue's truncated mid-sentence token: the orphan paren is
  ///   stripped, the sentence fragment becomes the row's behavior text).
  /// - `W3 (binds each button)` → `(id: 'W3', prose: 'binds each button')`
  ///   (a true paren wrap is unwrapped).
  /// - `W5 (a) and (b)` → `(id: 'W5', prose: '(a) and (b)')` (balanced
  ///   interior parens are preserved verbatim).
  /// - `Sign In header and subtitle` / `the W1 button` / empty → null.
  static ({String id, String prose})? sanitizeDeclaredSkinToken(String token) {
    final t = token.trim();
    if (t.isEmpty) return null;
    if (strictWId.hasMatch(t)) return (id: t, prose: '');
    final match = _leadingWId.firstMatch(t);
    if (match == null) return null;
    return (
      id: match.group(0)!,
      prose: _cleanProseRemainder(t.substring(match.end)),
    );
  }

  /// The behavior-column text for the prose remainder after a leading
  /// W-id: trimmed, a true paren wrap unwrapped, orphan (unbalanced)
  /// parens at the ends stripped — balanced parens stay verbatim.
  static String _cleanProseRemainder(String raw) {
    var s = raw.trim();
    if (s.length >= 2 && s.startsWith('(') && s.endsWith(')')) {
      final interior = s.substring(1, s.length - 1);
      // Unwrap only a TRUE wrap: the interior's parens stay balanced and
      // never dip negative (so `(a) and (b)` is left alone).
      if (_netParens(interior) == 0 && _parenFloor(interior) >= 0) {
        s = interior.trim();
      }
    }
    while (s.startsWith('(') && _netParens(s) > 0) {
      s = s.substring(1).trim();
    }
    while (s.endsWith(')') && _netParens(s) < 0) {
      s = s.substring(0, s.length - 1).trim();
    }
    return s;
  }

  /// `(open` count minus `close)` count of [s].
  static int _netParens(String s) {
    var net = 0;
    for (var i = 0; i < s.length; i++) {
      if (s[i] == '(') {
        net++;
      } else if (s[i] == ')') {
        net--;
      }
    }
    return net;
  }

  /// The lowest running paren balance of [s] (negative means some prefix
  /// closes more parens than it opens).
  static int _parenFloor(String s) {
    var net = 0;
    var floor = 0;
    for (var i = 0; i < s.length; i++) {
      if (s[i] == '(') {
        net++;
      } else if (s[i] == ')') {
        net--;
        if (net < floor) floor = net;
      }
    }
    return floor;
  }

  /// Why [id] is not a strict W-id, or null when it matches `^W\d+$`.
  ///
  /// Diagnosis precedence (the first matching class is named — the most
  /// fundamental malformation wins):
  /// 1. no `W\d+` pattern anywhere — the token is not a W-behavior at all
  ///    (`Sign In header and subtitle`);
  /// 2. unmatched paren — the issue's truncated mid-sentence id
  ///    (`W1 (renders`, `W1)`);
  /// 3. whitespace — prose leaked into the id column (`W1 renders`);
  /// 4. otherwise — the id is simply not a strict W-id.
  static String? malformedIdReason(String id) {
    if (strictWId.hasMatch(id)) return null;
    if (!_anyWId.hasMatch(id)) {
      return 'carries no W<digits> pattern (prose, not a W-behavior id)';
    }
    if (_netParens(id) != 0) {
      return 'carries an unmatched paren (truncated mid-sentence)';
    }
    if (_whitespace.hasMatch(id)) {
      return 'carries spaces (prose leaked into the id column)';
    }
    return 'is not a strict W-id (^W\\d+\$)';
  }

  /// The plan validator (issue #1405): one refusal line per non-strict
  /// id, each naming the offending token, the malformation class, and the
  /// fix. An empty list means the id list is clean (`W1..Wn` pass
  /// unchanged). The refusals ride the plan-time lane gate — a non-empty
  /// result refuses the plan (exit 2) BEFORE any artifact is written, so
  /// the malformed outer-loop table is never ingested.
  static List<String> validateSkinPlanWIds(Iterable<String> ids) {
    final refusals = <String>[];
    for (final id in ids) {
      final reason = malformedIdReason(id);
      if (reason == null) continue;
      refusals.add(
        'skin plan validator: declared skin behavior "$id" $reason. '
        '--> fix: write clean W-ids (^W\\d+\$) in the SKIN lane\'s '
        '`behaviors:` list and move the prose into a parenthetical '
        'annotation (`W1 (renders the login screen)`).',
      );
    }
    return refusals;
  }
}
