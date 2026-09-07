// The ZikZak corpus sweep (issue #1196, part of #908 P0) — the
// coverage tracker. Runs the FULL declaration-parse surface over the
// committed 120-spec corpus, then (with --plan) drives the REAL
// `zfa tdd plan` over every spec in throwaway temp projects and
// writes the committed sweep evidence `corpus/zik_zak/sweep.json`.
//
// Deterministic by construction (feature order lexicographic, no
// clock, no RNG): re-running the tool reproduces byte-identical
// evidence, so the committed JSON is a reviewable diff, never a
// claim.
//
// Usage:
//   dart run tool/sweep_zikzak_corpus.dart            # parse sweep + report
//   dart run tool/sweep_zikzak_corpus.dart --facts    # + per-shape facts
//   dart run tool/sweep_zikzak_corpus.dart --plan     # + plan sweep (slow),
//                                                     #   writes sweep.json
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_corpus_sweeper.dart';

Future<void> main(List<String> args) async {
  final root = p.dirname(p.fromUri(Platform.script));
  var dir = root;
  while (!File(p.join(dir, 'pubspec.yaml')).existsSync()) {
    dir = p.dirname(dir);
  }
  final corpusRoot = Directory(p.join(dir, 'corpus', 'zik_zak'));
  final oracle = <String, String>{};
  for (final line in File(
    p.join(corpusRoot.path, 'corpus-shapes.txt'),
  ).readAsStringSync().split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length == 2) oracle[parts[0]] = parts[1];
  }
  final sweep = await const SpecCorpusSweeper().sweep(corpusRoot);
  stdout.writeln(sweep.summaryLine);
  final byShape = <String, List<SpecSweepRecord>>{};
  for (final r in sweep.records) {
    byShape.putIfAbsent(oracle[r.feature] ?? '?', () => []).add(r);
  }
  for (final shape in byShape.keys.toList()..sort()) {
    final records = byShape[shape]!;
    final crashed = records.where((r) => r.isCrashed).length;
    final refused = records
        .where((r) => r.outcome == SweepOutcome.refused)
        .length;
    final clean = records.where((r) => r.isClean).length;
    stdout.writeln(
      '$shape: n=${records.length} clean=$clean refused=$refused '
      'crashed=$crashed',
    );
    for (final r in records.where((r) => !r.isClean).take(3)) {
      final msg = (r.refusal ?? r.error ?? '').split('\n').first;
      stdout.writeln('    ${r.feature}: ${r.outcome.name} — $msg');
    }
  }
  if (args.contains('--facts')) {
    _reportFacts(sweep, oracle);
  }
  if (args.contains('--json')) {
    stdout.writeln(jsonEncode({'summary': sweep.summaryLine}));
  }
  if (args.contains('--plan')) {
    await _planSweep(corpusRoot, sweep, oracle);
  }
}

void _reportFacts(SpecCorpusSweep sweep, Map<String, String> oracle) {
  const show = [
    'crlf',
    'html-entities',
    'epic-contracts',
    'fr-table',
    'non-english',
    'nested-ac',
    'inline-prose',
  ];
  final seen = <String>{};
  for (final r in sweep.records) {
    final shape = oracle[r.feature] ?? '?';
    if (!show.contains(shape) || seen.contains(shape)) continue;
    seen.add(shape);
    final f = r.facts;
    if (f == null) {
      stdout.writeln('${r.feature} ($shape): NO FACTS');
      continue;
    }
    stdout.writeln(
      '${r.feature} ($shape): behaviors=${f.behaviorCount} '
      'A=${f.acceptanceCount} U=${f.unitCount} '
      'entities=${f.entityCount} deps=${f.dependencyCount} '
      'layerContracts=${f.layerContractCount} lanes=${f.laneCount} '
      'contractRows=${f.contractRowCount} version=${f.templateVersion}',
    );
  }
}

/// The plan-level coverage tracker (the #1196 headline numbers):
/// X of 120 specs plan cleanly; Y behaviors route via the labeled
/// legacy fallback (the #1186 window — the tracker exists so that
/// number can only shrink honestly, toward zero).
Future<void> _planSweep(
  Directory corpusRoot,
  SpecCorpusSweep sweep,
  Map<String, String> oracle,
) async {
  final runner = CliRunner(exitOnCompletion: false);
  final features = oracle.keys.toList()..sort();
  final planRows = <Map<String, dynamic>>[];
  var clean = 0;
  var refused = 0;
  var declaredRoutes = 0;
  var fallbackRoutes = 0;
  final exitClasses = <String, int>{};
  final tmp = Directory.systemTemp.createTempSync('zikzak_plan_sweep_');
  try {
    for (final feature in features) {
      final featureDir = p.join(tmp.path, 'specs', feature);
      Directory(featureDir).createSync(recursive: true);
      File(p.join(featureDir, 'spec.md')).writeAsStringSync(
        File(p.join(corpusRoot.path, feature, 'spec.md')).readAsStringSync(),
      );
      final out = await runner.runCapturing([
        'tdd',
        'plan',
        feature,
        '--project',
        tmp.path,
      ]);
      final exit = CliRunner.lastDispatchedExitCode;
      final declared = RegExp(r'\[declared: ').allMatches(out).length;
      final fallback = RegExp(r'\[fallback: ').allMatches(out).length;
      exitClasses['exit$exit'] = (exitClasses['exit$exit'] ?? 0) + 1;
      if (exit == 0) {
        clean++;
      } else {
        refused++;
      }
      declaredRoutes += declared;
      fallbackRoutes += fallback;
      planRows.add({
        'feature': feature,
        'shape': oracle[feature],
        'planExit': exit,
        'declaredRoutes': declared,
        'fallbackRoutes': fallback,
      });
    }
  } finally {
    tmp.deleteSync(recursive: true);
  }

  final headline =
      'zikzak plan sweep: specs=${features.length} plan-clean=$clean '
      'plan-refused=$refused | routing: declared=$declaredRoutes '
      'fallback=$fallbackRoutes (#1186 window)';
  stdout.writeln(headline);
  for (final e in exitClasses.keys.toList()..sort()) {
    stdout.writeln('  $e: ${exitClasses[e]}');
  }

  // The committed evidence artifact — deterministic (no clock), so a
  // re-run must produce a byte-identical file.
  final evidence = {
    'schema': 'zikzak-sweep.v1',
    'corpus': 'corpus/zik_zak',
    'specs': sweep.records.length,
    'parse': {
      'clean': sweep.cleanCount,
      'refused': sweep.refusedCount,
      'crashed': sweep.crashedCount,
    },
    'plan': {
      'clean': clean,
      'refused': refused,
      'declaredRoutes': declaredRoutes,
      'fallbackRoutes': fallbackRoutes,
      'exitClasses': exitClasses,
    },
    'specRows': [
      for (final r in sweep.records)
        {
          'feature': r.feature,
          'shape': oracle[r.feature],
          'parse': r.outcome.name,
          if (r.refusal != null) 'refusal': r.refusal!.split('\n').first,
          if (r.facts != null) 'behaviors': r.facts!.behaviorCount,
        },
    ],
    'planRows': planRows,
  };
  final outFile = File(p.join(corpusRoot.path, 'sweep.json'));
  const encoder = JsonEncoder.withIndent('  ');
  outFile.writeAsStringSync('${encoder.convert(evidence)}\n');
  stdout.writeln('wrote ${outFile.path}');
}
