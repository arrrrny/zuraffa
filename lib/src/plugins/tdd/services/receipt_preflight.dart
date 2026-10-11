import 'package:path/path.dart' as p;

import '../../../core/proof/proof_checker.dart';
import '../../../core/project/receipt_store.dart';

/// Spec 0996 (issue #996), FR-005 — the receipt preflight gate for
/// `zfa tdd verify` (the audit step).
///
/// Before the mutation audit runs, the feature's provenance is checked:
///
///   1. Every receipt the project ships in `.zfa/receipts/` must still
///      validate (digest drift, deleted artifacts, stale specs) — the
///      same verdict semantics as `zfa proof check`.
///   2. When the project ships receipts at all, every audited subject
///      (the mutation scope's subject paths) must be covered by a
///      receipt — a subject with no receipt is a `missing_receipt`
///      finding and fails the gate: the audit would be mutating an
///      artifact that cannot prove where it came from.
///
/// Projects that ship NO receipts keep working: there is nothing to
/// check, the gate is vacuous ([ReceiptPreflightReport.gateActive] is
/// false). This is the backward-compatibility line — legacy TDD
/// fixtures and non-proof projects are not suddenly red.
class ReceiptPreflight {
  ReceiptPreflight({required this.projectRoot, ProofChecker? checker})
    : _checkerOverride = checker;

  /// Project root whose `.zfa/receipts/` is audited.
  final String projectRoot;

  final ProofChecker? _checkerOverride;

  /// Runs the gate. [auditedPaths] are the subject paths the audit is
  /// about to mutate (the mutation scope); they are coverage-checked
  /// only when the project ships receipts. The scope's paths arrive in
  /// whatever shape the artifact registry recorded — ABSOLUTE for
  /// registries written by `zfa tdd gen` (`'$cwd/lib/tdd/...'`),
  /// project-relative for legacy ones — so each path is relativized
  /// against [projectRoot] before the membership test against the
  /// receipt store's project-relative paths (issue #1312). Paths that
  /// resolve outside the project root are not auditable subjects of
  /// this project and are skipped rather than reported missing.
  Future<ReceiptPreflightReport> check({
    List<String> auditedPaths = const [],
  }) async {
    final store = ReceiptStore(projectRoot: projectRoot);
    final records = await store.loadAll();

    // Vacuous gate: no receipts shipped — nothing to prove or demand.
    if (records.isEmpty) {
      return ReceiptPreflightReport(
        ok: true,
        gateActive: false,
        receipts: 0,
        findings: const [],
      );
    }

    final checker = _checkerOverride ?? ProofChecker(projectRoot: projectRoot);
    final proof = await checker.check();

    final findings = <ReceiptPreflightFinding>[
      for (final finding in proof.findings)
        ReceiptPreflightFinding(
          kind: finding.kind,
          path: finding.path,
          detail: finding.detail,
        ),
    ];

    if (auditedPaths.isNotEmpty) {
      final covered = <String>{};
      for (final record in records) {
        for (final entry in record.receipt.files) {
          covered.add(entry.path);
        }
      }
      for (final subject in auditedPaths) {
        final normalized = _normalize(subject);
        // Outside the project root: not an auditable subject of this
        // project — skipped, not a missing receipt.
        if (normalized == null) continue;
        if (covered.contains(normalized)) continue;
        findings.add(
          ReceiptPreflightFinding(
            kind: ReceiptPreflightFinding.missingReceipt,
            path: normalized,
            detail:
                'no receipt in .zfa/receipts/ covers this audit subject — '
                'regenerate it with its capability (or restore the '
                'receipt) before the mutation audit runs',
          ),
        );
      }
    }

    return ReceiptPreflightReport(
      ok: findings.isEmpty,
      gateActive: true,
      receipts: records.length,
      findings: findings,
    );
  }

  /// Normalizes an audited subject path to the project-relative shape
  /// the receipt store records (`files[].path`), or returns `null` when
  /// the path lies outside [projectRoot].
  ///
  /// Issue #1312: the artifact registry (`specs/<f>/tdd/artifacts.json`)
  /// records `subject_path` ABSOLUTE while receipts store
  /// project-relative paths — the two shapes can never intersect unless
  /// the audited path is relativized against [projectRoot] first.
  /// Already-relative paths pass through unchanged (idempotent), and
  /// backslash separators are canonicalized to `/` (Windows registries).
  String? _normalize(String path) {
    final normalized = p.normalize(path).replaceAll('\\', '/');
    if (!p.isAbsolute(normalized)) return normalized;

    // Absolute audited path: relativize against the project root. The
    // root is resolved to an absolute form first so a relative
    // [projectRoot] still yields a deterministic comparison.
    final root = p.normalize(p.absolute(projectRoot)).replaceAll('\\', '/');
    final relative = p
        .normalize(p.relative(normalized, from: root))
        .replaceAll('\\', '/');
    if (relative == '..' || relative.startsWith('../')) {
      // Escapes the project root — not an auditable subject here.
      return null;
    }
    return relative;
  }
}

/// One preflight gate finding. [kind] is either a proof-check kind
/// (`modified`, `deleted`, `stale_spec`) or `missing_receipt`.
class ReceiptPreflightFinding {
  static const missingReceipt = 'missing_receipt';

  final String kind;
  final String path;
  final String detail;

  const ReceiptPreflightFinding({
    required this.kind,
    required this.path,
    required this.detail,
  });

  @override
  String toString() => '[$kind] $path — $detail';
}

/// The preflight verdict.
class ReceiptPreflightReport {
  /// True when the audit may proceed.
  final bool ok;

  /// True when the project ships receipts and the gate actually checked
  /// something (false = vacuous pass, no receipts shipped).
  final bool gateActive;

  /// Number of receipts the gate validated.
  final int receipts;

  final List<ReceiptPreflightFinding> findings;

  const ReceiptPreflightReport({
    required this.ok,
    required this.gateActive,
    required this.receipts,
    required this.findings,
  });
}
