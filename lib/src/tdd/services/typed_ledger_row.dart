/// TypedLedgerRow (spec 0966, issue #966; tightened by spec 1334, issue
/// #1143): typed coverage-ledger rows — every row carries a KIND
/// (`presence | absence | navigation | state | sequence`), and the gate
/// treats a kind with no traced row as a gap. The #963 ledger traced
/// presence only, which is gameable: a single `Column` rendering all 9
/// declared literals at once — error banner permanently visible, buttons
/// always enabled, navigating nowhere — passed every presence assertion
/// and posted a 9/9 matrix.
///
/// Kinds are assigned at PLAN TIME from scenario verbs (composing with
/// the finder-kind taxonomy, issue #964), never inferred post hoc. The
/// kind-specific semantics ride on the row: an absence row records the
/// state in which the surface must be hidden, a sequence row records the
/// interaction chain, a state row records the asserted widget attribute.
///
/// Issue #1143 (spec 1334) refinements:
/// - The kind vocabulary is FIVE values exactly. A golden (visual
///   regression) row is NOT a sixth kind: it carries `kind: presence`
///   with an `advisory: true` flag and per-platform tolerance, and stays
///   out of the merge gate (flaky economics on slow CI; recorded
///   decision).
/// - Every row carries its SCREEN; the per-screen kind report lists all
///   five kinds (0/0 included) and counts ANY kind with zero traced rows
///   as a gap — a presence-only screen is `partially-traced`, never 100%.
/// - Ledger JSON without typed kind fields (the 075 shape) reads in
///   LEGACY mode: rows reclassify to presence and the gate is rows-only
///   — existing projects do not break; only new typed ledgers tighten.
///
/// Pure and synchronous: declared facts + evidence in, ledger out. State
/// is recomputed at read time — a stored state is a cache, never the
/// truth (the #963 discipline).
library;

import 'dart:convert';

