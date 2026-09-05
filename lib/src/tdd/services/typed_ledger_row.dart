/// TypedLedgerRow (spec 0966, issue #966): typed coverage-ledger rows —
/// every row carries a KIND (`presence | absence | navigation | state |
/// sequence`), and the gate treats a declared kind with no traced row as
/// a gap. The #963 ledger traced presence only, which is gameable: a
/// single `Column` rendering all 9 declared literals at once — error
/// banner permanently visible, buttons always enabled, navigating
/// nowhere — passed every presence assertion and posted a 9/9 matrix.
///
/// Kinds are assigned at PLAN TIME from scenario verbs (composing with
/// the finder-kind taxonomy, issue #964), never inferred post hoc. The
/// kind-specific semantics ride on the row: an absence row records the
/// state in which the surface must be hidden, a sequence row records the
/// interaction chain, a state row records the asserted widget attribute,
/// and a golden row is advisory with per-platform tolerance (goldens are
/// kept out of the merge gate — flaky economics on slow CI; recorded
/// decision).
///
/// Pure and synchronous: declared facts + evidence in, ledger out. State
/// is recomputed at read time — a stored state is a cache, never the
/// truth (the #963 discipline).
library;

import 'dart:convert';

/// The kind of a typed ledger row (spec 0966, issue #966).
enum LedgerRowKind {
  /// A rendered text/widget surface ("Sign In" visible). The #963
  /// default — the only kind a presence-only ledger can express.
  presence('presence'),

  /// A surface that must NOT be rendered in a state ("error banner
  /// hidden initially"). Traced only by a behavior asserting the
  /// hiddenness in that state.
  absence('absence'),

  /// A route outcome ("sign-in → `deal_list`"), asserted through a
  /// recording navigator observer, never as on-screen text (#964).
  navigation('navigation'),

  /// A widget attribute ("buttons disabled in flight" — FR-005-class),
  /// which a presence row cannot express.
  state('state'),

  /// An interaction chain ("tap → loading → resolve → navigate"). The
  /// `When` clause the presence-only ledger discarded.
  sequence('sequence'),

  /// A visual-snapshot surface. Advisory ONLY — golden rows never
  /// block the merge gate (flaky economics on slow CI; per-platform
  /// tolerance; recorded decision, issue #966).
  golden('golden');

  /// The kebab-case label used in the machine-readable artifacts.
  final String label;

  const LedgerRowKind(this.label);

  // --- plan-time verb patterns (issue #964 taxonomy composition) ----
  // Precedence: golden > sequence > navigation > absence > state >
  // presence. An interaction chain outranks the verbs inside it ("tap →
  // loading → resolve → navigate" is a sequence even though it
  // navigates); a bare attribute verb is state, not sequence ("buttons
  // disabled while in flight" has no chain).

  static final RegExp _chainPattern = RegExp(
    r'\btap\b.*(\bthen\b|\bloading\b|\bresolve[sd]?\b|\bnavigat\w*\b)|'
    r'\bwhile\s+\w+ing\b.*\bthen\b',
  );
  static final RegExp _navigationPattern = RegExp(
    r'\bnavigat\w*\b|\broutes? to\b|\blands on\b|\bpush(es|ed)?\b|\bgoes to\b',
  );
  static final RegExp _absencePattern = RegExp(
    r'\bhidden\b|\bnot (?:shown|rendered|visible)\b|'
    r"\bdoes(?:n'?t| not) (?:appear|render|show)\b|\babsent\b|"
    r'\bdisappears?\b|\bno \w+ (?:is )?shown\b',
  );
  static final RegExp _statePattern = RegExp(
    r'\bdisabl\w*\b|\benabl\w*\b|\breadonly\b|\bgrayed\b|\bopacity\b|'
    r'\bselected\b|\bfocused\b|\bexpanded\b',
  );
  static final RegExp _goldenPattern = RegExp(r'\bgolden\b|\bsnapshot\b');

  /// Assign the row kind at PLAN TIME from the scenario's verbs (issue
  /// #966: kinds come from scenario verbs, not inferred post hoc — the
  /// gaming view cannot re-label a row to dodge a kind gap).
  static LedgerRowKind fromScenarioVerb(String scenario) {
    final s = scenario.toLowerCase();
    if (_goldenPattern.hasMatch(s)) return LedgerRowKind.golden;
    if (s.contains('→') || s.contains('->')) return LedgerRowKind.sequence;
    if (_chainPattern.hasMatch(s)) return LedgerRowKind.sequence;
    if (_navigationPattern.hasMatch(s)) return LedgerRowKind.navigation;
    if (_absencePattern.hasMatch(s)) return LedgerRowKind.absence;
    if (_statePattern.hasMatch(s)) return LedgerRowKind.state;
    return LedgerRowKind.presence;
  }
}

