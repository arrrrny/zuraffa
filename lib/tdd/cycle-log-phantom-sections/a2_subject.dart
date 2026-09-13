// IMPLEMENTED SUBJECT — `zfa tdd gen A2` stub replaced by hand (issue
// #1467 remediation; the designed hand-delta seam).
//
// behavior_id: A2
// source_criterion: AC-2
// description: fence state stays synchronized (info-string fences)
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/src/plugins/tdd/services/cycle_log_sections.dart';

/// A2 — fence state stays synchronized; info-string fences and fenced
/// output containing `## ` lines must not desynchronize section parsing.
void subject_a2() {
  const hash1 =
      'b2d4f6b2d4f6b2d4f6b2d4f6b2d4f6b2d4f6b2d4f6b2d4f6'
      'b2d4f6b2d4f6b2d4f6b2d4f6';
  const hash2 =
      'c3e5a7c3e5a7c3e5a7c3e5a7c3e5a7c3e5a7c3e5a7c3e5a7'
      'c3e5a7c3e5a7c3e5a7c3e5a7';
  final raw =
      '# Cycle Log\n\n'
      '## Cycle: A2 (red)\n\n'
      '- behavior: A2\n'
      '- kind: red\n'
      '- criterion: AC-2\n'
      '- test: test/tdd/cycle-log-phantom-sections/a2_test.dart::A2\n'
      '- command: `dart test a2`\n'
      '- exit: 1\n'
      '- at: 2026-09-11T00:00:00.000Z\n'
      '- output:\n'
      '```dart\n'
      'void main() {\n'
      '  // a captured markdown dump:\n'
      '## not a section even inside a code fence\n'
      '  print("x");\n'
      '}\n'
      '```\n'
      '- hash: $hash1\n\n'
      '## Cycle: B2 (green)\n\n'
      '- behavior: B2\n'
      '- kind: green\n'
      '- criterion: AC-2\n'
      '- test: test/tdd/x/b2_test.dart::B2\n'
      '- command: `dart test b2`\n'
      '- exit: 0\n'
      '- at: 2026-09-11T00:01:00.000Z\n'
      '- output:\n'
      '```\n'
      'ok\n'
      '```\n'
      '- hash: $hash2\n\n';

  final sections = splitCycleLogSections(raw);
  if (sections.length != 3) {
    throw StateError(
      'A2: expected 3 sections (header + 2 entries), got '
      '${sections.length} — fence state desynchronized',
    );
  }
  if (!sections[1].contains('- hash: $hash1')) {
    throw StateError('A2: first entry lost its hash — fence never closed');
  }
  if (!sections[2].contains('- behavior: B2') ||
      !sections[2].contains('- hash: $hash2')) {
    throw StateError('A2: second entry corrupted by first entry\'s fence');
  }
}
