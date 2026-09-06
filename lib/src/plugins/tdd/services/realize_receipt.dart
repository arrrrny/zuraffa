/// `RealizeReceipt` — the hand-delta receipt for the MOCKED→REAL swap
/// (spec 1193, issue #1193 step 6: "writing a hand-delta receipt
/// (generated / mock / hand ratios)").
///
/// One receipt per realized swap, at
/// `specs/<feature>/tdd/realize-receipt.json` (schema
/// `realize-receipt.v1`). It records:
///
///   - the ladder advance (`ladder.from` → `ladder.to`, with the
///     behavior state the unified journal advanced to DONE),
///   - the gate outcomes (contract verdict, differential verdict,
///     threshold, row/compared counts, hand-delta count),
///   - EVERY file the swap touched with its post-swap sha256 digest and
///     its provenance bucket (`generated` = rebind-written binding
///     files, covered by the #807 rebind receipt; `mock` = the certified
///     mock implementation files, unbound but never rewritten;
///     `hand` = scaffolded adapters and gated hand-deltas),
///   - the generated/mock/hand ratios over those files (`cell` renders
///     the referee's `G%/M%/H%` convention, spec 070).
///
/// The journal entry (#1113) references this receipt, so the unified
/// journal's realize record carries the swap's full evidence without
/// duplicating it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The provenance bucket a receipted file falls into (spec 070's
/// vocabulary: generated / mock / hand).
enum RealizeFileBucket { generated, mock, hand }

String realizeFileBucketLabel(RealizeFileBucket bucket) => switch (bucket) {
  RealizeFileBucket.generated => 'generated',
  RealizeFileBucket.mock => 'mock',
  RealizeFileBucket.hand => 'hand',
};

/// One receipted file: the path, what happened to it, its provenance
/// bucket, and its post-write digest.
class RealizeReceiptFile {
  const RealizeReceiptFile({
    required this.path,
    required this.action,
    required this.bucket,
    required this.sha256,
    required this.bytes,
  });

  /// Project-relative POSIX path.
  final String path;

  /// `update` (a rebound binding file), `scaffold` (a created adapter
  /// stub), `hand-delta` (a gated hand-written delta), `mock` (the
  /// certified mock's own file, receipted unbound).
  final String action;

  final RealizeFileBucket bucket;

  /// sha256 of the file's bytes at receipt time.
  final String sha256;
  final int bytes;

  Map<String, dynamic> toJson() => {
    'path': path,
    'action': action,
    'bucket': realizeFileBucketLabel(bucket),
    'sha256': sha256,
    'bytes': bytes,
  };
}

/// The generated/mock/hand ratio triple over the swap's files.
class RealizeRatios {
  const RealizeRatios({
    required this.generated,
    required this.mock,
    required this.hand,
  });

  final int generated;
  final int mock;
  final int hand;

  int get total => generated + mock + hand;

  /// The spec-070 ratio cell (`G%/M%/H%`), `n/a` over an empty swap.
  String get cell {
    if (total == 0) return 'n/a';
    final g = (generated * 100 / total).round();
    final m = (mock * 100 / total).round();
    final h = (hand * 100 / total).round();
    return '$g%/$m%/$h%';
  }

  Map<String, dynamic> toJson() => {
    'generated': generated,
    'mock': mock,
    'hand': hand,
    'total': total,
    'cell': cell,
  };
}

/// The assembled realize receipt (not yet persisted).
class RealizeReceipt {
  const RealizeReceipt({
    required this.feature,
    required this.entity,
    required this.adapter,
    required this.ladderFrom,
    required this.ladderTo,
    required this.behaviorState,
    required this.contract,
    required this.differential,
    required this.threshold,
    required this.rows,
    required this.compared,
    required this.handDeltas,
    required this.files,
    required this.ratios,
    required this.mocksTotal,
    required this.mocksCertified,
    required this.scaffolded,
    required this.at,
  });

  final String feature;
  final String entity;
  final String adapter;

  /// The ladder advance: `MOCKED` → `REAL` (era), with the behavior
  /// state the unified journal advanced (`done` when behaviors were
  /// advanced, `null` when the feature carried none).
  final String ladderFrom;
  final String ladderTo;
  final String? behaviorState;

  /// Gate outcomes (the acceptance's "receipt records the swap (files,
  /// digests, gate outcome)").
  final String contract;
  final String differential;
  final String threshold;
  final int rows;
  final int compared;
  final int handDeltas;

  final List<RealizeReceiptFile> files;
  final RealizeRatios ratios;

  /// The certified-mock accounting ({total, certified} — the #1110 cert
  /// registry's answer for the realized entity).
  final int mocksTotal;
  final int mocksCertified;

  /// The scaffolded adapter file (project-relative POSIX), or null when
  /// the adapter already existed.
  final String? scaffolded;

  final DateTime at;

  Map<String, dynamic> toJson() => {
    'schema': 'realize-receipt.v1',
    'feature': feature,
    'entity': entity,
    'adapter': adapter,
    'ladder': {
      'from': ladderFrom,
      'to': ladderTo,
      if (behaviorState != null) 'behavior_state': behaviorState,
    },
    'gates': {
      'contract': contract,
      'differential': differential,
      'threshold': threshold,
      'rows': rows,
      'compared': compared,
      'handDeltas': handDeltas,
    },
    'files': [for (final f in files) f.toJson()],
    'ratios': ratios.toJson(),
    'mocks': {'total': mocksTotal, 'certified': mocksCertified},
    if (scaffolded != null) 'scaffolded': scaffolded,
    'at': at.toUtc().toIso8601String(),
  };
}

/// Atomic persistence for `specs/<feature>/tdd/realize-receipt.json`.
class RealizeReceiptStore {
  const RealizeReceiptStore(this.featureDir);

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  static const String fileName = 'realize-receipt.json';

  String get path => p.join(featureDir, 'tdd', fileName);

  /// Persist [receipt] atomically (temp file + rename, the realize-state
  /// crash contract).
  Future<void> save(RealizeReceipt receipt) async {
    final dir = Directory(p.dirname(path));
    await dir.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(receipt.toJson())}\n',
    );
    await tmp.rename(path);
  }
}
