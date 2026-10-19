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
    // Deduplicate within the head run so a mutant listed twice in the
    // report does not count twice (review finding: newSurvived duplicates).
    final newSurvived = head.survivors
        .where((s) => !baseSurvivors.contains(s))
        .toSet()
        .toList(growable: false);
    // `newKilled` is a kill-count delta (head.killed - base.killed), NOT a
    // count of newly-introduced killed mutants: it conflates newly
    // introduced kills, pre-existing survivors that became killed, and
    // kills removed by the PR. It is reported as a heuristic only and is
    // deliberately not mixed into `newMutants` (see MutationDiffReport).
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
