/// The lane-split plan emission shared by `zfa tdd plan` and
/// `zfa tdd split` (issue #1000).
///
/// A Lanes-declaring spec plans into THREE files instead of the single
/// behavior table:
///
/// - `tdd/04-ENGINE.md` — behaviors whose lane is CORE or BOTH. Pure
///   Dart by construction: the noFlutter guard (plan) and the renderers
///   here never write a Flutter import into this file.
/// - `tdd/04-SKIN.md` — behaviors whose lane is SKIN or BOTH, plus the
///   AdaptiveViewSlots the spec's SKIN lane declares.
/// - `tdd/04-CONTRACT.md` — the engine/skin seam: the boundary
///   statement, the AdaptiveViewSlots, and the BOTH-lane shared
///   behaviors.
///
/// The legacy `tdd/test-list.md` becomes the META-INDEX: no behavior
/// rows, just the lane table and the pointers to the three files.
/// [TestListReader] detects the meta-index and resolves rows from the
/// split files, so gen/make/run keep working unmodified.
library;

import 'dart:convert';

import '../../../skin/contract/adaptive_skin_contract.dart';
import '../models/behavior.dart';
import '../models/lane.dart';
import 'spec_parser.dart';
import 'test_list_reader.dart' show GoldenMarker;

/// The lane-split plan file names (issue #1000 naming).
class LaneSplitFiles {
  const LaneSplitFiles._();

  /// The engine plan: behaviors whose lane is CORE or BOTH.
  static const String engine = '04-ENGINE.md';

  /// The skin plan: behaviors whose lane is SKIN or BOTH.
  static const String skin = '04-SKIN.md';

  /// The engine/skin contract: AdaptiveViewSlots + the BOTH seam.
  static const String contract = '04-CONTRACT.md';

  /// The one-shot migration receipt (`zfa tdd split`).
  static const String receipt = 'split-receipt.json';

  /// The meta-index section header in `test-list.md` — the machine
  /// marker [find] keys on.
  static const String metaSection = '## Lane split';

  /// The meta-index pointer line prefixes.
  static const String enginePointer = 'engine plan';
  static const String skinPointer = 'skin plan';
  static const String contractPointer = 'engine/skin contract';

  static final RegExp _pointer = RegExp(
    r'^\s*[-*]\s*(engine\s+plan|skin\s+plan|engine/skin\s+contract)\s*:\s*'
    r'`?([^`\n]+?)`?\s*$',
    caseSensitive: false,
  );

  /// Resolve the meta-index pointers of [content]: the (engine, skin)
  /// file names when [content] is a lane meta-index, null when it is a
  /// legacy behavior table. The detection requires BOTH the
  /// `## Lane split` section and the engine + skin pointer lines —
  /// legacy lists never carry the pointer shape.
  static ({String engine, String skin})? find(String content) {
    if (!RegExp(
      r'^#{1,6}\s+lane split\s*$',
      multiLine: true,
      caseSensitive: false,
    ).hasMatch(content)) {
      return null;
    }
    String? engine;
    String? skin;
    for (final line in content.split('\n')) {
      final m = _pointer.firstMatch(line);
      if (m == null) continue;
      final kind = m.group(1)!.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final value = m.group(2)!.trim();
      if (kind == enginePointer) engine = value;
      if (kind == skinPointer) skin = value;
    }
    if (engine == null || skin == null) return null;
    return (engine: engine, skin: skin);
  }
}

/// One plan row destined for a lane file — the common input shape
/// `plan` (from its derived [Behavior]s) and `split` (from the prior
/// list's [BehaviorRow]s) both construct.
class LaneRow {
  const LaneRow({
    required this.id,
    required this.description,
    required this.traces,
    required this.state,
    required this.kind,
    required this.lane,
    this.golden = false,
  });

  final String id;
  final String description;
  final String traces;
  final String state;
  final BehaviorKind kind;
  final Lane lane;

  /// Bug #1261: whether the behavior is golden-gated — the SKIN lane's
  /// `golden:` declaration resolved onto this row. Rendered as the
  /// ` [golden]` tag in the row's behavior cell (the same machine shape
  /// as ` [persistence]`, parsed by [GoldenMarker] in the shared
  /// reader); gen turns the tag into the matchesGoldenFile hook without
  /// the `--golden` flag.
  final bool golden;

  /// The canonical 4-column row line every lane plan table carries.
  String get tableLine =>
      '| $id | ${golden ? GoldenMarker.mark(description) : description} '
      '| $traces | $state |';
}

