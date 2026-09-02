/// `CycleLog` — append-only writer for `tdd/cycle-log.md`.
///
/// Bug #828 (evidence integrity): every appended entry carries the
/// versioned evidence schema (`- schema: 1`) and the per-behavior
/// tamper-evident hash chain (`- prev-hash:` / `- hash:`). The chain is
/// lightweight: sha256 over the entry's certified facts plus the previous
/// link, red-hash -> green-hash -> refactor-hash per behavior. Legacy
/// entries (no hash lines) stay valid and parseable — the rendering of
/// the certified facts is byte-compatible (U10 invariant), the chain
/// lines are appended after them. The append is flushed to disk (fsync)
/// before the writer returns, so a step that certified green has durable
/// evidence.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/cycle_entry.dart';
import 'cycle_evidence.dart';

class CycleLog {
  const CycleLog(this.featureDir);

  final String featureDir;

  /// The schema version stamped on entries this writer appends.
  static const int evidenceSchemaVersion = 1;

  /// The first link of a per-behavior chain (nothing hashed yet).
  static const String genesisHash = 'genesis';

  Future<void> append(CycleLogEntry entry) async {
    final dir = Directory('$featureDir/tdd');
    final file = File('${dir.path}/cycle-log.md');
    await dir.create(recursive: true);

    if (!await file.exists()) {
      await file.writeAsString(
        '# Cycle Log\n\nAppend only. Newest last. Every entry\'s `red` block '
        'is the evidence that the test existed and failed before the '
        'implementation.\n\n',
      );
    }

    // Bug #828: chain onto the behavior's last hashed entry. Legacy
    // (hash-less) entries contribute no link — the first hashed entry
    // chains from genesis.
    final prev = await CycleEvidence(featureDir).lastHashFor(entry.behaviorId);
    final hash = _chainHash(entry, prev ?? genesisHash);
    final sink = file.openWrite(mode: FileMode.append);
    sink.write(entry.toMarkdown());
    sink.write('- schema: $evidenceSchemaVersion\n');
    sink.write('- prev-hash: ${prev ?? genesisHash}\n');
    sink.write('- hash: $hash\n');
    sink.write('\n');
    await sink.flush();
    await sink.close();
  }

  /// The tamper-evident chain link for [entry]: sha256 over a canonical
  /// null-separated payload of the certified facts plus the previous
  /// link. The doctor recomputes this from the parsed entry and reports
  /// any mismatch as drift with a fix line.
  static String chainHashFor(CycleLogEntry entry, {required String prevHash}) {
    return _chainHash(entry, prevHash);
  }

  /// The canonical payload the chain hash covers (shared with the doctor).
  static String chainPayload(CycleLogEntry entry, String prevHash) {
    return payloadFromFields(
      behaviorId: entry.behaviorId,
      kind: entry.kind.name,
      exit: entry.exitCode.toString(),
      command: entry.runnerCommand,
      criterion: entry.sourceCriterion,
      test: entry.testPath,
      timestamp: entry.timestamp,
      prevHash: prevHash,
    );
  }

  /// The canonical payload built from the PARSED field values (the
  /// doctor's view of a rendered entry). The model-side [chainPayload]
  /// delegates here so both sides hash byte-identical payloads.
  static String payloadFromFields({
    required String behaviorId,
    required String kind,
    required String exit,
    required String command,
    required String criterion,
    required String test,
    required String timestamp,
    required String prevHash,
  }) {
    return [
      'v$evidenceSchemaVersion',
      behaviorId,
      kind,
      exit,
      command,
      criterion,
      test,
      timestamp,
      prevHash,
    ].join('\x00');
  }

  static String _chainHash(CycleLogEntry entry, String prevHash) =>
      sha256.convert(utf8.encode(chainPayload(entry, prevHash))).toString();
}
