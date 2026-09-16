/// ScenarioExample — the concrete example values an acceptance scenario
/// carries (issue #1651).
///
/// The spec's acceptance scenarios (`**Given** the integers 2 and 3,
/// **When** `Calculator.add` is called, **Then** the sum 5 is returned`)
/// are the ONLY place the spec names concrete example values. The
/// acceptance lane consumes them as prose; the UNIT lane ignored them
/// and invented scaffold representative arguments `(0, 0)` + a type-only
/// `isA<int>()` assertion — the vacuity that let a func-scaffolded
/// `return 0;` dummy certify a terminal green (#1259's class, reopened
/// by #1651).
///
/// This model carries the parsed segments + the concrete literals so the
/// unit test generator can derive example-based assertions: call the
/// subject with the scenario's arguments, assert the scenario's outcome.
/// Pure data + pure parsing helpers — no I/O.
library;

/// The kind of one concrete scenario value — the discriminator the
/// writer uses to map values onto declared parameter types.
enum ScenarioValueKind { number, string, boolean }

/// One concrete value parsed from a scenario clause.
class ScenarioValue {
  const ScenarioValue({required this.kind, required this.literal});

  /// The value class (`2` → number, `'Alice'` → string, `true` →
  /// boolean).
  final ScenarioValueKind kind;

  /// The literal verbatim, ready for typed emission: numbers keep their
  /// sign and decimal form (`-4`, `2.0`); strings keep their (unquoted)
  /// content; booleans are `true`/`false`.
  final String literal;

  /// Whether this value can flow into a declared parameter of type
  /// [type] (the renderable scalar surface: int, double, num, String,
  /// bool). Object/entity params never consume scenario values.
  bool fitsType(String type) {
    switch (type) {
      case 'int':
        return kind == ScenarioValueKind.number &&
            !literal.contains('.') &&
            !literal.toLowerCase().contains('e');
      case 'double':
      case 'num':
        return kind == ScenarioValueKind.number;
      case 'String':
        return kind == ScenarioValueKind.string;
      case 'bool':
        return kind == ScenarioValueKind.boolean;
    }
    return false;
  }
}

/// One acceptance scenario's structured example: the Given/When/Then
/// segments plus the concrete values each carries.
class ScenarioExample {
  const ScenarioExample({
    required this.id,
    required this.given,
    required this.when,
    required this.then,
    required this.givenValues,
    required this.thenValues,
  });

  /// The document-wide acceptance id (`A1`, aligned with the behavior
  /// walk's AC numbering).
  final String id;

  /// The Given clause text (after the marker, verbatim minus bold).
  final String given;

  /// The When clause text (after the marker, verbatim minus bold).
  final String when;

  /// The Then clause text (after the marker, verbatim minus bold).
  final String then;

  /// The concrete values the Given clause carries, in order of
  /// appearance — the scenario's INPUT examples.
  final List<ScenarioValue> givenValues;

  /// The concrete values the Then clause carries, in order of
  /// appearance — the scenario's OUTCOME examples.
  final List<ScenarioValue> thenValues;

  /// Whether this scenario names [target] — the declared method name
  /// (`add`) matching the scenario's qualified call (`Calculator.add`).
  /// The When clause is checked first (the call site), then the whole
  /// scenario text.
  bool mentionsTarget(String target) {
    final pattern = RegExp('\\b${RegExp.escape(target)}\\b');
    if (pattern.hasMatch(when)) return true;
    return pattern.hasMatch('$given $when $then');
  }
}

/// Resolves the scenario example a declared unit contract consumes.
class ScenarioResolver {
  const ScenarioResolver._();

  /// The FIRST scenario whose prose names [target] — the declared
  /// contract method (`add` matches the scenario's `Calculator.add`).
  /// Null when no scenario names it (the legacy declared shape stands).
  /// First-match: multiple scenarios naming the same method resolve to
  /// the spec's first — deterministic and documented.
  static ScenarioExample? firstForTarget(
    List<ScenarioExample> examples, {
    required String target,
  }) {
    if (target.isEmpty) return null;
    for (final example in examples) {
      if (example.mentionsTarget(target)) return example;
    }
    return null;
  }

  /// Picks the scenario value that fills ONE declared parameter slot of
  /// type [type], consuming from [remaining] (values are removed as
  /// they are claimed so two `int` params take the first two numbers in
  /// order). Null when no unconsumed value fits — the caller keeps the
  /// compileable representative literal for that slot.
  static ScenarioValue? claimArgumentForType(
    String type,
    List<ScenarioValue> remaining,
  ) {
    for (var i = 0; i < remaining.length; i++) {
      if (remaining[i].fitsType(type)) {
        return remaining.removeAt(i);
      }
    }
    return null;
  }

  /// Picks the scenario value matching the declared RETURN type
  /// [type] from [values] without consuming (the outcome is asserted
  /// once). Null when nothing fits — the caller keeps the typed
  /// `isA<T>()` fallback.
  static ScenarioValue? expectedForType(
    String type,
    List<ScenarioValue> values,
  ) {
    for (final value in values) {
      if (value.fitsType(type)) return value;
    }
    return null;
  }
}
