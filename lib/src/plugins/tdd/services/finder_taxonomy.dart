/// Finder-kind taxonomy for the widget lane (issue #964, TDD-137).
///
/// The pre-#964 pipeline treated every quoted scenario literal as display
/// text and discarded the scenario verb: a scenario asserting *"the app
/// navigates to the route `deal_list`"* was certified green by
/// `expect(find.text('deal_list'), findsOneWidget)` — a static `Column`
/// of `Text` widgets satisfied it while navigating nowhere. A certified
/// lie in the traceability matrix.
///
/// The taxonomy restores the two dimensions the flattening erased:
///
/// 1. **Verb → assertion class.** The scenario verb carries the
///    assertion semantics: shows/renders/displays → presence;
///    navigates → route outcome; disables/enables → enabled-state;
///    hides/not shown → absence; while/in-flight → sequence (an
///    intermediate + final state machine the single-pump template
///    cannot honestly assert — it is marked scaffolded, never silently
///    flattened to presence).
/// 2. **Literal → kind.** A quoted literal names a UI surface of a
///    particular kind: display text, a route name, an i18n key, a
///    semantics label. Route literals are asserted through a recording
///    `NavigatorObserver` (`pushedNames`), never as on-screen text.
///
/// Every emitted assertion is honest-red-capable: it fails through an
/// assertion (never a finder throw) when the scenario's outcome does
/// not happen, and passes only on the real outcome.
library;

/// The assertion semantics a scenario verb demands (issue #964).
enum ScenarioAssertionClass {
  /// The literal must be present on screen (`find.text` + findsOneWidget).
  presence('presence'),

  /// The literal must NOT be present (`find.text` + findsNothing).
  absence('absence'),

  /// The scenario asserts a navigation outcome: a route with the
  /// literal's name must be pushed (observed through a recording
  /// `NavigatorObserver`), never merely rendered as text.
  routeOutcome('route-outcome'),

  /// The scenario asserts a widget's enabled state (`onPressed`
  /// null-ness on the labeled control).
  enabledState('enabled-state'),

  /// The scenario describes a state machine (while in flight … then …).
  /// The single-pump widget template cannot honestly assert a sequence;
  /// such scenarios are marked scaffolded instead of silently
  /// flattened to presence (issue #964: presence assertions cannot see
  /// sequences).
  sequence('sequence');

  /// The kebab-case label used in the machine-readable
  /// `// scenario-assertions:` header of a generated test.
  final String label;

  const ScenarioAssertionClass(this.label);
}

/// The kind of UI surface a quoted literal names (issue #964). `key`
/// (i18n keys resolved through the i18n shell) and `label` (semantics
/// labels) are reserved for their contract issues; the generator
/// currently classifies text vs route.
enum LiteralKind { text, route, key, label }

/// One derived scenario assertion: a quoted literal, the assertion class
/// its verb context demands, and the literal's kind.
class ScenarioAssertion {
  const ScenarioAssertion({
    required this.assertionClass,
    required this.literal,
    this.kind = LiteralKind.text,
    this.disabled = false,
  });

  final ScenarioAssertionClass assertionClass;
  final String literal;
  final LiteralKind kind;

  /// For [ScenarioAssertionClass.enabledState]: true when the scenario
  /// asserts the control is DISABLED, false when enabled.
  final bool disabled;

  @override
  String toString() =>
      'ScenarioAssertion(${assertionClass.label}, "$literal", '
      'kind: ${kind.name}${disabled ? ', disabled' : ''})';
}

/// The taxonomy's full read of a scenario description: every derived
/// assertion plus whether the scenario carries a sequence clause.
class ScenarioAnalysis {
  const ScenarioAnalysis({
    required this.description,
    required this.assertions,
    this.sequence = false,
  });

  final String description;
  final List<ScenarioAssertion> assertions;

  /// True when the scenario describes an in-flight state machine
  /// (`while … in flight`, `while loading`, …).
  final bool sequence;