/// One typed ledger row (derived; state recomputed at read time).
class TypedLedgerRow {
  /// What the row traces: the surface literal, route, attribute, or
  /// chain description.
  final String surface;

  final LedgerRowKind kind;

  /// Behavior ids that trace (prove) this row.
  final List<String> provers;

  /// Recomputed state: `DONE` iff at least one prover is green;
  /// `NOT-DONE` otherwise (planned-but-red provers never count).
  final String state;

  /// Advisory rows (goldens) never block the merge gate; they are
  /// reported separately (recorded decision, issue #966).
  final bool advisory;

  /// For [LedgerRowKind.absence]: the state in which the surface must
  /// NOT be rendered ("error banner hidden initially" → `initial`).
  final String? notRenderedIn;

  /// For [LedgerRowKind.sequence]: the interaction chain steps
  /// (`tap → loading → resolve → navigate`).
  final List<String> steps;

  /// For [LedgerRowKind.state]: the asserted widget attribute
  /// (`buttons disabled in flight` → `enabled = false`).
  final String? attribute;

  /// For [LedgerRowKind.golden]: per-platform pixel tolerance
  /// (`{ios: 0.5, android: 1.0}` — advisory, never gate-blocking).
  final Map<String, double> platformTolerance;

  const TypedLedgerRow({
    required this.surface,
    required this.kind,
    this.provers = const [],
    required this.state,
    this.advisory = false,
    this.notRenderedIn,
    this.steps = const [],
    this.attribute,
    this.platformTolerance = const {},
  });
}

/// One declared typed row (plan time, from the scenario verbs + the
/// declared surface facts).
class DeclaredLedgerRow {
  final String surface;
  final LedgerRowKind kind;

  /// Behavior ids declared as tracing this row (may be empty — the row
  /// still appears, unproven; visible at plan time, never omitted).
  final List<String> declaredProvers;

  /// Force advisory (the `golden` kind is advisory regardless).
  final bool advisory;
  final String? notRenderedIn;
  final List<String> steps;
  final String? attribute;
  final Map<String, double> platformTolerance;

  const DeclaredLedgerRow({
    required this.surface,
    required this.kind,
    this.declaredProvers = const [],
    bool? advisory,
    this.notRenderedIn,
    this.steps = const [],
    this.attribute,
    this.platformTolerance = const {},
  }) : advisory = advisory ?? (kind == LedgerRowKind.golden);

  /// Declare a row whose kind is derived from the scenario's verbs at
  /// plan time (the plan-time assignment contract, FR-005).
  factory DeclaredLedgerRow.fromScenario({
    required String surface,
    required String scenario,
    List<String> declaredProvers = const [],
    String? notRenderedIn,
    List<String> steps = const [],
    String? attribute,
    Map<String, double> platformTolerance = const {},
  }) {
    return DeclaredLedgerRow(
      surface: surface,
      kind: LedgerRowKind.fromScenarioVerb(scenario),
      declaredProvers: declaredProvers,
      notRenderedIn: notRenderedIn,
      steps: steps,
      attribute: attribute,
      platformTolerance: platformTolerance,
    );
  }
}

/// Kind coverage for one screen (or the whole feature): how much of
/// each declared kind is traced. A screen holding presence rows only
/// shows as PARTIALLY traced — the presence-only lie is visible.
class KindCoverage {
  /// The screen the coverage belongs to (`''` = feature-wide).
  final String screen;
  final LedgerRowKind kind;

  /// Declared rows of this kind (advisory rows excluded).
  final int total;

  /// Rows traced green.
  final int traced;

  const KindCoverage({
    required this.screen,
    required this.kind,
    required this.total,
    required this.traced,
  });

  /// A kind with declared rows and zero traced rows is UNTRACED — a
  /// gate gap naming the kind (issue #966: untraced kinds are gaps).
  bool get untraced => total > 0 && traced == 0;

  bool get complete => total > 0 && traced == total;

  /// The overlay/deck label: `absence 0/1`.
  String get label => '${kind.label} $traced/$total';
}