/// The kind of a typed ledger row (spec 0966 FR-001; spec 1334 FR-001:
/// five values exactly — there is no `golden` kind, a golden row is a
/// presence row with `advisory: true`).
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
  sequence('sequence');

  /// The kebab-case label used in the machine-readable artifacts.
  final String label;

  const LedgerRowKind(this.label);

  /// Parse a stored kind label; `null` for anything else (legacy
  /// `text`/`route`/`affordance`/`key`, the 0966 `golden` label,
  /// unknown labels) — the legacy-mode classifier.
  static LedgerRowKind? tryParse(String? label) {
    if (label == null) return null;
    for (final kind in LedgerRowKind.values) {
      if (kind.label == label) return kind;
    }
    return null;
  }

  // --- plan-time verb patterns (issue #964 taxonomy composition) ----
  // Precedence: sequence > navigation > absence > state > presence. An
  // interaction chain outranks the verbs inside it ("tap → loading →
  // resolve → navigate" is a sequence even though it navigates); a bare
  // attribute verb is state, not sequence ("buttons disabled while in
  // flight" has no chain).

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

  /// Plan-time detection of a visual-regression (golden) scenario — the
  /// row is advisory (issue #1143 AC-5: goldens are out of the merge
  /// gate), not a distinct kind.
  static bool isGoldenScenario(String scenario) =>
      _goldenPattern.hasMatch(scenario.toLowerCase());

  /// Assign the row kind at PLAN TIME from the scenario's verbs (issue
  /// #966: kinds come from scenario verbs, not inferred post hoc — the
  /// gaming view cannot re-label a row to dodge a kind gap). A golden
  /// scenario maps to [LedgerRowKind.presence] — golden-ness is the
  /// advisory flag ([isGoldenScenario]), never the kind.
  static LedgerRowKind fromScenarioVerb(String scenario) {
    final s = scenario.toLowerCase();
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

  /// The screen the row belongs to (`''` = feature-wide / legacy). The
  /// #1143 per-screen report, overlay, and gate group by this.
  final String screen;

  /// Behavior ids that trace (prove) this row.
  final List<String> provers;

  /// Recomputed state: `DONE` iff at least one prover is green;
  /// `NOT-DONE` otherwise (planned-but-red provers never count).
  final String state;

  /// Advisory rows (goldens) never block the merge gate; they are
  /// reported separately (recorded decision, issues #966 + #1143).
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

  /// For advisory golden rows: per-platform pixel tolerance
  /// (`{ios: 0.5, android: 1.0}` — advisory, never gate-blocking).
  final Map<String, double> platformTolerance;

  const TypedLedgerRow({
    required this.surface,
    required this.kind,
    this.screen = '',
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

  /// The screen the row belongs to (`''` = feature-wide / legacy).
  final String screen;

  /// Behavior ids declared as tracing this row (may be empty — the row
  /// still appears, unproven; visible at plan time, never omitted).
  final List<String> declaredProvers;

  /// Advisory rows (goldens — visual regression) never block the merge
  /// gate. Set automatically for golden scenarios; explicit rows may
  /// force it (issue #1143 AC-5: a golden row is presence + advisory).
  final bool advisory;
  final String? notRenderedIn;
  final List<String> steps;
  final String? attribute;
  final Map<String, double> platformTolerance;

  const DeclaredLedgerRow({
    required this.surface,
    required this.kind,
    this.screen = '',
    this.declaredProvers = const [],
    bool? advisory,
    this.notRenderedIn,
    this.steps = const [],
    this.attribute,
    this.platformTolerance = const {},
  }) : advisory = advisory ?? false;

  /// Declare a row whose kind is derived from the scenario's verbs at
  /// plan time (the plan-time assignment contract, FR-005/#964). A
  /// golden-flavored scenario yields `kind: presence` + `advisory: true`
  /// (issue #1143 AC-5 — golden is a flag, not a kind).
  factory DeclaredLedgerRow.fromScenario({
    required String surface,
    required String scenario,
    String screen = '',
    List<String> declaredProvers = const [],
    String? notRenderedIn,
    List<String> steps = const [],
    String? attribute,
    Map<String, double> platformTolerance = const {},
  }) {
    return DeclaredLedgerRow(
      surface: surface,
      kind: LedgerRowKind.fromScenarioVerb(scenario),
      screen: screen,
      declaredProvers: declaredProvers,
      advisory: LedgerRowKind.isGoldenScenario(scenario),
      notRenderedIn: notRenderedIn,
      steps: steps,
      attribute: attribute,
      platformTolerance: platformTolerance,
    );
  }
}

/// Kind coverage for one screen (or the whole feature): how much of
/// each kind is traced.
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

  /// The #1143 per-screen gap predicate: ANY kind with zero traced rows
  /// is a gap — declared or not (a `0/0` kind still counts; the
  /// presence-only screen is partially traced, never 100%).
  bool get zeroTraced => traced == 0;

  /// The 0966 declared-kinds predicate: a DECLARED kind with zero
  /// traced rows is a gap naming the kind (issue #966).
  bool get untraced => total > 0 && traced == 0;

  bool get complete => total > 0 && traced == total;

  /// The overlay/deck label: `absence 0/1`.
  String get label => '${kind.label} $traced/$total';
}

/// The per-screen trace status (issue #1143 AC-2/AC-3): a screen with
/// presence rows only shows as PARTIALLY traced — not 100%.
enum ScreenTraceStatus {
  /// All five kinds have a traced row AND every gate row is DONE.
  fullyTraced('fully-traced'),

  /// Some kinds (or rows) traced, others not — the presence-only lie,
  /// visible.
  partiallyTraced('partially-traced'),

  /// Zero traced rows on the screen — nothing is proven.
  untraced('untraced');

  /// The status line label (the XRay overlay renders it verbatim).
  final String label;

  const ScreenTraceStatus(this.label);
}

/// The #1143 per-screen kind report: ALL FIVE kinds with traced/total
/// counts (0/0 included), the screen status, and the screen's gaps.
/// This is the report the XRay overlay renders and the per-screen gate
/// evaluates — the shape that makes a presence-only screen read
/// `partially-traced`, never 100%.
class ScreenKindReport {
  final String screen;

  /// Coverage for every one of the five kinds, in vocabulary order
  /// (advisory rows excluded — they are not gate surface).
  final List<KindCoverage> coverage;

  /// The screen's gate rows (advisory rows excluded).
  final List<TypedLedgerRow> rows;

  const ScreenKindReport({
    required this.screen,
    required this.coverage,
    required this.rows,
  });

  /// The display label (`'(feature)'` for the screenless bucket).
  String get screenLabel => screen.isEmpty ? '(feature)' : screen;

  /// The kinds with zero traced rows — the #1143 kind gaps.
  List<KindCoverage> get zeroTracedKinds =>
      coverage.where((c) => c.zeroTraced).toList();

  /// Row gaps: any gate row that is not DONE.
  bool get hasRowGaps => rows.any((r) => r.state != 'DONE');

  /// The row-gap lines (the #963 shape, per screen).
  List<String> get rowGaps => [
    for (final row in rows)
      if (row.state != 'DONE')
        '"${row.surface}" (${row.kind.label}) — no behavior traces it',
  ];

  /// `fully-traced` iff every kind has ≥ 1 traced row AND no row gaps;
  /// `untraced` iff zero traced rows overall; else `partially-traced`.
  ScreenTraceStatus get status {
    if (coverage.every((c) => c.zeroTraced)) {
      return ScreenTraceStatus.untraced;
    }
    if (zeroTracedKinds.isEmpty && !hasRowGaps) {
      return ScreenTraceStatus.fullyTraced;
    }
    return ScreenTraceStatus.partiallyTraced;
  }

  /// The gate predicate (FR-004): no kind gaps, no row gaps.
  bool get fullyTraced => zeroTracedKinds.isEmpty && !hasRowGaps;
}

/// The result of reading a stored ledger JSON (issue #1143 AC-6):
/// [legacy] is `true` iff NO row carried a typed kind label — the 075
/// shape (`text`/`route`/`affordance`/`key`, or no kind field at all).
/// Legacy rows are reclassified `presence`; the gate is rows-only.
class LedgerParseResult {
  /// The recomputed rows (state derived at read time — a stored state
  /// is a cache, never the truth).
  final List<TypedLedgerRow> rows;

  /// `true` when the source ledger carried no typed kind labels.
  final bool legacy;

  const LedgerParseResult({required this.rows, required this.legacy});
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
            screen: row.screen,
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
  /// `''` is feature-wide. The 0966 declared-kinds view: a kind the
  /// plan never declared does not appear.
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

  /// The #1143 per-screen coverage: ALL FIVE kinds, `0/0` included —
  /// any kind with zero traced rows is a gap (declared or not). This is
  /// the view the per-screen report/overlay/gate consume; the 0966
  /// declared-kinds view ([kindCoverage]) stays for the feature-wide
  /// verdict.
  static List<KindCoverage> kindCoverageAllKinds(
    List<TypedLedgerRow> rows, {
    String screen = '',
  }) {
    final gateRows = rows.where((r) => !r.advisory).toList();
    return [
      for (final kind in LedgerRowKind.values)
        KindCoverage(
          screen: screen,
          kind: kind,
          total: gateRows.where((r) => r.kind == kind).length,
          traced: gateRows
              .where((r) => r.kind == kind && r.state == 'DONE')
              .length,
        ),
    ];
  }

  /// Group the ledger rows by their screen (`''` = feature-wide /
  /// legacy bucket), preserving first-occurrence order.
  static Map<String, List<TypedLedgerRow>> groupByScreen(
    List<TypedLedgerRow> rows,
  ) {
    final byScreen = <String, List<TypedLedgerRow>>{};
    for (final row in rows) {
      byScreen.putIfAbsent(row.screen, () => []).add(row);
    }
    return byScreen;
  }

  /// The #1143 per-screen kind reports: one per screen, all five kinds
  /// each (advisory rows excluded from coverage and rows).
  static Map<String, ScreenKindReport> screenReports(
    Map<String, List<TypedLedgerRow>> ledgerByScreen,
  ) => {
    for (final entry in ledgerByScreen.entries)
      entry.key: ScreenKindReport(
        screen: entry.key,
        coverage: kindCoverageAllKinds(entry.value, screen: entry.key),
        rows: entry.value.where((r) => !r.advisory).toList(),
      ),
  };

  /// The typed ledger markdown artifact
  /// (`specs/<f>/tdd/typed-ledger.md`). The 0966 table shape is pinned
  /// by spec 0966's subjects — screen rides the JSON only.
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
    if (row.advisory && row.platformTolerance.isNotEmpty) {
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
  /// read). Screen and advisory ride the row.
  static String toJson(List<TypedLedgerRow> rows) => jsonEncode([
    for (final row in rows)
      <String, Object>{
        'surface': row.surface,
        'kind': row.kind.label,
        if (row.screen.isNotEmpty) 'screen': row.screen,
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

  /// Read a stored ledger JSON (issue #1143 AC-6, legacy mode).
  ///
  /// Accepts the bare-list ledger shape ([toJson], the 075
  /// `UiLedgerBuilder.toJson` shape) and the verdict shape (a map with
  /// a `surfaces` list — the 075 gate `encode()`). Row kind rules:
  /// - `kind` in the five typed labels → typed row (semantics carried);
  /// - `kind == 'golden'` (a 0966-written artifact) → `presence` +
  ///   `advisory: true` (the #1143 reclassification);
  /// - kind missing / a legacy `text`/`route`/`affordance`/`key` label
  ///   / unknown → `presence` (the legacy reclassification).
  ///
  /// The ledger is LEGACY iff no row carried a typed label. State is
  /// recomputed at read time from the recorded provers (a stored state
  /// is a cache, never the truth).
  static LedgerParseResult fromLedgerJson(String json) {
    final decoded = jsonDecode(json);
    final List<Object?> raw;
    if (decoded is List) {
      raw = decoded;
    } else if (decoded is Map && decoded['surfaces'] is List) {
      raw = decoded['surfaces'] as List<Object?>;
    } else {
      raw = const [];
    }

    final declared = <DeclaredLedgerRow>[];
    var anyTyped = false;
    final greenBehaviors = <String>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final kindLabel = entry['kind'] as String?;
      final typedKind = LedgerRowKind.tryParse(kindLabel);
      final isLegacyGolden = kindLabel == 'golden';
      if (typedKind != null || isLegacyGolden) anyTyped = true;

      final advisoryFlag =
          isLegacyGolden || (entry['advisory'] as bool? ?? false);

      final provers = (entry['provenBy'] as List? ?? const [])
          .whereType<String>()
          .toList();
      greenBehaviors.addAll(provers);

      declared.add(
        DeclaredLedgerRow(
          surface: entry['surface'] as String? ?? '',
          kind: typedKind ?? LedgerRowKind.presence,
          screen: entry['screen'] as String? ?? '',
          declaredProvers: provers,
          advisory: advisoryFlag,
          notRenderedIn: entry['notRenderedIn'] as String?,
          steps: (entry['steps'] as List? ?? const [])
              .whereType<String>()
              .toList(),
          attribute: entry['attribute'] as String?,
          platformTolerance: _tolerance(entry['platformTolerance']),
        ),
      );
    }

    final rows = derive(declared: declared, greenBehaviors: greenBehaviors);
    return LedgerParseResult(rows: rows, legacy: !anyTyped);
  }

  static Map<String, double> _tolerance(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is num)
          entry.key as String: (entry.value as num).toDouble(),
    };
  }
}

/// The typed coverage verdict: row gaps (#963 shape) PLUS kind gaps
/// (a declared kind with no traced row is a gap naming the kind).
/// Advisory rows are excluded from the outcome and reported separately.
///
/// Issue #1143: [legacy] ledgers (no typed kind fields — the 075 shape)
/// evaluate rows-only: kind gaps never count for them (AC-6 — the gate
/// does not break existing projects; it only tightens new typed
/// ledgers).
class TypedCoverageVerdict {
  final String feature;
  final List<TypedLedgerRow> rows;

  /// Advisory rows (goldens) — never gate-blocking.
  final List<TypedLedgerRow> advisoryRows;

  final List<KindCoverage> kindCoverage;

  /// Legacy mode (issue #1143 AC-6): kindless ledger, rows-only gate.
  final bool legacy;

  const TypedCoverageVerdict({
    required this.feature,
    required this.rows,
    this.advisoryRows = const [],
    required this.kindCoverage,
    this.legacy = false,
  });

  int get surfaces => rows.length;
  int get proven => rows.where((r) => r.state == 'DONE').length;
  int get unproven => surfaces - proven;

  /// The untraced kinds: declared kinds with zero traced rows.
  List<KindCoverage> get untracedKinds =>
      kindCoverage.where((c) => c.untraced).toList();

  /// Row gaps + kind gaps. Legacy ledgers: row gaps only. The gate
  /// fails iff the counted gap set is non-empty.
  bool get passed => unproven == 0 && (legacy || untracedKinds.isEmpty);

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
  /// the advisory rows (recorded decision), the legacy mode, and the
  /// outcome.
  String encode() => jsonEncode(<String, Object>{
    'check': 'typed-ui-coverage',
    'feature': feature,
    'surfaces': [
      for (final row in rows)
        <String, Object>{
          'surface': row.surface,
          'kind': row.kind.label,
          if (row.screen.isNotEmpty) 'screen': row.screen,
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
    if (legacy) 'legacy': true,
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
      'advisory=${advisoryRows.length} legacy=${legacy ? 'true' : 'false'} '
      'outcome=${passed ? 'complete' : 'gaps'}';

  /// The exit-coded failure lines: each gap named with a fix hint.
  List<String> failureLines() => [
    for (final gap in rowGaps)
      '$gap --> fix: write/land the proving behavior for the surface '
          '(issue #1143).',
    if (!legacy)
      for (final gap in kindGaps)
        '$gap --> fix: write/land the behavior the scenario verbs demand '
            'for this kind and trace it green (issue #1143).',
  ];
}

/// The #1143 per-screen verdict (FR-004): every screen is evaluated
/// against the all-five-kinds report — row gaps AND zero-traced kind
/// gaps count, named per screen. Legacy ledgers (AC-6) evaluate
/// rows-only: no kind gaps, no per-screen tightening.
class TypedScreensVerdict {
  final String feature;

  /// One report per screen (all five kinds each).
  final Map<String, ScreenKindReport> screens;

  /// Legacy mode (issue #1143 AC-6): rows-only evaluation.
  final bool legacy;

  const TypedScreensVerdict({
    required this.feature,
    required this.screens,
    this.legacy = false,
  });

  /// The screens with counted gaps (row gaps; kind gaps when typed).
  List<ScreenKindReport> get gapScreens => [
    for (final report in screens.values)
      if (report.hasRowGaps || (!legacy && report.zeroTracedKinds.isNotEmpty))
        report,
  ];

  /// Exit 0 iff no screen has a counted gap.
  bool get passed => gapScreens.isEmpty;

  /// The exit-coded failure lines: each gap named per screen with a fix
  /// hint (issue #1143).
  List<String> failureLines() => [
    for (final report in gapScreens)
      for (final gap in report.rowGaps)
        '$gap on screen "${report.screenLabel}" '
            '--> fix: write/land the proving behavior for the surface '
            '(issue #1143).',
    if (!legacy)
      for (final report in gapScreens)
        for (final c in report.zeroTracedKinds)
          'screen "${report.screenLabel}": kind "${c.kind.label}" has zero '
              'traced rows (${c.traced}/${c.total}) '
              '--> fix: declare and trace the behavior the scenario verbs '
              'demand for this kind on this screen (issue #1143).',
  ];

  /// Serialize (the `--json` shape): the per-screen kind report, the
  /// legacy mode, and the outcome.
  String encode() => jsonEncode(<String, Object>{
    'check': 'typed-screens-coverage',
    'feature': feature,
    'legacy': legacy,
    'passed': passed,
    'screens': {
      for (final entry in screens.entries)
        entry.key: <String, Object>{
          'screen': entry.key,
          'status': entry.value.status.label,
          'kinds': [
            for (final c in entry.value.coverage)
              <String, Object>{
                'kind': c.kind.label,
                'traced': c.traced,
                'total': c.total,
                'zeroTraced': c.zeroTraced,
              },
          ],
          if (entry.value.rowGaps.isNotEmpty) 'rowGaps': entry.value.rowGaps,
        },
    },
  });

  /// The final stdout summary line.
  String summaryLine() =>
      'typed-screens-coverage: feature=$feature '
      'screens=${screens.length} '
      'gapScreens=${gapScreens.length} '
      'legacy=${legacy ? 'true' : 'false'} '
      'outcome=${passed ? 'complete' : 'gaps'}';
}

/// The typed gate: the #963 gate discipline extended with kind gaps
/// (spec 0966) and the per-screen all-five-kinds report (spec 1334).
abstract final class TypedCoverageGate {
  /// Evaluate the typed ledger rows (the 0966 feature-wide shape):
  /// exit 0 iff every row is DONE AND every declared kind has a traced
  /// row. Legacy ledgers (`legacy: true`, AC-6): row gaps only.
  /// Advisory rows are excluded from the outcome (goldens stay out of
  /// the merge gate) but reported.
  static TypedCoverageVerdict evaluate({
    required String feature,
    required List<TypedLedgerRow> rows,
    bool legacy = false,
  }) {
    final gateRows = rows.where((r) => !r.advisory).toList();
    return TypedCoverageVerdict(
      feature: feature,
      rows: gateRows,
      advisoryRows: rows.where((r) => r.advisory).toList(),
      kindCoverage: TypedLedgerBuilder.kindCoverage(gateRows),
      legacy: legacy,
    );
  }

  /// Evaluate the ledger PER SCREEN (issue #1143 FR-004): exit 0 iff
  /// every screen is fully traced — all five kinds have ≥ 1 traced row
  /// AND every gate row is DONE. Legacy ledgers (`legacy: true`):
  /// rows-only per screen (AC-6 — no kind gaps, no tightening).
  static TypedScreensVerdict evaluateScreens({
    required String feature,
    required Map<String, List<TypedLedgerRow>> ledgerByScreen,
    bool legacy = false,
  }) {
    return TypedScreensVerdict(
      feature: feature,
      screens: TypedLedgerBuilder.screenReports(ledgerByScreen),
      legacy: legacy,
    );
  }
}
