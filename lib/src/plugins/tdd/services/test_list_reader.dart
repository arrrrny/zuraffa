/// `TestListReader` — the SINGLE format contract for a feature's
/// `tdd/test-list.md` (bug #617: plan, gen and run previously spoke two
/// independently-grown dialects; this reader is now the one parser every
/// consumer shares).
///
/// Canonical shape — the 4-column format `plan_command.dart` writes
/// (spec 049-tdd-run, FR-001 / U1-U3):
///
///     | B-001 | description | FR-001 | PENDING |
///
/// The kind (acceptance vs unit vs ffi) is inferred from the enclosing
/// `## Outer loop:` / `## Inner loop:` / `## Native loop:` section header
/// (bug #835: the native loop carries the FFI/OCR harness behaviors), and
/// the target defaults to `subject_<snake-id>` (the same defaulting gen's
/// private parser applied before the unification; see [resolveDefaultTarget]).
///
/// Deprecated compatibility shim (one release, bug #617 remediation):
/// hand-written 6-column rows are still accepted in TWO private dialects
///
///     | B-001 | description | FR-001 | unit | PENDING | target |
///
/// (gen's old dialect — the kind cell wins over the section header, an
/// empty or path-like target cell falls back to `subject_<snake-id>`),
/// and the spec-kit tdd EXTENSION's own hand-written shape, which the
/// repo's specs/044–049 use (spec 050, FR-007):
///
///     | A1 | description | US1.AC1 | example | DONE | test/ref::A1 |
///
/// whose kind cell names the test SHAPE (`example`, `property`,
/// `contract`, `approval`, `characterization`) — NOT the loop — so the
/// loop kind comes from the enclosing section header (as in the
/// canonical 4-column shape) and the last cell is a test reference: a
/// path-like or empty cell falls back to `subject_<snake-id>`. A row
/// that matches NEITHER dialect is malformed and stops the caller with
/// an error naming the line (FR-011 misfire-stop; format drift is
/// surfaced, not papered over — see specs/049-tdd-run research,
/// Decision 5). Gen's old dialect keeps a one-time deprecation note on
/// stderr naming the canonical 4-column format and a MANUAL migration
/// (bug #649 — never `zfa tdd plan`, which writes spec.md, not the test
/// list); the extension's own shape is spec-sanctioned (spec 050 FR-007)
/// and reads silently.
///
/// THEME KIND EXTENSION (issue #841): a `## Theme harness` section header
/// sets the theme kind for its rows (and the gen-legacy 6-column kind cell
/// accepts `theme`). Theme rows are HAND-MAINTAINED — `zfa tdd plan`
/// derives behaviors from spec.md Given/Then blocks only and must not be
/// re-run on a theme feature (it would drop hand-written theme rows), and
/// `zfa tdd make`/`run` stop honestly on theme ids (the planner does not
/// express them yet).
///
/// PLATFORM KIND EXTENSION (issue #831): a `## Platform harness` section
/// header (or a `platform` kind cell) marks rows whose subjects sit on
/// platform channels (camera, barcode, permissions, notifications,
/// location). Like theme rows they are HAND-MAINTAINED, and the gen pair
/// additionally requires the committed-intent scenario + certified fake
/// written by `zfa tdd fake <channel> --behavior <id>` — gen refuses a
/// platform row whose scenario is missing. `zfa tdd make`/`run` stop
/// honestly on platform ids (the planner does not express them yet).
///
/// CONTRACT KIND EXTENSION (issue #1007): a `## Contract loop:` section
/// header marks CONTRACT rows — one declared entity method, controller
/// method or usecase per row, written by `zfa tdd plan` from the spec's
/// Layer Contracts section with `contract:<id>` row ids. The gen pair is
/// a contract test scaffold (enumerating the contract's cases) + a
/// contract seam subject, and a failing contract test is BLOCKED — never
/// RED — so the row's state cell may also read BLOCKED (it parses to
/// [BehaviorState.blocked], the state the run driver persists when
/// verify-red reports the blocked verdict).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';
import 'lane_plans.dart';
import 'lane_split.dart';
import 'spec_parser.dart';

