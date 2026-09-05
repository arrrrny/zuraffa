/// `TheaterData` — the read-only snapshot loader behind
/// `zfa tdd theater <feature>` (spec 1006, issue #1006).
///
/// Loads everything the replay TUI renders from the evidence that already
/// exists on disk — no separate state, no mutation, no re-execution:
///
///  - behaviors: `specs/<feature>/tdd/artifacts.json` (the 044 registry),
///    enriched with descriptions from `tdd/test-list.md` (lenient — a
///    missing or unreadable list degrades to the registry's own
///    description segment, never an error);
///  - the cycle-log timeline: `specs/<feature>/tdd/cycle-log.md`, parsed
///    as a SUPERSET of `CycleEvidence.parseEntries` (which the doctor and
///    replay share): the theater additionally captures the red
///    `classification`, the failing-assertion `evidence`, the fenced
///    `output` block, green `generation:` steps and refactor `actions:`
///    so the TUI can show the diff behind every cycle;
///  - receipts: `.zfa/receipts/<feature>/*.json` (the per-feature layout
///    the issue names) AND the flat `.zfa/receipts/*.json` store
///    `ReceiptStore` writes today — flat documents are attributed to the
///    feature by matching their recorded file paths against the
///    feature's registered subject/test paths (the same attribution
///    `FeatureProvenanceReader` uses). Latest-wins per path; corrupted
///    documents are skipped, never fatal.
///
/// The read-only contract is structural: this library performs zero
/// writes. Verification (A6) hashes the project tree before/after.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/project/receipt_store.dart';
import '../models/artifact_record.dart';
import '../models/red_classification.dart';
import '../services/artifact_registry.dart';
import '../services/test_list_reader.dart';

/// Raised when the theater cannot load a feature's journal: unknown
/// feature directory or missing artifact registry. Absence of a
/// cycle-log or of receipts is NOT an error — it is honest pending
/// state (the absence of evidence is not an error, it is a not-done
/// behavior).
class TheaterException implements Exception {
  const TheaterException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A behavior's proof status, derived from the cycle-log.
enum TheaterProofStatus { green, red, pending }

/// The receipt card rendered when a behavior is selected: the derived
/// proof action, the evidence line, and the file line, with the #807
/// generation receipt backing when one covers the behavior's files.
class TheaterReceipt {
  const TheaterReceipt({
    required this.behaviorId,
    required this.action,
    required this.evidence,
    required this.file,
    this.receiptAction,
    this.bytes,
    this.sha256,
    this.at,
    this.command,
    this.repro,
    this.receiptFile,
  });

  final String behaviorId;

  /// The derived proof action: `satisfied` (green evidence), `red` (red
  /// evidence only) or `pending` (no recorded evidence).
  final String action;

  /// The evidence line: the green test + exit + timestamp, the red
  /// classification + exit, or the honest absence.
  final String evidence;

  /// The registered subject path (the `file:` line).
  final String file;

  /// The #807 receipt's action (`create`/`update`/`delete`) when a
  /// receipt covers the subject, else null.
  final String? receiptAction;

  /// The #807 receipt's byte count, when backed.
  final int? bytes;

  /// The #807 receipt's sha256 (hex), when backed.
  final String? sha256;

  /// The #807 receipt document's timestamp, when backed.
  final String? at;

  /// The #807 command that produced the covered artifact.
  final String? command;

  /// The one-line repro command from the receipt document.
  final String? repro;

  /// The receipt document's file name, when backed.
  final String? receiptFile;
}

/// The classifier verdict for a behavior's recorded red, mapped onto the
/// `RedClassification` vocabulary (kebab-case label + remediation hint).
/// An unmapped or absent classification keeps the raw label with an
/// empty hint — the theater never invents remediations.
class TheaterVerdict {
  const TheaterVerdict({
    required this.classificationLabel,
    required this.remediationHint,
    this.evidence,
  });

  final String classificationLabel;
  final String remediationHint;

  /// The recorded failing-assertion evidence (`- evidence:`), when the
  /// red entry carried one (issue #959).
  final String? evidence;
}

/// One registered behavior's theater card.
class TheaterBehavior {
  const TheaterBehavior({
    required this.id,
    required this.description,
    required this.criterion,
    required this.testPath,
    required this.subjectPath,
    required this.status,
    required this.receipt,
    this.verdict,
  });

