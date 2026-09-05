/// The `zfa slice` command: context-isolated codebase extraction (spec 043).
///
/// Subcommands (see `_usage` for the rendered forms):
///   cut, compose, merge, list, inspect, verify, run, export, import
///
/// INV-1: every subcommand validates its arguments and fails with usage text,
/// never a stack trace.
library;

import 'dart:io' as io show exitCode;
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'capabilities/cut_slice_capability.dart';
import 'capabilities/compose_slice_capability.dart';
import '../../core/context/progress_reporter.dart';
import 'capabilities/merge_slice_capability.dart';
import 'capabilities/export_slice_capability.dart';
import 'capabilities/verify_slice_capability.dart';
import 'exporter/github_exporter.dart';
import 'exporter/slice_importer.dart';
import 'generators/manifest_writer.dart';
import 'models/slice_file.dart';
import 'models/slice_manifest.dart';
import 'runner/slice_runner.dart';

/// The `zfa slice` command.
class SliceCommand extends Command<void> {
  /// Creates the command bound to [projectRoot] (the project the command
  /// operates on; tests inject a fixture directory, the CLI uses '.').
  ///
  /// [confirmShared] answers the interactive confirmation for shared-file
  /// writes (used by tests); when null the command prompts on a terminal
  /// and denies when there is none (deterministic in CI).
  SliceCommand({
    this.projectRoot = '.',
    bool Function()? confirmShared,
    this.analyzeLauncher,
    this.processLauncher,
    this.ghLauncher,
  }) : _confirmShared = confirmShared;

  /// Root of the project being sliced.
  final String projectRoot;

  final bool Function()? _confirmShared;

  /// Process seam for `verify --analyze` (injected by tests).
  final AnalyzeLauncher? analyzeLauncher;

  /// Process seam for `slice run` (injected by tests).
  final RunLauncher? processLauncher;

  /// Process seam for `slice export`/`slice import` (gh/git commands;
  /// injected by tests).
  final GhLauncher? ghLauncher;

  @override
  String get name => 'slice';

  @override
  String get description =>
      'Extract runnable, self-contained slices of a project for isolated '
      'agent work.';

  @override
  ArgParser get argParser => ArgParser.allowAnything();

  /// Exit code of the last invocation: 0 on success, 64 on usage errors,
  /// 1 on execution failures.
  int exitCode = 0;

  static const _usage = '''
usage: zfa slice SUBCOMMAND [options]

subcommands:
  cut <name>      Extract a runnable slice (see cut options below)
  compose <id>    Resolve a feature contract → SliceBoundary plan (spec 1098)
  merge <name>    Merge agent changes from a slice back into the project
  list            List active slices
  inspect <name>  Show a slice's files, ownership, and modification status
  verify <name>   Check a slice's imports resolve (--analyze for dart analyze)
  run <name>      Launch the slice (flutter run -t <main_slice.dart>)
  export <name>   Export a slice (--format tar.gz|github [--repo <name>])
  import <name>   Pull an exported GitHub repo back (--from github)

cut options:
  --entry <page|path>  Entry point (repeatable; page name or file path)
  --depth <level>      view | presentation | feature (default) | full
  --verify             Verify the slice after cutting; fail if incomplete

merge options:
  --yes                Confirm shared-file overwrites without prompting

verify options:
  --analyze            Also run dart analyze on the sandbox

export options:
  --format <fmt>       tar.gz or github (required)
  --repo <name>        Target repo (github format; auto-named when omitted)

import options:
  --from <source>      github (currently the only source)''';

