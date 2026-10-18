/// Per-PR mutation diff report (issue #811, VISION 2030 Pillar C).
///
/// Compares a mutation audit run on the PR head against the run on the base
/// ref and reports how many mutants the PR *newly* kills / misses, plus a
/// gate decision against a configurable threshold. Output is available as
/// both markdown (for a CI comment) and JSON (for machine consumption),
/// per the #778 output contract.
library;

import 'dart:convert';

import '../services/mutation_verifier.dart';

/// Gate decision for a per-PR mutation diff.
enum MutationDiffGate { pass, failSurvived }

/// A per-PR mutation diff report.
class MutationDiffReport {
  const MutationDiffReport({
    required this.baseKilled,
    required this.baseSurvived,
    required this.baseTotal,
    required this.headKilled,
    required this.headSurvived,
    required this.headTotal,
    required this.newKilled,
    required this.newSurvivedMutants,
    required this.threshold,
  });

  final int baseKilled;
  final int baseSurvived;
  final int baseTotal;
  final int headKilled;
  final int headSurvived;
  final int headTotal;

  /// Mutants the PR newly kills (head kills beyond the base count).
  final int newKilled;

  /// Mutants the PR misses (head survivors not present in the base run).
  final List<MutationSurvivor> newSurvivedMutants;

  /// Required kill ratio among the new mutants (0..1).
  final double threshold;

  /// Mutants newly introduced by this PR (killed + missed).
  int get newMutants => newKilled + newSurvivedMutants.length;

  /// Whether the kill ratio among new mutants meets the threshold.
  /// Vacuously true when there are no new mutants.
  bool get thresholdMet {
    if (newMutants == 0) return true;
    return newKilled / newMutants >= threshold;
  }

  MutationDiffGate get gate =>
      thresholdMet ? MutationDiffGate.pass : MutationDiffGate.failSurvived;

  Map<String, dynamic> toJsonMap() => {
    'schema': 'mutation-diff.v1',
    'base': {
      'killed': baseKilled,
      'survived': baseSurvived,
      'total': baseTotal,
    },
    'head': {
      'killed': headKilled,
      'survived': headSurvived,
      'total': headTotal,
    },
    'diff': {
      'new_killed': newKilled,
      'new_survived': newSurvivedMutants.length,
      'new_mutants': newMutants,
      'missed': [for (final s in newSurvivedMutants) s.toString()],
    },
    'threshold': threshold,
    'threshold_met': thresholdMet,
    'gate': gate.name,
  };

  String toJson() => const JsonEncoder.withIndent('  ').convert(toJsonMap());

  String toMarkdown() {
    final buf = StringBuffer()
      ..writeln('# Mutation diff — PR vs base')
      ..writeln()
      ..writeln(
        'This PR kills **$newKilled** new mutant(s), misses **${newSurvivedMutants.length}**.',
      )
      ..writeln()
      ..writeln(
        '- base: killed=$baseKilled survived=$baseSurvived total=$baseTotal',
      )
      ..writeln(
        '- head: killed=$headKilled survived=$headSurvived total=$headTotal',
      )
      ..writeln(
        '- new mutants: $newMutants (killed=$newKilled, missed=${newSurvivedMutants.length})',
      )
      ..writeln('- threshold: ${threshold.toStringAsFixed(2)}')
      ..writeln('- threshold met: $thresholdMet')
      ..writeln('- gate: `${gate.name}`')
      ..writeln();
    if (newSurvivedMutants.isNotEmpty) {
      buf.writeln('## Missed mutants (survived)');
      buf.writeln();
      for (final s in newSurvivedMutants) {
        buf.writeln('- `$s`');
      }
      buf.writeln();
    }
    return buf.toString();
  }
}
