import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/project/receipt_store.dart';
import '../core/proof/proof_chain_checker.dart';
import '../core/proof/proof_checker.dart';
import '../cli/exit_protocol.dart';

/// Proof-carrying generation (issue #807): every generated artifact ships
/// a verifiable receipt, and `zfa proof check` re-derives the proof.
///
/// Issue #1148 (VISION-4, EPIC 5) adds the end-to-end sibling
/// `zfa proof chain`: one command that walks `.zfa/receipts/` AND the
/// tdd stores under `specs/`, validating the whole chain — receipt
/// digests, behavior green evidence, generated-test integrity, route
/// and usecase verifies, xray coverage — with a `proof-chain.v1` JSON
/// verdict and SPEC 917 exit codes (0 intact / 1 drift / 2 infra).
class ProofCommand extends Command<void> {
  @override
  final String name = 'proof';

  @override
  final String description =
      'Generation receipts: prove where generated artifacts came from '
      '(issue #807), and validate the whole proof chain end-to-end '
      '(issue #1148).';

  ProofCommand() {
    addSubcommand(ProofCheckCommand());
    addSubcommand(ProofChainCommand());
    addSubcommand(ProofPruneCommand());
  }

  @override
  Future<void> run() async {
    print('Usage: zfa proof <subcommand> [paths...] [--format text|json]');
    print('');
    print(description);
    print('');
    print('Subcommands:');
    print(
      '  check    Verify every receipt in .zfa/receipts/ against the '
      'current tree',
    );
    print(
      '  chain    Walk .zfa/receipts/ + the project tree and validate '
      'every link of the proof chain end-to-end (digests, behaviors, '
      'tests, route/usecase verifies, xray coverage) — exit 0/1/2, '
      '--json verdict (issue #1148)',
    );
    print(
      '  prune    Delete receipts whose every artifact is missing (dead '
      'sandbox / interrupted-run receipts) — dry run by default, '
      '--apply to delete (issue #1378)',
    );
    exitCode = ExitProtocol.usage;
  }
}

/// `zfa proof prune` (issue #1378) — receipts whose EVERY artifact is
/// missing (a garbage-collected temp sandbox, an interrupted run) are
/// dead: `zfa proof check` reports them as permanent deleted-artifact
/// findings and nothing could cancel them. Prune deletes those receipts
/// explicitly. Dry run by default; `--apply` deletes. Partial receipts
/// (some artifacts missing) are KEPT — they may be hand-repairable, and
/// blanket-deleting them would hide real drift.
class ProofPruneCommand extends Command<void> {
  @override
  final String name = 'prune';

  @override
  final String description =
      'Delete receipts whose every artifact is missing (dead sandbox or '
      'interrupted-run receipts). Dry run by default; --apply deletes '
      '(issue #1378).';

  ProofPruneCommand() {
    argParser.addFlag(
      'apply',
      negatable: false,
      help: 'Actually delete the dead receipt files (default: dry run).',
    );
  }

  @override
  Future<void> run() async {
    final projectRoot = Directory.current.path;
    final store = ReceiptStore(projectRoot: projectRoot);
    final records = await store.loadAll();
    if (records.isEmpty) {
      print('proof prune: no receipts in ${store.directory.path}');
      return;
    }

    final dead = <ReceiptRecord>[];
    final partial = <ReceiptRecord>[];
    final alive = <ReceiptRecord>[];
    for (final record in records) {
      final files = record.receipt.files;
      if (files.isEmpty) {
        alive.add(record);
        continue;
      }
      final missing = files
          .where((f) => !File(p.join(projectRoot, f.path)).existsSync())
          .length;
      if (missing == files.length) {
        dead.add(record);
      } else if (missing > 0) {
        partial.add(record);
      } else {
        alive.add(record);
      }
    }

    for (final record in dead) {
      print(
        '  prune ${record.fileName} '
        '(${record.receipt.files.length} missing artifact(s); '
        'command: ${record.receipt.command})',
      );
    }
    for (final record in partial) {
      final missing = record.receipt.files
          .where((f) => !File(p.join(projectRoot, f.path)).existsSync())
          .length;
      print(
        '  keep ${record.fileName} ($missing of '
        '${record.receipt.files.length} artifact(s) missing — partial '
        'receipts are never pruned)',
      );
    }
    final apply = argResults!['apply'] == true;
    if (apply) {
      for (final record in dead) {
        File(p.join(store.directory.path, record.fileName)).deleteSync();
      }
    }
    print(
      'proof prune: ${dead.length} dead receipt(s) '
      '${apply ? 'pruned' : 'found (dry run — pass --apply to delete)'}, '
      '${partial.length} partial, ${alive.length} alive.',
    );
    exitCode = 0;
  }
}

