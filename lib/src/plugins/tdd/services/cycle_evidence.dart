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

import 'born_green.dart';
import 'cycle_log_sections.dart';

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

  /// The `- subject-hash:` evidence field (issue #1036), when present:
  /// the sha256 of the subject file at certification time.
  final String? subjectHash;

  /// The `- classification:` field of a red entry, when present: the
  /// failure class the certifying step recorded (`assertionFailure`,
  /// `compileError`, ...). Issue #1587 review: the make's drift-check
  /// dedup reads it so a red that certified anything other than an
  /// honest assertion failure can never satisfy the make's
  /// pre-generation precondition. Absent for legacy and non-red
  /// entries — the readers that require it fail open.
  final String? classification;

  /// The `- evidence:` field (issue #959 red entries; the issue #1411
  /// born-green transition's green entry), when present: the free-text
  /// evidence note the certifying step recorded. Issue #1542: the run
  /// driver's refactor evidence check reads this field's born-green
  /// marker ([bornGreenEvidenceMarker]) to accept green-only
  /// certification for born-green behaviors.
  final String? evidence;

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
    this.subjectHash,
    this.classification,
    this.evidence,
  });

  /// Whether this entry participates in the evidence hash chain (bug
  /// #828 schema-1 entries). Legacy entries without hash lines are valid
  /// but unverifiable — the doctor reports them, never fails them.
  bool get isHashed => hash != null;
}

class CycleEvidence {
  /// A plain view: every read hits disk. Writers and the run driver keep
  /// this one — appended evidence must never be read through a stale
  /// cache.
  CycleEvidence(this.featureDir) : _cache = false;

  /// A caching view for read-only multi-read flows (`zfa tdd doctor`
  /// parses the same log for every check): one disk read + parse serves
  /// every call on the instance. There is no invalidation — callers must
  /// not use it across a write to the same log (review #1612, finding 5).
  CycleEvidence.cached(this.featureDir) : _cache = true;

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  final bool _cache;

  bool _loaded = false;
  String? _raw;
  List<ParsedCycleEntry>? _entries;
  final Map<String, Set<String>> _kindSets = {};

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

  /// Behavior ids whose LAST green evidence entry names a test file that
  /// is missing from disk — `evidence-without-artifact` (issue #1264).
  ///
  /// The store-to-tree check the store-to-store comparisons miss: green
  /// evidence in the cycle-log survives artifact deletion (`zfa tdd reset`
  /// never touches append-only evidence), and a downstream reader that
  /// honors it without checking the tree reports done/green for behaviors
  /// whose test files no longer exist. The green entry's `- test:` line
  /// names the registered test path it certified (absolute or
  /// project-relative); a missing file orphans the evidence. Entries
  /// without a `- test:` line cannot be checked and are conservatively
  /// treated as backed (legacy tolerance — never fails what it cannot
  /// read).
  Future<Set<String>> orphanedGreenEvidence({
    required String projectRoot,
  }) async {
    // Append order is chronological: the LAST green entry per behavior
    // is the live evidence (the same rule greenEvidence() applies).
    final lastGreen = <String, ParsedCycleEntry>{};
    for (final entry in await entries()) {
      if (entry.kind != 'green') continue;
      lastGreen[entry.behaviorId] = entry;
    }
    final orphans = <String>{};
    for (final MapEntry(key: behaviorId, value: entry) in lastGreen.entries) {
      final test = entry.test;
      if (test == null || test.isEmpty) continue;
      // The cycle-log convention appends `::behaviorId` to the test path
      // (e.g. `test/foo_test.dart::A1`). Strip the suffix before checking
      // file existence so the real path is resolved.
      final cleanTest = test.contains('::') ? test.split('::').first : test;
      final resolved = p.isAbsolute(cleanTest)
          ? p.normalize(cleanTest)
          : p.normalize(p.join(projectRoot, cleanTest));
      if (!File(resolved).existsSync()) {
        orphans.add(behaviorId);
      }
    }
    return orphans;
  }