  final String id;
  final String description;
  final String criterion;
  final String testPath;
  final String subjectPath;
  final TheaterProofStatus status;
  final TheaterReceipt receipt;
  final TheaterVerdict? verdict;
}

/// One recorded generation step (green entries).
class TheaterGenerationStep {
  const TheaterGenerationStep({
    required this.command,
    this.exitCode,
    this.purpose,
  });

  final String command;
  final int? exitCode;
  final String? purpose;
}

/// One recorded refactor action (refactor entries).
class TheaterRefactorAction {
  const TheaterRefactorAction({
    required this.name,
    this.command,
    this.exitCode,
    this.changed,
  });

  final String name;
  final String? command;
  final int? exitCode;
  final String? changed;
}

/// One cycle-log timeline entry (file order).
class TheaterCycle {
  const TheaterCycle({
    required this.behaviorId,
    required this.kind,
    this.classification,
    this.redEvidence,
    this.criterion,
    this.test,
    this.command,
    this.exitCode,
    this.at,
    required this.output,
    this.schema,
    this.prevHash,
    this.hash,
    this.generationSteps = const [],
    this.refactorActions = const [],
    this.isNoOp = false,
  });

  final String behaviorId;
  final String kind;
  final String? classification;
  final String? redEvidence;
  final String? criterion;
  final String? test;
  final String? command;
  final int? exitCode;
  final String? at;

  /// The captured runner output (the fenced block) — the diff the TUI
  /// shows when a cycle is selected.
  final String output;
  final String? schema;
  final String? prevHash;
  final String? hash;
  final List<TheaterGenerationStep> generationSteps;
  final List<TheaterRefactorAction> refactorActions;
  final bool isNoOp;
}

/// The whole read-only snapshot the TUI renders.
class TheaterSnapshot {
  const TheaterSnapshot({
    required this.feature,
    required this.projectRoot,
    required this.behaviors,
    required this.cycles,
    required this.receiptCount,
    required this.cycleLogPresent,
  });

  final String feature;
  final String projectRoot;
  final List<TheaterBehavior> behaviors;
  final List<TheaterCycle> cycles;

  /// Distinct #807 receipt documents attributed to this feature.
  final int receiptCount;
  final bool cycleLogPresent;

  int get greenCount =>
      behaviors.where((b) => b.status == TheaterProofStatus.green).length;
  int get redCount =>
      behaviors.where((b) => b.status == TheaterProofStatus.red).length;
}

/// The loader. Every method is read-only.
class TheaterData {
  const TheaterData._();

  /// Map the cycle-log's camelCase `FailureClass` names onto the
  /// `RedClassification` vocabulary (kebab-case labels + remediation
  /// hints). Hand-written logs may carry labels outside this map — they
  /// render with the raw label and no invented remediation.
  static const Map<String, RedClassification> classificationVocabulary = {
    'assertionFailure': RedClassification.assertion,
    'compileError': RedClassification.compileError,
    'loadError': RedClassification.loadError,
    'skipped': RedClassification.skipped,
    'unexpectedGreen': RedClassification.unexpectedGreen,
    'runnerError': RedClassification.runnerError,
    'channelTimeout': RedClassification.channelTimeout,
    'kindMismatch': RedClassification.kindMismatch,
    // Kebab-case spellings already in the vocabulary (defensive).
    'assertion': RedClassification.assertion,
    'compile-error': RedClassification.compileError,
    'load-error': RedClassification.loadError,
    'unexpected-green': RedClassification.unexpectedGreen,
    'runner-error': RedClassification.runnerError,
    'channel-timeout': RedClassification.channelTimeout,
    'kind-mismatch': RedClassification.kindMismatch,
  };