class ProofCheckCommand extends Command<void> {
  @override
  final String name = 'check';

  @override
  final String description =
      'Verify generation receipts: digest drift, deletions, stale specs '
      'and — with coverage roots — unprovenanced generated-code paths.';

  ProofCheckCommand() {
    argParser.addOption(
      'format',
      allowed: ['text', 'json'],
      defaultsTo: 'text',
      help:
          'Output format. json emits a single proof.v1 verdict object and '
          'sets the exit code (CI-able, per #778).',
    );
  }

  @override
  Future<void> run() async {
    final jsonMode = (argResults!['format'] as String? ?? 'text') == 'json';
    final coverageRoots = argResults!.rest;

    final report = await ProofChecker(
      projectRoot: Directory.current.path,
    ).check(coverageRoots: coverageRoots);

    if (jsonMode) {
      // Single parseable verdict object (format per issue #778). No prose
      // so agents/CI can consume stdout directly.
      print(jsonEncode(report.toJson()));
    } else {
      _printText(report, coverageRoots);
    }
    exitCode = report.ok ? 0 : 1;
  }

  void _printText(ProofReport report, List<String> coverageRoots) {
    print('Proof Check (.zfa/receipts/)');
    print('============================');
    if (coverageRoots.isNotEmpty) {
      print('Audited coverage roots: ${coverageRoots.join(', ')}');
    }

    if (report.receipts == 0) {
      print('No generation receipts found.');
      if (coverageRoots.isEmpty) {
        print('proof: 0 receipt(s), 0 artifact(s) verified, 0 finding(s) — OK');
        print(
          'Nothing to prove yet: receipts appear after `zfa entity '
          'create` / `zfa make` runs.',
        );
        return;
      }
    } else {
      print(
        'Verified ${report.filesChecked} artifact(s) from '
        '${report.receipts} receipt(s).',
      );
    }

    if (report.findings.isEmpty) {
      print(
        'proof: ${report.receipts} receipt(s), '
        '${report.filesChecked} artifact(s) verified, '
        '0 finding(s) — OK',
      );
      print('Every generated artifact proves where it came from.');
      return;
    }

    print('');
    print('Findings (${report.findings.length}):');
    for (final finding in report.findings) {
      print('  [${finding.kind}] ${finding.path}');
      print('    ${finding.detail}');
      if (finding.diff != null && finding.diff!.isNotEmpty) {
        print('    diff:');
        for (final line in finding.diff!.split('\n')) {
          print('      $line');
        }
      }
    }
    print('');
    print(
      'proof: ${report.receipts} receipt(s), '
      '${report.filesChecked} artifact(s) verified, '
      '${report.findings.length} finding(s) — FAIL',
    );
    print(
      'Regenerate with the repro commands above, or restore the '
      'recorded bytes.',
    );
  }
}

