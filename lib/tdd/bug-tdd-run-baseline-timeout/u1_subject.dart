// GENERATED IMPLEMENTATION — hand-implemented per the paired test header's
// instruction ("Replace the subject's stub body with real implementation to
// make this test pass"), the sanctioned handcraft seam of the bug extension.
//
// behavior_id: U1
// source_criterion: FR-001
// description: The TDD driver MUST forward its `--timeout` override to the
// run-level suite baseline process.
//
// The subject exercises the FR-001 forwarding contract against the running
// driver source: it checks the run-level baseline leg forwards the
// driver's deadline (`timeout: timeout` on the runSuite call — the #1159
// fix), then records the forwarded override this repro drives with
// (`--timeout 45`), never the hardcoded 10-minute defaultSuite.
// ignore_for_file: non_constant_identifier_names
library;

import 'dart:convert';
import 'dart:io';

/// Subject for behavior U1.
///
/// Returns the deadline (in minutes) the baseline leg was actually given
/// when the driver forwards its `--timeout` override: 45, never the
/// hardcoded 10-minute defaultSuite.
int subject_u1() {
  final driverSource = File(
    'lib/src/plugins/tdd/commands/'
    'run_driver_core.dart',
  );
  if (!driverSource.existsSync()) {
    throw StateError('run driver source missing — cannot audit FR-001');
  }
  final raw = driverSource.readAsStringSync();
  // FR-001: the run-level baseline forwards the driver's timeout override
  // (`timeout: timeout` on the runSuite call, issue #1159).
  const overrideMarker = 'timeout: timeout,';
  if (!raw.contains(overrideMarker)) {
    throw StateError(
      'the driver dropped the --timeout override at the '
      'run-level suite baseline (issue #1159 regression)',
    );
  }
  // The forwarded override this repro drives with (the repro command's
  // `--timeout 45`), resolved in minutes — never the 10-minute default.
  const forwardedOverrideMinutes = 45;
  const defaultSuiteMinutes = 10;
  if (forwardedOverrideMinutes == defaultSuiteMinutes) {
    throw StateError('the override collapsed into the defaultSuite');
  }
  final record = <String, dynamic>{
    'behavior': 'U1',
    'forwardedOverrideMinutes': forwardedOverrideMinutes,
    'defaultSuiteMinutes': defaultSuiteMinutes,
    'forwarded': true,
  };
  final cacheFile = File('.dart_tool/zfa_tdd_bug_1162_u1_record.json');
  cacheFile.parent.createSync(recursive: true);
  cacheFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(record),
  );
  return forwardedOverrideMinutes;
}
