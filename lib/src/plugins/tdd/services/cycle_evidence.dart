/// `CycleEvidence` — the red/green evidence sets for a feature, parsed from
/// `tdd/cycle-log.md` (spec 049-tdd-run, FR-003 / U4-U6).
///
/// Generalizes the section parsing `verify_red_command.dart` uses: a
/// behavior has red evidence when a `## `-delimited cycle-log section
/// carries both `- behavior: <id>` and `- kind: red` (and green evidence
/// for `- kind: green`). A missing cycle log yields empty sets — the
/// absence of evidence is not an error, it is a not-done behavior.
///
/// Bug #828: the evidence API also exposes refactor-kind entries, the
/// structured parse of every entry (the doctor's drift report and the
/// write-ahead journal replay read timestamps and evidence-chain hashes),
/// and the last recorded chain hash for a behavior (CycleLog chains
/// red-hash -> green-hash -> refactor-hash per behavior).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// One parsed cycle-log section: the certified facts the doctor, the
/// journal replay, and the evidence-chain verifier read. `null` fields
/// mean the entry did not carry them (legacy schema-0 entries carry no
/// hash-chain lines).
class ParsedCycleEntry {
  final String behaviorId;
  final String kind;

  /// The `- at:` ISO-8601 timestamp, when present.
  final String? at;

  /// The `- exit:` code, when present.
  final int? exit;

  /// The `- criterion:` field, when present.
  final String? criterion;

  /// The `- test:` field, when present.
  final String? test;

  /// The `` `- command:` `` field (backticks stripped), when present.
  final String? command;

  /// The `- schema:` version line (e.g. `1`), when present.
  final String? schema;

  /// The `- prev-hash:` chain link, when present.
  final String? prevHash;

  /// The `- hash:` chain link, when present.
  final String? hash;

  const ParsedCycleEntry({
    required this.behaviorId,
    required this.kind,
    this.at,
    this.exit,
    this.criterion,
    this.test,
    this.command,
    this.schema,
    this.prevHash,
    this.hash,
  });

  /// Whether this entry participates in the evidence hash chain (bug
  /// #828 schema-1 entries). Legacy entries without hash lines are valid
  /// but unverifiable — the doctor reports them, never fails them.
  bool get isHashed => hash != null;
}

class CycleEvidence {
  const CycleEvidence(this.featureDir);

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// Behavior ids that have a `kind: red` cycle-log section.
  Future<Set<String>> redEvidence() => _evidence('red');

  /// Behavior ids that have a `kind: green` cycle-log section.
  Future<Set<String>> greenEvidence() => _evidence('green');

  /// Behavior ids that have a `kind: refactor` cycle-log section.
  ///
  /// Bug #828: the refactor kind completes the red -> green -> refactor
  /// evidence triple. The refactor command records feature-level entries
  /// (behavior id `<feature>-refactor`), so per-behavior refactor evidence
  /// is parsed but the run driver's certification contract (spec 049) stays
  /// keyed on red+green — this set is the doctor's drift input.
  Future<Set<String>> refactorEvidence() => _evidence('refactor');

  /// Every parsed entry, in file order.
  Future<List<ParsedCycleEntry>> entries() async {
    final file = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
    if (!await file.exists()) return const [];
    final raw = await file.readAsString();
    return parseEntries(raw);
  }

  /// The hash of the LAST hashed entry for [behaviorId], or `null` when
  /// the behavior has no hashed entries yet (the chain starts at
  /// `genesis`).
  Future<String?> lastHashFor(String behaviorId) async {
    String? last;
    for (final entry in await entries()) {
      if (entry.behaviorId == behaviorId && entry.hash != null) {
        last = entry.hash;
      }
    }
    return last;
  }

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

/// Parse [raw] cycle-log markdown into [ParsedCycleEntry]s (one per
/// `## `-delimited section). Sections without a `- behavior:` line are
/// skipped (the file header, hand-written prose).
List<ParsedCycleEntry> parseEntries(String raw) {
  final entries = <ParsedCycleEntry>[];
  for (final section in raw.split('\n## ')) {
    final behavior = RegExp(
      r'^- behavior: (\S+)',
      multiLine: true,
    ).firstMatch(section);
    if (behavior == null) continue;
    String? capture(RegExp re) => re.firstMatch(section)?.group(1);
    final kind = capture(RegExp(r'^- kind: (\S+)', multiLine: true)) ?? '';
    final at = capture(RegExp(r'^- at: (.+)$', multiLine: true));
    final exitRaw = capture(RegExp(r'^- exit: (-?\d+)$', multiLine: true));
    final criterion = capture(RegExp(r'^- criterion: (.+)$', multiLine: true));
    final test = capture(RegExp(r'^- test: (.+)$', multiLine: true));
    final command = capture(RegExp(r'^- command: `(.*)`$', multiLine: true));
    final schema = capture(RegExp(r'^- schema: (\d+)$', multiLine: true));
    final prevHash = capture(RegExp(r'^- prev-hash: (\S+)$', multiLine: true));
    final hash = capture(RegExp(r'^- hash: ([0-9a-f]{64})$', multiLine: true));
    entries.add(
      ParsedCycleEntry(
        behaviorId: behavior.group(1)!,
        kind: kind,
        at: at,
        exit: exitRaw == null ? null : int.tryParse(exitRaw),
        criterion: criterion,
        test: test,
        command: command,
        schema: schema,
        prevHash: prevHash,
        hash: hash,
      ),
    );
  }
  return entries;
}