/// `zfa proof chain` (issue #1148, VISION-4, EPIC 5) — the end-to-end
/// proof chain command.
///
/// Walks `.zfa/receipts/` and the project tree and validates every
/// link: (1) receipt digests match disk files, (2) spec behaviors have
/// green cycle-log evidence, (3) tdd gen'd tests exist and their
/// imports resolve (`--run-tests` executes them), (4) declared routes'
/// verify verdicts pass or are skipped with a reason, (5) usecase
/// entities pass the conformance gate, (6) xray coverage kinds are
/// traced. `--json` emits one `proof-chain.v1` verdict object.
///
/// Exit codes (SPEC 917, the issue's contract): 0 = chain intact
/// (gaps do not fail — missing proof is reported, never silent), 1 =
/// drift detected, 2 = infrastructure error.
class ProofChainCommand extends Command<void> {
  @override
  final String name = 'chain';

  @override
  final String description =
      'Validate the whole proof chain end-to-end: receipt digests, spec '
      'behavior green evidence, generated-test integrity, route and '
      'usecase verifies, and xray coverage — exit 0 intact / 1 drift / '
      '2 infra error (issue #1148).';

  ProofChainCommand() {
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit the proof-chain.v1 verdict as a single JSON object on '
          'stdout (CI-able): every item carries category, severity, '
          'file, expected, actual and fix.',
    );
    argParser.addFlag(
      'run-tests',
      negatable: false,
      help:
          'Execute every tdd-registered test file (dart test) in addition '
          'to the static checks. Default: off — runtime is then reported '
          'as not-exercised, never claimed.',
    );
  }

  @override
  Future<void> run() async {
    final jsonMode = argResults!['json'] as bool? ?? false;
    final runTests = argResults!['run-tests'] as bool? ?? false;

    final report = await ProofChainChecker(
      projectRoot: Directory.current.path,
    ).check(runTests: runTests);

    if (jsonMode) {
      // One parseable verdict object; no prose on stdout.
      print(jsonEncode(report.toJson()));
    } else {
      _printText(report);
    }
    exitCode = report.exitCode;
  }

  void _printText(ProofChainReport report) {
    print('Proof Chain (.zfa/receipts/ + specs/) — zfa proof chain');
    print('======================================================');

    if (report.infraErrors.isNotEmpty) {
      for (final error in report.infraErrors) {
        print('  infra: $error');
      }
      print(
        ExitProtocol.fixLine(
          'restore the unreadable store (remove the '
          'blocking file / fix permissions) and re-run',
        ),
      );
      print(
        'proof-chain: INFRA — ${report.infraErrors.length} '
        'infrastructure error(s) (exit 2)',
      );
      return;
    }

    final counts = report.counts;
    for (final kind in ProofChainCheckKind.values) {
      final count = counts[kind.countKey] ?? 0;
      if (count == 0 && !report.items.any((i) => i.check == kind)) continue;
      print(
        '  ${kind.category}: ${report.items.where((i) => i.check == kind && i.severity == ProofChainSeverity.drift).length} drift, '
        '${report.items.where((i) => i.check == kind && i.severity == ProofChainSeverity.gap).length} gap',
      );
    }

    if (report.items.isEmpty) {
      print(
        'No drift, no gaps — every existing link of the chain is '
        'proven.',
      );
      print('proof-chain: 0 drift, 0 gap — OK');
      return;
    }

    print('');
    print('Items (${report.items.length}):');
    for (final item in report.items) {
      print('  [${item.severity.name}] ${item.category} — ${item.file}');
      print('      expected: ${item.expected}');
      print('      actual:   ${item.actual}');
      print('      ${ExitProtocol.fixLine(item.fix)}');
    }

    if (report.ok) {
      print(
        'proof-chain: ${report.driftCount} drift, ${report.gapCount} '
        'gap(s), ${report.infoCount} info — OK (gaps are open links, '
        'reported not failed)',
      );
    } else {
      print(
        'proof-chain: ${report.driftCount} drift, ${report.gapCount} '
        'gap(s), ${report.infoCount} info — FAIL',
      );
      print(
        ExitProtocol.fixLine(
          'resolve every drift above (gaps are open links — close them '
          'with the suggested commands)',
        ),
      );
    }
  }
}
