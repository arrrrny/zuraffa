/// HandStepClassifier — the make-side classification of the
/// planner-declared hand-step class (issue #1568).
///
/// The planner announces the class up front (SPEC 1489 SC-4's seam
/// forecast: `Seam cost: N of M unit behaviors will hand-step because
/// return is an entity.`), but `make` graded the SAME condition
/// `generation-error` and stopped the whole run — the mechanical
/// behaviors behind the first hand-step were unreachable, and every
/// resume re-drove everything up to the same wall (#1544's
/// blocked-contract sibling).
///
/// The classifier keys on the declared contract's TYPE SHAPE, not the
/// entity's on-disk existence: phase-0 may create the entity between the
/// forecast and the make, and the classification must stay stable across
/// that boundary (the forecast's own predicate consults the registry at
/// forecast time — before phase-0 — so the make-side check mirrors its
/// type-shape half exactly, via the SAME
/// `UnitContractShape.isRenderableScalarType` vocabulary). Undeclared
/// behaviors (no resolvable contract row) are never hand-steps: they
/// keep the honest generic stop. The entity pipeline's served shapes
/// (#1498/#1500 — `wire` + certified mock) are excluded by the caller:
/// when the plan carried a mechanical implementation surface, the
/// post-generation red is a real generation outcome, not the designed
/// hand step.
library;

import '../services/declared_routing.dart';
import '../services/unit_contract_shape.dart';

/// The hand-step classification predicates (issue #1568).
class HandStepClassifier {
  const HandStepClassifier._();

  /// Whether a declared contract returning [returnType] is an
  /// ENTITY-SHAPED return — the SPEC 1489 seam class. Registry-independent:
  /// renderable scalars (and scalar containers) are never hand-steps
  /// (func serves them mechanically — the #1310 lineage); every other
  /// identifier/generic shape (`ScanSession`, `List<Task>`,
  /// `Map<String, Task>`, `Task?`) is.
  static bool isEntityShapedReturn(String returnType) {
    final trimmed = returnType.trim();
    if (trimmed.isEmpty) return false;
    return !isRenderableScalarType(trimmed);
  }

  /// Whether [behaviorId]'s DECLARED contract (resolved the same way the
  /// forecast resolves it — the test-list trace cell against the spec's
  /// contract rows) returns an entity-shaped type. Fail-closed to false:
  /// an unreadable artifact or a malformed declaration is NOT a
  /// hand-step — the generic stop stands (the malformed case is the
  /// caller's earlier refusal surface).
  static Future<bool> isPlannerDeclaredHandStep({
    required String cwd,
    required String featureName,
    required String featureDir,
    required String behaviorId,
  }) async {
    try {
      final signature = await DeclaredRouting.declaredSignatureFor(
        cwd: cwd,
        featureName: featureName,
        featureDir: featureDir,
        behaviorId: behaviorId,
      );
      if (signature == null) return false;
      return isEntityShapedReturn(signature.returnType);
    } on Exception {
      return false;
    }
  }
}
