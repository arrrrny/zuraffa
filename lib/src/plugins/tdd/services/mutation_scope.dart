/// MutationScope — derives the union of test+subject paths from
/// `specs/<feature>/tdd/artifacts.json` (spec 044-test-tdd-generation,
/// FR-012).
///
/// When the registry is empty (no behavior artifacts registered), the scope
/// is empty and [notAssessedReason] is set to "no behavior artifacts
/// registered". The [MutationAuditor] will translate this into a
/// `NOT_ASSESSED` gate decision.
library;

import 'artifact_registry.dart';

/// The derived mutation scope for a feature.
class MutationScope {
  MutationScope({
    required this.subjectPaths,
    required this.testPaths,
    required this.behaviorIds,
    required this.sourceCriteriaByBehavior,
    required this.notAssessedReason,
  });

  /// All subject paths in the scope (union across registered behaviors).
  final List<String> subjectPaths;

  /// All test paths in the scope (union across registered behaviors).
  final List<String> testPaths;

  /// All behavior ids in the scope.
  final List<String> behaviorIds;

  /// Map of behavior id -> source criterion (for the report — FR-018).
  final Map<String, String> sourceCriteriaByBehavior;

  /// If non-null, the scope is empty and the audit is NOT_ASSESSED with
  /// this reason.
  final String? notAssessedReason;

  /// True when the scope is empty (no behavior artifacts registered).
  bool get isEmpty => subjectPaths.isEmpty && testPaths.isEmpty;

  /// Look up the source criterion for a behavior id (for the report).
  String? sourceCriterionFor(String behaviorId) =>
      sourceCriteriaByBehavior[behaviorId];

  /// Derive the mutation scope from the registry for a feature.
  static Future<MutationScope> derive({required String featureDir}) async {
    final registry = ArtifactRegistry(featureDir: featureDir);
    final records = await registry.loadAll();
    if (records.isEmpty) {
      return MutationScope(
        subjectPaths: const [],
        testPaths: const [],
        behaviorIds: const [],
        sourceCriteriaByBehavior: const {},
        notAssessedReason: 'no behavior artifacts registered',
      );
    }
    final subjectPaths = <String>{};
    final testPaths = <String>{};
    final behaviorIds = <String>[];
    final sourceCriteria = <String, String>{};
    for (final r in records) {
      subjectPaths.add(r.subjectPath);
      testPaths.add(r.testPath);
      behaviorIds.add(r.behaviorId);
      sourceCriteria[r.behaviorId] = r.sourceCriterion;
    }
    return MutationScope(
      subjectPaths: subjectPaths.toList()..sort(),
      testPaths: testPaths.toList()..sort(),
      behaviorIds: behaviorIds,
      sourceCriteriaByBehavior: sourceCriteria,
      notAssessedReason: null,
    );
  }
}
