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

import '../models/behavior.dart';
import '../models/lane.dart';
import 'spec_parser.dart';

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
  });

  final String id;
  final String description;
  final String traces;
  final String state;
  final BehaviorKind kind;
  final Lane lane;

  /// The canonical 4-column row line every lane plan table carries.
  String get tableLine => '| $id | $description | $traces | $state |';
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
      .where((r) => r.kind == BehaviorKind.acceptance)
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
String renderSkinPlan({
  required String feature,
  required List<LaneRow> rows,
  required List<String> adaptiveSlots,
  Map<String, List<String>> provenance = const {},
}) {
  final acceptance = rows
      .where((r) => r.kind == BehaviorKind.acceptance)
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
    ..writeln('| lane | behaviors | flutter allowed | plan |')
    ..writeln('| ---- | --------- | --------------- | ---- |');
  for (final lane in lanes) {
    final declared = lane.behaviorIds.join(', ');
    final resolved = classification.entries
        .where((e) => e.value.label == lane.lane.toUpperCase())
        .map((e) => e.key)
        .join(', ');
    buf.writeln(
      '| ${lane.lane} | ${resolved.isNotEmpty ? resolved : declared} '
      '| ${lane.flutterAllowed.isEmpty ? '-' : lane.flutterAllowed} '
      '| ${_planColumn(lane.lane)} |',
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
        buf.writeln('- `${c.interfaceName}`: ${c.methods.join(', ')}');
      }
    }
    buf.writeln();
  }
}