  /// Whether the emitted test needs a recording `NavigatorObserver`
  /// installed on the pump (at least one route-outcome assertion).
  bool get needsRouteObserver => assertions.any(
    (a) => a.assertionClass == ScenarioAssertionClass.routeOutcome,
  );

  /// The distinct assertion classes the scenario requires.
  Set<ScenarioAssertionClass> get requiredClasses =>
      assertions.map((a) => a.assertionClass).toSet();

  @override
  String toString() =>
      'ScenarioAnalysis(${assertions.length} assertions, '
      'sequence: $sequence)';
}

/// The scenario → assertion classifier and test-assertion emitter.
abstract final class FinderTaxonomy {
  /// A quoted literal: `'…'` or `"…"`.
  static final RegExp quoted = RegExp("'([^']+)'|\"([^\"]+)\"");

  /// Navigation verbs — active and passive conjugations (bug #936
  /// grammar: Then-clauses are passive by convention).
  static final RegExp _routeVerb = RegExp(
    r'\bnavigat(?:e|es|ed|ing|ion)\b',
    caseSensitive: false,
  );

  /// Absence verbs/phrases: hides, hidden, not/never shown, rendered,
  /// displayed, visible; absent; no longer visible.
  static final RegExp _absenceVerb = RegExp(
    r'\bhid(?:e|es|ing|den)\b|'
    r'\bnot\s+(?:be\s+)?(?:shown|rendered|displayed|visible)\b|'
    r'\bnever\s+(?:be\s+)?(?:shown|rendered|displayed|visible)\b|'
    r'\bno\s+longer\s+visible\b|'
    r'\babsent\b',
    caseSensitive: false,
  );

  /// Enabled-state verbs: disable(s|d|ing), enable(s|d|ing), disabled,
  /// enabled.
  static final RegExp _enabledVerb = RegExp(
    r'\bdisabl(?:e|es|ed|ing)\b|\benabl(?:e|es|ed|ing)\b|'
    r'\bdisabled\b|\benabled\b',
    caseSensitive: false,
  );

  /// The disable-form subset of [_enabledVerb] (the enabled-state
  /// assertion's polarity).
  static final RegExp _disableVerb = RegExp(
    r'\bdisabl(?:e|es|ed|ing)\b|\bdisabled\b',
    caseSensitive: false,
  );

  /// Presence verbs — the default for a quoted literal (issue #912
  /// defect 3 grammar + bug #936 conjugations).
  static final RegExp _presenceVerb = RegExp(
    r'\b(?:show(?:s|n)?|render(?:s|ed|ing)?|display(?:s|ed|ing)?|'
    r'visible)\b',
    caseSensitive: false,
  );

  /// A passive copula construction AFTER the literal ("the button is
  /// disabled", "the banner is not shown"): the verb trails the literal
  /// in the Then-clause's passive voice, so it never appears in the
  /// preceding window. Only copula-bound forms bind the literal — an
  /// active verb after the literal ("shows 'X' and disables the 'Y'
  /// button") owns the NEXT literal, not this one.
  static final RegExp _postCopulaVerb = RegExp(
    r'\b(?:is|are|was|were|stays?|remains?|becomes?|gets?)\s+'
    r'(?:not\s+|never\s+)?(?:disabled|enabled|hidden|shown|rendered|'
    r'displayed|visible)\b',
    caseSensitive: false,
  );

  /// Sequence clauses: an in-flight state machine. The single-pump
  /// widget template cannot honestly assert act → intermediate → final,
  /// so a sequence scenario is marked scaffolded (issue #964), never
  /// flattened to presence.
  static final RegExp sequenceClause = RegExp(
    r'\bin flight\b|'
    r'\bwhile\b[^.;]*\b(?:load(?:s|ed|ing)?|pending|in progress|'
    r'signing|processing|fetch(?:ing)?|saving)\b',
    caseSensitive: false,
  );

  /// The explicit absence prefix a scenario may put on a literal
  /// (`"absent: An error occurred"`) — absence is expressible even when
  /// the surrounding prose verb is ambiguous (issue #964 acceptance
  /// criterion 2).
  static const String absencePrefix = 'absent:';

