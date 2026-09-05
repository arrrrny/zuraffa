/// `GapLedgerEntry` + totals — the append-only gap ledger model (spec
/// 051-corpus-harness, FR-007/FR-008, data-model.md). Gap entries record
/// every STOP-ON-ROADBLOCK with the required fields; resolution
/// entries record a previously-gapped feature later passing (a NEW entry,
/// never an edit — US4.AC2). Only `issueLink` and `status` are
/// maintainer-edited after the fact.
library;

enum GapLedgerKind { gap, resolution }

/// The severity of a gap entry (issue #1007): contract-test failures are
/// the HIGHEST-severity gaps — they prove a declared contract is
/// unsatisfied, which blocks the dream substrate itself, so they outrank
/// every other open gap in the totals' ranking and head the blocking
/// list the corpus surfaces.
///
/// Precedence (highest to lowest): `contract` > `standard`. Every gap
/// appended before #1007 (and every non-contract stop after it) carries
/// no severity field at all — legacy entries parse with `null` severity
/// and rank as [standard].
enum GapSeverity {
  /// A contract-test failure: the stopped behavior is a contract
  /// behavior (`contract:<id>`) or the stop's outcome token is `blocked`.
  contract('contract'),

  /// Every other gap (run stops, verify gates, plan gaps).
  standard('standard');

  const GapSeverity(this.label);

  /// The serialized label.
  final String label;

  /// The classification rule for a corpus stop (issue #1007 FR-006): a
  /// contract behavior id (the plan's `contract:<id>` grammar) or a
  /// `blocked` outcome token — the BLOCKED verdict distinct from RED —
  /// makes the gap contract-severity; everything else is standard.
  static GapSeverity forStop({String? behavior, String? outcome}) {
    if (outcome == 'blocked') return GapSeverity.contract;
    if (behavior != null && behavior.startsWith('contract:')) {
      return GapSeverity.contract;
    }
    return GapSeverity.standard;
  }
}

