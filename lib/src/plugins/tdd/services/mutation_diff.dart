/// `MutationDiff` — computes a [MutationDiffReport] comparing a PR head
/// mutation audit against the base ref (issue #811, VISION 2030 Pillar C).
library;

import '../models/mutation_diff_report.dart';
import '../services/mutation_verifier.dart';

class MutationDiff {
  const MutationDiff();

  MutationDiffReport compute({
    required MutationResult base,
    required MutationResult head,
    double threshold = 0.8,
  }) {
    final baseSurvivors = base.survivors.toSet();
    final newSurvived = head.survivors
        .where((s) => !baseSurvivors.contains(s))
        .toList(growable: false);
    final rawNewKilled = head.killedCount - base.killedCount;
    final newKilled = rawNewKilled < 0 ? 0 : rawNewKilled;
    return MutationDiffReport(
      baseKilled: base.killedCount,
      baseSurvived: base.survivedCount,
      baseTotal: base.totalMutants,
      headKilled: head.killedCount,
      headSurvived: head.survivedCount,
      headTotal: head.totalMutants,
      newKilled: newKilled,
      newSurvivedMutants: newSurvived,
      threshold: threshold,
    );
  }
}