/// One parsed test-list row.
class BehaviorRow {
  const BehaviorRow({
    required this.id,
    required this.description,
    required this.traces,
    required this.state,
    required this.kind,
    required this.target,
    this.persistence = false,
    this.lane,
  });

  final String id;
  final String description;
  final String traces;
  final BehaviorState state;
  final BehaviorKind kind;

  /// The two-cycle lane tag the row carries (spec 1008-two-cycle-driver,
  /// issue #1008): `core`, `skin` or `both`, parsed from the ` [core]` /
  /// ` [skin]` / ` [both]` tags in the behavior cell (stripped from
  /// [description] exactly like `[persistence]`). Null = untagged — the
  /// engine-lane (CORE) default of the pre-split world; the split
  /// receipt and the 04-ENGINE.md / 04-SKIN.md plan pair (#1000)
  /// override tags when present.
  final String? lane;

  /// Whether the plan marked the behavior persistence-kind with the
  /// ` [persistence]` tag (bug #833). The tag is stripped from
  /// [description] so generated assertion prose never leaks it.
  final bool persistence;

  /// The subject function this behavior targets. Never empty: rows
  /// without an explicit target resolve to `subject_<snake-id>`
  /// (moved here from gen's private parser, bug #617).
  final String target;

  @override
  String toString() =>
      'BehaviorRow(id: $id, kind: ${kind.name}, state: ${state.name}, '
      'persistence: $persistence, lane: $lane, traces: $traces)';
}

/// The `[persistence]` marker contract (bug #833).
///
/// The plan marks a behavior persistence-kind by appending ` [persistence]`
/// to the behavior cell; the shared reader parses the mark into
/// [BehaviorRow.persistence] and strips it from the description prose. The
/// marker lives here — the SINGLE format contract — so plan (mark), reader
/// (parse) and any tooling agree on the exact tag shape.
class PersistenceMarker {
  const PersistenceMarker._();

  /// The exact tag appended by plan and parsed by the reader.
  static const String tag = '[persistence]';

  /// The word list plan uses to decide which behaviors are
  /// persistence-kind: a behavior description naming any of these gets the
  /// tag. Tight by design — false positives only change the generated test
  /// shape, never correctness.
  static const Set<String> keywords = {
    'hive',
    'cache',
    'ttl',
    'persist',
    'offline',
    'corrupt',
    'registrar',
  };

  /// Whether [description] carries the marker.
  static bool isMarked(String description) =>
      description.toLowerCase().contains(tag);

  /// Whether [description] names a persistence keyword (the plan's marking
  /// rule).
  static bool matchesKeywords(String description) {
    final lower = description.toLowerCase();
    return keywords.any(lower.contains);
  }

  /// Append the tag to [description]; idempotent — an already-marked
  /// description is returned unchanged.
  static String mark(String description) {
    final trimmed = description.trim();
    if (isMarked(trimmed)) return trimmed;
    return '$trimmed $tag';
  }

  /// Split a behavior cell into (description, persistence): the tag is
  /// removed wherever it sits, everything else is kept verbatim.
  static (String, bool) extract(String cell) {
    var text = cell;
    var marked = false;
    while (true) {
      final idx = text.toLowerCase().indexOf(tag);
      if (idx < 0) break;
      marked = true;
      text = text.substring(0, idx) + text.substring(idx + tag.length);
    }
    if (!marked) return (cell, false);
    return (text.replaceAll(RegExp(r'\s+'), ' ').trim(), true);
  }
}

/// Raised when the test list cannot be read or a row is malformed. The
/// message names the file and — for malformed rows — the line number and
/// content (U3).
class TestListReadException implements Exception {
  const TestListReadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One entity row of the test list's `## Key entities` section (bug
/// #829): the entity name plus the spec-carried `name: Type` fields plan
/// extracted from the spec's Key Entities prose (empty when none).
class DeclaredEntity {
  const DeclaredEntity({required this.name, this.fields = const []});

  final String name;

  /// `name:Type` field strings exactly as plan rendered them (e.g.
  /// `name:String`), ready for `zfa entity create --field <f>`.
  final List<String> fields;

