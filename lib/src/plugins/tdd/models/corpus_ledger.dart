/// `GapLedgerEntry` + totals — the append-only gap ledger model (spec
/// 051-corpus-harness, FR-007/FR-008, data-model.md). Gap entries record
/// every STOP-ON-ROADBLOCK with the six required fields; resolution
/// entries record a previously-gapped feature later passing (a NEW entry,
/// never an edit — US4.AC2). Only `issueLink` and `status` are
/// maintainer-edited after the fact.
library;

enum GapLedgerKind { gap, resolution }

class GapLedgerEntry {
  const GapLedgerEntry({
    required this.id,
    required this.kind,
    required this.at,
    required this.feature,
    this.behavior,
    this.step,
    this.outcome,
    this.failingCommand,
    this.issueLink,
    this.status = 'open',
    this.resolves,
  });

  /// `gap-###` for gaps, `res-###` for resolutions (monotonic per series).
  final String id;
  final GapLedgerKind kind;

  /// ISO-8601 UTC timestamp of the append.
  final String at;

  /// The manifest feature the stop belongs to.
  final String feature;

  /// The behavior id the stop hit (run's `stopped_at`), null for
  /// gate/manifest-level stops.
  final String? behavior;

  /// The failing corpus step: `run` | `verify`.
  final String? step;

  /// The run outcome token (`stopped`, `runner-error`, …) or the verify
  /// gate label (`fail_survived`, `not_assessed`, …). `resolved` for
  /// resolution entries.
  final String? outcome;

  /// The spawned argv that failed (joined).
  final String? failingCommand;

  /// Issue link placeholder — null until the maintainer files the issue.
  final String? issueLink;

  /// `open` when appended; `filed`/`merged`/`resolved` are maintainer
  /// edits (the only fields a human edits).
  final String? status;

  /// Resolution entries only: the gap entry id this closes.
  final String? resolves;

  const GapLedgerEntry.gap({
    required this.id,
    required this.at,
    required this.feature,
    this.behavior,
    this.step,
    this.outcome,
    this.failingCommand,
    this.issueLink,
    this.status = 'open',
  }) : kind = GapLedgerKind.gap,
       resolves = null;

  const GapLedgerEntry.resolution({
    required this.id,
    required this.at,
    required this.feature,
    required this.resolves,
  }) : kind = GapLedgerKind.resolution,
       behavior = null,
       step = null,
       outcome = 'resolved',
       failingCommand = null,
       issueLink = null,
       status = 'resolved';

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'at': at,
    'feature': feature,
    if (behavior != null) 'behavior': behavior,
    if (step != null) 'step': step,
    if (outcome != null) 'outcome': outcome,
    if (failingCommand != null) 'failing_command': failingCommand,
    if (issueLink != null) 'issue_link': issueLink,
    if (status != null) 'status': status,
    if (resolves != null) 'resolves': resolves,
  };

  static GapLedgerEntry fromJson(dynamic decoded) {
    if (decoded is! Map) {
      throw FormatException('gap ledger entry is not an object');
    }
    final map = decoded;
    final id = map['id'];
    final kindRaw = map['kind'];
    final at = map['at'];
    final feature = map['feature'];
    if (id is! String ||
        kindRaw is! String ||
        at is! String ||
        feature is! String) {
      throw FormatException('gap ledger entry is missing id/kind/at/feature');
    }
    final kind = GapLedgerKind.values
        .where((k) => k.name == kindRaw)
        .firstOrNull;
    if (kind == null) {
      throw FormatException('gap ledger entry kind "$kindRaw" is unknown');
    }
    return GapLedgerEntry(
      id: id,
      kind: kind,
      at: at,
      feature: feature,
      behavior: map['behavior'] as String?,
      step: map['step'] as String?,
      outcome: map['outcome'] as String?,
      failingCommand: map['failing_command'] as String?,
      issueLink: map['issue_link'] as String?,
      status: map['status'] as String?,
      resolves: map['resolves'] as String?,
    );
  }
}

/// FR-008 ledger totals: found / filed / merged / blocking.
class GapLedgerTotals {
  const GapLedgerTotals({
    required this.found,
    required this.filed,
    required this.merged,
    required this.blocking,
  });

  /// Gap entries recorded (resolutions excluded).
  final int found;

  /// Gaps whose issue link is set (filed).
  final int filed;

  /// Gaps whose status is `merged` (the fix landed in zuraffa).
  final int merged;

  /// Unresolved gaps whose feature is not done/waived — the ones blocking
  /// corpus completion (named in the final report).
  final List<GapLedgerEntry> blocking;

  /// Compute totals from [entries]; [doneFeatures] are the features whose
  /// corpus state is done or waived. A gap is resolved when its status is
  /// `resolved`/`merged` or a resolution entry names it in `resolves`.
  static GapLedgerTotals fromEntries(
    List<GapLedgerEntry> entries, {
    required Set<String> doneFeatures,
  }) {
    final gaps = entries.where((e) => e.kind == GapLedgerKind.gap).toList();
    final resolvedIds = entries
        .where((e) => e.kind == GapLedgerKind.resolution)
        .map((e) => e.resolves)
        .whereType<String>()
        .toSet();

    bool isResolved(GapLedgerEntry gap) =>
        gap.status == 'resolved' ||
        gap.status == 'merged' ||
        resolvedIds.contains(gap.id);

    final blocking = gaps
        .where((gap) => !isResolved(gap) && !doneFeatures.contains(gap.feature))
        .toList();

    return GapLedgerTotals(
      found: gaps.length,
      filed: gaps.where((g) => g.issueLink != null).length,
      merged: gaps.where((g) => g.status == 'merged').length,
      blocking: blocking,
    );
  }
}
