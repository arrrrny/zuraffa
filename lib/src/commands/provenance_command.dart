/// `zfa provenance` — repo-wide provenance SBOM (issue #812, VISION
/// Pillar C): attribute every generated file under `lib/` and `test/tdd/`
/// to a recorded origin (spec, generator version, commit, agent identity).
/// `zfa provenance report` renders `provenance.report.json`; the gate
/// fails (exit 1) when a file in a generated path has no origin record.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/project/project_root.dart';
import '../plugins/tdd/services/provenance_scanner.dart';

class ProvenanceCommand extends Command<void> {
  ProvenanceCommand() {
    addSubcommand(ProvenanceReportCommand());
  }

  @override
  String get name => 'provenance';

  @override
  String get description =>
      'Repo-wide provenance SBOM: attribute generated files under lib/ and '
      'test/tdd/ to their origin (issue #812).';

  @override
  String get invocation => 'zfa provenance <subcommand> [options]';

  @override
  Future<void> run() async {
    print('Usage: $invocation');
    print(description);
    print('');
    print('Subcommands:');
    print('  report   Scan generated paths and write provenance.report.json');
    exitCode = 2;
  }
}

class ProvenanceReportCommand extends Command<void> {
  ProvenanceReportCommand() {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help: 'Project root containing lib/, test/tdd/. Defaults to CWD.',
    );
    argParser.addOption(
      'output',
      help: 'Output path for provenance.report.json.',
    );
  }

  @override
  String get name => 'report';

  @override
  String get description =>
      'Scan generated paths and write provenance.report.json; fail on '
      'unowned files.';

  @override
  String get invocation => 'zfa provenance report [--project <dir>]';

  @override
  Future<void> run() async {
    final argResults = this.argResults;
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : (ProjectRoot.find(anchorDir: 'lib'));
    final outputFlag = argResults?['output'] as String?;

    print('zfa provenance report: scanning generated paths...');
    print('   project: $projectRoot');

    final scanner = ProvenanceScanner(projectRoot);
    final report = await scanner.scan();

    final reportPath = outputFlag != null && outputFlag.isNotEmpty
        ? p.absolute(outputFlag)
        : p.join(projectRoot, 'provenance.report.json');

    final file = File(reportPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'project': projectRoot,
        'files': {
          for (final entry in report.files.entries)
            entry.key: {
              'source': entry.value.source.name,
              'command': entry.value.command,
            },
        },
        'unattributed': report.unattributed,
        'conflicts': report.conflicts,
        'counts': {
          'files': report.counts.files,
          'attributed': report.counts.attributed,
          'carveout': report.counts.carveout,
          'unattributed': report.counts.unattributed,
        },
        'result': report.result,
      }),
    );

    print('   files: ${report.counts.files}');
    print('   attributed: ${report.counts.attributed}');
    print('   carve-out: ${report.counts.carveout}');
    print('   unattributed: ${report.counts.unattributed}');
    if (report.unattributed.isNotEmpty) {
      print('unattributed files:');
      for (final f in report.unattributed) {
        print('   $f');
      }
    }
    print('   report: $reportPath');

    exitCode = report.result == 'pass' ? 0 : 1;
  }
}