/// Render the ENGINE plan (`04-ENGINE.md`).
///
/// PURE DART BY CONSTRUCTION: nothing this renderer writes may name a
/// Flutter import — the noFlutter guard rejected the offending behaviors
/// upstream, and the prose stays on the word "Flutter" (never the
/// package URI) so the exit criterion's scan stays clean.
String renderEnginePlan({
  required String feature,
  required List<LaneRow> rows,
  List<SpecEntity> entities = const [],
  List<SpecDependency> dependencies = const [],
  List<LayerContract> layerContracts = const [],
  Map<String, List<String>> provenance = const {},
}) {
  final acceptance = rows
      .where(
        (r) =>
            r.kind == BehaviorKind.acceptance ||
            // Issue #1432: a platform-typed acceptance scenario routes to
            // this lane — it renders as an outer-loop row with the same
            // columns as the acceptance rows (the loop's reader resolves
            // it with the same positional contract). Filtering it out was
            // the silent drop: the route log claimed the lane while the
            // artifact omitted the row.
            r.kind == BehaviorKind.platform,
      )
      .toList();
  final widget = rows.where((r) => r.kind == BehaviorKind.widget).toList();
  final unit = rows.where((r) => r.kind == BehaviorKind.unit).toList();
  final ffi = rows.where((r) => r.kind == BehaviorKind.ffi).toList();

  final buf = StringBuffer()
    ..writeln('# Engine Plan: $feature (CORE + BOTH)')
    ..writeln()
    ..writeln(
      'The engine lane (issue #1000): pure Dart — behaviors whose lane '
      'is CORE or BOTH. The noFlutter guard rejects any behavior that '
      'references Flutter at plan time, so this file stays engine-only.',
    )
    ..writeln();
  _section(
    buf,
    title: '## Outer loop: acceptance behaviors',
    intro: 'One per acceptance criterion in `spec.md`.',
    rows: acceptance,
  );
  _section(
    buf,
    title: '## Outer loop: widget behaviors',
    intro:
        'Seam-side acceptance scenarios whose engine copy asserts the '
        'engine half of the behavior.',
    rows: widget,
  );
  _section(
    buf,
    title: '## Inner loop: unit behaviors',
    intro: 'One per functional requirement in `spec.md`.',
    rows: unit,
  );
  _section(
    buf,
    title: '## Native loop: ffi behaviors',
    intro:
        'Native-boundary behaviors (bug #835) — engine-side by default '
        'lane assignment.',
    rows: ffi,
  );
  _declarations(buf, entities, dependencies, layerContracts);
  _provenance(buf, provenance);
  buf.writeln();
  return buf.toString();
}

/// Render the SKIN plan (`04-SKIN.md`).
///
/// Issue #1004: a spec declaring the adaptive `## Skin Contract`
/// section additionally renders the typed contract rows — the
/// platform matrix, the state machine, the route table — plus the
/// machine-parseable JSON contract block the loop referees the skin
/// against. A spec without the declaration ([skinContract] null)
/// renders exactly the pre-1004 shape.
String renderSkinPlan({
  required String feature,
  required List<LaneRow> rows,
  required List<String> adaptiveSlots,
  Map<String, List<String>> provenance = const {},
  AdaptiveSkinContract? skinContract,
}) {
  final acceptance = rows
      .where(
        (r) =>
            r.kind == BehaviorKind.acceptance ||
            // Issue #1432: same as the engine plan — the platform-typed
            // acceptance scenario is routed here, so its row renders in
            // the acceptance outer-loop section instead of vanishing.
            r.kind == BehaviorKind.platform,
      )
      .toList();
  final widget = rows.where((r) => r.kind == BehaviorKind.widget).toList();
  final unit = rows.where((r) => r.kind == BehaviorKind.unit).toList();

  final buf = StringBuffer()
    ..writeln('# Skin Plan: $feature (SKIN + BOTH)')
    ..writeln()
    ..writeln(
      'The skin lane (issue #1000): Flutter allowed — behaviors whose '
      'lane is SKIN or BOTH, plus the AdaptiveViewSlots the spec '
      'declares (the adaptive-layout contract slots the skin must '
      'provide).',
    )
    ..writeln();
  if (adaptiveSlots.isNotEmpty) {
    buf
      ..writeln('## Adaptive view slots')
      ..writeln()
      ..writeln('| slot |')
      ..writeln('| ---- |');
    for (final slot in adaptiveSlots) {
      buf.writeln('| $slot |');
    }
    buf.writeln();
  }
  if (skinContract != null) {
    _renderSkinContract(buf, skinContract, rows);
  }
  _section(
    buf,
    title: '## Outer loop: acceptance behaviors',
    intro: 'One per acceptance criterion in `spec.md`.',
    rows: acceptance,
  );
  _section(
    buf,
    title: '## Outer loop: widget behaviors',
    intro:
        'Skin behaviors (bug #830 / issue #1000): asserted through a '
        'testWidgets pair — includes the hand-declared lane rows (the '
        '`W` ids the `## Lanes` section reserves).',
    rows: widget,
  );
  _section(
    buf,
    title: '## Inner loop: unit behaviors',
    intro: 'One per functional requirement in `spec.md`.',
    rows: unit,
  );
  _renderVisualContract(buf, rows);
  _provenance(buf, provenance);
  buf.writeln();
  return buf.toString();
}

