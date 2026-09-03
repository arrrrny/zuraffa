/// `EraTaggedLog` — era-tagged, hash-chained evidence entries appended to
/// the feature's `tdd/cycle-log.md` (spec 913, phase 5).
///
/// The entries follow the schema-1 chain format the run driver, the
/// doctor, and the #832 fixture registry already parse (`- schema: 1`,
/// `- prev-hash:` / `- hash:`), with the era as a first-class certified
/// fact: the chain hash covers an era-aware payload, so era-tagged
/// evidence is tamper-evident and readable back ([lastEra]).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import 'cycle_evidence.dart';
import 'realize_state.dart';

/// One era-tagged cycle-log entry: the realization evidence a transition
/// leaves behind.
class EraTaggedLogEntry {
  const EraTaggedLogEntry({
    required this.behaviorId,
    required this.kind,
    required this.era,
    required this.criterion,
    required this.test,
    required this.command,
    required this.exitCode,
    required this.output,
  });

  /// The chain behavior id (e.g. `user-realize`).
  final String behaviorId;

  /// Entry kind: `realize` (the transition), `realize-contract`,
  /// `realize-differential` (gate evidence).
  final String kind;

  /// The era this entry certifies (MOCKED before, REAL after a swap).
  final RealizeEra era;

  final String criterion;

  /// Suite scope the evidence covers (or `-`).
  final String test;

  final String command;

  final int exitCode;

  final String output;
}

class EraTaggedLog {
  const EraTaggedLog(this.featureDir);

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// The schema version stamped on entries this writer appends.
  static const int evidenceSchemaVersion = 1;

  /// The first link of a per-behavior chain (nothing hashed yet).
  static const String genesisHash = 'genesis';

  String get _path => p.join(featureDir, 'tdd', 'cycle-log.md');

  /// Append one era-tagged entry in the schema-1 hash-chain format: the
  /// payload covers the era, and the entry chains onto the behavior's
  /// last hashed link.
  Future<void> append(EraTaggedLogEntry entry) async {
    final dir = Directory(p.dirname(_path));
    await dir.create(recursive: true);
    final file = File(_path);
    if (!await file.exists()) {
      await file.writeAsString(
        '# Cycle Log\n\nAppend only. Newest last. Every entry\'s `red` '
        'block is the evidence that the test existed and failed before '
        'the implementation.\n\n',
      );
    }
    final prev =
        await CycleEvidence(featureDir).lastHashFor(entry.behaviorId) ??
        genesisHash;
    final hash = chainHashFor(entry, prev);

    final sink = file.openWrite(mode: FileMode.append);
    sink.write('## Cycle: ${entry.behaviorId} (${entry.kind})\n\n');
    sink.write('- behavior: ${entry.behaviorId}\n');
    sink.write('- kind: ${entry.kind}\n');
    sink.write('- era: ${entry.era.name.toUpperCase()}\n');
    sink.write('- criterion: ${entry.criterion}\n');
    sink.write('- test: ${entry.test}\n');
    sink.write('- command: `${entry.command}`\n');
    sink.write('- exit: ${entry.exitCode}\n');
    sink.write('- at: ${DateTime.now().toUtc().toIso8601String()}\n');
    sink.write('- output:\n```\n${entry.output.trim()}\n```\n');
    sink.write('- schema: $evidenceSchemaVersion\n');
    sink.write('- prev-hash: $prev\n');
    sink.write('- hash: $hash\n\n');
    await sink.flush();
    await sink.close();
  }

  /// The chain hash for [entry] given [prevHash] (shared with the
  /// verification side). The payload is era-aware: the era is a
  /// certified fact inside the hash.
  static String chainHashFor(EraTaggedLogEntry entry, String prevHash) {
    final payload = [
      'v$evidenceSchemaVersion',
      entry.behaviorId,
      entry.kind,
      entry.era.name.toUpperCase(),
      entry.exitCode.toString(),
      entry.command,
      entry.criterion,
      entry.test,
      prevHash,
    ].join('\x00');
    return crypto.sha256.convert(utf8.encode(payload)).toString();
  }

  /// The last era tag recorded in the cycle log, or null when the log
  /// carries no era-tagged entries yet. The era survives across appended
  /// entries — evidence per era, readable back.
  Future<RealizeEra?> lastEra() async {
    final file = File(_path);
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    RealizeEra? last;
    for (final section in raw.split('\n## ')) {
      final behavior = RegExp(
        r'^- behavior: (\S+)',
        multiLine: true,
      ).firstMatch(section);
      if (behavior == null) continue;
      final era = RegExp(
        r'^- era: (MOCKED|REAL)$',
        multiLine: true,
      ).firstMatch(section);
      if (era != null) {
        last = era.group(1) == 'REAL' ? RealizeEra.real : RealizeEra.mocked;
      }
    }
    return last;
  }
}