  @override
  String toString() => 'DeclaredEntity(name: $name, fields: $fields)';
}

class TestListReader {
  const TestListReader(this.featureDir);

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// Parse `tdd/test-list.md` into rows, in list order.
  ///
  /// Issue #1000: when the test list is a lane META-INDEX (a
  /// `## Lane split` section pointing at the lane plans), the rows
  /// resolve from `tdd/04-ENGINE.md` then `tdd/04-SKIN.md` — the
  /// engine file first so a BOTH-lane behavior's id resolves exactly
  /// once (its skin copy is skipped by id). Legacy lists parse exactly
  /// as before — the split is transparent to every consumer.
  Future<List<BehaviorRow>> read() async {
    final file = File(p.join(featureDir, 'tdd', 'test-list.md'));
    if (!await file.exists()) {
      throw TestListReadException(
        'no test list at ${file.path} — run `zfa tdd plan <feature>` first',
      );
    }
    final content = await file.readAsString();
    final split = LaneSplitFiles.find(content);
    if (split == null) {
      return _parseRows(content, path: file.path);
    }
    final rows = <BehaviorRow>[];
    final seen = <String>{};
    for (final name in [split.engine, split.skin]) {
      final laneFile = File(p.join(featureDir, 'tdd', name));
      if (!await laneFile.exists()) {
        throw TestListReadException(
          'lane split: plan file ${laneFile.path} (pointed at by '
          '${file.path}) does not exist — re-run `zfa tdd plan <feature>`',
        );
      }
      for (final row in _parseRows(
        await laneFile.readAsString(),
        path: laneFile.path,
      )) {
        // BOTH-lane behaviors appear in both files; the engine copy
        // (read first) is the row of record.
        if (seen.add(row.id)) rows.add(row);
      }
    }
    return rows;
  }