/// Render the ENGINE/SKIN CONTRACT (`04-CONTRACT.md`): the boundary
/// statement, the AdaptiveViewSlots, and the BOTH-lane shared seam.
String renderContractPlan({
  required String feature,
  required List<String> adaptiveSlots,
  required List<LaneRow> bothRows,
}) {
  final buf = StringBuffer()
    ..writeln('# Engine/Skin Contract: $feature')
    ..writeln()
    ..writeln(
      'The seam between `tdd/04-ENGINE.md` and `tdd/04-SKIN.md` '
      '(issue #1000).',
    )
    ..writeln()
    ..writeln('## Boundary')
    ..writeln()
    ..writeln(
      '- CORE (engine): pure Dart — zero Flutter references, '
      'plan-enforced.',
    )
    ..writeln('- SKIN (skin): Flutter allowed.')
    ..writeln(
      '- BOTH (seam): Flutter conditionally — one behavior, '
      'asserted on both sides of the seam.',
    )
    ..writeln();
  buf
    ..writeln('## Adaptive view slots')
    ..writeln()
    ..writeln('| slot | declared lane |')
    ..writeln('| ---- | ------------- |');
  if (adaptiveSlots.isEmpty) {
    buf.writeln('| (none declared) | - |');
  } else {
    for (final slot in adaptiveSlots) {
      buf.writeln('| $slot | SKIN |');
    }
  }
  buf
    ..writeln()
    ..writeln('## Shared seam behaviors (BOTH lane)')
    ..writeln()
    ..writeln(
      'Behaviors asserted on BOTH sides of the seam — their engine copy '
      'lives in `tdd/04-ENGINE.md`, their skin copy in '
      '`tdd/04-SKIN.md`.',
    )
    ..writeln()
    ..writeln('| id | behavior | traces |')
    ..writeln('| -- | -------- | ------ |');
  if (bothRows.isEmpty) {
    buf.writeln('| (none) | | |');
  } else {
    for (final row in bothRows) {
      buf.writeln('| ${row.id} | ${row.description} | ${row.traces} |');
    }
  }
  buf.writeln();
  return buf.toString();
}

/// Render the META-INDEX (`test-list.md`): the lane table + the
/// pointers. No behavior rows — they live in the lane plans.
String renderMetaIndex({
  required String feature,
  required List<LaneDeclaration> lanes,
  required Map<String, Lane> classification,
}) {
  final buf = StringBuffer()
    ..writeln('# Test List: $feature (meta-index)')
    ..writeln()
    ..writeln(
      'This feature\'s plan is split by lane (issue #1000): this file '
      'is the meta-index — the behavior rows live in the lane plans it '
      'points at.',
    )
    ..writeln()
    ..writeln(LaneSplitFiles.metaSection)
    ..writeln()
    ..writeln('| lane | behaviors | flutter allowed | golden | plan |')
    ..writeln('| ---- | --------- | --------------- | ------ | ---- |');
  for (final lane in lanes) {
    final declared = lane.behaviorIds.join(', ');
    final resolved = classification.entries
        .where((e) => e.value.label == lane.lane.toUpperCase())
        .map((e) => e.key)
        .join(', ');
    final golden = lane.goldenIds.isEmpty ? '-' : lane.goldenIds.join(', ');
    buf.writeln(
      '| ${lane.lane} | ${resolved.isNotEmpty ? resolved : declared} '
      '| ${lane.flutterAllowed.isEmpty ? '-' : lane.flutterAllowed} '
      '| $golden | ${_planColumn(lane.lane)} |',
    );
  }
  buf
    ..writeln()
    ..writeln('- ${LaneSplitFiles.enginePointer}: `${LaneSplitFiles.engine}`')
    ..writeln('- ${LaneSplitFiles.skinPointer}: `${LaneSplitFiles.skin}`')
    ..writeln(
      '- ${LaneSplitFiles.contractPointer}: `${LaneSplitFiles.contract}`',
    )
    ..writeln();
  return buf.toString();
}

