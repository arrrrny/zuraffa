/// The shared schema-1 evidence hash-chain walk (bug #828).
///
/// One reader-side verifier for the per-behavior chain `CycleLog.append`
/// builds, so `zfa tdd doctor` (feature-wide drift report) and `zfa tdd
/// replay` ([ReplayHistory.verifyIntegrity]) cannot drift apart on what
/// "the chain broke" means — the two used to carry divergent copies of
/// this rule (review #1612, finding 3: replay hashed `exit ?? ''` and the
/// recorded `prev-hash`, the doctor `exit ?? 0` and the expected link).
///
/// The walk verdicts per entry, in file order per behavior:
///
/// - A section that claims the chain (`- prev-hash:` and/or `- schema: 1`)
///   but carries no well-formed `- hash:` line is ALWAYS a drift
///   ([EvidenceChainDriftKind.missingHash]): deleting or mangling that one
///   line is otherwise the one tamper the walk cannot see, because the
///   entry never joins the chain and (at the tail) no successor exposes
///   the severed link (review #1612, finding 2).
/// - A hashed entry whose `- prev-hash:` does not link the behavior's
///   previous recorded hash is a drift ([EvidenceChainDriftKind.linkage]).
/// - A hashed, linked entry whose recorded hash does not recompute from
///   the canonical payload ([CycleLog.payloadFromFields]) is a drift
///   ([EvidenceChainDriftKind.content]) — but only when the kind belongs
///   to the `CycleLog` writer (`red` / `green` / `refactor` / `error` /
///   `refresh`). Certifier writers (`fixtures`, `mock-cert`, `world-cert`,
///   `world-run`, `world-replay`, `realize*`) stamp their own payloads
///   into `- hash:` in legacy logs, so the canonical recompute cannot
///   rebuild them: those mismatch entries are unverifiable, never failed
///   (review #1612, finding 1 — the walk used to report every committed
///   simulation certification as tampering). Writers that chain through
///   [CycleLog.chainHashFromFields] verify cleanly here; legacy sections
///   stay tolerated.
/// - Hash-less sections with no chain claim (schema-0 legacy) contribute
///   no link and are never failed; their kinds are reported through
///   [EvidenceChainWalk.unverifiedKinds].
library;

import '../models/cycle_entry.dart';
import 'cycle_evidence.dart';
import 'cycle_log.dart';

/// Which arm of the walk a [EvidenceChainDrift] came from.
enum EvidenceChainDriftKind {
  /// A chain-claiming section with no well-formed `- hash:` line.
  missingHash,

  /// `- prev-hash:` does not link the previous recorded hash.
  linkage,

  /// The recorded hash does not recompute from the canonical payload.
  content,
}

/// One chain violation, with the doctor-ready human message.
class EvidenceChainDrift {
  const EvidenceChainDrift({
    required this.entry,
    required this.kind,
    required this.message,
  });

  final ParsedCycleEntry entry;
  final EvidenceChainDriftKind kind;
  final String message;
}

/// The walk's outcome over a list of parsed entries.
class EvidenceChainWalk {
  const EvidenceChainWalk({
    required this.drifts,
    required this.unverifiedKinds,
  });

  /// Violations, grouped per behavior (behavior ids sorted) and in file
  /// order within each behavior.
  final List<EvidenceChainDrift> drifts;

  /// Kinds of hash-less schema-0 entries, in walk order — valid but
  /// unverifiable (the legacy tolerance).
  final List<String> unverifiedKinds;

  bool get ok => drifts.isEmpty;
}

/// Whether [entry] was written by `CycleLog` (its kind is a
/// [CycleEntryKind] member) — the entries whose payload the canonical
/// walk can rebuild. Certifier/era kinds are foreign to that writer.
bool cycleLogOwnsKind(String kind) =>
    CycleEntryKind.values.any((candidate) => candidate.name == kind);

/// Whether the section advertises the schema-1 chain — `- prev-hash:`
/// and/or `- schema: 1` — regardless of whether its `- hash:` line is
/// well-formed. The signal the missing-hash guard keys on.
bool claimsChain(ParsedCycleEntry entry) =>
    entry.prevHash != null || entry.schema == '1';

/// Walk the per-behavior hash chain over [entries] (file order expected,
/// as [parseEntries] yields it) and report every violation.
EvidenceChainWalk verifyEvidenceChain(List<ParsedCycleEntry> entries) {
  final byBehavior = <String, List<ParsedCycleEntry>>{};
  for (final entry in entries) {
    byBehavior.putIfAbsent(entry.behaviorId, () => []).add(entry);
  }
  final drifts = <EvidenceChainDrift>[];
  final unverified = <String>[];
  final ids = byBehavior.keys.toList()..sort();
  for (final id in ids) {
    var prev = CycleLog.genesisHash;
    for (final entry in byBehavior[id]!) {
      final recorded = entry.hash;
      if (recorded == null) {
        if (claimsChain(entry)) {
          drifts.add(
            EvidenceChainDrift(
              entry: entry,
              kind: EvidenceChainDriftKind.missingHash,
              message:
                  'hash chain broken for "$id" (${entry.kind} entry): the '
                  '`- hash:` chain line is missing or malformed — the entry '
                  'cannot be verified',
            ),
          );
        } else {
          unverified.add(entry.kind);
        }
        continue;
      }
      if (entry.prevHash != prev) {
        drifts.add(
          EvidenceChainDrift(
            entry: entry,
            kind: EvidenceChainDriftKind.linkage,
            message:
                'hash chain broken for "$id" (${entry.kind} entry): prev-hash '
                '${entry.prevHash} does not link the previous hash $prev',
          ),
        );
        prev = recorded;
        continue;
      }
      final recomputed = CycleLog.chainHashFromFields(
        behaviorId: entry.behaviorId,
        kind: entry.kind,
        exit: (entry.exit ?? 0).toString(),
        command: entry.command ?? '',
        criterion: entry.criterion ?? '',
        test: entry.test ?? '',
        timestamp: entry.at ?? '',
        prevHash: prev,
      );
      if (recomputed != recorded && cycleLogOwnsKind(entry.kind)) {
        // Only kinds the CycleLog writer produces can be failed here:
        // a certifier/era section that does not recompute carries a
        // legacy foreign payload the canonical walk cannot rebuild
        // (tolerated above), while a converged one that DOES recompute
        // just verified cleanly through this same arm.
        drifts.add(
          EvidenceChainDrift(
            entry: entry,
            kind: EvidenceChainDriftKind.content,
            message:
                'hash chain broken for "$id" (${entry.kind} entry): '
                'recomputed hash $recomputed != recorded $recorded — the '
                'entry was tampered with after it was certified',
          ),
        );
      }
      prev = recorded;
    }
  }
  return EvidenceChainWalk(drifts: drifts, unverifiedKinds: unverified);
}