  /// The single-file row parser (bug #617): the line walk every list
  /// shape funnels through — section headers set the kind, declarative
  /// sections are skipped, table rows parse in the canonical 4-column
  /// or deprecated 6-column shapes.
  List<BehaviorRow> _parseRows(String content, {required String path}) {
    final lines = content.split('\n');
    final rows = <BehaviorRow>[];
    BehaviorKind? kind;
    var inDeclarativeSection = false;
    // Spec 1008 (two-cycle driver): the note is per-FILE guidance, and one
    // CLI invocation may read the same list more than once (the meta
    // `zfa tdd run` resolves lanes once per lane pass). Print it once per
    // process per file — separate processes (separate commands) each
    // print their own, exactly as before.
    var deprecatedDialectWarned = _deprecationNotedFiles.contains(path);
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final trimmed = raw.trim();
      if (trimmed.startsWith('## ')) {
        final header = trimmed.substring(3).toLowerCase();
        if (header.startsWith('outer loop')) {
          // Bug #830: `## Outer loop: widget behaviors` marks the UI
          // acceptance section — its rows are widget kind, still outer-loop
          // (acceptance-level) but asserted through a testWidgets pair.
          kind = header.contains('widget')
              ? BehaviorKind.widget
              : BehaviorKind.acceptance;
        } else if (header.startsWith('inner loop')) {
          kind = BehaviorKind.unit;
        } else if (header.startsWith('theme harness')) {
          // Theme-harness section (issue #841): theme-kind behaviors whose
          // gen pair is the theme-harness widget test + subject contract.
          kind = BehaviorKind.theme;
        } else if (header.startsWith('native loop')) {
          // Bug #835: the native loop section carries FFI/OCR
          // native-boundary behaviors. Rows under it are ffi-kind.
          kind = BehaviorKind.ffi;
        } else if (header.startsWith('platform harness')) {
          // Platform-harness section (issue #831): platform-kind behaviors
          // whose gen pair drives a platform channel through the certified
          // fake + committed scenario written by `zfa tdd fake`.
          kind = BehaviorKind.platform;
        } else if (header.startsWith('contract loop')) {
          // Contract-loop section (issue #1007): CONTRACT-kind behaviors —
          // one declared entity method, controller method or usecase per
          // row, written by plan from the spec's Layer Contracts section.
          // A failing contract test is BLOCKED (never RED), so this lane
          // never feeds the red-evidence path (verify-red refuses to
          // certify contract reds; the blocked receipt is the record).
          kind = BehaviorKind.contract;
        } else {
          kind = null;
        }
        // Bug #829: the Key entities section carries ENTITY rows, not
        // behavior rows — skip them instead of rejecting them as
        // malformed (plan writes the section; the reader is the single
        // format contract and must speak every shape plan writes).
        // Bug #937: the same contract covers the External dependencies
        // and Layer contracts sections #926 taught plan to render —
        // their rows are declarations, not behaviors; parsing them as
        // behavior rows killed `zfa tdd run` (exit 2) on every
        // deps-declaring (zuraffa-1.0) spec.
        // Issue #1000: the Lane split section of a meta-index carries
        // the pointer table — declarations, not behaviors.
        inDeclarativeSection =
            header.startsWith('key entities') ||
            header.startsWith('external dependencies') ||
            header.startsWith('layer contracts') ||
            header.startsWith('lane split') ||
            header.startsWith('adaptive view slots') ||
            header.startsWith('boundary') ||
            header.startsWith('shared seam behaviors');
        continue;
      }
      if (inDeclarativeSection) continue;
      if (!trimmed.startsWith('|')) continue;
      final cells = _splitRow(trimmed).map((c) => c.trim()).toList();
      // Bug #984: a bare ` |` line between table groups (e.g. between a
      // sub-heading and the next table) splits into all-empty cells. It
      // is whitespace between sections, not a malformed row — skipping it
      // keeps committed test-lists with this spacing running instead of
      // stopping `zfa tdd run` with "expected 4 columns, found 0".
      if (cells.every((c) => c.isEmpty)) continue;
      if (cells.length > 1 && cells.last.isEmpty) cells.removeLast();
      // Separator rows (`| -- | --- | ...`).
      final isSeparator = cells
          .skip(1)
          .any((c) => c.isNotEmpty && RegExp(r'^-+$').hasMatch(c));
      if (isSeparator) continue;
      // Header rows (`| id | behavior | ...`).
      if (cells.length > 1 && cells[1].toLowerCase() == 'id') continue;
      final (row: row, dialect: dialect) = _parseDataRow(
        cells,
        kind: kind,
        lineNo: i + 1,
        raw: raw,
      );
      if (row != null) rows.add(row);
      // Bug #649: only gen's old dialect warns. The tdd extension's own
      // hand-written shape (specs/044–049, spec 050 FR-007) is
      // spec-sanctioned for one release and reads silently — the user
      // did nothing wrong.
      if (dialect == _DeprecatedDialect.genLegacy && !deprecatedDialectWarned) {
        deprecatedDialectWarned = true;
        _deprecationNotedFiles.add(path);
        stderr.writeln(
          'zfa: $path: deprecated 6-column test-list rows detected '
          '(id/behavior/traces/kind/state/target). Migrate by manually '
          'converting tdd/test-list.md to the canonical 4-column shape '
          '(id/behavior/traces/state); the 6-column dialect is accepted '
          'for one release.',
        );
      }
    }
    return rows;
  }

  /// The content that carries the plan's declaration sections (Key
  /// entities / External dependencies / Layer contracts): the test
  /// list itself, or — for a lane-split feature (issue #1000) — the
  /// ENGINE plan the meta-index points at (plan writes the spec-wide
  /// declarations into the engine file). Empty when neither exists.
  Future<String> _sectionsSource() async {
    final file = File(p.join(featureDir, 'tdd', 'test-list.md'));
    if (!await file.exists()) return '';
    final content = await file.readAsString();
    final split = LaneSplitFiles.find(content);
    if (split != null) {
      final engine = File(p.join(featureDir, 'tdd', split.engine));
      if (await engine.exists()) return await engine.readAsString();
    }
    return content;
  }

