// IMPLEMENTED SUBJECT — `zfa tdd gen A4` stub replaced by hand (issue
// #1467 remediation; the designed hand-delta seam).
//
// behavior_id: A4
// source_criterion: AC-4
// description: all 9 reader call sites route through the shared splitter
// ignore_for_file: non_constant_identifier_names
library;

import 'dart:io';

/// A4 — every cycle-log reader adopts the shared fence-aware splitter.
///
/// The 9 naive `raw.split('\n## ')` sites from issue #1467 must all be
/// gone from the reader sources, and every reader file must import the
/// shared helper — a partial fix would leave readers disagreeing with the
/// doctor (the exact failure mode of bug #828).
void subject_a4() {
  final root = _packageRoot();
  const readers = [
    'lib/src/plugins/tdd/services/cycle_evidence.dart', // 2 sites
    'lib/src/plugins/tdd/commands/verify_red_command.dart',
    'lib/src/plugins/tdd/commands/make_command.dart', // 2 sites
    'lib/src/plugins/tdd/commands/compose_command.dart', // 2 sites
    'lib/src/plugins/tdd/services/era_tagged_log.dart',
    'lib/src/plugins/tdd/services/theater_data.dart',
    'lib/src/plugins/tdd/services/replay_history.dart',
  ];
  const legacyPattern = "split('\\n## ')";
  for (final rel in readers) {
    final file = File('$root/$rel');
    if (!file.existsSync()) {
      throw StateError('A4: $rel missing — reader list stale');
    }
    final content = file.readAsStringSync();
    if (content.contains(legacyPattern)) {
      throw StateError(
        'A4: $rel still uses the naive split — not routed through '
        'the shared splitter',
      );
    }
    if (!content.contains('cycle_log_sections.dart')) {
      throw StateError('A4: $rel does not import the shared splitter');
    }
  }
  // The helper itself exists and exports the splitter.
  final helper = File(
    '$root/lib/src/plugins/tdd/services/cycle_log_sections.dart',
  );
  if (!helper.existsSync() ||
      !helper.readAsStringSync().contains('splitCycleLogSections')) {
    throw StateError('A4: shared splitter helper missing');
  }
}

String _packageRoot() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 8; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: zuraffa')) {
      return dir.path;
    }
    dir = dir.parent;
  }
  throw StateError('A4: could not locate the zuraffa package root');
}
