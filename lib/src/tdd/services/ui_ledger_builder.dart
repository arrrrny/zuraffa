/// UiLedgerBuilder (feature 075, issue #963): derives the per-feature
/// UI surface ledger — one row per DECLARED surface (texts from the
/// quoted-literal contract, routes from the Presentation contract row,
/// affordances named in scenario markers), with kind, proving behavior
/// ids, and evidence-derived state.
///
/// Pure and synchronous: declared facts + evidence in, ledger out.
/// A surface nobody declares is never guessed; a surface with no
/// prover appears as NOT-DONE (visible at plan time, never omitted).
library;

import 'dart:convert';

/// The kind of a declared UI surface. `key` (issue #965) is an i18n
/// surface declared by the spec contract — its ledger row is the slang
/// accessor (`t.<key>`), never the EN literal.
enum UiSurfaceKind { text, route, affordance, key }

/// One ledger row.
class UiSurfaceRow {
  final String surface;
  final UiSurfaceKind kind;

  /// Behavior ids that trace (prove) this surface.
  final List<String> provers;

  /// Recomputed state: `DONE` iff at least one prover is green;
  /// `NOT-DONE` otherwise (planned-but-red provers never count).
  final String state;

  const UiSurfaceRow({
    required this.surface,
    required this.kind,
    this.provers = const [],
    required this.state,
  });
}

/// One declared surface fact (from the plan's declared sources).
class DeclaredSurface {
  final String surface;
  final UiSurfaceKind kind;

  /// Behavior ids declared as tracing this surface (may be empty —
  /// the row still appears, unproven).
  final List<String> declaredProvers;

  const DeclaredSurface({
    required this.surface,
    required this.kind,
    this.declaredProvers = const [],
  });
}

/// Derives and renders the UI surface ledger.
abstract final class UiLedgerBuilder {
  /// Derive the ledger rows from declared surfaces and the current
  /// evidence (behavior id → green). State is recomputed HERE, at
  /// read time — a stored state is a cache, never the truth.
  static List<UiSurfaceRow> derive({
    required List<DeclaredSurface> declared,
    required Set<String> greenBehaviors,
  }) {
    return [
      for (final surface in declared)
        () {
          final proven = surface.declaredProvers
              .where((id) => greenBehaviors.contains(id))
              .toList();
          return UiSurfaceRow(
            surface: surface.surface,
            kind: surface.kind,
            provers: proven,
            state: proven.isEmpty ? 'NOT-DONE' : 'DONE',
          );
        }(),
    ];
  }

  /// The ledger markdown artifact (`specs/<f>/tdd/ui-ledger.md`).
  static String toMarkdown(List<UiSurfaceRow> rows) {
    final buffer = StringBuffer()
      ..writeln('# UI Surface Ledger')
      ..writeln()
      ..writeln('| surface | kind | proven by | state |')
      ..writeln('| --- | --- | --- | --- |');
    for (final row in rows) {
      buffer.writeln(
        '| ${row.surface} | ${row.kind.name} | '
        '${row.provers.isEmpty ? "" : row.provers.join(", ")} '
        '| ${row.state} |',
      );
    }
    return buffer.toString();
  }

  /// The ledger JSON artifact (the cache; truth is recomputed on read).
  static String toJson(List<UiSurfaceRow> rows) => jsonEncode([
    for (final row in rows)
      <String, Object>{
        'surface': row.surface,
        'kind': row.kind.name,
        'provenBy': row.provers,
        'state': row.state,
      },
  ]);

  /// The untraced-surface audit (issue #965 composing #963): every
  /// hardcoded user-facing string in a generated view — a quoted string
  /// literal inside `Text(...)` — must trace to a ledger surface. A
  /// string is TRACED when
  ///   - a `text` row names it verbatim (the quoted-literal contract), or
  ///   - it is the anchor of a declared i18n key whose `t.<key>` row the
  ///     ledger carries (the key contract — the EN literal is the anchor,
  ///     the accessor `Text(t.app.name)` is code identity and needs no
  ///     tracing at all).
  /// Returns the untraced literals in first-occurrence order,
  /// de-duplicated; empty means the view is fully traced.
  static List<String> untracedHardcodedStrings({
    required String viewSource,
    required List<UiSurfaceRow> ledger,
    Map<String, String> anchorToKey = const {},
  }) {
    // A quoted string inside Text(...): single or double quotes, with a
    // comma or closing paren after (a call argument, never a prefix like
    // TextEditingController(text: ...) — the user-facing WIDGET call).
    final quoted = RegExp(
      '''Text\\(\\s*(['"])((?:[^'\\\\]|\\\\.)*?)\\1\\s*[,)]''',
    );
    final tracedTextRows = {
      for (final row in ledger)
        if (row.kind == UiSurfaceKind.text) row.surface,
    };
    final tracedKeyRows = {
      for (final row in ledger)
        if (row.kind == UiSurfaceKind.key) row.surface,
    };
    final violations = <String>[];
    for (final match in quoted.allMatches(viewSource)) {
      final literal = match.group(2)!;
      if (tracedTextRows.contains(literal)) continue;
      final key = anchorToKey[literal];
      if (key != null && tracedKeyRows.contains('t.$key')) continue;
      if (!violations.contains(literal)) violations.add(literal);
    }
    return violations;
  }
}
