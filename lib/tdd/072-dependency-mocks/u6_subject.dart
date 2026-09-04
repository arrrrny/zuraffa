// GENERATED subject — implemented (issue #960 U6 / FR-006).
//
// A dependencyMake behavior whose mock artifacts are absent is refused
// with the generation fix named — never a silently absent test double.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/capabilities/dependency_mock_capability.dart';

Object? subject_u6() {
  // The refusal contract is a named constant the make/loop paths share,
  // so the fix hint cannot drift between the single and batch lanes.
  expect(
    DependencyMockCapability.missingMockFixHint,
    equals('zfa mock dependency <Name>'),
  );
  expect(
    DependencyMockCapability.absentArtifactsOutcome,
    equals('refused'),
    reason: 'absent artifacts are a named refusal, never a silent pass',
  );
  return null;
}
