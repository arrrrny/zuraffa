/// Lane resolution for the two-cycle driver (spec 1008-two-cycle-driver,
/// issue #1008): which behaviors belong to the ENGINE lane (CORE + BOTH)
/// and which to the SKIN lane (SKIN + BOTH).
///
/// #1000 (the plan split) has landed, so lane truth comes from its
/// artifacts first, in priority order:
///
/// 1. **The split receipt** — `tdd/split-receipt.json` (written by
///    `zfa tdd split` / `zfa tdd plan`): the authoritative
///    `classification` map (behavior id -> CORE | SKIN | BOTH).
/// 2. **Plan files** — `tdd/04-ENGINE.md` and `tdd/04-SKIN.md`, the
///    split plan pair. Behavior ids are parsed from markdown table data
///    rows (first cell) and `- <id>` bullets. An id present in both
///    files is a BOTH behavior (engine plan carries CORE+BOTH, skin
///    plan SKIN+BOTH — the intersection IS the BOTH set). Ids in neither
///    file default to the engine lane (CORE): the engine is the
///    superset lane of the pre-split world.
/// 3. **Row tags** — ` [core]` / ` [skin]` / ` [both]` tags in the test
///    list's behavior cell, parsed and stripped by [TestListReader]
///    exactly like `[persistence]` (the single-format-contract way, bug
///    #617). A feature with no tags and no split artifacts is LEGACY:
///    every behavior is engine-lane (CORE), the skin lane is empty, and
///    `zfa tdd run` behaves byte-compatibly with the pre-split driver.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'lane_split.dart';
import 'test_list_reader.dart';

/// The lane marker contract for test-list behavior cells: ` [core]`,
/// ` [skin]`, ` [both]` (mirrors [PersistenceMarker]).
class LaneMarker {
  const LaneMarker._();

  static const coreTag = '[core]';
  static const skinTag = '[skin]';
  static const bothTag = '[both]';

  /// Strip every lane tag from [cell], returning the cleaned description
  /// and the last declared lane (null when untagged — the CORE default).
  static (String, String?) extract(String cell) {
    var text = cell;
    String? lane;
    for (final tag in [coreTag, skinTag, bothTag]) {
      while (true) {
        final idx = text.indexOf(tag);
        if (idx < 0) break;
        lane = _laneForTag(tag);
        text = text.substring(0, idx) + text.substring(idx + tag.length);
      }
    }
    if (identical(text, cell)) return (cell, null);
    return (text.replaceAll(RegExp(r'\s+'), ' ').trim(), lane);
  }

  static String? _laneForTag(String tag) => switch (tag) {
    coreTag => 'core',
    skinTag => 'skin',
    bothTag => 'both',
    _ => null,
  };
}

/// The resolved lane assignment for one feature.
class LaneAssignment {
  const LaneAssignment({
    required this.engineIds,
    required this.skinIds,
    required this.fromPlanFiles,
  });

  /// CORE + BOTH behavior ids (the engine plan's rows).
  final Set<String> engineIds;

  /// SKIN + BOTH behavior ids (the skin plan's rows).
  final Set<String> skinIds;

  /// Whether the 04-ENGINE.md / 04-SKIN.md plan pair was the source (vs
  /// row tags / the legacy CORE default).
  final bool fromPlanFiles;
}

class LanePlanReader {
  const LanePlanReader(this.featureDir);

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// Resolve the lane assignment for [rows] (the full test list, in list
  /// order — ids not present in the rows are ignored by the callers).
  Future<LaneAssignment> resolve(List<BehaviorRow> rows) async {
    // 1. The split receipt (issue #1000): the authoritative classification.
    final fromReceipt = await _readSplitReceipt();
    if (fromReceipt != null) return fromReceipt;
    // 2. The plan pair (issue #1000): ids in ENGINE.md / SKIN.md.
    final enginePlan = await _readPlanFile(LaneSplitFiles.engine);
    final skinPlan = await _readPlanFile(LaneSplitFiles.skin);
    if (enginePlan != null || skinPlan != null) {
      return LaneAssignment(
        engineIds: enginePlan ?? const {},
        skinIds: skinPlan ?? const {},
        fromPlanFiles: true,
      );
    }
    // 3. Row tags (or the legacy CORE default: untagged = engine).
    final engine = <String>{};
    final skin = <String>{};
    for (final row in rows) {
      switch (row.lane) {
        case 'skin':
          skin.add(row.id);
        case 'both':
          engine.add(row.id);
          skin.add(row.id);
        default:
          engine.add(row.id);
      }
    }
    return LaneAssignment(
      engineIds: engine,
      skinIds: skin,
      fromPlanFiles: false,
    );
  }

