/// `zfa skin` — the runtime skin-contract auditor command group
/// (issue #1102).
///
/// * `zfa skin kit [--route <name>]...` — emits the Flutter glue of
///   the auditor (`<output>/skin/skin_contract_auditor.dart`) into
///   the target project, with the `kSkinRouteContract` table built
///   from the `--route` flags or, when none are given, from the
///   routing barrel's declared routes (the static manifest side of
///   the route contract).
/// * `zfa skin verify` — statically reconciles the kit's route
///   contract table against the routing barrel. Honest verdicts
///   (the route-verify precedent): `match` (exit 0), `drift`
///   (exit 1, per-route findings + `--> fix:` lines),
///   `insufficient-input` (exit 2 — the kit or the barrel is
///   missing; never a fake pass). `--json` emits the machine
///   envelope as the final stdout line.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/context/file_system.dart';
import '../skin/builders/skin_contract_kit_builder.dart';
import '../utils/file_utils.dart';
import '../core/project/project_root.dart';

/// The honest verdict of a `zfa skin verify` reconciliation. Never
/// collapse a missing input into a pass (the route-verify contract).
enum SkinVerifyVerdict {
  /// The kit's route contract agrees with the routing barrel.
  match,

  /// The kit table and the routing barrel disagree.
  drift,

  /// The kit or the routing barrel is missing — nothing to reconcile.
  insufficientInput;

  String get label => switch (this) {
    SkinVerifyVerdict.match => 'match',
    SkinVerifyVerdict.drift => 'drift',
    SkinVerifyVerdict.insufficientInput => 'insufficient-input',
  };

  int get exitCode => switch (this) {
    SkinVerifyVerdict.match => 0,
    SkinVerifyVerdict.drift => 1,
    SkinVerifyVerdict.insufficientInput => 2,
  };
}

/// Static route-source scanning for the routing barrel.
///
/// Collects what the generated routing tree declares: the
/// `AppRoutes` path constants (`static const String <name> =
/// '/path'`) and every `GoRoute(path: ...)` argument (literal or
/// `AppRoutes.<name>` reference, resolved through the consts).
class SkinRouteSources {
  static final _constPattern = RegExp(
    r"static\s+const\s+String\s+(\w+)\s*=\s*'([^']*)'",
  );

  static final _goRoutePattern = RegExp(r"GoRoute\s*\((?:[^)]*)\)", dotAll: true);

  static final _pathArgPattern = RegExp(
    r'''path\s*:\s*('([^']*)'|"([^"]*)"|([\w.]+))''',
  );

  static final _nameArgPattern = RegExp(
    r'''name\s*:\s*('([^']*)'|"([^"]*)"|([\w.]+))''',
  );

  /// Scans every `.dart` file under [routingDir]; returns the
  /// declared route set (empty when the dir is absent).
  static Future<Set<String>> scan(String routingDir) async {
    final dir = Directory(routingDir);
    if (!dir.existsSync()) return const {};
    final files =
        dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final consts = <String, String>{};
    for (final file in files) {
      final src = file.readAsStringSync();
      for (final match in _constPattern.allMatches(src)) {
        consts[match.group(1)!] = match.group(2)!;
      }
    }

    final routes = <String>{};
    for (final file in files) {
      final src = file.readAsStringSync();
      for (final goRoute in _goRoutePattern.allMatches(src)) {
        final body = goRoute.group(0) ?? '';
        for (final arg in [_pathArgPattern, _nameArgPattern]) {
          for (final match in arg.allMatches(body)) {
            final literal =
                match.group(2) ??
                match.group(3) ??
                _resolveConst(match.group(4), consts);
            if (literal != null && literal.isNotEmpty) {
              routes.add(literal);
            }
          }
        }
      }
    }
    // The navigator root conforms by construction on BOTH sides of
    // the reconciliation — never a drift finding.
    routes.remove(RouteRootMarker.root);
    return routes;
  }

  static String? _resolveConst(String? reference, Map<String, String> consts) {
    if (reference == null) return null;
    final match = RegExp(r'^([\w]+)\.(\w+)$').firstMatch(reference);
    if (match == null) return null;
    // AppRoutes.<name> (the generated barrel's const holder).
    if (match.group(1) != 'AppRoutes') return null;
    return consts[match.group(2)!];
  }
}

/// Shared marker so the scanner and the verifier agree the root is
/// exempt from drift reconciliation.
abstract final class RouteRootMarker {
  static const String root = '/';
}