  /// Focused per-subcommand help with examples (T072).
  static const _subcommandHelp = <String, String>{
    'cut': '''
usage: zfa slice cut <name> --entry <point> [--depth <level>] [--verify]

options:
  --entry <page|path>  Entry point (repeatable; page name or file path)
  --depth <level>      view | presentation | feature (default) | full
  --verify             Verify the slice after cutting; fail if incomplete
  --verbose            Print per-file and boundary diagnostics

example:
  zfa slice cut product_feature --entry product
  zfa slice cut checkout --entry cart --entry payment --depth full --verify''',
    'compose': '''
usage: zfa slice compose <feature-id>

Resolves the feature's declared contract (specs/<feature-id>/contract.yaml)
into a compose plan (specs/<feature-id>/compose.plan.json) carrying the
resolved SliceBoundary, routes, entities, xray layer and the @FeatureOwned
decorator — the minimal base an agent receives for that feature (spec 1098).

example:
  zfa slice compose login''',
    'merge': '''
usage: zfa slice merge <name> [--yes] [--verbose]

options:
  --yes       Confirm shared-file overwrites without prompting
  --verbose   Print per-file merge decisions

example:
  zfa slice merge product_feature
  zfa slice merge product_feature --yes''',
    'list': '''
usage: zfa slice list

example:
  zfa slice list''',
    'inspect': '''
usage: zfa slice inspect <name>

example:
  zfa slice inspect product_feature''',
    'verify': '''
usage: zfa slice verify <name> [--analyze]

options:
  --analyze   Also run dart analyze on the sandbox

example:
  zfa slice verify product_feature --analyze''',
    'run': '''
usage: zfa slice run <name> [flutter flags...]

example:
  zfa slice run product_feature
  zfa slice run product_feature --device chrome''',
    'export': '''
usage: zfa slice export <name> --format <tar.gz|github> [--repo <name>]

options:
  --format <fmt>   tar.gz or github (required)
  --repo <name>    Target repo (github format; auto-named when omitted)

example:
  zfa slice export product_feature --format tar.gz
  zfa slice export product_feature --format github --repo agent/checkout''',
    'import': '''
usage: zfa slice import <name> --from github

example:
  zfa slice import product_feature --from github''',
  };

  @override
  Future<void> run() async {
    // Issue #767: the instance `exitCode` field SHADOWS dart:io's global
    // inside this class, so failure-path assignments (usage errors, failed
    // capabilities) never reach the process — the real binary exited 0 for
    // every failed slice capability while the INV-1 in-process assertions
    // stayed green. Publish the instance outcome to the global when the
    // dispatch completes so CliRunner._runDispatched honors it.
    exitCode = 0;
    try {
      final args = argResults!.arguments;
      if (args.isEmpty || args.first == '--help' || args.first == '-h') {
        print(_usage);
        return;
      }

      final rawSubcommand = args.first;
      final rest = args.sublist(1);

      // Manifest alias: the manifest advertises dotted/underscored capability
      // names (cut_slice, merge_slice, verify_slice, export_slice); accept them
      // as aliases of the canonical subcommands.
      const manifestAliases = <String, String>{
        'cut_slice': 'cut',
        'merge_slice': 'merge',
        'verify_slice': 'verify',
        'export_slice': 'export',
        'slice.cut': 'cut',
        'slice.merge': 'merge',
        'slice.verify': 'verify',
        'slice.export': 'export',
      };
      final subcommand = manifestAliases[rawSubcommand] ?? rawSubcommand;

      // T072: focused help per subcommand.
      if (rest.contains('--help') || rest.contains('-h')) {
        print(_subcommandHelp[subcommand] ?? _usage);
        return;
      }

      switch (subcommand) {
        case 'cut':
          await _cut(rest);
        case 'compose':
          await _compose(rest);
        case 'merge':
          await _merge(rest);
        case 'list':
          await _list(rest);
        case 'inspect':
          await _inspect(rest);
        case 'verify':
          await _verify(rest);
        case 'run':
          await _run(rest);
        case 'export':
          await _export(rest);
        case 'import':
          await _import(rest);
        default:
          print('Unknown slice subcommand: $rawSubcommand');
          print(_usage);
          // Issue #767: was `exit(64)` — a hard process exit that also
          // killed in-process test runners. Set the outcome and return;
          // the finally below publishes it to the process.
          exitCode = 64;
          return;
      }
    } finally {
      io.exitCode = exitCode;
    }
  }

  /// Prints a usage error (INV-1: usage text, never a stack trace).
  void _usageError(String message) {
    print(message);
    print(_usage);
    exitCode = 64;
  }

