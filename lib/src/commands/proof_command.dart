import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../core/proof/proof_checker.dart';

/// Proof-carrying generation (issue #807): every generated artifact ships
/// a verifiable receipt, and `zfa proof check` re-derives the proof.
class ProofCommand extends Command<void> {
  @override
  final String name = 'proof';

  @override
  final String description =
      'Generation receipts: prove where generated artifacts came from '
      '(issue #807).';

  ProofCommand() {
    addSubcommand(ProofCheckCommand());
  }

  @override
  Future<void> run() async {
    print('Usage: zfa proof check [paths...] [--format text|json]');
    print('');
    print(description);
    print('');
    print('Subcommands:');
    print(
      '  check    Verify every receipt in .zfa/receipts/ against the '
      'current tree',
    );
    exitCode = 64;
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
