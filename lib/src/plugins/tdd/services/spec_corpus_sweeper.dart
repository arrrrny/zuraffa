/// `SpecCorpusSweeper` — the 120-format sweep harness (issue #1196,
/// part of #908 P0).
///
/// Runs the FULL declaration-parse surface of [SpecParser] over every
/// spec of a corpus root and classifies each outcome:
///
/// - `clean` — every parse walked without refusing;
/// - `refused` — a [StateError] refusal whose message names the
///   offending `spec line N` (the errors-are-an-API contract — the
///   #1186 strict-grammar markers make refusals actionable);
/// - `crashed` — anything else: a non-StateError exception, or a
///   StateError WITHOUT a line address (a refusal the author cannot
///   act on is a crash of the honesty contract, not a refusal).
///
/// The sweeper is PURE over inputs (no I/O beyond reading the corpus
/// files, no clocks): the same corpus sweeps to the same verdict, so
/// the committed sweep evidence (`corpus/zik_zak/sweep.json`) is a
/// reviewable diff, never a claim.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'spec_parser.dart';

/// One spec's sweep outcome.
enum SweepOutcome { clean, refused, crashed }

/// The parsed facts of one corpus spec — what the declaration surface
/// actually derived, so "silent misroute" is checkable: a shape that
/// declares contracts/dependencies/lanes must show them here.
class SpecSweepFacts {
  const SpecSweepFacts({
    required this.behaviorCount,
    required this.acceptanceCount,
    required this.unitCount,
    required this.entityCount,
    required this.dependencyCount,
    required this.layerContractCount,
    required this.laneCount,
    required this.contractRowCount,
    required this.templateVersion,
  });

  final int behaviorCount;
  final int acceptanceCount;
  final int unitCount;
  final int entityCount;
  final int dependencyCount;
  final int layerContractCount;
  final int laneCount;
  final int contractRowCount;
  final String? templateVersion;
}

/// One corpus spec's sweep record.
class SpecSweepRecord {
  const SpecSweepRecord({
    required this.feature,
    required this.outcome,
    required this.refusal,
    required this.error,
    this.facts,
  });

  /// The corpus feature (directory name under the corpus root).
  final String feature;

  final SweepOutcome outcome;

  /// The refusal message (null unless outcome == refused).
  final String? refusal;

  /// The crash diagnostics (null unless outcome == crashed).
  final String? error;

  /// The derived facts (null when the surface refused/crashed before
  /// completing — honest absence, never a partial lie).
  final SpecSweepFacts? facts;

  bool get isCrashed => outcome == SweepOutcome.crashed;
  bool get isClean => outcome == SweepOutcome.clean;
}

/// The whole corpus sweep.
class SpecCorpusSweep {
  const SpecCorpusSweep({required this.records});

  final List<SpecSweepRecord> records;

  int get cleanCount =>
      records.where((r) => r.outcome == SweepOutcome.clean).length;

  int get refusedCount =>
      records.where((r) => r.outcome == SweepOutcome.refused).length;

  int get crashedCount =>
      records.where((r) => r.outcome == SweepOutcome.crashed).length;

  /// The honest summary line: the coverage tracker's headline.
  String get summaryLine =>
      'zikzak sweep: specs=${records.length} parse-clean=$cleanCount '
      'parse-refused(line)=$refusedCount crashed=$crashedCount';
}

class SpecCorpusSweeper {
  const SpecCorpusSweeper();

  /// Sweeps every `<corpusRoot>/<feature>/spec.md` (lexicographic
  /// feature order). A corpus root without subdirectories sweeps empty.
  Future<SpecCorpusSweep> sweep(Directory corpusRoot) async {
    final records = <SpecSweepRecord>[];
    if (!corpusRoot.existsSync()) return SpecCorpusSweep(records: records);
    final features =
        corpusRoot
            .listSync()
            .whereType<Directory>()
            .map((d) => p.basename(d.path))
            .toList()
          ..sort();
    for (final feature in features) {
      final specFile = File(p.join(corpusRoot.path, feature, 'spec.md'));
      if (!specFile.existsSync()) continue;
      final specMd = specFile.readAsStringSync();
      records.add(_sweepOne(feature, specMd));
    }
    return SpecCorpusSweep(records: records);
  }

  /// Sweeps one spec content directly (the fuzz/property tests feed
  /// mutated bodies through the same classification).
  SpecSweepRecord sweepContent(String feature, String specMd) =>
      _sweepOne(feature, specMd);

  /// Runs the full declaration surface with the crash classification.
  SpecSweepRecord _sweepOne(String feature, String specMd) {
    final parser = const SpecParser();
    try {
      final behaviors = parser.parse(feature, specMd);
      final entities = parser.parseKeyEntities(specMd);
      final dependencies = parser.parseDependencies(specMd);
      final layerContracts = parser.parseLayerContracts(specMd);
      final lanes = parser.parseLanes(specMd);
      final contractRows = parser.parseContractRows(specMd);
      SpecParser.parseScenarioTypeMarkers(specMd);
      SpecParser.parseFrContractTraces(specMd);
      SpecParser.parsePersistenceDeclarations(specMd);
      final version = parser.parseTemplateVersion(specMd);
      return SpecSweepRecord(
        feature: feature,
        outcome: SweepOutcome.clean,
        refusal: null,
        error: null,
        facts: SpecSweepFacts(
          behaviorCount: behaviors.length,
          acceptanceCount: behaviors.where((b) => b.id.startsWith('A')).length,
          unitCount: behaviors.where((b) => b.id.startsWith('U')).length,
          entityCount: entities.length,
          dependencyCount: dependencies.length,
          layerContractCount: layerContracts.length,
          laneCount: lanes.length,
          contractRowCount: contractRows.length,
          templateVersion: version,
        ),
      );
    } on StateError catch (e) {
      final message = e.message;
      // An honest refusal names the offending line — either the
      // `spec line N` convention (the marker/marker-refusal walks) or
      // the `line N` form (the duplicate-marker refusal, bug #846
      // family). Any StateError without a line address is a crash of
      // the honesty contract: the author cannot act on it.
      final namesLine = RegExp(
        r'(?:spec )?line \d+',
        caseSensitive: false,
      ).hasMatch(message);
      return SpecSweepRecord(
        feature: feature,
        outcome: namesLine ? SweepOutcome.refused : SweepOutcome.crashed,
        refusal: namesLine ? message : null,
        error: namesLine ? null : 'lineless StateError: $message',
      );
    } catch (e, st) {
      return SpecSweepRecord(
        feature: feature,
        outcome: SweepOutcome.crashed,
        refusal: null,
        error: '$e\n$st',
      );
    }
  }
}