class GapLedgerEntry {
  const GapLedgerEntry({
    required this.id,
    required this.kind,
    required this.at,
    required this.feature,
    this.behavior,
    this.step,
    this.outcome,
    required this.expectedResult,
    this.failingCommand,
    this.issueLink,
    this.status = 'open',
    this.resolves,
    this.severity,
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

  /// The failing inner run step, or `verify` for a verify-gate failure.
  final String? step;

  /// The run outcome token (`stopped`, `runner-error`, …) or the verify
  /// gate label (`fail_survived`, `not_assessed`, …). `resolved` for
  /// resolution entries.
  final String? outcome;

  /// The successful result token expected from the failing corpus command:
  /// `complete` for run, `pass` for verify, `behavior` for a plan-gap
  /// entry (an FR/AC declared by the plan whose behavior is missing —
  /// bug #836).
  final String? expectedResult;

  /// The spawned argv that failed (joined).
  final String? failingCommand;

  /// Issue link placeholder — null until the maintainer files the issue.
  final String? issueLink;

  /// `open` when appended; `filed`/`merged`/`resolved` are maintainer
  /// edits (the only fields a human edits).
  final String? status;

  /// Resolution entries only: the gap entry id this closes.
  final String? resolves;

  /// The gap's severity (issue #1007): `contract` for contract-test
  /// failures (the highest-severity gaps), null on every pre-#1007 and
  /// non-contract entry (legacy entries parse with null severity and
  /// rank as [GapSeverity.standard]). Serialized LAST — after the
  /// existing keys — so previously-appended entries stay byte-identical
  /// across appends (the U13 fixed-field-order contract).
  final GapSeverity? severity;

  const GapLedgerEntry.gap({
    required this.id,
    required this.at,
    required this.feature,
    this.behavior,
    this.step,
    this.outcome,
    required this.expectedResult,
    this.failingCommand,
    this.issueLink,
    this.status = 'open',
    this.severity,
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
       expectedResult = null,
       failingCommand = null,
       issueLink = null,
       status = 'resolved',
       severity = null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'at': at,
    'feature': feature,
    if (behavior != null) 'behavior': behavior,
    if (step != null) 'step': step,
    if (outcome != null) 'outcome': outcome,
    if (expectedResult != null) 'expected_result': expectedResult,
    if (failingCommand != null) 'failing_command': failingCommand,
    if (issueLink != null) 'issue_link': issueLink,
    if (status != null) 'status': status,
    if (resolves != null) 'resolves': resolves,
    // Issue #1007: appended AFTER the existing keys so previously
    // appended entries serialize byte-identically (U13).
    if (severity != null) 'severity': severity!.label,
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
    String? optionalString(String key) {
      final value = map[key];
      if (value != null && value is! String) {
        throw FormatException('gap ledger entry "$key" is not a string');
      }
      return value as String?;
    }

    final expectedResult = optionalString('expected_result');
    if (kind == GapLedgerKind.gap &&
        !const {'complete', 'pass', 'behavior'}.contains(expectedResult)) {
      throw FormatException(
        'gap ledger entry "expected_result" must be "complete", "pass" '
        'or "behavior" (a plan-gap entry — bug #836)',
      );
    }
    // Issue #1007: null-tolerant severity — legacy entries carry none.
    final severityRaw = map['severity'];
    GapSeverity? severity;
    if (severityRaw is String) {
      severity = GapSeverity.values
          .where((s) => s.label == severityRaw)
          .firstOrNull;
    }
    return GapLedgerEntry(
      id: id,
      kind: kind,
      at: at,
      feature: feature,
      behavior: optionalString('behavior'),
      step: optionalString('step'),
      outcome: optionalString('outcome'),
      expectedResult: expectedResult,
      failingCommand: optionalString('failing_command'),
      issueLink: optionalString('issue_link'),
      status: optionalString('status'),
      resolves: optionalString('resolves'),
      severity: severity,
    );
  }
}

/// FR-008 ledger totals: found / filed / merged / blocking + open (bug
/// #846: `open` counts every unresolved gap regardless of feature state
/// — a done feature's open gap still refuses a `complete` corpus
/// verdict; the per-feature coverage numbers live in the plan's
/// traceability artifact).
class GapLedgerTotals {
  const GapLedgerTotals({
    required this.found,
    required this.filed,
    required this.merged,
    required this.blocking,
    required this.open,
    this.contract = 0,
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

  /// Every unresolved gap, regardless of feature state (bug #846: the
  /// corpus refuses a `complete` verdict while ANY of these is open).
  final List<GapLedgerEntry> open;

  /// Open gaps carrying contract severity (issue #1007) — the
  /// highest-severity gaps, ranked first in [open] and [blocking].
  final int contract;

  /// Compute totals from [entries]; [doneFeatures] are the features whose
  /// corpus state is done or waived. A gap is resolved when its status is
  /// `resolved`/`merged` or a resolution entry names it in `resolves`.
  ///
  /// Issue #1007: contract-severity gaps RANK FIRST — they head the open
  /// and blocking lists (a stable sort: severity rank desc, then append
  /// order), so the highest-severity gaps are always the first thing an
  /// operator reads.
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

    int severityRank(GapLedgerEntry gap) =>
        gap.severity == GapSeverity.contract ? 0 : 1;

    final open = gaps.where((gap) => !isResolved(gap)).toList()
      ..sort((a, b) {
        final bySeverity = severityRank(a).compareTo(severityRank(b));
        return bySeverity != 0
            ? bySeverity
            : gaps.indexOf(a).compareTo(gaps.indexOf(b));
      });
    final blocking = open
        .where((gap) => !doneFeatures.contains(gap.feature))
        .toList();

    return GapLedgerTotals(
      found: gaps.length,
      filed: gaps.where((g) => g.issueLink != null).length,
      merged: gaps.where((g) => g.status == 'merged').length,
      blocking: blocking,
      open: open,
      contract: open.where((g) => g.severity == GapSeverity.contract).length,
    );
  }
}