  /// The `classification` map from `tdd/split-receipt.json` (issue
  /// #1000's `zfa tdd split`): behavior id -> CORE | SKIN | BOTH. Null
  /// when the receipt is absent; a present-but-unreadable receipt is
  /// ignored (the plan pair / tags / legacy default still resolve).
  Future<LaneAssignment?> _readSplitReceipt() async {
    final file = File(p.join(featureDir, 'tdd', LaneSplitFiles.receipt));
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final classification = decoded['classification'];
      if (classification is! Map) return null;
      final engine = <String>{};
      final skin = <String>{};
      classification.forEach((id, lane) {
        if (id is! String || lane is! String) return;
        switch (lane.toUpperCase()) {
          case 'CORE':
            engine.add(id);
          case 'SKIN':
            skin.add(id);
          case 'BOTH':
            engine.add(id);
            skin.add(id);
        }
      });
      if (engine.isEmpty && skin.isEmpty) return null;
      return LaneAssignment(
        engineIds: engine,
        skinIds: skin,
        fromPlanFiles: true,
      );
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  /// Behavior ids parsed from one plan file: markdown table data rows
  /// (first non-empty cell) and `- <id>` bullets. Header rows (`id`,
  /// `behavior`), separator rows, and id-shaped-but-empty cells are
  /// skipped.
  Future<Set<String>?> _readPlanFile(String name) async {
    final file = File(p.join(featureDir, 'tdd', name));
    if (!await file.exists()) return null;
    final ids = <String>{};
    for (final raw in (await file.readAsString()).split('\n')) {
      final line = raw.trim();
      final id = _rowId(line);
      if (id != null) ids.add(id);
    }
    return ids;
  }

  /// The behavior id carried by one plan-file line, or null when the line
  /// is not a table data row / bullet naming a behavior id.
  static String? _rowId(String line) {
    // Table row: `| <id> | ...` — cells split on unescaped pipes (the same
    // rule the test-list reader applies, spec 050).
    if (line.startsWith('|')) {
      final cells = _splitRow(line).map((c) => c.trim()).toList();
      if (cells.length > 1 && cells.last.isEmpty) cells.removeLast();
      // Separator rows.
      final isSeparator = cells
          .skip(1)
          .any((c) => c.isNotEmpty && RegExp(r'^-+$').hasMatch(c));
      if (isSeparator) return null;
      if (cells.length < 2) return null;
      final first = cells[1];
      if (first.isEmpty) return null;
      final lower = first.toLowerCase();
      if (lower == 'id' || lower == 'behavior') return null;
      return _isBehaviorId(first) ? first : null;
    }
    // Bullet: `- <id>` / `- <id>: ...`.
    final bullet = RegExp(
      r'^[-*]\s+([A-Za-z][\w-]*)(?::|\s|$)',
    ).firstMatch(line);
    if (bullet == null) return null;
    final id = bullet.group(1)!;
    return _isBehaviorId(id) ? id : null;
  }

  /// Behavior-id shape: starts with a letter, short, and carries a digit,
  /// dash or underscore — tight enough to keep plan prose (`The`, `engine`,
  /// `skin`) out, loose enough for `A1`, `U12`, `W1`, `B-001`, `FR-003`.
  static bool _isBehaviorId(String id) =>
      RegExp(r'^[A-Za-z][A-Za-z0-9_-]{0,15}$').hasMatch(id) &&
      RegExp(r'\d|[-_]').hasMatch(id);

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
