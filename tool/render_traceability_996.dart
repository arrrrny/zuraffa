// Renders specs/0996-receipts-standalone-capabilities/tdd/traceability.md
// using the repo's OWN TraceabilityMatrix renderer + RequirementScanner,
// so the spec-hash is exactly what `zfa tdd verify` re-derives (bug #846).
import 'dart:io';

import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/requirement_scan.dart';

void main() {
  const feature = '0996-receipts-standalone-capabilities';
  final featureDir = 'specs/$feature';
  final specMd = File('$featureDir/spec.md').readAsStringSync();

  final scan = const RequirementScanner().scan(specMd);

  final behaviors = <Behavior>[
    for (final record in [
      (
        'B-001',
        'FR-001',
        'wrapper auto-persists a proof.v1 receipt keyed '
            '<plugin>-<capability>-<entity>-<timestamp>.json',
      ),
      ('B-002', 'FR-003', 'machine-readable receipt schema on disk'),
      (
        'B-003',
        'FR-002',
        'receipts for all twelve standalone capabilities (hook + matrix)',
      ),
      ('B-004', 'FR-005', 'receipt preflight gate in zfa tdd verify'),
      (
        'B-005',
        'FR-004',
        'proof-checkable receipt bytes: digests/snapshots the wrapper '
            'writes validate under zfa proof check',
      ),
    ])
      Behavior(
        id: record.$1,
        feature: feature,
        kind: BehaviorKind.acceptance,
        description: record.$3,
        sourceCriterion: record.$2,
        target: 'lib/src/core/plugin_system/capability_invocation_wrapper.dart',
        state: BehaviorState.done,
      ),
  ];

  final matrix = TraceabilityMatrix().render(
    feature: feature,
    scan: scan,
    behaviors: behaviors,
  );
  File('$featureDir/tdd/traceability.md').writeAsStringSync(matrix);
  final hash = SpecContractHash.compute(scan);
  print('statements: ${scan.statements.length}');
  print('spec-hash: $hash');
  print('wrote $featureDir/tdd/traceability.md');
}