/// Derives and renders the typed coverage ledger.
abstract final class TypedLedgerBuilder {
  /// Derive the typed rows from declared rows and the current evidence
  /// (behavior id → green). State is recomputed HERE, at read time.
  ///
  /// Kind rules (issue #966):
  /// - absence: traced iff a green prover exists AND the row names the
  ///   state it must be hidden in (`notRenderedIn`) — an absence
  ///   assertion that never pins a state is malformed and never counts
  ///   as proof (FR-002; honest-red discipline).
  /// - sequence: traced iff a green prover exists AND the row records a
  ///   chain (≥ 2 steps) — a "sequence" with no recorded steps traced
  ///   nothing; the single-pump presence assertion cannot satisfy it
  ///   (FR-003).
  /// - state: traced iff a green prover exists AND the row records the
  ///   asserted attribute — a "state" row with no attribute expresses
  ///   nothing a presence row does not (FR-004).
  static List<TypedLedgerRow> derive({
    required List<DeclaredLedgerRow> declared,
    required Set<String> greenBehaviors,
  }) {
    return [
      for (final row in declared)
        () {
          final proven = row.declaredProvers
              .where((id) => greenBehaviors.contains(id))
              .toList();
          final malformedAbsence =
              row.kind == LedgerRowKind.absence &&
              (row.notRenderedIn == null || row.notRenderedIn!.isEmpty);
          final malformedSequence =
              row.kind == LedgerRowKind.sequence && row.steps.length < 2;
          final malformedState =
              row.kind == LedgerRowKind.state &&
              (row.attribute == null || row.attribute!.isEmpty);
          return TypedLedgerRow(
            surface: row.surface,
            kind: row.kind,
            provers: proven,
            state:
                (proven.isEmpty ||
                    malformedAbsence ||
                    malformedSequence ||
                    malformedState)
                ? 'NOT-DONE'
                : 'DONE',
            advisory: row.advisory,
            notRenderedIn: row.notRenderedIn,
            steps: row.steps,
            attribute: row.attribute,
            platformTolerance: row.platformTolerance,
          );
        }(),
    ];
  }

  /// Per-kind coverage over the ledger (advisory rows excluded — they
  /// are not gate surface). `screen` labels the result for the overlay;
  /// `''` is feature-wide.
  static List<KindCoverage> kindCoverage(
    List<TypedLedgerRow> rows, {
    String screen = '',
  }) {
    final gateRows = rows.where((r) => !r.advisory).toList();
    final coverage = <KindCoverage>[];
    for (final kind in LedgerRowKind.values) {
      final ofKind = gateRows.where((r) => r.kind == kind).toList();
      if (ofKind.isEmpty) continue; // a kind the plan never declared
      coverage.add(
        KindCoverage(
          screen: screen,
          kind: kind,
          total: ofKind.length,
          traced: ofKind.where((r) => r.state == 'DONE').length,
        ),
      );
    }
    return coverage;
  }

  /// The typed ledger markdown artifact
  /// (`specs/<f>/tdd/typed-ledger.md`).
  static String toMarkdown(List<TypedLedgerRow> rows) {
    final buffer = StringBuffer()
      ..writeln('# Typed Coverage Ledger')
      ..writeln()
      ..writeln('| surface | kind | proven by | state | semantics | advisory |')
      ..writeln('| --- | --- | --- | --- | --- | --- |');
    for (final row in rows) {
      buffer.writeln(
        '| ${row.surface} | ${row.kind.label}'
        '${_semanticsSuffix(row)}'
        '| ${row.provers.isEmpty ? "" : row.provers.join(", ")} '
        '| ${row.state} | ${_semantics(row)} | ${row.advisory ? "advisory" : ""} |',
      );
    }
    return buffer.toString();
  }

  static String _semantics(TypedLedgerRow row) {
    if (row.kind == LedgerRowKind.absence && row.notRenderedIn != null) {
      return 'not rendered in ${row.notRenderedIn}';
    }
    if (row.kind == LedgerRowKind.sequence && row.steps.isNotEmpty) {
      return row.steps.join(' → ');
    }
    if (row.kind == LedgerRowKind.state && row.attribute != null) {
      return row.attribute!;
    }
    if (row.kind == LedgerRowKind.golden && row.platformTolerance.isNotEmpty) {
      return row.platformTolerance.entries
          .map((e) => '${e.key}: ±${e.value}px')
          .join(', ');
    }
    return '';
  }

  static String _semanticsSuffix(TypedLedgerRow row) {
    final s = _semantics(row);
    return s.isEmpty ? ' ' : ' ($s) ';
  }

  /// The typed ledger JSON artifact (the cache; truth is recomputed on
  /// read).
  static String toJson(List<TypedLedgerRow> rows) => jsonEncode([
    for (final row in rows)
      <String, Object>{
        'surface': row.surface,
        'kind': row.kind.label,
        'provenBy': row.provers,
        'state': row.state,
        if (row.advisory) 'advisory': true,
        if (row.notRenderedIn != null) 'notRenderedIn': row.notRenderedIn!,
        if (row.steps.isNotEmpty) 'steps': row.steps,
        if (row.attribute != null) 'attribute': row.attribute!,
        if (row.platformTolerance.isNotEmpty)
          'platformTolerance': row.platformTolerance,
      },
  ]);
}