/// Extracts the `kSkinRouteContract` table's route names from the
/// emitted kit source (the `RouteContractTable.fromRouteNames(...)`
/// literal set).
Set<String> extractKitRouteContract(String kitSource) {
  final match = RegExp(
    r'kSkinRouteContract\s*=\s*RouteContractTable\.fromRouteNames\('
    r'([^;]*?)\)',
    dotAll: true,
  ).firstMatch(kitSource);
  if (match == null) return const {};
  final body = match.group(1)!;
  final routes = <String>{};
  for (final quoted in RegExp(r"'([^']*)'").allMatches(body)) {
    final value = quoted.group(1)!;
    if (value.isNotEmpty) routes.add(value);
  }
  routes.remove(RouteRootMarker.root);
  return routes;
}

class SkinCommand extends Command<void> {
  SkinCommand({String? projectRoot, FileSystem? fileSystem})
    : _fileSystem = fileSystem ?? const DefaultFileSystem() {
    addSubcommand(
      SkinKitCommand(projectRoot: projectRoot, fileSystem: _fileSystem),
    );
    addSubcommand(
      SkinVerifyCommand(projectRoot: projectRoot, fileSystem: _fileSystem),
    );
  }

  final FileSystem _fileSystem;

  @override
  String get name => 'skin';

  @override
  String get description =>
      'Runtime skin-contract auditor (issue #1102): emit the kit '
      '(skin kit) and statically verify the route-contract table '
      'against the routing barrel (skin verify).';

  @override
  String get invocation => 'zfa skin <subcommand> [options]';

  @override
  Future<void> run() async {
    printUsage();
  }
}

class SkinKitCommand extends Command<void> {
  SkinKitCommand({String? projectRoot, FileSystem? fileSystem})
    : _projectRootOverride = projectRoot,
      _fileSystem = fileSystem ?? const DefaultFileSystem() {
    argParser
      ..addFlag('dry-run', negatable: false, help: 'Preview without writing')
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite an existing kit (default: preserve hand edits)',
      )
      ..addFlag('verbose', abbr: 'v', negatable: false)
      ..addMultiOption(
        'route',
        help:
            'Route name the skin contract allows (repeatable). Defaults '
            'to the routing barrel\'s declared routes when the barrel '
            'exists, else an empty table (the navigator root always '
            'conforms by construction).',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output directory (project-root-relative, under lib/)',
        defaultsTo: 'lib/src',
      )
      ..addOption(
        'root',
        help: 'Project root to emit into (default: current directory)',
      );
  }

  final FileSystem _fileSystem;
  final String? _projectRootOverride;

  @override
  String get name => 'kit';

  @override
  String get description =>
      'Emit the runtime skin-contract auditor Flutter glue '
      '(skin/skin_contract_auditor.dart)';

  @override
  String get invocation => 'zfa skin kit [options]';

  @override
  Future<void> run() async {
    final dryRun = argResults!['dry-run'] as bool;
    final force = argResults!['force'] as bool;
    final verbose = argResults!['verbose'] as bool;
    final routeFlags = (argResults!['route'] as List<String>).cast<String>();
    final outputDir = argResults!['output'] as String;
    final projectRoot =
        (argResults!['root'] as String?) ??
        _projectRootOverride ??
        ProjectRoot.safeCurrentPath();

    var routes = routeFlags;
    var routeSource = 'explicit --route flags';
    if (routes.isEmpty) {
      final barrel = await SkinRouteSources.scan(
        p.join(projectRoot, outputDir, 'routing'),
      );
      if (barrel.isNotEmpty) {
        routes = barrel.toList()..sort();
        routeSource = 'routing barrel (${barrel.length} route(s))';
      }
    }

    final content = const SkinContractKitBuilder().build(routes: routes);
    final kitPath = p.join(
      projectRoot,
      outputDir,
      SkinContractKitBuilder.kitDir,
      SkinContractKitBuilder.kitFileName,
    );

    if (!force && await _fileSystem.exists(kitPath)) {
      print('  skipped: $kitPath already exists (use --force to overwrite)');
      return;
    }

    await FileUtils.writeFile(
      kitPath,
      content,
      'skin_contract_kit',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
      fileSystem: _fileSystem,
    );

    print(
      'skin kit: wrote $kitPath '
      '(routes: ${routes.isEmpty ? 0 : routes.length} from $routeSource)',
    );
    print(
      '   mount points: view getter wrap (--skin), app shell '
      '(--skin-audit), zfa skin verify',
    );
  }
}

