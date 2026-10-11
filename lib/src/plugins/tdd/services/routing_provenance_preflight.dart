/// The routing-provenance preflight for `zfa tdd run` (issue #1482).
///
/// `zfa tdd run` certified 19 reds over 27m41s on `001-todo-app` before
/// stopping at `U1:make` — a failure whose precondition (all 21 unit
/// behaviors fallback-routed, no derivable assertion) was already fully
/// known at plan time. The engine cycle spawns a `flutter test` per
/// `verify-red`, so the first fatal condition must be detected BEFORE the
/// loop starts, not 19 certifications in.
///
/// The gate reads the routing provenance `zfa tdd plan` ALREADY produces
/// (issue #951): the `## Routing provenance` section of
/// `tdd/test-list.md`, rendered identically into the lane plans
/// `tdd/04-ENGINE.md` / `tdd/04-SKIN.md` when the list is a lane
/// meta-index. It does NOT re-run the routing ladder — `RoutingResolver`
/// stays the single routing owner (the plan's decision record is consumed
/// verbatim), and nothing in `tdd plan`, `tdd verify`, or the loop
/// semantics changes.
///
/// Offending row (a unit behavior that cannot pass make) — ALL of:
///   - the row's kind is `unit`;
///   - its provenance line is `[fallback: ...]` (the labeled legacy
///     fallback: no declared contract trace, no derivable assertion — the
///     exact precondition of the #1259/#1308 vacuous-green make stop);
///   - its loop state is not `done` (a DONE row's loop is complete —
///     evidence beats state, FR-003 of spec 1008; refusing would block
///     legitimate resumption);
///   - it has no generated test carrying a REAL assertion set — the sole
///     assertion predicate is `contentIsVacuousGreen` (issue #1259),
///     reused, never duplicated. A hand-completed test is evidence the
///     row CAN pass make and is never listed.
///
/// Fail-open boundaries — the preflight's SINGLE contract is the
/// fallback-routed-unit refusal; everything else fails honestly
/// downstream:
///   - no/unreadable test list → vacuous pass (the driver's own
///     missing-list error names the real problem);
///   - no provenance section → vacuous pass (legacy lists predate the
///     artifact — nothing is invented);
///   - declared/refused `route:` lines → not fallback;
///   - lane plans contribute ONLY when `test-list.md` is a lane
///     meta-index (issue #1000) — a leftover `04-ENGINE.md` beside a
///     legacy list is ignored, never a false refusal.
///
/// O(1) by construction: file reads only — no subprocess, no spec
/// re-parse, no re-plan.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';
import 'lane_split.dart';
import 'spec_parser.dart';
import 'test_list_reader.dart';
import 'vacuous_guard.dart';

/// The `Suggested:` remedy line (issue #1482) — printed after the
/// offending-row block, before the summary line.
const String kRoutingPreflightSuggested =
    'Suggested: fix routing in plan, or run `zfa tdd run --force` to '
    'skip preflight.';

/// The `FR<id>` trace shape FR-002 renders (`fallback to FR-001`). The
/// routing ladder's own token class also admits `AC-`/`SC-`
/// (`RoutingResolver`), but the refusal line renders ONLY an FR-shaped
/// token — a row tracing just `AC-1` omits the suffix, exactly as a row
/// tracing nothing does. Used ONLY to name the FR a finding falls back
/// to; the routing decision itself is the plan's.
final RegExp _criterionToken = RegExp(r'^FR[-]?\d+', caseSensitive: false);

/// One unit behavior the routing provenance proves cannot pass make.
class RoutingProvenanceFinding {
  /// The behavior id exactly as the test list names it.
  final String id;

  /// The behavior description cell (the `<name>` of the row line).
  final String description;

  /// The criterion-shaped tokens (FR-001, AC-2, …) the row's traces cell
  /// carries — what the behavior falls back to. Empty when the row
  /// traces nothing criterion-shaped (the suffix is omitted then).
  final List<String> criterionTraces;

  const RoutingProvenanceFinding({
    required this.id,
    required this.description,
    this.criterionTraces = const [],
  });

  /// The rendered row line (issue #1482's exact shape):
  /// `  U1 — <name> (no declared contract trace, fallback to FR-001)`.
  /// The `, fallback to ...` suffix is omitted when the row carries no
  /// criterion token.
  String get line {
    final suffix = criterionTraces.isEmpty
        ? ''
        : ', fallback to ${criterionTraces.join(', ')}';
    return '  $id — $description (no declared contract trace$suffix)';
  }
}

/// The gate verdict: `ok` when no unit behavior is fallback-routed with
/// no derivable assertion (or the artifacts to prove it are absent — the
/// fail-open boundaries above).
class RoutingProvenancePreflightReport {
  final bool ok;

  /// One finding per offending row, in test-list order.
  final List<RoutingProvenanceFinding> offending;

  const RoutingProvenancePreflightReport({
    required this.ok,
    required this.offending,
  });

  /// The refusal header naming ALL offending rows at once:
  /// `run: preflight failed — N unit behaviour(s) cannot pass make:`.
  String get headerLine =>
      'run: preflight failed — ${offending.length} unit behaviour(s) '
      'cannot pass make:';
}

/// The preflight gate. Stateless per (projectRoot, featureDir); see the
/// library doc for the contract and the fail-open boundaries.
class RoutingProvenancePreflight {
  RoutingProvenancePreflight({
    required this.projectRoot,
    required this.featureDir,
  });