String _planColumn(String laneName) {
  final lane = Lane.parse(laneName);
  if (lane == null) return '`?`';
  return switch (lane) {
    Lane.core => '`${LaneSplitFiles.engine}`',
    Lane.skin => '`${LaneSplitFiles.skin}`',
    Lane.both => '`${LaneSplitFiles.engine}` + `${LaneSplitFiles.skin}`',
  };
}

/// Renders the #1004 skin-contract sections into the SKIN plan: the
/// platform matrix, the state machine, the route table — each as
/// declarative rows [TestListReader] skips (declarations, not
/// behaviors) — plus the machine-parseable JSON contract block
/// generated from the typed model.
void _renderSkinContract(
  StringBuffer buf,
  AdaptiveSkinContract contract,
  List<LaneRow> skinRows,
) {
  final behaviors = skinRows.map((r) => r.id).join(', ');

  // -- Platform contract: the adaptive-layout platform matrix ------
  buf
    ..writeln('## Platform contract')
    ..writeln()
    ..writeln(
      'The adaptive-layout platform matrix (issue #1004): every SKIN '
      'behavior renders the declared slots on every adaptive '
      'platform; platform overrides refine the contract per platform.',
    )
    ..writeln()
    ..writeln('| platform | contract | behaviors | source |')
    ..writeln('| -------- | -------- | --------- | ------ |');
  for (final platform in contract.adaptiveSlots) {
    final overrides = contract.platformOverrides[platform];
    final statement = overrides == null || overrides.isEmpty
        ? 'renders the adaptive slots'
        : 'renders the adaptive slots; '
              '${overrides.entries.map((e) => '${e.key}: ${e.value}').join('; ')}';
    final source = overrides == null || overrides.isEmpty
        ? 'adaptive_slots'
        : 'adaptive_slots, platform_overrides.$platform';
    buf.writeln('| $platform | $statement | $behaviors | $source |');
  }
  buf.writeln();

  // -- State machine contract ---------------------------------------
  final happy = contract.happyPathStates;
  final alternates = contract.alternateStates;
  buf
    ..writeln('## State machine contract')
    ..writeln()
    ..writeln(
      'The declared state machine (issue #1004): the happy path runs '
      'the declared states in order — states: '
      '${happy.join(' -> ')}'
      '${alternates.isEmpty ? '' : ' (alternate states: ${alternates.join(', ')})'}.',
    )
    ..writeln()
    ..writeln('| state | transition | source |')
    ..writeln('| ----- | ---------- | ------ |');
  for (var i = 0; i < happy.length; i++) {
    final transition = i < happy.length - 1
        ? '${happy[i]} -> ${happy[i + 1]}'
        : 'terminal';
    buf.writeln('| ${happy[i]} | $transition | states |');
  }
  for (final state in alternates) {
    buf.writeln('| $state | alternate | states |');
  }
  buf.writeln();

  // -- Route contract ------------------------------------------------
  buf
    ..writeln('## Route contract')
    ..writeln()
    ..writeln(
      'The declared routes (issue #1004): navigation target, screen '
      'class, and route path for every route the skin can navigate '
      'to.',
    )
    ..writeln()
    ..writeln('| navigation target | screen class | route path | source |')
    ..writeln('| ----------------- | ------------ | ---------- | ------ |');
  for (final route in contract.routeContracts) {
    buf.writeln(
      '| ${route.target} | ${route.screenClass} | ${route.path} '
      '| routes |',
    );
  }
  buf.writeln();

  // -- The machine contract -------------------------------------------
  // Generated from the typed model (`toJson`), never hand-written:
  // the loop referees the skin against this block, not prose.
  const encoder = JsonEncoder.withIndent('  ');
  buf
    ..writeln('## Skin contract (machine)')
    ..writeln()
    ..writeln(
      'The typed contract (issue #1004): machine-parseable JSON '
      'generated from the typed model — schema-validated, never '
      'prose.',
    )
    ..writeln()
    ..writeln('```json')
    ..writeln(encoder.convert(contract.toJson()))
    ..writeln('```')
    ..writeln();
}