  Future<void> _cut(List<String> rest) async {
    final parser = ArgParser()
      ..addMultiOption(
        'entry',
        help: 'Entry point: page name (e.g. product) or file path',
      )
      // Issue #771: the manifest inputSchema names this required property
      // `entries` — accept it as an alias so manifest-driven callers and
      // the canonical `--entry` form both work.
      ..addMultiOption(
        'entries',
        help: 'Alias of --entry (manifest schema name)',
      )
      ..addOption(
        'depth',
        allowed: ['view', 'presentation', 'feature', 'full'],
        defaultsTo: 'feature',
        help: 'Extraction depth',
      )
      ..addFlag(
        'verify',
        help: 'Verify the slice after cutting; fail if incomplete',
      )
      ..addFlag('verbose', help: 'Print per-file and boundary diagnostics')
      ..addOption(
        'name',
        help: 'Slice name (alternative to the positional argument)',
      );

    final ArgResults results;
    try {
      results = parser.parse(rest);
    } on FormatException catch (e) {
      _usageError(e.message);
      return;
    }

    final entries = [
      ...results['entry'] as List<String>,
      ...results['entries'] as List<String>,
    ];
    if (entries.isEmpty) {
      _usageError(
        'Missing --entry: cut requires at least one entry point '
        '(page name or file path).',
      );
      return;
    }

    if (results.rest.isEmpty && results['name'] == null) {
      _usageError('Missing slice name: zfa slice cut <name> --entry <point>');
      return;
    }

    final sliceName = results.rest.isNotEmpty
        ? results.rest.first
        : results['name'] as String;
    final reporter = CliProgressReporter();
    reporter.started('Cutting slice "$sliceName"', 4);
    final capability = CutSliceCapability();
    final result = await capability.execute({
      'name': sliceName,
      'entries': entries,
      'depth': results['depth'] as String,
      'projectRoot': projectRoot,
      'verify': results['verify'] as bool,
      'progressReporter': reporter,
    });

    if (!result.success) {
      reporter.failed(result.message ?? 'cut failed');
      print('Error: ${result.message}');
      exitCode = 1;
      return;
    }
    reporter.completed();

    print(result.message);
    final warnings = result.data?['warnings'] as List? ?? const [];
    for (final warning in warnings) {
      print('warning: $warning');
    }

    // T073: verbose diagnostics — every file with its ownership, every
    // boundary interface, and the generated harness files.
    if (results['verbose'] as bool) {
      final sandboxDir = CutSliceCapability.sandboxDirFor(
        projectRoot,
        sliceName,
      );
      final manifest = await ManifestWriter().read(sandboxDir);
      for (final file in manifest.files) {
        print('verbose: ${file.relativePath} (${file.ownership.name})');
      }
      for (final boundary in manifest.boundaries) {
        print('verbose: boundary ${boundary.typeName}');
      }
      for (final generated in manifest.generatedFiles) {
        print('verbose: generated $generated');
      }
    }

    // T057/A19: fail-fast verification rolls the sandbox back on failure.
    if (results['verify'] as bool) {
      final verify = await VerifySliceCapability().execute({
        'name': results.rest.first,
        'projectRoot': projectRoot,
        'analyzeLauncher': analyzeLauncher,
      });
      if (verify.success) {
        print(verify.message);
      } else {
        print('Error: slice verification failed — rolling back.');
        for (final issue in (verify.data?['issues'] as List? ?? const [])) {
          final issueMap = issue as Map;
          print(
            'unresolved: ${issueMap['file']}:${issueMap['line']} '
            '"${issueMap['importPath']}" — ${issueMap['reason']}',
          );
        }
        final sandbox = CutSliceCapability.sandboxDirFor(
          projectRoot,
          results.rest.first,
        );
        final dir = Directory(sandbox);
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
        exitCode = 1;
      }
    }
  }

  /// Spec 1098 (materialization step 6): resolve a feature contract into
  /// its SliceBoundary compose plan. INV-1: usage errors print text and
  /// set [exitCode]; never a stack trace.
  Future<void> _compose(List<String> rest) async {
    final id = rest.isEmpty || rest.first.startsWith('-')
        ? null
        : rest.first.trim();
    if (id == null || id.isEmpty) {
      _usageError(
        'Missing feature id: zfa slice compose <feature-id>\n'
        'The feature must be declared at specs/<feature-id>/contract.yaml.',
      );
      return;
    }

    final result = await ComposeSliceCapability().execute(
      projectRoot: projectRoot,
      featureId: id,
    );

    print(result.message);
    for (final file in result.files) {
      print('  Wrote: $file');
    }
    exitCode = result.success ? 0 : 1;
  }