  /// Load the feature's journal. Throws [TheaterException] for an
  /// unknown feature directory or a missing artifact registry; a missing
  /// cycle-log yields zero cycles (honest pending state).
  static Future<TheaterSnapshot> load({
    required String feature,
    required String projectRoot,
  }) async {
    final featureDir = p.join(projectRoot, 'specs', feature);
    if (!Directory(featureDir).existsSync()) {
      throw TheaterException(
        'no feature directory at specs/$feature — the theater replays a '
        'feature that exists. List features with `ls specs/` or run '
        '`zfa tdd init $feature` first.',
      );
    }
    final registry = ArtifactRegistry(featureDir: featureDir);
    final registryFile = File(registry.registryPath);
    if (!await registryFile.exists()) {
      throw TheaterException(
        'no artifact registry at specs/$feature/tdd/artifacts.json — run '
        '`zfa tdd gen <behavior-id> --feature $feature` first. The theater '
        'renders registered behaviors; it never invents them.',
      );
    }
    final records = await registry.loadAll();
    if (records.isEmpty) {
      throw TheaterException(
        'the artifact registry at specs/$feature/tdd/artifacts.json carries '
        'no behavior records — run `zfa tdd gen <behavior-id> --feature '
        '$feature` first. The theater renders registered behaviors; it '
        'never invents them.',
      );
    }

    // The test-list descriptions (lenient: absence degrades to the
    // registry's own description segment).
    final descriptions = await _readDescriptions(featureDir, records);

    // The cycle-log timeline (a missing log yields zero cycles).
    final cycleLogFile = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
    final cycles = await cycleLogFile.exists()
        ? TheaterLogParser.parse(await cycleLogFile.readAsString())
        : const <TheaterCycle>[];

    // Receipts: per-feature layout + flat attributed store.
    final receipts = await _loadReceipts(
      projectRoot: projectRoot,
      feature: feature,
      records: records,
    );

    final behaviors = <TheaterBehavior>[];
    for (final record in records) {
      behaviors.add(
        _deriveBehavior(
          record,
          descriptions[record.behaviorId],
          cycles,
          receipts,
        ),
      );
    }

    return TheaterSnapshot(
      feature: feature,
      projectRoot: projectRoot,
      behaviors: behaviors,
      cycles: cycles,
      receiptCount: receipts.documents.length,
      cycleLogPresent: await cycleLogFile.exists(),
    );
  }

  /// Registry descriptions enriched by the test-list prose, keyed by
  /// behavior id. A missing or unreadable test-list contributes nothing.
  static Future<Map<String, String>> _readDescriptions(
    String featureDir,
    List<ArtifactRecord> records,
  ) async {
    final byId = <String, String>{};
    for (final record in records) {
      byId[record.behaviorId] = record.descriptionSegment;
    }
    try {
      final rows = await TestListReader(featureDir).read();
      for (final row in rows) {
        if (row.description.trim().isNotEmpty) {
          byId[row.id] = row.description;
        }
      }
    } on TestListReadException {
      // No test-list (or unreadable): the registry's own description
      // segment stands. Never an error for a read-only projector.
    }
    return byId;
  }

  // -----------------------------------------------------------------
  // Receipts: per-feature dir + flat store, attributed, latest-wins.
  // -----------------------------------------------------------------

  static Future<_ReceiptIndex> _loadReceipts({
    required String projectRoot,
    required String feature,
    required List<ArtifactRecord> records,
  }) async {
    final featurePaths = <String>{};
    for (final record in records) {
      featurePaths.add(_normalizeRel(record.subjectPath));
      featurePaths.add(_normalizeRel(record.testPath));
    }

    final documents = <String, _ReceiptDocument>{};
    // 1. The per-feature layout the issue names.
    final perFeatureDir = Directory(
      p.join(projectRoot, '.zfa', 'receipts', feature),
    );
    if (perFeatureDir.existsSync()) {
      for (final file in perFeatureDir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.json')) continue;
        final doc = _readReceiptDocument(file);
        if (doc != null) documents[doc.fileName] = doc;
      }
    }
    // 2. The flat store ReceiptStore writes today, attributed by the
    // feature's registered paths (the FeatureProvenanceReader rule).
    final flatDir = Directory(p.join(projectRoot, '.zfa', 'receipts'));
    if (flatDir.existsSync()) {
      for (final entity in flatDir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final doc = _readReceiptDocument(entity);
        if (doc == null) continue;
        final attributed = doc.receipt.files.any(
          (f) => featurePaths.contains(_normalizeRel(f.path)),
        );
        if (attributed) documents[doc.fileName] = doc;
      }
    }

    // Latest-wins per covered path: documents are ordered oldest-first
    // (at, then file name), so the LAST hit wins.
    final ordered = documents.values.toList()
      ..sort((a, b) {
        final byTime = a.receipt.at.compareTo(b.receipt.at);
        return byTime != 0 ? byTime : a.fileName.compareTo(b.fileName);
      });
    final latestByPath =
        <String, ({_ReceiptDocument doc, GenerationReceiptFile entry})>{};
    for (final doc in ordered) {
      for (final entry in doc.receipt.files) {
        latestByPath[_normalizeRel(entry.path)] = (doc: doc, entry: entry);
      }
    }
    return _ReceiptIndex(documents: documents, latestByPath: latestByPath);
  }

