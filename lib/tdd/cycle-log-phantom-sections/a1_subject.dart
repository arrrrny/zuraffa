// IMPLEMENTED SUBJECT — `zfa tdd gen A1` stub replaced by hand (issue
// #1467 remediation; the designed hand-delta seam).
//
// behavior_id: A1
// source_criterion: AC-1
// description: the in-fence `## ` lines do NOT start new sections
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/src/plugins/tdd/services/cycle_log_sections.dart';

/// A1 — in-fence `## ` lines do NOT start new sections.
///
/// A red entry whose fenced `- output:` contains `## ` banner lines must
/// parse as ONE section: the phantom-section bug (issue #1467) stranded the
/// entry's trailing `- kind:`/`- hash:` fields in a fake section.
void subject_a1() {
  const hash =
      'a1c3e5a1c3e5a1c3e5a1c3e5a1c3e5a1c3e5a1c3e5a1c3e5'
      'a1c3e5a1c3e5a1c3e5a1c3e5';
  final raw =
      '# Cycle Log\n\n'
      '## Cycle: A1 (red)\n\n'
      '- behavior: A1\n'
      '- kind: red\n'
      '- criterion: AC-1\n'
      '- test: test/tdd/cycle-log-phantom-sections/a1_test.dart::A1\n'
      '- command: `dart test a1`\n'
      '- exit: 1\n'
      '- at: 2026-09-11T00:00:00.000Z\n'
      '- output:\n'
      '```\n'
      'flutter banner\n'
      '## Cycle: BOGUS (red)\n'
      '## Notes\n'
      'more output\n'
      '```\n'
      '- hash: $hash\n\n';

  final sections = splitCycleLogSections(raw);
  if (sections.length != 2) {
    throw StateError(
      'A1: expected 2 sections (file header + one entry), got '
      '${sections.length} — in-fence "## " lines started phantom sections',
    );
  }
  final entry = sections[1];
  if (!entry.contains('- kind: red')) {
    throw StateError('A1: the real entry lost its - kind: field');
  }
  if (!entry.contains('- hash: $hash')) {
    throw StateError('A1: the real entry lost its - hash: chain link');
  }
}