  Future<void> _merge(List<String> rest) async {
    final parser = ArgParser()
      ..addFlag('yes', help: 'Confirm shared writes')
      ..addFlag('verbose', help: 'Print per-file merge decisions')
      ..addOption(
        'name',
        help: 'Slice name (alternative to the positional argument)',
      );

    final ArgResults results;
    try {
      results = parser.parse(rest);
    } on FormatException catch (e) {
      _usageError(e.message);
      return;
    }

    // Issue #771: the manifest schema declares `name` as required — accept
    // the flag form; the positional argument keeps precedence.
    if (results.rest.isEmpty && results['name'] == null) {
      _usageError('Missing slice name: zfa slice merge <name>');
      return;
    }

    final confirmAll = results['yes'] as bool;
    bool confirmOverwrite(SliceFile file) {
      if (confirmAll) return true;
      return _promptShared(
        'Overwrite shared file "${file.relativePath}"? [y/N] ',
      );
    }

    bool confirmDelete(String path) {
      if (confirmAll) return true;
      return _promptShared(
        'Delete shared file "$path" from the project? [y/N] ',
      );
    }

    final sliceName = results.rest.isNotEmpty
        ? results.rest.first
        : results['name'] as String;
    final reporter = CliProgressReporter();
    reporter.started('Merging slice "$sliceName"', 3);
    final capability = MergeSliceCapability();
    final result = await capability.execute({
      'name': sliceName,
      'projectRoot': projectRoot,
      'confirmAll': confirmAll,
      'confirmSharedOverwrite': confirmOverwrite,
      'confirmSharedDelete': confirmDelete,
      'progressReporter': reporter,
    });
    if (result.success) {
      reporter.completed();
    } else {
      reporter.failed(result.message ?? 'merge failed');
    }

    await _printMergeResult(result, verbose: results['verbose'] as bool);
  }

  /// Prompts on a real terminal; denies when there is none (CI, tests).
  bool _promptShared(String question) {
    if (_confirmShared != null) return _confirmShared();
    if (!stdin.hasTerminal) return false;
    stdout.write(question);
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    return answer == 'y' || answer == 'yes';
  }

  Future<void> _printMergeResult(dynamic result, {bool verbose = false}) async {
    final data = result.data as Map<String, dynamic>? ?? const {};
    if (result.success) {
      print(result.message);
      _printList('merged', data['copied'] as List? ?? const []);
      _printList('created', data['created'] as List? ?? const []);
      _printList('deleted', data['deleted'] as List? ?? const []);
      for (final warning in (data['warnings'] as List? ?? const [])) {
        print('warning: $warning');
      }
      if (verbose) {
        // T073: per-file decisions for debugging the merge.
        for (final file in (data['copied'] as List? ?? const [])) {
          print('verbose: copied $file');
        }
        for (final file in (data['created'] as List? ?? const [])) {
          print('verbose: created $file');
        }
        for (final file in (data['deleted'] as List? ?? const [])) {
          print('verbose: deleted $file');
        }
        for (final file in (data['conflicts'] as List? ?? const [])) {
          print('verbose: conflict $file');
        }
        final skipped = (data['skipped'] as List? ?? const []).length;
        if (skipped > 0) {
          print('verbose: skipped $skipped unchanged file(s)');
        }
        for (final entry in (data['unconfirmedShared'] as List? ?? const [])) {
          print('verbose: unconfirmed $entry');
        }
      }
      return;
    }
    print('Error: merge incomplete — ${result.message}');
    _printList('conflict', data['conflicts'] as List? ?? const []);
    _printList(
      'shared change not confirmed',
      data['unconfirmedShared'] as List? ?? const [],
    );
    for (final warning in (data['warnings'] as List? ?? const [])) {
      print('warning: $warning');
    }
    exitCode = 1;
  }