/// Renders the visual-contract section into the SKIN plan (bug #1261):
/// the golden-gated SKIN behaviors — the spec's `golden:` declaration
/// resolved onto the lane rows. The section is the human-readable
/// surface; the machine truth rides the rows' ` [golden]` tags (parsed
/// by the shared reader, honored by gen without the `--golden` flag).
void _renderVisualContract(StringBuffer buf, List<LaneRow> rows) {
  final goldenRows = rows.where((r) => r.golden).toList();
  if (goldenRows.isEmpty) return;
  buf
    ..writeln('## Visual contract')
    ..writeln()
    ..writeln(
      'Golden-gated skin behaviors (bug #1261): each row\'s generated '
      'widget test carries a matchesGoldenFile baseline hook — gen '
      'picks the gate up from the lane plan, no `--golden` flag '
      'needed. Baselines are committed per platform under '
      'test/tdd/goldens/ and refreshed with `flutter test '
      '--update-goldens`.',
    )
    ..writeln()
    ..writeln('| behavior | golden gate |')
    ..writeln('| -------- | ----------- |');
  for (final row in goldenRows) {
    buf.writeln('| ${row.id} | matchesGoldenFile |');
  }
  buf.writeln();
}

void _section(
  StringBuffer buf, {
  required String title,
  required String intro,
  required List<LaneRow> rows,
}) {
  if (rows.isEmpty) return;
  buf
    ..writeln(title)
    ..writeln()
    ..writeln(intro)
    ..writeln()
    ..writeln('| id | behavior | traces | state |')
    ..writeln('| -- | -------- | ------ | ----- |');
  for (final row in rows) {
    buf.writeln(row.tableLine);
  }
  buf.writeln();
}

void _provenance(StringBuffer buf, Map<String, List<String>> provenance) {
  if (provenance.isEmpty) return;
  buf
    ..writeln('## Routing provenance')
    ..writeln()
    ..writeln(
      'Per-behavior routing decisions (issue #951): what each '
      'decision consulted — a declared marker/contract row, or the '
      'labeled legacy fallback to migrate.',
    )
    ..writeln();
  for (final lines in provenance.values) {
    for (final line in lines) {
      buf.writeln(line);
    }
  }
  buf.writeln();
}

/// The spec-wide declaration sections (bug #829 / bug #919) — rendered
/// into the ENGINE plan (the engine side owns the declarations), in the
/// same shapes the legacy single-file plan wrote so the reader's
/// section fallbacks resolve them unchanged.
void _declarations(
  StringBuffer buf,
  List<SpecEntity> entities,
  List<SpecDependency> dependencies,
  List<LayerContract> layerContracts,
) {
  if (entities.isNotEmpty) {
    final hasPurpose = entities.any((e) => e.purpose.isNotEmpty);
    buf
      ..writeln('## Key entities')
      ..writeln();
    if (hasPurpose) {
      buf
        ..writeln('| entity | fields | purpose |')
        ..writeln('| ------ | ------ | ------- |');
      for (final e in entities) {
        buf.writeln(
          '| ${e.name} | '
          '${e.fields.map((f) => '${f.name}: ${f.type}').join(', ')}'
          ' | ${e.purpose} |',
        );
      }
    } else {
      buf
        ..writeln('| entity | fields |')
        ..writeln('| ------ | ------ |');
      for (final e in entities) {
        buf.writeln(
          '| ${e.name} | '
          '${e.fields.map((f) => '${f.name}: ${f.type}').join(', ')} |',
        );
      }
    }
    buf.writeln();
  }
  if (dependencies.isNotEmpty) {
    buf
      ..writeln('## External dependencies')
      ..writeln()
      ..writeln('| dependency | type | contract | mock priority |')
      ..writeln('| ---------- | ---- | -------- | ------------- |');
    for (final d in dependencies) {
      buf.writeln(
        '| ${d.dependency} | ${d.type} | ${d.contract} '
        '| ${d.mockPriority} |',
      );
    }
    buf.writeln();
  }
  if (layerContracts.isNotEmpty) {
    buf
      ..writeln('## Layer contracts')
      ..writeln();
    final byLayer = <String, List<LayerContract>>{};
    for (final c in layerContracts) {
      byLayer.putIfAbsent(c.layer, () => []).add(c);
    }
    for (final entry in byLayer.entries) {
      buf
        ..writeln('### ${entry.key}')
        ..writeln();
      for (final c in entry.value) {
        // Bug #919 (fixed by #1141): methods stay BACKTICKED so
        // TestListReader.readLayerContracts round-trips the contract
        // (components + key: tokens survive the plan → test-list leg).
        buf.writeln(
          '- `${c.interfaceName}`: '
          '${c.methods.map((m) => '`$m`').join(', ')}',
        );
      }
    }
    buf.writeln();
  }
}
