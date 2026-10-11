/// BehaviorKindTrace — the verify kind-trace reader (spec
/// 1376-verify-kind-trace, issue #1376, EPIC #1133 exit criterion 3).
///
/// `zfa tdd verify` is the referee; the referee must report WHAT KINDS of
/// behavior it watched, not just how many mutants died. The machine-
/// certified source is the `// scenario-assertions:` header the writer
/// emits on every generated widget test (issue #964's finder-kind
/// taxonomy, `FinderTaxonomy.headerLine`):
///
/// ```text
/// // scenario-assertions: presence("t.auth.signIn")
/// // scenario-assertions: route-outcome("deal_list")
/// // scenario-assertions: absence("t.auth.error")
/// // scenario-assertions: enabled-state("t.auth.signIn")(disabled)
/// // scenario-assertions: sequence, presence("t.auth.working")
/// ```
///
/// Kinds are PARSED, never re-derived from scenario prose (the gaming
/// view cannot re-label a row to dodge a kind gap — the same honesty rule
/// spec 0966 set for ledger rows). Unknown tokens degrade to the
/// `not-traced` bucket with the raw token preserved: a future taxonomy
/// extension must degrade to honest reporting, never a referee crash.
///
/// This is ADDITIVE reporting — no gate semantics, no exit-class change,
/// no writer change (verify only READS the generated tests). The
/// kind-MISMATCH enforcement lives in verify-red (#959/#964) and stays
/// there.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'artifact_registry.dart';

class BehaviorKindTrace {
  BehaviorKindTrace._();

  /// The canonical kind order (issue #964's taxonomy labels): the order
  /// every count table and summary line uses, so consumers never re-sort.
  static const List<String> canonicalKinds = [
    'presence',
    'absence',
    'route-outcome',
    'enabled-state',
    'sequence',
  ];

  static final RegExp _headerLine = RegExp(
    r'^//\s*scenario-assertions:\s*(.*)$',
    multiLine: true,
  );

  /// `kind("literal")` cells — the known kinds EXCEPT the bare-token
  /// sequence, matched before the bare-token scan so the literal cell is
  /// consumed once.
  static final RegExp _literalCell = RegExp(
    r'\b(presence|absence|route-outcome|enabled-state)\s*\(\s*"',
  );

  /// Any other `word(` cell — an unknown kind token (forward
  /// compatibility, FR-002).
  static final RegExp _anyCell = RegExp(r'\b([a-z][a-z0-9-]*)\s*\(\s*"');

  /// The bare `sequence` token — present when NOT followed by a paren
  /// (the writer emits it without a literal).
  static final RegExp _bareSequence = RegExp(r'\bsequence\b(?!\s*\()');

  /// Parse every `// scenario-assertions:` header in [testContent].
  ///
  /// Returns `(kinds, unknownTokens)`: kinds = the canonical labels found
  /// (deduped, canonical order); unknownTokens = raw tokens that matched
  /// no canonical kind (verbatim, never inferred).
  static (List<String>, List<String>) parseHeader(String testContent) {
    final found = <String>{};
    final unknown = <String>{};
    for (final match in _headerLine.allMatches(testContent)) {
      final payload = match.group(1) ?? '';
      for (final cell in _literalCell.allMatches(payload)) {
        found.add(cell.group(1)!);
      }
      for (final cell in _anyCell.allMatches(payload)) {
        final token = cell.group(1)!;
        if (!canonicalKinds.contains(token) && token != 'sequence') {
          unknown.add(token);
        }
      }
      if (_bareSequence.hasMatch(payload)) found.add('sequence');
    }
    final ordered = [
      for (final k in canonicalKinds)
        if (found.contains(k)) k,
    ];
    return (ordered, unknown.toList()..sort());
  }

  /// Trace the declared kinds of every registered behavior of a feature:
  /// resolve the behavior's generated test path from the artifact
  /// registry (relative paths against [workingDirectory]), read the file,
  /// parse the header. A missing test file, a header-less test, or an
  /// unknown kind token lands the behavior in `notTraced` with the
  /// reason (honest absence — never silently dropped).
  static Future<BehaviorKindTraceResult> trace({
    required String featureDir,
    String? workingDirectory,
  }) async {
    final registry = ArtifactRegistry(featureDir: featureDir);
    final records = await registry.loadAll();
    final kindsByBehavior = <String, List<String>>{};
    final notTraced = <String, String>{};
    final root = workingDirectory ?? Directory.current.path;
    for (final r in records) {
      final testFile = File(
        p.isAbsolute(r.testPath) ? r.testPath : p.join(root, r.testPath),
      );
      final (kinds, unknown) = testFile.existsSync()
          ? parseHeader(testFile.readAsStringSync())
          : (const <String>[], const <String>[]);
      kindsByBehavior[r.behaviorId] = kinds;
      if (!testFile.existsSync()) {
        notTraced[r.behaviorId] = 'test file missing: ${r.testPath}';
      } else if (unknown.isNotEmpty) {
        notTraced[r.behaviorId] =
            'unknown scenario-assertions kind token: ${unknown.join(', ')}';
      } else if (kinds.isEmpty) {
        notTraced[r.behaviorId] =
            'no scenario-assertions header in ${r.testPath}';
      }
    }
    return BehaviorKindTraceResult(
      kindsByBehavior: kindsByBehavior,
      notTraced: notTraced,
    );
  }

  /// Aggregated per-kind counts across the trace, in canonical order
  /// (zeros included — the referee shows the whole table).
  static Map<String, int> kindCounts(
    Map<String, List<String>> kindsByBehavior,
  ) {
    final counts = {for (final k in canonicalKinds) k: 0};
    for (final kinds in kindsByBehavior.values) {
      for (final k in kinds) {
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// The stdout summary line (FR-004): the canonical table order, the
  /// not-traced count last.
  static String kindCountsLine(
    Map<String, int> counts, {
    required int notTracedCount,
  }) =>
      'kinds: '
      '${canonicalKinds.map((k) => '$k=${counts[k] ?? 0}').join(' ')} '
      'not-traced=$notTracedCount';

  /// The JSON-ready `behavior_kinds` object for the verdict envelope's
  /// `details` (FR-005).
  static Map<String, Object?> detailsObject({
    required Map<String, List<String>> kindsByBehavior,
    required Map<String, String> notTraced,
  }) => {
    'counts': {
      for (final k in canonicalKinds)
        k: kindsByBehavior.values.where((kinds) => kinds.contains(k)).length,
    },
    'by_behavior': {
      for (final entry in kindsByBehavior.entries) entry.key: entry.value,
    },
    'not_traced': Map<String, String>.of(notTraced),
  };
}

/// The trace outcome for one feature's registered behaviors.
class BehaviorKindTraceResult {
  const BehaviorKindTraceResult({
    required this.kindsByBehavior,
    required this.notTraced,
  });

  /// Behavior id -> the canonical kind labels its generated test declares
  /// (empty when the behavior is not traced).
  final Map<String, List<String>> kindsByBehavior;

  /// Behavior id -> the reason it is not traced (missing test file, no
  /// header, unknown kind token).
  final Map<String, String> notTraced;
}
