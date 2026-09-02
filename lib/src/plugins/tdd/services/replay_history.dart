/// `ReplayHistory` — the parsed, grouped, integrity-verified recorded
/// history of a feature's TDD cycle log (spec 066-zfa-replay).
///
/// Reads `specs/<feature>/tdd/cycle-log.md` through the shared
/// `CycleEvidence.parseEntries` (one `## `-delimited section per entry,
/// `- behavior:` required — hand-written narrative sections without it are
/// naturally skipped, replay never executes prose) and groups the entries
/// per behavior in file order. Green sections additionally yield their
/// recorded `generation:` steps (the `  - step:` / `    exit:` /
/// `    purpose:` lines the 047 make pipeline renders), which replay
/// re-executes in the sandbox.
///
/// The integrity stage recomputes the per-behavior evidence chain exactly
/// as `CycleLog.append` built it — sha256 over `CycleLog.payloadFromFields`
/// plus prev-hash linkage from `CycleLog.genesisHash` — and structurally
/// validates red evidence against the real tree. A behavior whose integrity
/// stage diverges MUST NOT proceed to gen/verify: the commands of a
/// tampered history are never executed (FR-004).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'cycle_evidence.dart';
import 'cycle_log.dart';

/// One recorded generation step parsed from a green section's
/// `generation:` block.
class ReplayGenerationStep {
  /// The full recorded command line, e.g. `zfa tdd gen <id> --feature <f>`.
  final String command;

  /// The recorded `exit:` value, when the step carried one.
  final int? exitCode;

  /// The recorded `purpose:` value, when the step carried one.
  final String? purpose;

  const ReplayGenerationStep({
    required this.command,
    this.exitCode,
    this.purpose,
  });
}

/// One behavior's grouped recorded history (file order preserved).
class ReplayBehavior {
  final String id;
  final List<ParsedCycleEntry> entries;
  final ParsedCycleEntry? red;
  final ParsedCycleEntry? green;
  final List<ParsedCycleEntry> refactors;
  final List<ReplayGenerationStep> genSteps;

  /// The `- classification:` value of the red section, when present
  /// (parseEntries does not carry it; replay extracts it from the section).
  final String? redClassification;

  const ReplayBehavior({
    required this.id,
    required this.entries,
    required this.red,
    required this.green,
    required this.refactors,
    required this.genSteps,
    required this.redClassification,
  });

  /// Gen replay is possible when a green entry recorded generation steps.
  bool get canReplayGen => green != null && genSteps.isNotEmpty;

  /// Verify replay is possible when a green entry recorded a command.
  bool get canReplayVerify =>
      green?.command != null && green!.command!.isNotEmpty;

  /// Whether any parsed entry lacked a hash chain (legacy schema-0).
  bool get hashless => entries.any((entry) => !entry.isHashed);
}

/// The integrity stage's outcome for one behavior.
class IntegrityOutcome {
  final bool ok;

  /// The kind of the first broken entry (`green`, …) on a chain mismatch.
  final String? brokenEntryKind;

  /// Machine detail: `chain mismatch: <kind>`, `chain linkage: <kind>`,
  /// or a red violation (`red-missing-test-artifact`, `red-exit-zero`,
  /// `red-no-classification`).
  final String? reason;

  /// Kinds of hash-less (schema-0) entries: unverifiable, never failed.
  final List<String> unverifiedKinds;

  const IntegrityOutcome._(
    this.ok,
    this.brokenEntryKind,
    this.reason,
    this.unverifiedKinds,
  );

  const IntegrityOutcome.passed({List<String> unverifiedKinds = const []})
      : this._(true, null, null, unverifiedKinds);

  const IntegrityOutcome.broken({
    required String reason,
    String? entryKind,
    List<String> unverifiedKinds = const [],
  }) : this._(false, entryKind, reason, unverifiedKinds);
}

class ReplayHistory {
  const ReplayHistory._();

  /// Load and group the feature's recorded history. A missing or
  /// narrative-only log yields an empty list (the caller decides whether
  /// that is partial or an error — FR-002).
  static Future<List<ReplayBehavior>> load(String featureDir) async {
    final file = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
    if (!await file.exists()) return const [];
    final raw = await file.readAsString();
    final behaviors = <String, ReplayBehavior>{};
    for (final section in raw.split('\n## ')) {
      final behaviorMatch = RegExp(
        r'^- behavior: (\S+)',
        multiLine: true,
      ).firstMatch(section);
      if (behaviorMatch == null) continue;
      final id = behaviorMatch.group(1)!;
      // parseEntries on the single section text (it contains no '\n## ')
      // reuses the shared field regexes verbatim.
      final parsed = parseEntries(section);
      if (parsed.isEmpty) continue;
      final entry = parsed.first;
      final kind = entry.kind;
      final classification =
          RegExp(r'^- classification: (\S+)', multiLine: true)
              .firstMatch(section)
              ?.group(1);
      final genSteps = kind == 'green'
          ? _parseGenerationSteps(section)
          : const <ReplayGenerationStep>[];
      final existing = behaviors[id];
      final red = kind == 'red' ? entry : existing?.red;
      final green = kind == 'green' ? entry : existing?.green;
      final refactors = kind == 'refactor'
          ? [...(existing?.refactors ?? const <ParsedCycleEntry>[]), entry]
          : existing?.refactors ?? const <ParsedCycleEntry>[];
      behaviors[id] = ReplayBehavior(
        id: id,
        entries: [...(existing?.entries ?? const <ParsedCycleEntry>[]), entry],
        red: red,
        green: green,
        refactors: refactors,
        genSteps: kind == 'green'
            ? genSteps
            : existing?.genSteps ?? const <ReplayGenerationStep>[],
        redClassification: kind == 'red'
            ? classification
            : existing?.redClassification,
      );
    }
    return behaviors.values.toList(growable: false);
  }