  void _printList(String label, List items) {
    for (final item in items) {
      print('$label: $item');
    }
  }

  Future<void> _list(List<String> rest) async {
    final slicesRoot = p.join(projectRoot, '.zuraffa', 'slices');
    final rootDir = Directory(slicesRoot);
    final writer = ManifestWriter();

    if (!rootDir.existsSync()) {
      print(
        'No active slices. Cut one with `zfa slice cut <name> --entry <point>`.',
      );
      return;
    }

    final manifests = <String, SliceManifest>{};
    for (final entity in rootDir.listSync()) {
      if (entity is! Directory) continue;
      try {
        manifests[p.basename(entity.path)] = await writer.read(entity.path);
      } on SliceManifestError {
        // Not a slice directory (or corrupt manifest) — skip in list.
      }
    }

    if (manifests.isEmpty) {
      print(
        'No active slices. Cut one with `zfa slice cut <name> --entry <point>`.',
      );
      return;
    }

    for (final sliceName in manifests.keys.toList()..sort()) {
      final manifest = manifests[sliceName]!;
      print(
        '$sliceName  depth=${manifest.depth.name}  '
        '${manifest.files.length} files  '
        'created=${manifest.createdAt.toIso8601String().substring(0, 10)}',
      );
      for (final entry in manifest.entries) {
        print('  entry: $entry');
      }
    }
  }

  Future<void> _inspect(List<String> rest) async {
    if (rest.isEmpty || rest.first.startsWith('-')) {
      _usageError('Missing slice name: zfa slice inspect <name>');
      return;
    }

    final sliceName = rest.first;
    final sandboxDir = CutSliceCapability.sandboxDirFor(projectRoot, sliceName);
    if (!Directory(sandboxDir).existsSync()) {
      print(
        'Error: no slice named "$sliceName" at '
        '${p.relative(sandboxDir, from: projectRoot)}.',
      );
      exitCode = 1;
      return;
    }

    final SliceManifest manifest;
    try {
      manifest = await ManifestWriter().read(sandboxDir);
    } on SliceManifestError catch (e) {
      print('Error: ${e.message}');
      exitCode = 1;
      return;
    }
    print('slice: ${manifest.name}');
    print('depth: ${manifest.depth.name}');
    print('package: ${manifest.packageName}');
    print('branch: ${manifest.branch}');
    if (manifest.exportedTo != null) {
      print('exportedTo: ${manifest.exportedTo}');
    }
    print('');
    for (final file in manifest.files) {
      final sandboxPath = p.join(sandboxDir, file.relativePath);
      final current = File(sandboxPath).existsSync()
          ? sha256.convert(File(sandboxPath).readAsBytesSync()).toString()
          : null;
      final status = current == null
          ? 'deleted'
          : current == file.hashAtCut
          ? 'unmodified'
          : 'modified';
      print(
        '[${file.ownership.name}] ${file.relativePath} — $status '
        '(${file.layer})',
      );
    }
    if (manifest.boundaries.isNotEmpty) {
      print('');
      print('boundaries:');
      for (final boundary in manifest.boundaries) {
        print('  ${boundary.typeName} (${boundary.interfaceFile})');
      }
    }
  }

  Future<void> _verify(List<String> rest) async {
    final parser = ArgParser()
      ..addFlag('analyze', help: 'Run dart analyze')
      ..addOption(
        'name',
        help: 'Slice name (alternative to the positional argument)',
      );

    final ArgResults results;
    try {
      results = parser.parse(rest);
    } on FormatException catch (e) {
      _usageError(e.message);
      return;
    }

    // Issue #771: the manifest schema declares `name` as required — accept
    // the flag form; the positional argument keeps precedence.
    if (results.rest.isEmpty && results['name'] == null) {
      _usageError('Missing slice name: zfa slice verify <name>');
      return;
    }

    final capability = VerifySliceCapability();
    final result = await capability.execute({
      'name': results.rest.isNotEmpty
          ? results.rest.first
          : results['name'] as String,
      'projectRoot': projectRoot,
      'analyze': results['analyze'] as bool,
      'analyzeLauncher': analyzeLauncher,
    });

    if (result.success) {
      print(result.message);
      return;
    }

    print('Error: ${result.message}');
    for (final issue in (result.data?['issues'] as List? ?? const [])) {
      final issueMap = issue as Map;
      print(
        'unresolved: ${issueMap['file']}:${issueMap['line']} '
        '"${issueMap['importPath']}" — ${issueMap['reason']}',
      );
    }
    for (final error in (result.data?['analyzeErrors'] as List? ?? const [])) {
      print('analyze: $error');
    }
    exitCode = 1;
  }