  static _ReceiptDocument? _readReceiptDocument(File file) {
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return _ReceiptDocument(
        fileName: p.basename(file.path),
        receipt: GenerationReceipt.fromJson(json),
      );
    } catch (_) {
      // Corrupted receipt documents are skipped, never fatal — the same
      // contract ReceiptStore.loadAll applies.
      return null;
    }
  }

  // -----------------------------------------------------------------
  // Per-behavior derivation (status, receipt card, verdict).
  // -----------------------------------------------------------------

  static TheaterBehavior _deriveBehavior(
    ArtifactRecord record,
    String? description,
    List<TheaterCycle> cycles,
    _ReceiptIndex receipts,
  ) {
    final id = record.behaviorId;
    final own = cycles.where((c) => c.behaviorId == id).toList();
    final hasGreen = own.any((c) => c.kind == 'green');
    final hasRed = own.any((c) => c.kind == 'red');
    final status = hasGreen
        ? TheaterProofStatus.green
        : hasRed
        ? TheaterProofStatus.red
        : TheaterProofStatus.pending;

    // Verdict: the LATEST red entry's classification, mapped onto the
    // RedClassification vocabulary.
    TheaterVerdict? verdict;
    final reds = own.where((c) => c.kind == 'red').toList();
    if (reds.isNotEmpty) {
      final latestRed = reds.last;
      final label = latestRed.classification;
      if (label != null && label.trim().isNotEmpty) {
        final mapped = classificationVocabulary[label.trim()];
        verdict = TheaterVerdict(
          classificationLabel: mapped?.label ?? label.trim(),
          remediationHint: mapped?.remediationHint ?? '',
          evidence: latestRed.redEvidence,
        );
      }
    }

    return TheaterBehavior(
      id: id,
      description: description ?? record.descriptionSegment,
      criterion: record.sourceCriterion,
      testPath: record.testPath,
      subjectPath: record.subjectPath,
      status: status,
      receipt: _deriveReceipt(record, own, receipts),
      verdict: verdict,
    );
  }

  static TheaterReceipt _deriveReceipt(
    ArtifactRecord record,
    List<TheaterCycle> own,
    _ReceiptIndex receipts,
  ) {
    final id = record.behaviorId;
    final greens = own.where((c) => c.kind == 'green').toList();
    final reds = own.where((c) => c.kind == 'red').toList();

    final String action;
    final String evidence;
    if (greens.isNotEmpty) {
      final green = greens.last;
      action = 'satisfied';
      evidence =
          'test ${green.test ?? '-'} exit ${green.exitCode ?? '?'} '
          'at ${green.at ?? '-'}';
    } else if (reds.isNotEmpty) {
      final red = reds.last;
      action = 'red';
      evidence =
          'red ${red.classification ?? '-'} exit ${red.exitCode ?? '?'} '
          'at ${red.at ?? '-'}';
    } else {
      action = 'pending';
      evidence = 'no recorded evidence (neither red nor green)';
    }

    // The #807 backing: the latest receipt entry covering the subject
    // (preferred) or the paired test.
    final subjectRel = _normalizeRel(record.subjectPath);
    final testRel = _normalizeRel(record.testPath);
    final backing =
        receipts.latestByPath[subjectRel] ?? receipts.latestByPath[testRel];

    return TheaterReceipt(
      behaviorId: id,
      action: action,
      evidence: evidence,
      file: record.subjectPath,
      receiptAction: backing?.entry.action,
      bytes: backing?.entry.bytes,
      sha256: backing?.entry.sha256,
      at: backing?.doc.receipt.at.toUtc().toIso8601String(),
      command: backing?.doc.receipt.command,
      repro: backing?.doc.receipt.repro,
      receiptFile: backing?.doc.fileName,
    );
  }

  static String _normalizeRel(String rel) =>
      p.posix.normalize(p.posix.joinAll(p.split(rel))).replaceAll('\\', '/');
}

/// A parsed receipt document, with the file name it came from.
class _ReceiptDocument {
  const _ReceiptDocument({required this.fileName, required this.receipt});
  final String fileName;
  final GenerationReceipt receipt;
}

/// The attributed receipt index: attributed documents + the latest
/// (doc, entry) per covered project-relative path.
class _ReceiptIndex {
  const _ReceiptIndex({
    required Map<String, _ReceiptDocument> documents,
    required this.latestByPath,
  }) : _documents = documents;

  final Map<String, _ReceiptDocument> _documents;
  final Map<String, ({_ReceiptDocument doc, GenerationReceiptFile entry})>
  latestByPath;

  Map<String, _ReceiptDocument> get documents => Map.unmodifiable(_documents);
}