  /// Whether the behavior's LAST green evidence entry certifies the
  /// born-green hand transition (issue #1411) — the entry's `- evidence:`
  /// field carries the shared journal marker the `make --born-green`
  /// transition writes ([bornGreenEvidenceMarker]).
  ///
  /// Issue #1542: the run driver's refactor evidence check keys on this
  /// to accept green-only certification for born-green behaviors — red is
  /// defined out of existence by the transition, so demanding a red entry
  /// would dead-end the run. The probe reads the JOURNAL (append-only
  /// evidence), not the run state, so the certification survives state
  /// resets and degradations; the LAST-green rule is the same append-order
  /// rule [greenEvidence] and [orphanedGreenEvidence] apply.
  ///
  /// Review #1566: the match is ANCHORED to the note's start (the
  /// transition writes the marker first) — `- evidence:` is free-form
  /// (the issue #959 additive field), so a bare substring probe would
  /// also exempt a red-less entry whose note merely QUOTES the marker
  /// prose (a hand-written debugging note).
  Future<bool> bornGreenCertified(String behaviorId) async {
    final last = await lastEntryFor(behaviorId, kind: 'green');
    if (last == null) return false;
    final note = last.evidence;
    if (note == null) return false;
    return note.startsWith(bornGreenEvidenceMarker);
  }

  /// Every parsed entry, in file order.
  Future<List<ParsedCycleEntry>> entries() async {
    if (_cache && _entries != null) return _entries!;
    final raw = await _readRaw();
    final parsed = raw == null ? const <ParsedCycleEntry>[] : parseEntries(raw);
    if (_cache) _entries = parsed;
    return parsed;
  }

  /// The log's raw text, or null when the file does not exist. Cached in
  /// [CycleEvidence.cached] mode (one disk read per instance).
  Future<String?> _readRaw() async {
    if (_loaded) return _raw;
    final file = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
    final raw = await file.exists() ? await file.readAsString() : null;
    if (_cache) {
      _loaded = true;
      _raw = raw;
    }
    return raw;
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

  /// The LAST parsed entry of [kind] (`red` / `green` / `refactor`) for
  /// [behaviorId] in file order, or `null` when the behavior has no
  /// entry of that kind. The make skip transition reads the last red and
  /// last green entries' `- subject-hash:` to refuse a skip on a subject
  /// the certified evidence never exercised (issue #1036).
  Future<ParsedCycleEntry?> lastEntryFor(
    String behaviorId, {
    required String kind,
  }) async {
    ParsedCycleEntry? last;
    for (final entry in await entries()) {
      if (entry.behaviorId == behaviorId && entry.kind == kind) {
        last = entry;
      }
    }
    return last;
  }

  Future<Set<String>> _evidence(String kind) async {
    if (_cache && _kindSets.containsKey(kind)) return _kindSets[kind]!;
    final raw = await _readRaw();
    final ids = <String>{};
    if (raw != null) {
      for (final section in splitCycleLogSections(raw)) {
        final behavior = RegExp(
          r'^- behavior: (\S+)',
          multiLine: true,
        ).firstMatch(section);
        if (behavior == null) continue;
        if (RegExp('^- kind: $kind\$', multiLine: true).hasMatch(section)) {
          ids.add(behavior.group(1)!);
        }
      }
    }
    if (_cache) _kindSets[kind] = ids;
    return ids;
  }
}

/// Parse [raw] cycle-log markdown into [ParsedCycleEntry]s (one per
/// `## `-delimited section). Sections without a `- behavior:` line are
/// skipped (the file header, hand-written prose).
List<ParsedCycleEntry> parseEntries(String raw) {
  final entries = <ParsedCycleEntry>[];
  for (final section in splitCycleLogSections(raw)) {
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
    final subjectHash = capture(
      RegExp(r'^- subject-hash: ([0-9a-f]{64})$', multiLine: true),
    );
    final classification = capture(
      RegExp(r'^- classification: (\S+)$', multiLine: true),
    );
    final evidence = capture(RegExp(r'^- evidence: (.+)$', multiLine: true));
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
        subjectHash: subjectHash,
        classification: classification,
        evidence: evidence,
      ),
    );
  }
  return entries;
}