class SkinVerifyCommand extends Command<void> {
  SkinVerifyCommand({String? projectRoot, FileSystem? fileSystem})
    : _projectRootOverride = projectRoot,
      _fileSystem = fileSystem ?? const DefaultFileSystem() {
    argParser
      ..addFlag(
        'json',
        negatable: false,
        help: 'Emit the machine verdict envelope as the final line',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output directory (project-root-relative, under lib/)',
        defaultsTo: 'lib/src',
      )
      ..addOption(
        'root',
        help: 'Project root to verify (default: current directory)',
      );
  }

  final FileSystem _fileSystem;
  final String? _projectRootOverride;

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Statically reconcile the kit route-contract table against the '
      'routing barrel (match / drift / insufficient-input)';

  @override
  String get invocation => 'zfa skin verify [options]';

  @override
  Future<void> run() async {
    final jsonMode = argResults!['json'] as bool;
    final outputDir = argResults!['output'] as String;
    final projectRoot =
        (argResults!['root'] as String?) ??
        _projectRootOverride ??
        ProjectRoot.safeCurrentPath();

    final kitPath = p.join(
      projectRoot,
      outputDir,
      SkinContractKitBuilder.kitDir,
      SkinContractKitBuilder.kitFileName,
    );
    final routingDir = p.join(projectRoot, outputDir, 'routing');

    final kitExists = await _fileSystem.exists(kitPath);
    final barrelRoutes = await SkinRouteSources.scan(routingDir);
    final barrelExists = barrelRoutes.isNotEmpty;
    final kitRoutes = kitExists
        ? extractKitRouteContract(await _fileSystem.read(kitPath))
        : const <String>{};

    Map<String, Object?> envelope(
      SkinVerifyVerdict verdict, {
      List<String> drift = const [],
    }) => {
      'verdict': verdict.label,
      'kitRoutes': kitRoutes.toList(),
      'barrelRoutes': barrelRoutes.toList()..sort(),
      'drift': drift,
    };

    if (!kitExists || !barrelExists) {
      final missing = !kitExists
          ? 'the skin kit ($kitPath)'
          : 'the routing barrel ($routingDir)';
      print(
        'zfa skin verify: verdict=insufficient-input — $missing '
        'contributed no routes, so the tables cannot be reconciled.',
      );
      if (!kitExists) {
        print('   --> fix: run `zfa skin kit` to emit the auditor kit.');
      } else {
        print(
          '   --> fix: generate the routing barrel (zfa route create '
          '<Entity>) or pass the route set via `zfa skin kit --route`.',
        );
      }
      if (jsonMode) {
        print(jsonEncode(envelope(SkinVerifyVerdict.insufficientInput)));
      }
      exitCode = SkinVerifyVerdict.insufficientInput.exitCode;
      return;
    }

    final driftKitMissing = barrelRoutes.difference(kitRoutes).toList()..sort();
    final driftBarrelMissing = kitRoutes.difference(barrelRoutes).toList()
      ..sort();

    if (driftKitMissing.isEmpty && driftBarrelMissing.isEmpty) {
      print(
        'zfa skin verify: verdict=match routes=${kitRoutes.length} '
        '(kit=${kitRoutes.length} barrel=${barrelRoutes.length})',
      );
      if (jsonMode) {
        print(jsonEncode(envelope(SkinVerifyVerdict.match)));
      }
      exitCode = SkinVerifyVerdict.match.exitCode;
      return;
    }

    print('zfa skin verify: verdict=drift');
    for (final route in driftKitMissing) {
      print(
        '   [kit-missing] $route — declared by the routing barrel, '
        'absent from the kit route contract',
      );
    }
    for (final route in driftBarrelMissing) {
      print(
        '   [barrel-missing] $route — declared by the kit route '
        'contract, absent from the routing barrel',
      );
    }
    print(
      '   --> fix: re-run `zfa skin kit --force` (the table regenerates '
      'from the routing barrel), or reconcile the drift explicitly with '
      '`zfa skin kit --route <name>`.',
    );
    if (jsonMode) {
      print(
        jsonEncode(
          envelope(
            SkinVerifyVerdict.drift,
            drift: [...driftKitMissing, ...driftBarrelMissing],
          ),
        ),
      );
    }
    exitCode = SkinVerifyVerdict.drift.exitCode;
  }
}