/// The typed coverage verdict: row gaps (#963 shape) PLUS kind gaps
/// (a declared kind with no traced row is a gap naming the kind).
/// Advisory rows are excluded from the outcome and reported separately.
class TypedCoverageVerdict {
  final String feature;
  final List<TypedLedgerRow> rows;

  /// Advisory rows (goldens) — never gate-blocking.
  final List<TypedLedgerRow> advisoryRows;

  final List<KindCoverage> kindCoverage;

  const TypedCoverageVerdict({
    required this.feature,
    required this.rows,
    this.advisoryRows = const [],
    required this.kindCoverage,
  });

  int get surfaces => rows.length;
  int get proven => rows.where((r) => r.state == 'DONE').length;
  int get unproven => surfaces - proven;

  /// The untraced kinds: declared kinds with zero traced rows.
  List<KindCoverage> get untracedKinds =>
      kindCoverage.where((c) => c.untraced).toList();

  /// Row gaps + kind gaps. The gate fails iff either is non-empty.
  bool get passed => unproven == 0 && untracedKinds.isEmpty;

  /// The unproven rows and their missing provers (#963 shape).
  List<String> get rowGaps => [
    for (final row in rows)
      if (row.state != 'DONE')
        '"${row.surface}" (${row.kind.label}) — no behavior traces it',
  ];

  /// The kind gaps: each names the kind and the semantics it demands.
  List<String> get kindGaps => [
    for (final c in untracedKinds)
      'kind "${c.kind.label}" declared but untraced '
          '(${c.traced}/${c.total} traced) — no green behavior traces any '
          '${c.kind.label} row',
  ];

  /// Serialize (the `--json` shape): per-row lines, per-kind coverage,
  /// the advisory rows (recorded decision), and the outcome.
  String encode() => jsonEncode(<String, Object>{
    'check': 'typed-ui-coverage',
    'feature': feature,
    'surfaces': [
      for (final row in rows)
        <String, Object>{
          'surface': row.surface,
          'kind': row.kind.label,
          'provenBy': row.provers,
          'state': row.state,
          if (row.notRenderedIn != null) 'notRenderedIn': row.notRenderedIn!,
          if (row.steps.isNotEmpty) 'steps': row.steps,
          if (row.attribute != null) 'attribute': row.attribute!,
        },
    ],
    'kinds': [
      for (final c in kindCoverage)
        <String, Object>{
          'kind': c.kind.label,
          if (c.screen.isNotEmpty) 'screen': c.screen,
          'traced': c.traced,
          'total': c.total,
          'untraced': c.untraced,
        },
    ],
    'advisory': [
      for (final row in advisoryRows)
        <String, Object>{
          'surface': row.surface,
          'kind': row.kind.label,
          'state': row.state,
          if (row.platformTolerance.isNotEmpty)
            'platformTolerance': row.platformTolerance,
        },
    ],
    'proven': proven,
    'unproven': unproven,
    'untracedKinds': [for (final c in untracedKinds) c.kind.label],
    'passed': passed,
  });

  /// The final stdout summary line.
  String summaryLine() =>
      'typed-coverage: feature=$feature surfaces=$surfaces '
      'proven=$proven unproven=$unproven '
      'kinds=${kindCoverage.length} untracedKinds=${untracedKinds.length} '
      'advisory=${advisoryRows.length} '
      'outcome=${passed ? 'complete' : 'gaps'}';

  /// The exit-coded failure lines: each gap named with a fix hint.
  List<String> failureLines() => [
    for (final gap in rowGaps)
      '$gap --> fix: write/land the proving behavior for the surface '
          '(issue #966).',
    for (final gap in kindGaps)
      '$gap --> fix: write/land the behavior the scenario verbs demand '
          'for this kind and trace it green (issue #966).',
  ];
}

/// The typed gate: the #963 gate discipline extended with kind gaps.
abstract final class TypedCoverageGate {
  /// Evaluate the typed ledger rows: exit 0 iff every row is DONE AND
  /// every declared kind has a traced row. Advisory rows are excluded
  /// from the outcome (goldens stay out of the merge gate) but reported.
  static TypedCoverageVerdict evaluate({
    required String feature,
    required List<TypedLedgerRow> rows,
  }) {
    final gateRows = rows.where((r) => !r.advisory).toList();
    return TypedCoverageVerdict(
      feature: feature,
      rows: gateRows,
      advisoryRows: rows.where((r) => r.advisory).toList(),
      kindCoverage: TypedLedgerBuilder.kindCoverage(gateRows),
    );
  }
}
