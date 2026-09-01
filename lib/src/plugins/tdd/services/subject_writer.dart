/// SubjectWriter — emits the compilable subject half of a `gen` pair
/// (spec 044-test-tdd-generation, FR-001, FR-003, FR-004, FR-011).
///
/// The emitted subject:
///   - compiles cleanly (FR-011: `dart analyze` reports zero errors);
///   - does NOT satisfy the behavior's expected observable behavior, so the
///     paired test fails for the right reason on first execution (honest
///     red — FR-010);
///   - For `unit` classification: a function-level subject that throws
///     `UnimplementedError()`.
///   - For `acceptance` classification: a behavior-level "scenario runner"
///     that throws `UnimplementedError()`. The acceptance subject does NOT
///     reference any entity/use case/repository — it stands alone (FR-004).
library;

import 'dart:io';

import '../models/behavior.dart';

/// Writes a minimal compilable Dart subject file for a behavior.
class SubjectWriter {
  const SubjectWriter();

  /// Write the subject file at [subjectPath] for [behavior].
  Future<void> write({
    required Behavior behavior,
    required String subjectPath,
  }) async {
    final file = File(subjectPath);
    await file.parent.create(recursive: true);
    final content = renderSubject(behavior: behavior);
    await file.writeAsString(content);
  }

  /// Render the subject content this binary would write for [behavior]
  /// without touching disk (bug #683 — lets `gen` compare on-disk artifacts
  /// against current output before deciding to regenerate).
  String renderSubject({required Behavior behavior}) =>
      _renderSubject(behavior);

  String _renderSubject(Behavior b) {
    final target = b.target.isEmpty ? 'subjectUnderTest' : b.target;
    final kind = b.kind;
    if (kind == BehaviorKind.unit) {
      return '''
// GENERATED STUB — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// description: ${b.description}
//
// This is a MINIMAL COMPILABLE STUB. It compiles cleanly (FR-011) but
// does NOT satisfy the behavior described above — the paired test will
// fail on first execution with an assertion-level failure (honest red).
// Replace this stub body with real implementation to make the test pass.
library;

/// Subject for behavior ${b.id}.
///
/// Throws [UnimplementedError] until the real implementation lands.
int $target() => throw UnimplementedError('$target not implemented');
''';
    }
    // Acceptance: emit a "scenario runner" that throws UnimplementedError.
    // The acceptance subject does NOT reference any entity/use case/
    // repository — it stands alone (FR-004).
    return '''
// GENERATED STUB — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// description: ${b.description}
//
// This is a MINIMAL COMPILABLE acceptance-scenario stub. It compiles
// cleanly (FR-011) but does NOT satisfy the behavior described above —
// the paired test will fail on first execution with an assertion-level
// failure (honest red). The acceptance subject intentionally does NOT
// reference any entity/use case/repository (FR-004): it stands alone.
// Replace this stub body with real implementation to make the test pass.
library;

/// Scenario runner for behavior ${b.id}.
///
/// Throws [UnimplementedError] until the real implementation lands.
void $target() => throw UnimplementedError('$target not implemented');
''';
  }
}
