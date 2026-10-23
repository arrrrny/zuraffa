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
///
/// ISSUE #1996: the taxonomy is a WIDGET-lane vocabulary — the widget
/// template alone emits the `// scenario-assertions:` header. A unit /
/// contract / acceptance test carries the generator's OWN header block
/// instead:
///
/// ```text
/// // behavior_id: U1
/// // source_criterion: FR-001
/// // kind: unit
/// ```
///
/// That block is the machine-readable trace source for those lanes, so a
/// behavior whose test carries it is TRACED (by its declared kind) — never
/// reported "not traced" for a header the generator cannot emit on that
/// lane (and never fixable in the consumer repo, where generated tests
/// must not be hand-edited).
///
/// The block is read AS A UNIT, from the LEADING comment block of the
/// generated test only: a `// kind:` comment in the test body is prose,
/// never a header. A block that lost its `// behavior_id:` line is
/// incomplete (an honest absence — the id is the only place the
/// behavior↔file binding can be verified), an id that names another
/// behavior is a swapped artifact, and a `// kind:` token that is not one
/// of the kinds the generator can emit degrades to `not-traced` with the
/// raw token preserved — the mirror image of the taxonomy channel's rule
/// above (FR-002): a typo must never make a behavior count as TRACED with
/// a nonsense kind.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';
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

  /// The generator's own header block (issue #1996): the `// kind:` line
  /// `zfa tdd gen` stamps on EVERY generated test — the unit, contract,
  /// widget, ffi, theme and platform lanes alike.
  static final RegExp _declaredKindLine = RegExp(
    r'^//\s*kind:\s*([a-z][a-z0-9_-]*)\s*$',
    multiLine: true,
  );

  /// The `// behavior_id:` line of the generator's own header block — the
  /// behavior↔file binding, the ONLY place it can be verified (an
  /// `ArtifactRecord` carries no kind field).
  static final RegExp _behaviorIdLine = RegExp(
    r'^//\s*behavior_id:\s*(\S+)\s*$',
    multiLine: true,
  );

  /// The kinds the generator can declare (issue #1996) — derived from the
  /// `BehaviorKind` enum so a new lane cannot drift out of sync.
  ///
  /// An unknown token is NOT a kind: it degrades to the `not-traced`
  /// bucket with the raw token preserved, exactly like the taxonomy
  /// channel's unknown token (FR-002). A typo (`// kind: unti`) must not
  /// make a behavior count as TRACED with a nonsense kind.
  static final Set<String> declaredKinds = {
    for (final k in BehaviorKind.values) k.name,
  };

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

  /// The generator's own header block (issue #1996) — the LEADING run of
  /// `//` comment lines at the top of the generated test.
  ///
  /// The block ends at the first line that is neither a comment nor blank,
  /// so a full-line `// kind:` comment in the test BODY is prose, never a
  /// header: only the block `zfa tdd gen` stamps declares the kind.
  static String _leadingCommentBlock(String testContent) {
    final block = StringBuffer();
    for (final line in testContent.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (!trimmed.startsWith('//')) break;
      block.writeln(trimmed);
    }
    return block.toString();
  }

  /// Parse the generator's own header block (issue #1996) AS A UNIT: the
  /// `// behavior_id:` line and the `// kind:` line, both read from the
  /// leading comment block of the generated test.
  ///
  /// Returns `(behaviorId, kind)`:
  ///  - `behaviorId` — the `// behavior_id:` value, or null when the
  ///    block does not carry it (a truncated block);
  ///  - `kind` — the RAW `// kind:` token, or null when the block does
  ///    not carry it. The token is returned verbatim (never filtered
  ///    here) so the caller can report an unknown token honestly.
  static (String? behaviorId, String? kind) parseHeaderBlock(
    String testContent,
  ) {
    final block = _leadingCommentBlock(testContent);
    return (
      _behaviorIdLine.firstMatch(block)?.group(1),
      _declaredKindLine.firstMatch(block)?.group(1),
    );
  }

  /// Parse the generator's own header block (issue #1996): the `// kind:`
  /// line `zfa tdd gen` stamps on every generated test.
  ///
  /// Returns the declared behavior kind (`unit`, `contract`, `widget`,
  /// `ffi`, `theme`, `platform`, `acceptance`) or null when the block is
  /// absent, INCOMPLETE (no `// behavior_id:` line — the id is the only
  /// place the behavior↔file binding can be verified, so a truncated
  /// header is an honest absence) or carries a token that is not a kind.
  ///
  /// The honest absence the trace reports, never inferred.
  static String? parseDeclaredKind(String testContent) {
    final (_, kind) = parseHeaderBlock(testContent);
    if (kind == null || !declaredKinds.contains(kind)) return null;
    return kind;
  }

  /// Trace the declared kinds of every registered behavior of a feature:
  /// resolve the behavior's generated test path from the artifact
  /// registry (relative paths against [workingDirectory]), read the file,
  /// parse the header. A missing test file, a test with no
  /// machine-readable trace header at all, or an unknown kind token lands
  /// the behavior in `notTraced` with the reason (honest absence — never
  /// silently dropped).
  ///
  /// Issue #1996: a test that carries the generator's own header block
  /// (`// behavior_id:` / `// source_criterion:` / `// kind:`) but no
  /// `// scenario-assertions:` header IS traced — by its declared
  /// behavior kind. The finder-kind taxonomy is a widget-lane
  /// vocabulary, so demanding its header on a unit/contract behavior
  /// reported every such behavior as "not traced" although its test
  /// carries real assertions.
  static Future<BehaviorKindTraceResult> trace({
    required String featureDir,
    String? workingDirectory,
  }) async {
    final registry = ArtifactRegistry(featureDir: featureDir);
    final records = await registry.loadAll();
    final kindsByBehavior = <String, List<String>>{};
    final notTraced = <String, String>{};
    final declaredKindByBehavior = <String, String>{};
    final root = workingDirectory ?? Directory.current.path;
    for (final r in records) {
      final testFile = File(
        p.isAbsolute(r.testPath) ? r.testPath : p.join(root, r.testPath),
      );
      final exists = testFile.existsSync();
      final content = exists ? testFile.readAsStringSync() : '';
      final (kinds, unknown) = parseHeader(content);
      final (headerId, declaredKind) = parseHeaderBlock(content);
      kindsByBehavior[r.behaviorId] = kinds;
      if (!exists) {
        notTraced[r.behaviorId] = 'test file missing: ${r.testPath}';
      } else if (unknown.isNotEmpty) {
        notTraced[r.behaviorId] =
            'unknown scenario-assertions kind token: ${unknown.join(', ')}';
      } else if (kinds.isNotEmpty) {
        // The taxonomy path (the widget lane): the behavior is traced by
        // its `// scenario-assertions:` kinds, never by a declared kind —
        // the widget template emits BOTH headers, and the taxonomy is the
        // stricter of the two.
      } else if (declaredKind != null &&
          !declaredKinds.contains(declaredKind)) {
        // An unknown token is not a kind: the same honest absence the
        // taxonomy channel reports for an unknown token (FR-002), with
        // the raw token preserved.
        notTraced[r.behaviorId] = 'unknown declared kind token: $declaredKind';
      } else if (declaredKind != null && headerId != r.behaviorId) {
        // The header block is the only place the behavior↔file binding
        // can be verified (an `ArtifactRecord` carries no kind field), so
        // a file that declares another behavior's id is not this
        // behavior's test.
        notTraced[r.behaviorId] =
            'test file declares behavior_id $headerId, '
            'not ${r.behaviorId}';
      } else if (declaredKind != null) {
        declaredKindByBehavior[r.behaviorId] = declaredKind;
      } else {
        notTraced[r.behaviorId] =
            'no trace header in ${r.testPath}: expected a '
            '`// scenario-assertions:` header or the generated '
            '`// behavior_id:` / `// source_criterion:` / `// kind:` block';
      }
    }
    return BehaviorKindTraceResult(
      kindsByBehavior: kindsByBehavior,
      notTraced: notTraced,
      declaredKindByBehavior: declaredKindByBehavior,
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

  /// Aggregated counts of the DECLARED behavior kinds (issue #1996) —
  /// the `// kind:` header of the generator's own block, for the lanes
  /// the finder-kind taxonomy does not cover. Sorted by kind name so the
  /// rendering is stable across runs.
  static Map<String, int> declaredKindCounts(
    Map<String, String> declaredKindByBehavior,
  ) {
    final counts = <String, int>{};
    for (final kind in declaredKindByBehavior.values) {
      counts[kind] = (counts[kind] ?? 0) + 1;
    }
    final sorted = counts.keys.toList()..sort();
    return {for (final kind in sorted) kind: counts[kind]!};
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
  ///
  /// Issue #1996: `declared_kind_by_behavior` carries the `// kind:` header
  /// of the generator's own block for the lanes the finder-kind taxonomy
  /// does not cover — so a machine consumer can tell a behavior traced by
  /// its declared kind (`unit`) from a behavior with no kinds at all.
  static Map<String, Object?> detailsObject({
    required Map<String, List<String>> kindsByBehavior,
    required Map<String, String> notTraced,
    Map<String, String> declaredKindByBehavior = const {},
  }) => {
    'counts': {
      for (final k in canonicalKinds)
        k: kindsByBehavior.values.where((kinds) => kinds.contains(k)).length,
    },
    'by_behavior': {
      for (final entry in kindsByBehavior.entries) entry.key: entry.value,
    },
    'not_traced': Map<String, String>.of(notTraced),
    'declared_kind_by_behavior': Map<String, String>.of(declaredKindByBehavior),
  };
}

/// The trace outcome for one feature's registered behaviors.
class BehaviorKindTraceResult {
  const BehaviorKindTraceResult({
    required this.kindsByBehavior,
    required this.notTraced,
    this.declaredKindByBehavior = const {},
  });

  /// Behavior id -> the canonical kind labels its generated test declares
  /// (empty when the behavior is not traced).
  final Map<String, List<String>> kindsByBehavior;

  /// Behavior id -> the reason it is not traced (missing test file, no
  /// header, unknown kind token).
  final Map<String, String> notTraced;

  /// Behavior id -> the DECLARED behavior kind (`unit`, `contract`, …)
  /// read from the generator's own `// kind:` header (issue #1996).
  ///
  /// Carries the behaviors whose generated test has no
  /// `// scenario-assertions:` header — the lanes the finder-kind
  /// taxonomy does not cover. Those behaviors ARE traced; this map says
  /// by what.
  final Map<String, String> declaredKindByBehavior;
}
