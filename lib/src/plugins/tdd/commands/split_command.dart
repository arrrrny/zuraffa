/// `zfa tdd split <feature>` — the one-shot lane migration (issue
/// #1000).
///
/// Features planned before the lane grammar carry a single
/// `tdd/test-list.md` with behavior rows. This command reads that old
/// plan, classifies every behavior row CORE or SKIN, and emits the new
/// plan pair — `04-ENGINE.md`, `04-SKIN.md`, `04-CONTRACT.md` — plus
/// `tdd/split-receipt.json`, converting `test-list.md` into the
/// meta-index.
///
/// Classification:
///
/// - **Declarations win**: when the feature's spec declares `##
///   Lanes`, the declaration assigns every row it names (undeclared
///   rows fall through to the kind heuristic, recorded in the receipt
///   as `heuristic` rather than `declared`).
/// - **Kind heuristic** (no Lanes, or an undeclared row): `widget` /
///   `theme` rows are SKIN (their gen pair imports Flutter); everything
///   else (acceptance / unit / ffi / platform) is CORE.
///
/// The migration is:
///
/// - **One-shot**: a feature whose `split-receipt.json` already exists
///   (or whose test-list is already a meta-index) is REFUSED (exit 1)
///   naming the receipt — never a silent re-split.
/// - **Fail-honest**: a feature with no legacy test list refuses
///   naming the file to plan first; a prior list the shared reader
///   cannot parse refuses with the reader's error.
/// - **Receipt-carrying**: every row's classification, the emitted
///   file set, the adaptive slots, and the engine plan's
///   flutter-reference count are recorded for audit.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../models/lane.dart';
import '../services/lane_split.dart';
import '../services/spec_parser.dart';
import '../services/test_list_reader.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class SplitCommand extends Command<void> {
  SplitCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/<feature>/tdd/. When omitted, the '
          'current working directory is used. Tests pass the temp fixture '
          'root here instead of mutating Directory.current.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'split';

  @override
  String get description =>
      'One-shot migration (issue #1000): read the legacy single-file '
      'tdd/test-list.md, classify every behavior CORE or SKIN (spec '
      '`## Lanes` declarations winning over the kind heuristic), and emit '
      'tdd/04-ENGINE.md + tdd/04-SKIN.md + tdd/04-CONTRACT.md + '
      'tdd/split-receipt.json; test-list.md becomes the lane meta-index.';

  @override
  String get invocation => 'zfa tdd split <feature>';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      usageException('Feature name is required: zfa tdd split <feature>');
    }
    final feature = rest.first;
    final projectFlag = argResults?['project'] as String?;
    final repoRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final featureDir = '$repoRoot/specs/$feature';
    final tddDir = '$featureDir/tdd';
    final listFile = File('$tddDir/test-list.md');
    final receiptFile = File('$tddDir/${LaneSplitFiles.receipt}');

    // One-shot guard: the receipt is the migration record.
    if (await receiptFile.exists()) {
      print(
        'zfa tdd split: REFUSED — $feature is already split '
        '(${receiptFile.path} exists). The split is one-shot; re-planning '
        'the feature (`zfa tdd plan $feature`) rewrites the lane plans '
        'from the spec.',
      );
      exitCode = 1;
      return;
    }

    if (!await listFile.exists()) {
      print(
        'zfa tdd split: REFUSED — no test list at ${listFile.path}. Run '
        '`zfa tdd plan $feature` first, then split.',
      );
      exitCode = 1;
      return;
    }
    final listContent = await listFile.readAsString();
    if (LaneSplitFiles.find(listContent) != null) {
      print(
        'zfa tdd split: REFUSED — ${listFile.path} is already the lane '
        'meta-index (no $receiptFile, so the migration record was lost — '
        'restore it or re-run `zfa tdd plan $feature` to rewrite the '
        'lane plans from the spec).',
      );
      exitCode = 1;
      return;
    }

    final rows = await TestListReader(featureDir).read();

    // The legacy list's declaration sections (Key entities / External
    // dependencies / Layer contracts) migrate into the engine plan —
    // the reader's section fallback resolves them there. Read the
    // sections from the list itself (it is NOT yet a meta-index at
    // split time).
    final legacyDeclarations = listContent;

    // Declarations win: a spec `## Lanes` section assigns the rows it
    // names; undeclared rows fall through to the kind heuristic.
    final specFile = File('$featureDir/spec.md');
    final specMd = await specFile.exists() ? await specFile.readAsString() : '';
    final lanes = specMd.isEmpty
        ? const <LaneDeclaration>[]
        : const SpecParser().parseLanes(specMd);
    final declared = <String, Lane>{};
    for (final lane in lanes) {
      final parsed = Lane.parse(lane.lane);
      if (parsed == null) continue;
      for (final id in lane.behaviorIds) {
        declared[id] = parsed;
      }
    }

    Lane classify(BehaviorRow row) => declared[row.id] ?? _heuristic(row);

    final classification = <String, Lane>{};
    final sources = <String, String>{};
    for (final row in rows) {
      classification[row.id] = classify(row);
      sources[row.id] = declared.containsKey(row.id) ? 'declared' : 'heuristic';
    }

    // The emitted lane rows: the prior rows verbatim (id, description,
    // traces, state, kind preserved — the migration never rewords a
    // row), assigned to their lane.
    final allRows = [
      for (final row in rows)
        LaneRow(
          id: row.id,
          description: row.description,
          traces: row.traces,
          state: row.state.name.toUpperCase(),
          kind: row.kind,
          lane: classification[row.id]!,
        ),
    ];
    final engineRows = allRows.where((r) => r.lane.destinedForEngine).toList();
    final skinRows = allRows.where((r) => r.lane.destinedForSkin).toList();
    final adaptiveSlots = lanes.expand((l) => l.adaptiveSlots).toSet().toList();

    final engineMd = renderEnginePlan(
      feature: feature,
      rows: engineRows,
      entities: const SpecParser().parseKeyEntities(legacyDeclarations),
      dependencies: const SpecParser().parseDependencies(legacyDeclarations),
      layerContracts: const SpecParser().parseLayerContracts(
        legacyDeclarations,
      ),
    );
    final skinMd = renderSkinPlan(
      feature: feature,
      rows: skinRows,
      adaptiveSlots: adaptiveSlots,
    );
    final contractMd = renderContractPlan(
      feature: feature,
      adaptiveSlots: adaptiveSlots,
      bothRows: engineRows.where((r) => r.lane == Lane.both).toList(),
    );
    final metaMd = renderMetaIndex(
      feature: feature,
      lanes: lanes.isNotEmpty
          ? lanes
          : [
              // No spec declaration: the meta-index still records the
              // heuristic split the receipt audited.
              LaneDeclaration(
                lane: Lane.core.label,
                behaviorIds: engineRows
                    .where((r) => r.lane == Lane.core)
                    .map((r) => r.id)
                    .toList(),
                flutterAllowed: 'false',
              ),
              LaneDeclaration(
                lane: Lane.skin.label,
                behaviorIds: skinRows
                    .where((r) => r.lane == Lane.skin)
                    .map((r) => r.id)
                    .toList(),
                flutterAllowed: 'true',
                adaptiveSlots: adaptiveSlots,
              ),
              if (classification.containsValue(Lane.both))
                LaneDeclaration(
                  lane: Lane.both.label,
                  behaviorIds: allRows
                      .where((r) => r.lane == Lane.both)
                      .map((r) => r.id)
                      .toList(),
                  flutterAllowed: 'conditionally',
                ),
            ],
      classification: classification,
    );

    await File(p.join(tddDir, LaneSplitFiles.engine)).writeAsString(engineMd);
    await File(p.join(tddDir, LaneSplitFiles.skin)).writeAsString(skinMd);
    await File(
      p.join(tddDir, LaneSplitFiles.contract),
    ).writeAsString(contractMd);
    await listFile.writeAsString(metaMd);

    // The receipt: the audit record of the one-shot migration.
    final receipt = {
      'feature': feature,
      'split_at': DateTime.now().toUtc().toIso8601String(),
      'source': 'tdd/test-list.md',
      'rows': rows.length,
      'classification': {
        for (final entry in classification.entries)
          entry.key: entry.value.label,
      },
      'classification_source': sources,
      'adaptive_slots': adaptiveSlots,
      'files': [
        'tdd/${LaneSplitFiles.engine}',
        'tdd/${LaneSplitFiles.skin}',
        'tdd/${LaneSplitFiles.contract}',
        'tdd/test-list.md (meta-index)',
      ],
      'engine_flutter_references': _flutterReferenceCount(engineMd),
    };
    await receiptFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(receipt),
    );

    final coreCount = engineRows.where((r) => r.lane == Lane.core).length;
    final skinCount = skinRows.where((r) => r.lane == Lane.skin).length;
    final bothCount = allRows.where((r) => r.lane == Lane.both).length;
    stdout.writeln(
      'zfa tdd split: wrote tdd/${LaneSplitFiles.engine} ($coreCount CORE), '
      'tdd/${LaneSplitFiles.skin} ($skinCount SKIN), '
      'tdd/${LaneSplitFiles.contract}; test-list.md is now the lane '
      'meta-index ($bothCount BOTH) — receipt: ${receiptFile.path}.',
    );
  }

  /// The kind heuristic (issue #1000): widget/theme rows are SKIN (their
  /// gen pair — testWidgets + view builder / theme harness — imports
  /// Flutter); acceptance/unit/ffi/platform rows are CORE. Contract rows
  /// (issue #1007) are CORE — the declared contract surface is engine
  /// territory.
  static Lane _heuristic(BehaviorRow row) => switch (row.kind) {
    BehaviorKind.widget || BehaviorKind.theme => Lane.skin,
    BehaviorKind.acceptance ||
    BehaviorKind.unit ||
    BehaviorKind.ffi ||
    BehaviorKind.platform ||
    BehaviorKind.contract => Lane.core,
  };
}

/// Count the engine plan's flutter references (audit field of the
/// receipt; zero by construction). Built from pieces so this file's
/// source is not a false positive for repo-wide greps.
int _flutterReferenceCount(String content) {
  final needle = 'package:${'flutter'}';
  var count = 0;
  var idx = content.indexOf(needle);
  while (idx >= 0) {
    count++;
    idx = content.indexOf(needle, idx + needle.length);
  }
  return count;
}
