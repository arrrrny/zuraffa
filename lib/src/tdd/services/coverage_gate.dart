/// CoverageGate (feature 075, issue #963): the `zfa tdd coverage`
/// verdict — exit 0 only when every declared surface is proven green;
/// failures name each unproven surface and its missing prover. The
/// gate composes into the 074 conformance verdict as the `coverage`
/// check and runs standalone (CI-able) on hosts without it.
///
/// Contract: `contracts/coverage-gate.md` — a feature with zero
/// declared surfaces exits 0 with an empty verdict.
library;

import 'dart:convert';

import 'ui_ledger_builder.dart';

/// The coverage verdict: one line per surface with kind, proven-by,
/// and state.
class CoverageVerdict {
  final String feature;
  final List<UiSurfaceRow> rows;

  const CoverageVerdict({required this.feature, required this.rows});

  int get surfaces => rows.length;
  int get proven => rows.where((r) => r.state == 'DONE').length;
  int get unproven => surfaces - proven;
  bool get passed => unproven == 0;

  /// The unproven surfaces and their missing provers.
  List<String> get gaps => [
    for (final row in rows)
      if (row.state != 'DONE')
        '"${row.surface}" (${row.kind.name}) — no behavior traces it',
  ];

  /// Serialize (the `--json` shape): per-row lines plus the outcome.
  String encode() => jsonEncode(<String, Object>{
    'check': 'ui-coverage',
    'feature': feature,
    'surfaces': [
      for (final row in rows)
        <String, Object>{
          'surface': row.surface,
          'kind': row.kind.name,
          'provenBy': row.provers,
          'state': row.state,
        },
    ],
    'proven': proven,
    'unproven': unproven,
    'passed': passed,
  });

  /// The final stdout summary line (contract shape).
  String summaryLine() =>
      'coverage: feature=$feature surfaces=$surfaces '
      'proven=$proven unproven=$unproven '
      'outcome=${passed ? 'complete' : 'gaps'}';

  /// The exit-coded failure lines: each gap named with a fix hint.
  List<String> failureLines() => [
    for (final gap in gaps)
      '$gap --> fix: write/land the proving behavior for the surface '
          '(issue #963).',
  ];
}

/// Evaluates the ledger into the verdict.
abstract final class CoverageGate {
  /// Evaluate the ledger rows: exit 0 iff every row is DONE.
  static CoverageVerdict evaluate({
    required String feature,
    required List<UiSurfaceRow> rows,
  }) {
    return CoverageVerdict(feature: feature, rows: rows);
  }
}