/// The cycle-log parser — a superset of `CycleEvidence.parseEntries`
/// capturing the full journal row: classification, failing-assertion
/// evidence, the fenced output block, green generation steps, refactor
/// actions and the hash-chain lines. Sections without a `- behavior:`
/// line are skipped (the file header, hand-written prose).
class TheaterLogParser {
  const TheaterLogParser._();

  static List<TheaterCycle> parse(String raw) {
    final cycles = <TheaterCycle>[];
    for (final section in raw.split('\n## ')) {
      final behavior = RegExp(
        r'^- behavior: (\S+)',
        multiLine: true,
      ).firstMatch(section);
      if (behavior == null) continue;
      String? capture(RegExp re) => re.firstMatch(section)?.group(1);

      final output = _parseOutput(section);
      final cycles_ = TheaterCycle(
        behaviorId: behavior.group(1)!,
        kind: capture(RegExp(r'^- kind: (\S+)', multiLine: true)) ?? '',
        classification: capture(
          RegExp(r'^- classification: (.+)$', multiLine: true),
        ),
        redEvidence: capture(RegExp(r'^- evidence: (.+)$', multiLine: true)),
        criterion: capture(RegExp(r'^- criterion: (.+)$', multiLine: true)),
        test: capture(RegExp(r'^- test: (.+)$', multiLine: true)),
        command: capture(RegExp(r'^- command: `(.*)`$', multiLine: true)),
        exitCode: _parseInt(
          capture(RegExp(r'^- exit: (-?\d+)$', multiLine: true)),
        ),
        at: capture(RegExp(r'^- at: (.+)$', multiLine: true)),
        output: output,
        schema: capture(RegExp(r'^- schema: (\d+)$', multiLine: true)),
        prevHash: capture(RegExp(r'^- prev-hash: (\S+)$', multiLine: true)),
        hash: capture(RegExp(r'^- hash: ([0-9a-f]{64})$', multiLine: true)),
        generationSteps: _parseGenerationSteps(section),
        refactorActions: _parseRefactorActions(section),
        isNoOp: RegExp(r'^- no-op: true$', multiLine: true).hasMatch(section),
      );
      cycles.add(cycles_);
    }
    return cycles;
  }

  /// The fenced output block: the content between the ``` fences that
  /// follow the `- output:` line. Empty when the entry carried none.
  ///
  /// Parsed line-by-line (never a single greedy expression): a
  /// `((?:.+\n?)*)`-style group over a fenced block backtracks
  /// catastrophically on real journal sections (~50s per green entry),
  /// while the linear scan is O(lines).
  static String _parseOutput(String section) {
    final lines = section.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('- output:')) {
        // The opening fence (which may carry an info string).
        if (i + 1 >= lines.length || !lines[i + 1].startsWith('```')) {
          return '';
        }
        final body = StringBuffer();
        for (var j = i + 2; j < lines.length; j++) {
          if (lines[j].startsWith('```')) {
            return body.toString().trimRight();
          }
          body.writeln(lines[j]);
        }
        return body.toString().trimRight();
      }
    }
    return '';
  }

  static List<TheaterGenerationStep> _parseGenerationSteps(String section) {
    final steps = <TheaterGenerationStep>[];
    final stepRe = RegExp(
      r'^  - step: (.+)$\n    exit: (-?\d+)$'
      r'(?:\n    purpose: (.+)$)?',
      multiLine: true,
    );
    for (final match in stepRe.allMatches(section)) {
      steps.add(
        TheaterGenerationStep(
          command: match.group(1)!.trim(),
          exitCode: int.tryParse(match.group(2) ?? ''),
          purpose: match.group(3)?.trim(),
        ),
      );
    }
    return steps;
  }

  static List<TheaterRefactorAction> _parseRefactorActions(String section) {
    final actions = <TheaterRefactorAction>[];
    final actionRe = RegExp(
      r'^- action: (.+)$\n  command: `(.*)`$\n  exit: (-?\d+)$'
      r'(?:\n  changed: (.*)$)?',
      multiLine: true,
    );
    for (final match in actionRe.allMatches(section)) {
      actions.add(
        TheaterRefactorAction(
          name: match.group(1)!.trim(),
          command: match.group(2),
          exitCode: int.tryParse(match.group(3) ?? ''),
          changed: match.group(4)?.trim(),
        ),
      );
    }
    return actions;
  }

  static int? _parseInt(String? raw) => raw == null ? null : int.tryParse(raw);
}