  /// Parse the `## Key entities` section plan writes (bug #829). Lenient
  /// by design: a list without the section yields an empty list (every
  /// pre-829 artifact), and rows that do not carry a name cell are
  /// skipped rather than rejected — the section is an extraction aid,
  /// not a behavior contract.
  Future<List<DeclaredEntity>> readEntities() async {
    final specMd = await _sectionsSource();
    if (specMd.isEmpty) return const [];
    final lines = specMd.split('\n');
    final entities = <DeclaredEntity>[];
    var inEntitySection = false;
    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('## ')) {
        inEntitySection = trimmed
            .substring(3)
            .toLowerCase()
            .startsWith('key entities');
        continue;
      }
      if (!inEntitySection) continue;
      if (!trimmed.startsWith('|')) continue;
      final cells = _splitRow(trimmed).map((c) => c.trim()).toList();
      if (cells.length < 3) continue; // needs a leading empty + 2 cells
      final first = cells[1];
      // Separator and header rows.
      if (first.isEmpty || RegExp(r'^-+$').hasMatch(first)) continue;
      if (first.toLowerCase() == 'entity') continue;
      final fields = cells.length > 2 && cells[2].isNotEmpty
          ? cells[2]
                .split(',')
                .map(
                  // Normalize `name: Type` to `name:Type` — the argv
                  // shape `zfa entity create --field` parses.
                  (f) {
                    final idx = f.indexOf(':');
                    if (idx < 0) return f.trim();
                    return '${f.substring(0, idx).trim()}:'
                        '${f.substring(idx + 1).trim()}';
                  },
                )
                .where((f) => f.isNotEmpty)
                .toList()
          : const <String>[];
      entities.add(DeclaredEntity(name: first, fields: fields));
    }
    return entities;
  }

  /// Parse the `## External dependencies` section plan writes (bug #919).
  /// Lenient like [readEntities]: a list without the section yields an
  /// empty list (every pre-919 artifact); header/separator rows and rows
  /// without a dependency name are skipped rather than rejected.
  Future<List<SpecDependency>> readDependencies() async {
    final specMd = await _sectionsSource();
    if (specMd.isEmpty) return const [];
    final lines = specMd.split('\n');
    final dependencies = <SpecDependency>[];
    var inSection = false;
    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('## ')) {
        inSection = trimmed
            .substring(3)
            .toLowerCase()
            .startsWith('external dependencies');
        continue;
      }
      if (!inSection || !trimmed.startsWith('|')) continue;
      final cells = _splitRow(trimmed).map((c) => c.trim()).toList();
      // Leading empty cell + the four data cells.
      if (cells.length < 5) continue;
      final first = cells[1];
      if (first.isEmpty || RegExp(r'^-+$').hasMatch(first)) continue;
      if (first.toLowerCase() == 'dependency') continue;
      dependencies.add(
        SpecDependency(
          dependency: first,
          type: cells[2],
          contract: cells[3],
          mockPriority: cells[4],
        ),
      );
    }
    return dependencies;
  }

  /// Parse the `## Layer contracts` section plan writes (bug #919):
  /// `### <layer>` headings and `- `<interface>`: `sig1`, `sig2``
  /// bullets beneath them.
  Future<List<LayerContract>> readLayerContracts() async {
    final specMd = await _sectionsSource();
    if (specMd.isEmpty) return const [];
    final lines = specMd.split('\n');
    final contracts = <LayerContract>[];
    var inSection = false;
    var layer = '';
    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('## ')) {
        inSection = trimmed
            .substring(3)
            .toLowerCase()
            .startsWith('layer contracts');
        if (!inSection) layer = '';
        continue;
      }
      if (!inSection || trimmed.isEmpty) continue;
      final layerM = RegExp(r'^###\s+(.+)$').firstMatch(trimmed);
      if (layerM != null) {
        layer = layerM.group(1)!.trim();
        continue;
      }
      final bullet = RegExp(
        r'^\s*[-*]\s+`([^`]+)`\s*:\s*(.+)$',
      ).firstMatch(trimmed);
      if (bullet == null || layer.isEmpty) continue;
      contracts.add(
        LayerContract(
          layer: layer,
          interfaceName: bullet.group(1)!.trim(),
          methods: RegExp(r'`([^`]+)`')
              .allMatches(bullet.group(2)!)
              .map((m) => m.group(1)!.trim())
              .toList(),
        ),
      );
    }
    return contracts;
  }

  /// Parse one data row. Returns the row (null when the line is a row
  /// shaped like a deprecated 6-column dialect but with an unusable
  /// kind cell — that falls through to the malformed error) plus which
  /// deprecated dialect the row used, if any (bug #649).
  ({BehaviorRow? row, _DeprecatedDialect dialect}) _parseDataRow(
    List<String> cells, {
    required BehaviorKind? kind,
    required int lineNo,
    required String raw,
  }) {
    Never malformed(String reason) => throw TestListReadException(
      'test-list.md line $lineNo: $reason: "$raw"',
    );

    // Canonical 4-column row: `| id | behavior | traces | state |`
    // (cells[0] is the empty string before the leading pipe).
    if (cells.length == 5) {
      if (kind == null) {
        malformed('table row outside an outer/inner loop behavior section');
      }
      final id = cells[1];
      if (id.isEmpty) malformed('empty behavior id');
      final state = _parseState(cells[4]);
      if (state == null) malformed('unknown state "${cells[4]}"');
      final (description, persistence) = PersistenceMarker.extract(cells[2]);
      final (untagged, lane) = LaneMarker.extract(description);
      return (
        row: BehaviorRow(
          id: id,
          description: untagged,
          traces: cells[3],
          state: state,
          kind: kind,
          target: resolveDefaultTarget(id),
          persistence: persistence,
          lane: lane,
        ),
        dialect: _DeprecatedDialect.none,
      );
    }

    // Deprecated 6-column row, dialect 1 (gen's old private dialect):
    // `| id | behavior | traces | kind | state | target |`. Only rows
    // whose kind cell is a loop kind (acceptance/unit/ffi — bug #835
    // adds the native-boundary kind) take the shim;
    // anything else falls through.
    if (cells.length == 7) {
      final kindFromCell = _kindFromCell(cells[4]);
      if (kindFromCell != null) {
        final id = cells[1];
        if (id.isEmpty) malformed('empty behavior id');
        final state = _parseState(cells[5]);
        if (state == null) malformed('unknown state "${cells[5]}"');
        final (description, persistence) = PersistenceMarker.extract(cells[2]);
        final (untagged, lane) = LaneMarker.extract(description);
        return (
          row: BehaviorRow(
            id: id,
            description: untagged,
            traces: cells[3],
            state: state,
            kind: kindFromCell,
            target: resolveDefaultTarget(id, cell: cells[6]),
            persistence: persistence,
            lane: lane,
          ),
          dialect: _DeprecatedDialect.genLegacy,
        );
      }

      // Deprecated 6-column row, dialect 2 (the tdd extension's own
      // hand-written shape, specs/044–049; spec 050 FR-007): the kind
      // cell names the test SHAPE, not the loop, so the loop kind comes
      // from the section header (required — an orphaned row cannot
      // infer one) and the last cell is a test reference (path-like or
      // empty -> the default target).
      if (_isExtensionTestShape(cells[4])) {
        if (kind == null) {
          malformed('table row outside an outer/inner loop behavior section');
        }
        final id = cells[1];
        if (id.isEmpty) malformed('empty behavior id');
        final state = _parseState(cells[5]);
        if (state == null) malformed('unknown state "${cells[5]}"');
        final (description, persistence) = PersistenceMarker.extract(cells[2]);
        final (untagged, lane) = LaneMarker.extract(description);
        return (
          row: BehaviorRow(
            id: id,
            description: untagged,
            traces: cells[3],
            state: state,
            kind: kind,
            target: resolveDefaultTarget(id, cell: cells[6]),
            persistence: persistence,
            lane: lane,
          ),
          dialect: _DeprecatedDialect.extensionShape,
        );
      }
    }

    malformed(
      'expected 4 columns (id/behavior/traces/state), '
      'found ${cells.length - 1}',
    );
  }

  /// The subject function this behavior targets (moved from gen's private
  /// parser, bug #617): an explicit non-path cell wins; an empty or
  /// path-like cell (`/`, `::`, `$`) falls back to `subject_<snake-id>`.
  ///
  /// Issue #1007: the snake-id fold now covers EVERY non-alphanumeric
  /// character (not just `-`), so the `contract:A1` ids plan writes for
  /// contract rows resolve to a valid Dart identifier
  /// (`subject_contract_a1`, never `subject_contract:a1` — the `:` leaked
  /// into the generated subject's function name before, and the pair died
  /// at compile). Existing id shapes (`A1`, `B-001`) fold identically to
  /// the previous `replaceAll('-', '_')` behavior.
  static String resolveDefaultTarget(String id, {String cell = ''}) {
    final isPathLike =
        cell.isEmpty ||
        cell.contains('/') ||
        cell.contains('::') ||
        cell.contains(r'$');
    if (isPathLike) {
      final snakeId = id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      return 'subject_$snakeId';
    }
    return cell;
  }

  static BehaviorKind? _kindFromCell(String cell) {
    final kindStr = cell.toLowerCase();
    if (kindStr.contains('acceptance')) return BehaviorKind.acceptance;
    if (kindStr.contains('unit')) return BehaviorKind.unit;
    // Bug #830: the widget subject kind — an outer-loop behavior whose
    // paired artifacts are a view-builder stub + a testWidgets test.
    if (kindStr.contains('widget')) return BehaviorKind.widget;
    // Theme-harness kind cell (issue #841). Checked after the loop kinds:
    // 'theme' contains neither 'acceptance' nor 'unit', so the order is
    // only about readability.
    if (kindStr.contains('theme')) return BehaviorKind.theme;
    // Bug #835: the native-boundary kind, declared by hand in the kind
    // cell (dialect 1) or via a `## Native loop` section header. No
    // other kind-cell substring collides with "ffi".
    if (kindStr.contains('ffi')) return BehaviorKind.ffi;
    // Platform-harness kind cell (issue #831). Last: 'platform' shares no
    // substring with the kinds above, so ordering is purely cosmetic.
    if (kindStr.contains('platform')) return BehaviorKind.platform;
    return null;
  }

  /// Whether a 6-column row's kind cell names one of the tdd extension's
  /// test SHAPES (spec 050 FR-007): `example`, `property`, `contract`,
  /// `approval`, or `characterization`. These describe the shape of the
  /// test, not its loop, so the row's kind still comes from the section
  /// header.
  static bool _isExtensionTestShape(String cell) => const {
    'example',
    'property',
    'contract',
    'approval',
    'characterization',
  }.contains(cell.trim().toLowerCase());

  static BehaviorState? _parseState(String cell) {
    for (final state in BehaviorState.values) {
      if (state.name == cell.toLowerCase()) return state;
    }
    // The tdd extension's verification verdict, seen on deprecated
    // 6-column rows (specs/044 B-003): `PROVEN` means the audit proved
    // the cycle — completed work — so it maps to the driver's `done`
    // (spec 050, SC-002). Canonical plan rows never carry it (plan
    // writes PENDING); every other extension bookkeeping state stays
    // malformed so drift keeps surfacing.
    if (cell.trim().toLowerCase() == 'proven') return BehaviorState.done;
    return null;
  }

  /// Split a table row on UNESCAPED pipes: markdown's `\|` inside a cell
  /// is a literal pipe, not a delimiter (spec 050; specs/049's hand-written
  /// U15 row carries `outcome=clean\|refactored` in its behavior text —
  /// a naive `split('|')` mis-counts 7 data columns and rejects the row).
  static List<String> _splitRow(String line) {
    final cells = <String>[];
    final buf = StringBuffer();
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == r'\' && i + 1 < line.length && line[i + 1] == '|') {
        buf.write('|');
        i++;
      } else if (ch == '|') {
        cells.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    cells.add(buf.toString());
    return cells;
  }
}

/// Which deprecated 6-column dialect a data row uses (bug #649): gen's
/// old private dialect is genuinely legacy and warns once per file with
/// manual migration advice; the tdd extension's own hand-written shape
/// (specs/044–049, spec 050 FR-007) is spec-sanctioned and reads
/// silently.
enum _DeprecatedDialect { none, genLegacy, extensionShape }

/// The test-list/plan files this process already printed the gen-legacy
/// deprecation note for (spec 1008: one note per file per process — the
/// two-cycle driver reads the list once per lane pass).
final Set<String> _deprecationNotedFiles = {};
