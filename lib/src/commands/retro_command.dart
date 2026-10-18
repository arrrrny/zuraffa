/// `zfa retro` — mine closed bug issues into auto-proposed regression
/// tests (issue #823, VISION 2030 Pillar G: Meta-intelligence).
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

enum RetroTaxonomy {
  plannerRouting,
  writer,
  flagParsing,
  generator,
  mock,
  cache,
  testHarness,
  uncategorized,
}

extension RetroTaxonomyX on RetroTaxonomy {
  String get label {
    switch (this) {
      case RetroTaxonomy.plannerRouting:
        return 'planner-routing';
      case RetroTaxonomy.writer:
        return 'writer';
      case RetroTaxonomy.flagParsing:
        return 'flag-parsing';
      case RetroTaxonomy.generator:
        return 'generator';
      case RetroTaxonomy.mock:
        return 'mock';
      case RetroTaxonomy.cache:
        return 'cache';
      case RetroTaxonomy.testHarness:
        return 'test-harness';
      case RetroTaxonomy.uncategorized:
        return 'uncategorized';
    }
  }

  static RetroTaxonomy classify(String text) {
    final lower = text.toLowerCase();
    if (_has(lower, const [
      'planner',
      'routing',
      'route table',
      'route-table',
    ])) {
      return RetroTaxonomy.plannerRouting;
    }
    if (_has(lower, const ['flag parsing', 'flag-parsing', 'arg parsing'])) {
      return RetroTaxonomy.flagParsing;
    }
    if (_has(lower, const ['writer', 'smart merge', 'smartmerge'])) {
      return RetroTaxonomy.writer;
    }
    if (_has(lower, const ['generator', 'codegen', 'code gen', 'code-gen'])) {
      return RetroTaxonomy.generator;
    }
    if (_has(lower, const ['mock', 'mocktail', 'mockito'])) {
      return RetroTaxonomy.mock;
    }
    if (_has(lower, const ['cache', 'hive', 'adapter'])) {
      return RetroTaxonomy.cache;
    }
    if (_has(lower, const ['test harness', 'test-harness', 'flutter test'])) {
      return RetroTaxonomy.testHarness;
    }
    if (lower.contains('flag')) return RetroTaxonomy.flagParsing;
    return RetroTaxonomy.uncategorized;
  }

  static bool _has(String text, List<String> needles) {
    for (final n in needles) {
      if (text.contains(n)) return true;
    }
    return false;
  }
}

class RetroCommand extends Command<void> {
  RetroCommand() {
    addSubcommand(RetroScanCommand());
  }

  @override
  String get name => 'retro';

  @override
  String get description =>
      'Mine closed bug issues into auto-proposed regression tests '
      '(VISION 2030 Pillar G). v0: scan + dry-run listing only.';

  @override
  String get invocation => 'zfa retro <subcommand> [options]';

  @override
  Future<void> run() async {
    print(usage);
  }
}

class RetroScanCommand extends Command<void> {
  RetroScanCommand() {
    argParser.addOption('repo', help: 'GitHub repo (owner/name) to scan.');
    argParser.addOption(
      'limit',
      help: 'Number of closed bug issues to scan.',
      defaultsTo: '10',
    );
    argParser.addOption(
      'label',
      help: 'Issue label to filter on.',
      defaultsTo: 'bug',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'List proposed PRs without opening them.',
      defaultsTo: true,
    );
    argParser.addFlag(
      'open',
      negatable: false,
      help: 'Open draft PRs (not implemented in v0).',
    );
    argParser.addFlag('json', negatable: false, help: 'Emit results as JSON.');
  }

  @override
  String get name => 'scan';

  @override
  String get description =>
      'Scan closed bug issues and propose regression-test PRs (dry-run).';

  @override
  String get invocation => 'zfa retro scan [options]';

  @override
  Future<void> run() async {
    final repo = argResults?['repo'] as String? ?? await _detectRepo();
    final limitStr = argResults?['limit'] as String? ?? '10';
    final limit = int.tryParse(limitStr) ?? 10;
    final label = argResults?['label'] as String? ?? 'bug';
    final dryRun = argResults?['dry-run'] == true;
    final open = argResults?['open'] == true;
    final json = argResults?['json'] == true;

    if (repo == null || repo.isEmpty) {
      print('Could not detect repo. Pass --repo owner/name.');
      exitCode = 2;
      return;
    }

    List<Map<String, dynamic>> issues;
    try {
      final result = await Process.run('gh', [
        'issue',
        'list',
        '--repo',
        repo,
        '--state',
        'closed',
        '--label',
        label,
        '--limit',
        '$limit',
        '--json',
        'number,title,body,labels',
      ]);
      if (result.exitCode != 0) {
        print('gh issue list failed: ${result.stderr}');
        exitCode = 1;
        return;
      }
      final decoded = jsonDecode(result.stdout as String);
      issues = (decoded as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Failed to run gh: $e');
      exitCode = 1;
      return;
    }

    final proposals = <Map<String, dynamic>>[];
    for (final issue in issues) {
      final number = issue['number'] as int;
      final title = (issue['title'] as String?) ?? '';
      final body = (issue['body'] as String?) ?? '';
      final taxonomy = RetroTaxonomyX.classify('$title\n$body');
      proposals.add({
        'issue': number,
        'title': title,
        'taxonomy': taxonomy.label,
        'testName': 'issue_$number',
        'prTitle': 'test: regression for $repo#$number ($taxonomy)',
      });
    }

    if (json) {
      print(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'repo': repo, 'dryRun': dryRun, 'proposals': proposals}),
      );
    } else {
      print('Retro scan — $repo (closed/$label, limit $limit)');
      print('Dry run: $dryRun');
      print('');
      if (proposals.isEmpty) {
        print('No closed bug issues found.');
      } else {
        for (final p in proposals) {
          print('#${p['issue']}  [${p['taxonomy']}]  ${p['title']}');
          print('   proposed test: test/.../issue_${p['issue']}_test.dart');
          print('   proposed PR:   ${p['prTitle']}');
        }
        print('');
        print('Proposed: ${proposals.length} regression PR(s).');
      }
    }

    if (open && !dryRun) {
      print('Opening draft PRs is not implemented in v0 (dry-run only).');
    }
  }

  Future<String?> _detectRepo() async {
    try {
      final result = await Process.run('git', ['remote', 'get-url', 'origin']);
      if (result.exitCode != 0) return null;
      final url = (result.stdout as String).trim();
      final m = RegExp(r'[:/]([^/]+/[^/]+?)(?:\.git)?$').firstMatch(url);
      return m?.group(1);
    } catch (_) {
      return null;
    }
  }
}