  /// The integrity stage (FR-004/FR-005): recompute the per-behavior chain
  /// over hashed entries, then structurally validate the red evidence.
  static Future<IntegrityOutcome> verifyIntegrity(
    ReplayBehavior behavior, {
    required String projectRoot,
  }) async {
    final unverified = <String>[];
    String? prevHash;
    for (final entry in behavior.entries) {
      if (!entry.isHashed) {
        unverified.add(entry.kind);
        continue;
      }
      final recomputed = sha256
          .convert(
            utf8.encode(
              CycleLog.payloadFromFields(
                behaviorId: entry.behaviorId,
                kind: entry.kind,
                exit: entry.exit?.toString() ?? '',
                command: entry.command ?? '',
                criterion: entry.criterion ?? '',
                test: entry.test ?? '',
                timestamp: entry.at ?? '',
                prevHash: entry.prevHash ?? '',
              ),
            ),
          )
          .toString();
      if (recomputed != entry.hash) {
        return IntegrityOutcome.broken(
          reason: 'chain mismatch: ${entry.kind}',
          entryKind: entry.kind,
          unverifiedKinds: unverified,
        );
      }
      final expectedPrev = prevHash ?? CycleLog.genesisHash;
      if ((entry.prevHash ?? '') != expectedPrev) {
        return IntegrityOutcome.broken(
          reason: 'chain linkage: ${entry.kind}',
          entryKind: entry.kind,
          unverifiedKinds: unverified,
        );
      }
      prevHash = entry.hash;
    }

    final red = behavior.red;
    if (red != null) {
      final testPath = red.test;
      if (testPath == null || testPath.isEmpty) {
        return IntegrityOutcome.broken(
          reason: 'red-missing-test-artifact',
          entryKind: 'red',
          unverifiedKinds: unverified,
        );
      }
      final resolved = p.isAbsolute(testPath)
          ? testPath
          : p.join(projectRoot, testPath);
      if (!await File(resolved).exists()) {
        return IntegrityOutcome.broken(
          reason: 'red-missing-test-artifact: $testPath',
          entryKind: 'red',
          unverifiedKinds: unverified,
        );
      }
      if (red.exit == null || red.exit == 0) {
        return IntegrityOutcome.broken(
          reason: 'red-exit-zero',
          entryKind: 'red',
          unverifiedKinds: unverified,
        );
      }
      if (behavior.redClassification == null) {
        return IntegrityOutcome.broken(
          reason: 'red-no-classification',
          entryKind: 'red',
          unverifiedKinds: unverified,
        );
      }
    }
    return IntegrityOutcome.passed(unverifiedKinds: unverified);
  }

  /// Extract the recorded generation steps from a green section's
  /// `generation:` block, in recorded order. The writer renders
  /// `  - step: <cmd>` then `    exit: <n>` then `    purpose: <p>` per
  /// step (or `  (none)` for an empty block).
  static List<ReplayGenerationStep> _parseGenerationSteps(String section) {
    final steps = <ReplayGenerationStep>[];
    String? command;
    int? exit;
    String? purpose;
    void flush() {
      final cmd = command;
      if (cmd != null) {
        steps.add(
          ReplayGenerationStep(
            command: cmd,
            exitCode: exit,
            purpose: purpose,
          ),
        );
      }
      command = null;
      exit = null;
      purpose = null;
    }

    for (final line in section.split('\n')) {
      final stepMatch = RegExp(r'^  - step: (.+)$').firstMatch(line);
      if (stepMatch != null) {
        flush();
        command = stepMatch.group(1)!.trim();
        continue;
      }
      final exitMatch = RegExp(r'^    exit: (-?\d+)$').firstMatch(line);
      if (exitMatch != null && command != null) {
        exit = int.parse(exitMatch.group(1)!);
        continue;
      }
      final purposeMatch = RegExp(r'^    purpose: (.+)$').firstMatch(line);
      if (purposeMatch != null && command != null) {
        purpose = purposeMatch.group(1)!.trim();
        continue;
      }
    }
    flush();
    return steps;
  }
}