  /// Classify [description]: derive one [ScenarioAssertion] per quoted
  /// literal. The literal's nearest preceding verb (within the text
  /// segment since the previous literal) decides its assertion class —
  /// absence over enabled-state over route over presence. A passive
  /// copula form trailing the literal ("the button is disabled") is
  /// honored when the preceding window leaves the literal as plain
  /// presence.
  static ScenarioAnalysis analyze(String description) {
    final assertions = <ScenarioAssertion>[];
    final matches = quoted.allMatches(description).toList();
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final raw = (match.group(1) ?? match.group(2))?.trim();
      if (raw == null || raw.isEmpty) continue;
      final window = description.substring(
        segmentStartOf(matches, i),
        match.end,
      );
      if (raw.toLowerCase().startsWith(absencePrefix)) {
        assertions.add(
          ScenarioAssertion(
            assertionClass: ScenarioAssertionClass.absence,
            literal: raw.substring(absencePrefix.length).trim(),
          ),
        );
        continue;
      }
      var assertion = _classifyByNearestVerb(raw, window);
      if (assertion.assertionClass == ScenarioAssertionClass.presence) {
        // Passive voice: the verb may trail the literal ("the "Sign in"
        // button is disabled"). Only a copula-bound form binds — an
        // active verb after the literal owns the NEXT literal.
        final nextStart = i + 1 < matches.length
            ? matches[i + 1].start
            : description.length;
        final postWindow = description.substring(
          match.end,
          nextStart.clamp(match.end, description.length),
        );
        final copula = _postCopulaVerb.firstMatch(postWindow);
        if (copula != null) {
          assertion = _classifyByNearestVerb(raw, copula.group(0)!);
        }
      }
      assertions.add(assertion);
    }
    return ScenarioAnalysis(
      description: description,
      assertions: assertions,
      sequence: sequenceClause.hasMatch(description),
    );
  }

  /// The segment start for literal [index]: the end of the previous
  /// literal's match (0 for the first).
  static int segmentStartOf(List<RegExpMatch> matches, int index) =>
      index <= 0 ? 0 : matches[index - 1].end;

  /// Nearest-preceding-verb classification inside one literal's window:
  /// the closest verb match to the literal wins, so "shows 'Welcome'
  /// after the user navigates" stays presence for 'Welcome' while
  /// "navigates to the route 'deal_list'" becomes a route outcome.
  static ScenarioAssertion _classifyByNearestVerb(
    String literal,
    String window,
  ) {
    var best = -1;
    var bestClass = ScenarioAssertionClass.presence;
    void consider(RegExp verb, ScenarioAssertionClass kind) {
      for (final m in verb.allMatches(window)) {
        if (m.end > best) {
          best = m.end;
          bestClass = kind;
        }
      }
    }

    consider(_absenceVerb, ScenarioAssertionClass.absence);
    consider(_enabledVerb, ScenarioAssertionClass.enabledState);
    consider(_routeVerb, ScenarioAssertionClass.routeOutcome);
    consider(_presenceVerb, ScenarioAssertionClass.presence);
    if (bestClass == ScenarioAssertionClass.enabledState) {
      final lastDisable = _disableVerb
          .allMatches(window)
          .fold(-1, (end, m) => m.end > end ? m.end : end);
      final lastEnable = RegExp(
        r'\benabl(?:e|es|ed|ing)\b|\benabled\b',
        caseSensitive: false,
      ).allMatches(window).fold(-1, (end, m) => m.end > end ? m.end : end);
      return ScenarioAssertion(
        assertionClass: bestClass,
        literal: literal,
        disabled: lastDisable >= lastEnable,
      );
    }
    return ScenarioAssertion(
      assertionClass: bestClass,
      literal: literal,
      kind: bestClass == ScenarioAssertionClass.routeOutcome
          ? LiteralKind.route
          : LiteralKind.text,
    );
  }

  /// Emit the Dart assertion lines for [analysis], in scenario order.
  /// [escape] makes each literal safe inside a single-quoted Dart string
  /// (the writer passes [its own escaper]). Every line fails through an
  /// ASSERTION when the outcome does not happen — no finder throw can
  /// leak into the transcript as a runner-tier failure (issue #830
  /// widget failure taxonomy).
  static List<String> emitTestAssertions(
    ScenarioAnalysis analysis, {
    String Function(String raw) escape = _identity,
  }) {
    return [
      for (final assertion in analysis.assertions) _emit(assertion, escape),
    ];
  }

  static String _identity(String raw) => raw;

  static String _emit(
    ScenarioAssertion assertion,
    String Function(String raw) escape,
  ) {
    final literal = escape(assertion.literal);
    switch (assertion.assertionClass) {
      case ScenarioAssertionClass.presence:
        return "expect(find.text('$literal'), findsOneWidget);";
      case ScenarioAssertionClass.absence:
        return "expect(find.text('$literal'), findsNothing);";
      case ScenarioAssertionClass.routeOutcome:
        return "expect(observer.pushedNames, contains('$literal'),\n"
            '          reason: '
            "'the scenario asserts navigation to route $literal; "
            "a rendered string is not a navigation');";
      case ScenarioAssertionClass.enabledState:
        return "final buttonFinder = find.widgetWithText(ElevatedButton, "
            "'$literal');\n"
            '      expect(buttonFinder, findsOneWidget,\n'
            "          reason: 'the scenario asserts the $literal control "
            "exists');\n"
            '      expect(\n'
            '        tester.widget<ElevatedButton>(buttonFinder).onPressed,\n'
            '        ${assertion.disabled ? 'isNull' : 'isNotNull'},\n'
            "        reason: 'the scenario asserts the $literal control is "
            "${assertion.disabled ? 'disabled' : 'enabled'}');";
      case ScenarioAssertionClass.sequence:
        // Never emitted: a sequence scenario is marked scaffolded by the
        // writer; its per-literal sub-assertions arrive through their
        // own classes above.
        return '';
    }
  }

  /// The machine-readable `// scenario-assertions:` header line for a
  /// generated test — the per-scenario record the verify-red kind gate
  /// and grepping humans read (issue #964 acceptance: absence assertions
  /// are traced, presence can no longer masquerade as a route outcome).
  /// Empty when the scenario derives no assertions.
  static String headerLine(ScenarioAnalysis analysis) {
    String cell(ScenarioAssertion a) {
      final literal = a.literal
          .replaceAll('\r', ' ')
          .replaceAll('\n', ' ')
          .replaceAll('\t', ' ');
      final polarity = a.assertionClass == ScenarioAssertionClass.enabledState
          ? a.disabled
                ? '(disabled)'
                : '(enabled)'
          : '';
      return '${a.assertionClass.label}("$literal")$polarity';
    }

    final parts = <String>[
      if (analysis.sequence) ScenarioAssertionClass.sequence.label,
      ...analysis.assertions.map(cell),
    ];
    if (parts.isEmpty) return '';
    return '// scenario-assertions: ${parts.join(', ')}';
  }

  /// The kind gate (issue #964 proposal 3): given the scenario analysis
  /// derived from a test's description and the test's source, return the
  /// required assertion classes the file does NOT satisfy. Empty means
  /// the test's assertion kinds match the scenario verbs. A single-pump
  /// file can never satisfy [ScenarioAssertionClass.sequence] — scaffold
  /// callers must gate-check the scaffolded marker BEFORE this helper.
  static Set<ScenarioAssertionClass> unsatisfiedClasses(
    ScenarioAnalysis analysis,
    String testContent,
  ) {
    bool satisfied(ScenarioAssertionClass cls) => switch (cls) {
      ScenarioAssertionClass.presence =>
        testContent.contains('find.text(') &&
            testContent.contains('findsOneWidget'),
      ScenarioAssertionClass.absence => testContent.contains('findsNothing'),
      ScenarioAssertionClass.routeOutcome => testContent.contains(
        'pushedNames',
      ),
      ScenarioAssertionClass.enabledState => testContent.contains('.onPressed'),
      ScenarioAssertionClass.sequence => false,
    };
    return {...analysis.requiredClasses.where((cls) => !satisfied(cls))};
  }
}
