/// `CycleEvidence` — the red/green evidence sets for a feature, parsed from
/// `tdd/cycle-log.md` (spec 049-tdd-run, FR-003 / U4-U6).
///
/// Generalizes the section parsing `verify_red_command.dart` uses: a
/// behavior has red evidence when a `## `-delimited cycle-log section
/// carries both `- behavior: <id>` and `- kind: red` (and green evidence
/// for `- kind: green`). A missing cycle log yields empty sets — the
/// absence of evidence is not an error, it is a not-done behavior.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

class CycleEvidence {
  const CycleEvidence(this.featureDir);

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// Behavior ids that have a `kind: red` cycle-log section.
  Future<Set<String>> redEvidence() => _evidence('red');

  /// Behavior ids that have a `kind: green` cycle-log section.
  Future<Set<String>> greenEvidence() => _evidence('green');

  Future<Set<String>> _evidence(String kind) async {
    final file = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
    if (!await file.exists()) return const {};
    final raw = await file.readAsString();
    final ids = <String>{};
    for (final section in raw.split('\n## ')) {
      final behavior = RegExp(
        r'^- behavior: (\S+)',
        multiLine: true,
      ).firstMatch(section);
      if (behavior == null) continue;
      if (RegExp('^- kind: $kind\$', multiLine: true).hasMatch(section)) {
        ids.add(behavior.group(1)!);
      }
    }
    return ids;
  }
}
