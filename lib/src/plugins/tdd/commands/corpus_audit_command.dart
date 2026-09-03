/// `zfa tdd corpus audit` — the epic's proof artifact (spec
/// 051-corpus-harness, FR-005/FR-006): attribute every file under the
/// driven app's `lib/` to a recorded zfa command invocation (the loop's
/// artifact registries, cycle-log refactor evidence, setup/import
/// provenance) or an entry in the versioned carve-out manifest. Any
/// unattributed file fails the audit BY NAME — the carve-out manifest is
/// the only exemption path (US3).
///
/// Machine contract: writes `.zfa/corpus/audit-report.json` (per-file
/// attribution map, carve-out list, counts, result) and ends with
/// `audit: files=<n> attributed=<n> carveout=<n> unattributed=<n>
/// result=<pass|fail>`. Exit 0 pass, 1 fail (every unattributed file
/// named), 2 runner-error.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../tdd_plugin.dart';
import '../services/adapter_parity_checker.dart';
import '../services/corpus_manifest_store.dart';
import '../services/provenance_scanner.dart';
import '../../../core/project/project_root.dart';

class CorpusAuditCommand extends Command<void> {
  CorpusAuditCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root of the driven app (containing .zfa/, specs/, lib/). '
          'When omitted, the current working directory is used.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'audit';

  @override
  String get description =>
      'Attribute every lib/ file to a recorded zfa invocation or carve-out '
      'entry; unattributed files fail by name (spec 051, FR-005/FR-006).';

  @override
  String get invocation => 'zfa tdd corpus audit [--project <dir>]';

  static const _exitPass = 0;
  static const _exitFail = 1;
  static const _exitRunnerError = 2;

  @override
  Future<void> run() async {
    final argResults = this.argResults;
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');

    print('zfa tdd corpus audit: scanning lib/ provenance...');
    print('   project: $projectRoot');

    ProvenanceReport? report;
    try {
      final scanner = ProvenanceScanner(projectRoot);
      report = await scanner.scan();
      final result = report.unattributed.isEmpty ? 'pass' : 'fail';

      // The human summary + the failure names (FR-006).
      print('   files: ${report.counts.files}');
      print('   attributed: ${report.counts.attributed}');
      print('   carve-out: ${report.counts.carveout}');
      print('   unattributed: ${report.counts.unattributed}');
      if (report.unattributed.isNotEmpty) {
        print('unattributed files:');
        for (final file in report.unattributed) {
          print('   $file');
        }
      }

      // The machine-readable report (FR-006).
      final reportPath = CorpusManifestStore(projectRoot).auditReportPath;
      final reportFile = File(reportPath);
      await reportFile.parent.create(recursive: true);
      await reportFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'project': projectRoot,
          'files': {
            for (final entry in report.files.entries)
              entry.key: {
                'source': entry.value.source.name,
                'command': entry.value.command,
              },
          },
          'carveouts': [
            for (final entry in report.files.entries)
              if (entry.value.source == AttributionSource.carveout)
                {'path': entry.key, 'reason': entry.value.command},
          ],
          'unattributed': report.unattributed,
          'counts': {
            'files': report.counts.files,
            'attributed': report.counts.attributed,
            'carveout': report.counts.carveout,
            'unattributed': report.counts.unattributed,
          },
          'result': result,
        }),
      );
      print('   report: $reportPath');

      // Per-adapter parity rollup (bug #915): every spec feature with
      // committed adapter-contract fixtures gets its parity score
      // surfaced in the audit. Features without contract fixtures have
      // no line — reported, never invented.
      for (final feature in AdapterParityChecker.discoverFeaturesWithContracts(
        projectRoot,
      )) {
        final rollup = AdapterParityChecker.rollupForFeature(
          p.join(projectRoot, 'specs', feature),
        );
        print('   parity: $feature ${rollup.summaryLine}');
      }

      _printSummary(report, result);
      exitCode = result == 'pass' ? _exitPass : _exitFail;
    } on IOException catch (e) {
      print('zfa tdd corpus audit: runner error: $e');
      _printSummary(report, 'runner-error');
      exitCode = _exitRunnerError;
    }
  }

  static void _printSummary(ProvenanceReport? report, String result) {
    final counts = report?.counts;
    print(
      'audit: files=${counts?.files ?? 0} '
      'attributed=${counts?.attributed ?? 0} '
      'carveout=${counts?.carveout ?? 0} '
      'unattributed=${counts?.unattributed ?? 0} '
      'result=$result',
    );
  }
}
