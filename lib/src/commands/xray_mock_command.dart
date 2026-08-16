import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../plugins/xray/xray_mock_scaffolder.dart';

/// `zfa xray mock <Entity>` — scaffold `@XRayMock` annotations onto
/// generated usecases so the Control Deck has real entries out of the
/// box (issue #360).
///
/// Scans `lib/src/domain/usecases/*/` for files matching
/// `*_<entity_snake>_usecase.dart` and injects a single
/// `@XRayMock(name: ..., payload: ..., type: ...)` annotation above
/// each `class ...UseCase` declaration. Also adds the
/// `package:zuraffa_flutter/zuraffa_flutter.dart` import when missing.
///
/// Usage:
///   `zfa xray mock <Entity> [--domain <d>] [--dry-run] [--force]`
class XrayMockCommand extends Command<void> {
  @override
  String get name => 'mock';

  @override
  String get description =>
      'Scaffold @XRayMock annotations onto generated usecases';

  @override
  String get invocation => 'zfa xray mock <Entity> [options]';

  XrayMockCommand() {
    argParser.addOption(
      'domain',
      help: 'Domain subdirectory (default: scan all domains)',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview annotations without writing files',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing @XRayMock annotations',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('Entity name is required: zfa xray mock <Entity>');
    }

    final entityName = rest.first;
    final domain = argResults?['domain'] as String?;
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final force = argResults?['force'] as bool? ?? false;
    final verbose = argResults?['verbose'] as bool? ?? false;

    final projectRoot = Directory.current.path;
    final usecasesDir = p.join(
      projectRoot,
      'lib',
      'src',
      'domain',
      'usecases',
    );
    if (!Directory(usecasesDir).existsSync()) {
      print(
        'No usecases directory found at $usecasesDir.\n'
        '   Generate usecases first:  zfa usecase <Entity>   '
        '(or `zfa make <Entity> --with=usecase`).',
      );
      return;
    }

    if (verbose) {
      print('Scaffolding @XRayMock for "$entityName"...');
      print('  usecases dir: $usecasesDir');
      if (domain != null) print('  domain:       $domain');
      print('  dry-run:      $dryRun');
      print('  force:        $force');
    }

    final scaffolder = XRayMockScaffolder(projectRoot: projectRoot);
    final results = scaffolder.scaffold(
      entityName: entityName,
      domain: domain,
      force: force,
      dryRun: dryRun,
    );

    if (results.isEmpty) {
      print(
        'No usecase files found for "$entityName".\n'
        '   Expected files matching *_${_toSnake(entityName)}_usecase.dart\n'
        '   under $usecasesDir/.',
      );
      return;
    }

    var injected = 0;
    var skipped = 0;
    for (final r in results) {
      final prefix = r.injected ? (dryRun ? '[dry-run]' : 'injected') : 'skipped';
      print('  $prefix  ${p.relative(r.path, from: projectRoot)}');
      if (r.importAdded && r.injected) {
        print('           + import zuraffa_flutter');
      }
      if (!r.injected) {
        print('           ${r.message}');
      }
      if (r.injected) {
        injected++;
      } else {
        skipped++;
      }
    }

    print('');
    final dryRunText = dryRun ? 'would be ' : '';
    print(
      '$injected file(s) ${dryRunText}scaffolded${skipped > 0 ? ", $skipped skipped" : ""}.',
    );

    if (injected > 0 && !dryRun) {
      print('');
      print('── Next steps ──');
      print(
        '   zfa xray deck --entity $entityName   '
        '# generate the Control Deck from these annotations',
      );
      print(
        '   zfa app shell --xray                '
        '# wire the bridge server into main.dart',
      );
    }
  }

  String _toSnake(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char.toUpperCase() == char && char.toLowerCase() != char) {
        if (i > 0) buffer.write('_');
        buffer.write(char.toLowerCase());
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}