  /// The project root — the generated tests resolve against it exactly
  /// the way `RunDriverCore` resolves them (#827 namespaced layout first,
  /// legacy flat fallback second).
  final String projectRoot;

  /// The already-resolved feature directory (bug features live under
  /// `.specify/bugs/<slug>/` — issue #1471).
  final String featureDir;

  /// Evaluate the gate. O(1): file reads only, no subprocess, no spec
  /// parse, no re-plan.
  Future<RoutingProvenancePreflightReport> check() async {
    final List<BehaviorRow> rows;
    try {
      rows = await TestListReader(featureDir).read();
    } on TestListReadException {
      return const RoutingProvenancePreflightReport(ok: true, offending: []);
    } on FileSystemException {
      // An unreadable list (deleted between the reader's exists check
      // and this read, permission-denied) fails OPEN like the missing
      // case — the driver's own missing-list error names the real
      // problem (house precedent: `run_driver_core.dart`'s
      // `_testCarriesVacuousGuardMarker`).
      return const RoutingProvenancePreflightReport(ok: true, offending: []);
    }
    final fallbackById = await _fallbackRoutedIds();
    if (fallbackById.isEmpty) {
      return const RoutingProvenancePreflightReport(ok: true, offending: []);
    }

    final offending = <RoutingProvenanceFinding>[];
    for (final row in rows) {
      if (row.kind != BehaviorKind.unit) continue;
      if (fallbackById[row.id] != true) continue;
      // A DONE row's loop is complete — evidence beats state (FR-003,
      // spec 1008); refusing on it would block legitimate resumption.
      if (row.state == BehaviorState.done) continue;
      if (_testCarriesRealAssertions(row.id)) continue;
      offending.add(
        RoutingProvenanceFinding(
          id: row.id,
          description: row.description,
          criterionTraces: SpecParser.traceTokens(
            row.traces,
          ).where(_criterionToken.hasMatch).toList(),
        ),
      );
    }
    return RoutingProvenancePreflightReport(
      ok: offending.isEmpty,
      offending: offending,
    );
  }

  /// The `route:` provenance lines the plan wrote. `tdd/test-list.md`
  /// carries them for a legacy single-file list; ONLY when that file is
  /// a lane meta-index (issue #1000) do the lane plans
  /// (`04-ENGINE.md` then `04-SKIN.md`) contribute too — a leftover lane
  /// file beside a legacy list must never false-refuse (the fail-open
  /// boundary above).
  /// Maps behavior id → fallback-routed. Absent section / absent id →
  /// NOT fallback (never invented).
  Future<Map<String, bool>> _fallbackRoutedIds() async {
    final map = <String, bool>{};
    final listFile = File(p.join(featureDir, 'tdd', 'test-list.md'));
    if (!await listFile.exists()) return map;
    final String listContent;
    try {
      listContent = await listFile.readAsString();
    } on FileSystemException {
      return map; // unreadable: fail open — the loop names the real error
    }
    final files = <File>[listFile];
    final split = LaneSplitFiles.find(listContent);
    if (split != null) {
      // The list IS a meta-index: follow its pointers (mirroring
      // `TestListReader`) instead of assuming the default file names.
      files
        ..add(File(p.join(featureDir, 'tdd', split.engine)))
        ..add(File(p.join(featureDir, 'tdd', split.skin)));
    }
    for (final file in files) {
      if (!await file.exists()) continue;
      final String content;
      try {
        content = await file.readAsString();
      } on FileSystemException {
        continue; // unreadable: fail open — the loop names the real error
      }
      for (final raw in content.split('\n')) {
        final line = raw.trim();
        if (!line.startsWith('route: ')) continue;
        final arrow = line.indexOf(' -> ');
        if (arrow <= 0) continue;
        final id = line.substring('route: '.length, arrow).trim();
        if (id.isEmpty) continue;
        // First writer wins. For a meta-index the list carries no
        // `route:` lines, so the engine plan (added before the skin
        // plan) stays the row of record for a BOTH behavior — the
        // `TestListReader` order. A unit-lane anchor keeps a
        // differently-laned line for the same id out of the verdict.
        map.putIfAbsent(
          id,
          () => line.contains('-> unit lane') && line.contains('[fallback:'),
        );
      }
    }
    return map;
  }

  /// Whether the generated unit test for [behaviorId] already carries a
  /// REAL assertion set (`contentIsVacuousGreen` == false) — the
  /// hand-completion evidence that the row can pass make. Unreadable
  /// files fail CLOSED for the exemption (no proof of real assertions →
  /// the row stays listed — the refusal is the honest side).
  bool _testCarriesRealAssertions(String behaviorId) {
    final snakeId = behaviorId.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    final candidates = [
      p.join(
        projectRoot,
        'test',
        'tdd',
        p.basename(featureDir),
        '${snakeId}_test.dart',
      ),
      p.join(projectRoot, 'test', 'tdd', '${snakeId}_test.dart'),
    ];
    for (final candidate in candidates) {
      final file = File(candidate);
      if (!file.existsSync()) continue;
      try {
        return !contentIsVacuousGreen(file.readAsStringSync());
      } on FileSystemException {
        return false; // unreadable: no proof → keep the row listed
      }
    }
    return false; // no test on disk: nothing derivable, nothing to exempt
  }
}
