/// The `04-skin-receipt.json` writer (issue #1005) — schema `skin.v1`.
///
/// The receipt is the proof-carrying record of one `zfa tdd run-skin`
/// cycle: per-behavior `conformance`, the `platform_slot_fills` observed
/// in the green run's SkinEvent stream, every `_XRaySkinHandEdit`
/// annotation the cycle scanned (cross-checked, never author-claimed),
/// the sha256 digest of the full SkinEvent trace, and whether the red
/// witness ran. Written after every run — green or stopped — so a
/// stopped run records its honest partial state, exactly like the
/// engine receipts.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Per-behavior skin receipt row.
class SkinReceipt {
  const SkinReceipt({
    required this.behavior,
    required this.conformance,
    required this.testPath,
    required this.subjectPath,
    required this.platformSlotFills,
  });

  /// The behavior id (e.g. `W1`).
  final String behavior;

  /// Whether the cycle accepted the hand-written implementation: the
  /// declared platform slots all filled, the paired test exists and
  /// executed, red witnessed before green, and a cross-checked
  /// `_XRaySkinHandEdit` annotation present.
  final bool conformance;

  /// Project-relative POSIX path of the paired test.
  final String testPath;

  /// Project-relative POSIX path of the hand-written implementation.
  final String subjectPath;

  /// The platform slots observed in this behavior's green-run SkinEvent
  /// stream, in observation order.
  final List<String> platformSlotFills;

  Map<String, dynamic> toJson() => {
    'behavior': behavior,
    'conformance': conformance,
    'test': testPath,
    'subject': subjectPath,
    'platform_slot_fills': platformSlotFills,
  };

  factory SkinReceipt.fromJson(Map<String, dynamic> json) => SkinReceipt(
    behavior: json['behavior'] as String,
    conformance: json['conformance'] as bool? ?? false,
    testPath: json['test'] as String? ?? '',
    subjectPath: json['subject'] as String? ?? '',
    platformSlotFills: [
      for (final slot in (json['platform_slot_fills'] as List? ?? const []))
        slot as String,
    ],
  );
}

/// One scanned hand-edit record: the annotation triple the receipt
/// captures verbatim.
class SkinHandEditRecord {
  const SkinHandEditRecord({
    required this.behavior,
    required this.file,
    required this.loggedAt,
  });

  final String behavior;
  final String file;
  final String loggedAt;

  Map<String, dynamic> toJson() => {
    'behavior': behavior,
    'file': file,
    'logged_at': loggedAt,
  };

  factory SkinHandEditRecord.fromJson(Map<String, dynamic> json) =>
      SkinHandEditRecord(
        behavior: json['behavior'] as String,
        file: json['file'] as String,
        loggedAt: json['logged_at'] as String,
      );
}

/// The whole receipt document.
class SkinReceiptDocument {
  const SkinReceiptDocument({
    required this.feature,
    required this.command,
    required this.behaviors,
    required this.handEdits,
    required this.skinEventTraceDigest,
    required this.redWitness,
    required this.generatedAt,
  });

  /// The feature directory name (e.g. `004-login-ui`).
  final String feature;

  /// The repro command line.
  final String command;

  /// Per-behavior rows, in test-list order.
  final List<SkinReceipt> behaviors;

  /// Every scanned `_XRaySkinHandEdit` annotation (behavior, file,
  /// logged_at) — cross-checked by the cycle, recorded verbatim.
  final List<SkinHandEditRecord> handEdits;

  /// sha256 over the canonical SkinEvent trace (red + green runs).
  final String skinEventTraceDigest;

  /// Whether the stub-revert red witness ran for every behavior.
  final bool redWitness;

  /// ISO-8601 UTC generation timestamp.
  final String generatedAt;

  /// The union of every behavior's slot fills, order-preserving,
  /// de-duplicated — the receipt's top-level `platform_slot_fills`.
  List<String> get platformSlotFills {
    final slots = <String>[];
    for (final b in behaviors) {
      for (final slot in b.platformSlotFills) {
        if (!slots.contains(slot)) slots.add(slot);
      }
    }
    return slots;
  }

  Map<String, dynamic> toJson() => {
    'schema': 'skin.v1',
    'feature': feature,
    'command': command,
    'behaviors': [for (final b in behaviors) b.toJson()],
    'platform_slot_fills': platformSlotFills,
    'hand_edits': [for (final e in handEdits) e.toJson()],
    'skin_event_trace_digest': skinEventTraceDigest,
    'red_witness': redWitness,
    'generated_at': generatedAt,
  };
}

/// Writes the receipt to `specs/<feature>/tdd/04-skin-receipt.json`
/// (beside the `04-SKIN.md` lane plan — the same 04- prefix family).
class SkinReceiptWriter {
  const SkinReceiptWriter({required this.featureDir});

  /// Absolute path of the feature's spec directory.
  final String featureDir;

  /// Absolute path of the receipt file.
  String get receiptPath => p.join(featureDir, 'tdd', '04-skin-receipt.json');

  /// Write [document]; returns [SkinReceiptWriter.receiptPath].
  Future<String> write(SkinReceiptDocument document) async {
    final file = File(receiptPath);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(document.toJson())}\n');
    return receiptPath;
  }
}