  Future<void> _run(List<String> rest) async {
    if (rest.isEmpty || rest.first.startsWith('-')) {
      _usageError('Missing slice name: zfa slice run <name> [flags...]');
      return;
    }

    final sliceName = rest.first;
    final passthrough = rest.sublist(1);
    final runner = processLauncher != null
        ? SliceRunner(launcher: processLauncher)
        : SliceRunner();
    final result = await runner.runSlice(
      sliceName: sliceName,
      projectRoot: projectRoot,
      extraArgs: passthrough,
    );

    if (result.launched) {
      print(result.message);
      if (result.exitCode != 0) {
        exitCode = 1;
      }
      return;
    }
    print('Error: ${result.message}');
    exitCode = 1;
  }

  Future<void> _export(List<String> rest) async {
    final parser = ArgParser()
      ..addOption(
        'format',
        allowed: ['tar.gz', 'github'],
        help: 'Export format',
      )
      ..addOption('repo', help: 'Target repo (github format)')
      ..addOption(
        'name',
        help: 'Slice name (alternative to the positional argument)',
      );

    final ArgResults results;
    try {
      results = parser.parse(rest);
    } on FormatException catch (e) {
      _usageError(e.message);
      return;
    }

    final format = results['format'] as String?;
    if (format == null) {
      _usageError(
        'Missing --format: export requires --format tar.gz or --format github',
      );
      return;
    }

    // Issue #771: the manifest schema declares `name` as required — accept
    // the flag form; the positional argument keeps precedence.
    if (results.rest.isEmpty && results['name'] == null) {
      _usageError('Missing slice name: zfa slice export <name> --format <fmt>');
      return;
    }

    final sliceName = results.rest.isNotEmpty
        ? results.rest.first
        : results['name'] as String;
    final repo = results['repo'] as String?;
    final reporter = CliProgressReporter();
    reporter.started('Exporting slice "$sliceName"', 3);
    final capability = ExportSliceCapability();
    final result = await capability.execute({
      'name': sliceName,
      'projectRoot': projectRoot,
      'format': format,
      'repo': repo,
      'progressReporter': reporter,
      if (ghLauncher != null) 'ghLauncher': ghLauncher,
    });

    if (result.success) {
      reporter.completed();
      print(result.message);
      return;
    }
    reporter.failed(result.message ?? 'export failed');
    print('Error: ${result.message}');
    for (final issue in (result.data?['issues'] as List? ?? const [])) {
      final issueMap = issue as Map;
      print(
        'unresolved: ${issueMap['file']}:${issueMap['line']} '
        '"${issueMap['importPath']}" — ${issueMap['reason']}',
      );
    }
    exitCode = 1;
  }

  Future<void> _import(List<String> rest) async {
    final parser = ArgParser()
      ..addOption('from', allowed: ['github'], help: 'Import source');

    final ArgResults results;
    try {
      results = parser.parse(rest);
    } on FormatException catch (e) {
      _usageError(e.message);
      return;
    }

    final from = results['from'] as String?;
    if (from == null) {
      _usageError('Missing --from: import requires --from github');
      return;
    }

    if (results.rest.isEmpty) {
      _usageError('Missing slice name: zfa slice import <name> --from github');
      return;
    }

    final sliceName = results.rest.first;
    final importer = SliceImporter(ghLauncher: ghLauncher);
    final result = await importer.importSlice(
      sliceName: sliceName,
      projectRoot: projectRoot,
    );

    if (result.success) {
      print(result.message);
      return;
    }
    print('Error: ${result.message}');
    exitCode = 1;
  }
}
