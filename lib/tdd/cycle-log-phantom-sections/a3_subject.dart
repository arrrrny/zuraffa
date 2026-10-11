// IMPLEMENTED SUBJECT — `zfa tdd gen A3` stub replaced by hand (issue
// #1467 remediation; the designed hand-delta seam).
//
// behavior_id: A3
// source_criterion: AC-3
// description: clean logs parse byte-identically to the legacy split
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/src/plugins/tdd/services/cycle_log_sections.dart';

/// A3 — no format change: a cycle-log whose captured output contains no
/// `## ` lines must section exactly like the legacy `split('\n## ')`.
void subject_a3() {
  final raw =
      '# Cycle Log\n\n'
      '## Cycle: A3-1 (red)\n\n'
      '- behavior: A3-1\n'
      '- kind: red\n'
      '- criterion: AC-3\n'
      '- test: test/tdd/x/a3_1_test.dart::A3-1\n'
      '- command: `dart test a3_1`\n'
      '- exit: 1\n'
      '- at: 2026-09-11T00:00:00.000Z\n'
      '- output:\n'
      '```\n'
      'Expected: true\n'
      '  Actual: false\n'
      '```\n'
      '- hash: d4f6a8d4f6a8d4f6a8d4f6a8d4f6a8d4f6a8d4f6a8d4f6a8d4f6a8d4f6a8\n'
      '\n'
      '## Notes\n\n'
      'hand-written prose, not an entry\n\n'
      '## Cycle: A3-2 (green)\n\n'
      '- behavior: A3-2\n'
      '- kind: green\n'
      '- criterion: AC-3\n'
      '- test: test/tdd/x/a3_2_test.dart::A3-2\n'
      '- command: `dart test a3_2`\n'
      '- exit: 0\n'
      '- at: 2026-09-11T00:02:00.000Z\n'
      '- output:\n'
      '```\n'
      '+1: All tests passed\n'
      '```\n'
      '- hash: e5a7b9e5a7b9e5a7b9e5a7b9e5a7b9e5a7b9e5a7b9e5a7b9e5a7b9e5a7b9\n\n';

  final legacy = raw.split('\n## ');
  final fenceAware = splitCycleLogSections(raw);
  if (fenceAware.length != legacy.length) {
    throw StateError(
      'A3: section count drifted: legacy=${legacy.length} '
      'fence-aware=${fenceAware.length}',
    );
  }
  for (var i = 0; i < legacy.length; i++) {
    if (fenceAware[i] != legacy[i]) {
      throw StateError(
        'A3: section $i differs from the legacy split — clean log '
        'byte-compat broken',
      );
    }
  }
  // Joining reproduces the raw document (no bytes lost or invented).
  if (fenceAware.join('\n## ') != raw) {
    throw StateError('A3: sections do not re-join to the raw document');
  }
}
