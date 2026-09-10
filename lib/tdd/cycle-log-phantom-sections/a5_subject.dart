// IMPLEMENTED SUBJECT — `zfa tdd gen A5` stub replaced by hand (issue
// #1467 remediation; the designed hand-delta seam).
//
// behavior_id: A5
// source_criterion: AC-5
// description: parseEntries yields exactly one entry with id/kind/hash
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/src/plugins/tdd/services/cycle_evidence.dart';

/// A5 — end-to-end structured parse: `parseEntries` on a log whose red
/// entry's captured output contains `## Cycle: BOGUS (red)` and
/// `## Notes` lines yields exactly one entry, with the behavior id, kind,
/// and hash-chain link intact.
void subject_a5() {
  // 64 hex chars — the shape parseEntries' `- hash:` regex enforces
  // (`[0-9a-f]{64}`, cycle_evidence.dart); a longer fake hash would rightly
  // be rejected and leave the entry unhashed.
  final hash = 'f6b8d0' * 10 + 'f6b8';
  final raw =
      '# Cycle Log\n\n'
      '## Cycle: A5 (red)\n\n'
      '- behavior: A5\n'
      '- kind: red\n'
      '- criterion: AC-5\n'
      '- test: test/tdd/cycle-log-phantom-sections/a5_test.dart::A5\n'
      '- command: `dart test a5`\n'
      '- exit: 1\n'
      '- at: 2026-09-11T00:00:00.000Z\n'
      '- output:\n'
      '```\n'
      'captured stdout\n'
      '## Cycle: BOGUS (red)\n'
      '## Notes\n'
      '```\n'
      '- schema: 1\n'
      '- prev-hash: genesis\n'
      '- hash: $hash\n\n';

  final entries = parseEntries(raw);
  if (entries.length != 1) {
    throw StateError(
      'A5: expected exactly 1 parsed entry, got ${entries.length} — '
      'phantom section absorbed or duplicated the real entry',
    );
  }
  final entry = entries.single;
  if (entry.behaviorId != 'A5') {
    throw StateError('A5: behavior id misattributed: ${entry.behaviorId}');
  }
  if (entry.kind != 'red') {
    throw StateError('A5: kind lost to the phantom section: ${entry.kind}');
  }
  if (entry.hash != hash) {
    throw StateError('A5: hash-chain link lost: ${entry.hash}');
  }
  if (!entry.isHashed) {
    throw StateError('A5: entry does not participate in the hash chain');
  }
}
