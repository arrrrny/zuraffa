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
import '../services/corpus_manifest_store.dart';
import '../services/provenance_scanner.dart';

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

  @override
  Future<void> run() async {
    final argResults = this.argResults;
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : Directory.current.path;

    print('zfa tdd corpus audit: scanning lib/ provenance...');
    print('   project: $projectRoot');

    final scanner = ProvenanceScanner(projectRoot);
    final report = await scanner.scan();

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
        'result': report.unattributed.isEmpty ? 'pass' : 'fail',
      }),
    );
    print('   report: $reportPath');

    final result = report.unattributed.isEmpty ? 'pass' : 'fail';
    print(
      'audit: files=${report.counts.files} '
      'attributed=${report.counts.attributed} '
      'carveout=${report.counts.carveout} '
      'unattributed=${report.counts.unattributed} '
      'result=$result',
    );

    exitCode = result == 'pass' ? _exitPass : _exitFail;
  }
}
