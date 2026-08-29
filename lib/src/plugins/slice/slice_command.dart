/// The `zfa slice` command: context-isolated codebase extraction (spec 043).
///
/// Subcommands:
///   cut <name> --entry <page|path> [--entry ...] [--depth view|presentation|
///        feature|full] [--verify]
///   merge <name> [--yes]
///   list
///   inspect <name>
///   verify <name> [--analyze]
///   run <name> [flutter run passthrough flags...]
///   export <name> --format tar.gz|github [--repo <owner/name|name>]
///   import <name> --from github
///
/// INV-1: every subcommand validates its arguments and fails with usage text,
/// never a stack trace.
library;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

/// The `zfa slice` command.
class SliceCommand extends Command<void> {
  /// Creates the command bound to [projectRoot] (the project the command
  /// operates on; tests inject a fixture directory, the CLI uses '.').
  SliceCommand({this.projectRoot = '.'});

  /// Root of the project being sliced.
  final String projectRoot;

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

  @override
  Future<void> run() async {
    final args = argResults!.arguments;
    if (args.isEmpty || args.first == '--help' || args.first == '-h') {
      print(_usage);
      return;
    }

    final subcommand = args.first;
    final rest = args.sublist(1);

    switch (subcommand) {
      case 'cut':
        await _cut(rest);
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
        print('Unknown slice subcommand: $subcommand');
        print(_usage);
        exitCode = 64;
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
      ..addOption(
        'depth',
        allowed: ['view', 'presentation', 'feature', 'full'],
        defaultsTo: 'feature',
        help: 'Extraction depth',
      )
      ..addFlag(
        'verify',
        help: 'Verify the slice after cutting; fail if incomplete',
      );

    final ArgResults results;
    try {
      results = parser.parse(rest);
    } on FormatException catch (e) {
      _usageError(e.message);
      return;
    }

    final entries = results['entry'] as List<String>;
    if (entries.isEmpty) {
      _usageError(
        'Missing --entry: cut requires at least one entry point '
        '(page name or file path).',
      );
      return;
    }

    if (results.rest.isEmpty) {
      _usageError('Missing slice name: zfa slice cut <name> --entry <point>');
      return;
    }

    print('slice cut is not wired yet');
    exitCode = 1;
  }

  Future<void> _merge(List<String> rest) async {
    final parser = ArgParser()..addFlag('yes', help: 'Confirm shared writes');

    final ArgResults results;
    try {
      results = parser.parse(rest);
    } on FormatException catch (e) {
      _usageError(e.message);
      return;
    }

    if (results.rest.isEmpty) {
      _usageError('Missing slice name: zfa slice merge <name>');
      return;
    }

    print('slice merge is not wired yet');
    exitCode = 1;
  }

  Future<void> _list(List<String> rest) async {
    print('slice list is not wired yet');
    exitCode = 1;
  }

  Future<void> _inspect(List<String> rest) async {
    if (rest.isEmpty || rest.first.startsWith('-')) {
      _usageError('Missing slice name: zfa slice inspect <name>');
      return;
    }

    print('slice inspect is not wired yet');
    exitCode = 1;
  }

  Future<void> _verify(List<String> rest) async {
    final parser = ArgParser()..addFlag('analyze', help: 'Run dart analyze');

    final ArgResults results;
    try {
      results = parser.parse(rest);
    } on FormatException catch (e) {
      _usageError(e.message);
      return;
    }

    if (results.rest.isEmpty) {
      _usageError('Missing slice name: zfa slice verify <name>');
      return;
    }

    print('slice verify is not wired yet');
    exitCode = 1;
  }

  Future<void> _run(List<String> rest) async {
    if (rest.isEmpty || rest.first.startsWith('-')) {
      _usageError('Missing slice name: zfa slice run <name> [flags...]');
      return;
    }

    print('slice run is not wired yet');
    exitCode = 1;
  }

  Future<void> _export(List<String> rest) async {
    final parser = ArgParser()
      ..addOption(
        'format',
        allowed: ['tar.gz', 'github'],
        help: 'Export format',
      )
      ..addOption('repo', help: 'Target repo (github format)');

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

    if (results.rest.isEmpty) {
      _usageError('Missing slice name: zfa slice export <name> --format <fmt>');
      return;
    }

    print('slice export is not wired yet');
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

    print('slice import is not wired yet');
    exitCode = 1;
  }
}
