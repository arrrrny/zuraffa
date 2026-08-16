import 'package:path/path.dart' as path;

import '../../../core/generator_options.dart';
import '../../../core/plugin_system/capability.dart';
import '../../../models/generated_file.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../builders/route_builder.dart';
import '../builders/shell_routes_builder.dart';
import '../route_plugin.dart';

/// `zfa route shell <Name> --branch <Label>:<path> [--branch ...] `
/// `[--bottom-nav | --rail] [--adaptive]`
///
/// Generates a `StatefulShellRoute.indexedStack` shell module:
///
///  - `lib/src/routing/<name_snake>_shell.dart` containing:
///    * `<Name>Shell` StatelessWidget wrapping `StatefulNavigationShell`
///      with a Material 3 `NavigationBar` (default) or no nav bar.
///    * `<Name>ShellDesktop` with `NavigationRail` when `--adaptive`.
///    * Top-level getter `<nameCamel>ShellRoute()` returning
///      `List<RouteBase>` containing the `StatefulShellRoute.indexedStack`
///      (one `StatefulShellBranch` per `--branch`).
///  - Regenerated `routing/index.dart` aggregating the new shell module
///    into `getAllRoutes()` (now `List<RouteBase>`) so the shell becomes
///    the app's primary navigation surface.
///
/// Each `--branch Label:/path` argument maps to one branch whose single
/// `GoRoute(path: <path>, builder: ...)` renders `SizedBox.shrink()` (or
/// the supplied `--view` class). The shell's branches are designed to
/// delegate to existing entity routes at the same path — when a real
/// entity route module is present, the placeholder `GoRoute` is shadowed
/// by the entity's `GoRoute` at the same path.
///
/// The capability follows the same lifecycle as `DeepLinkRouteCapability`:
/// write file → regenerate index → return generated files list.
class ShellRouteCapability implements ZuraffaCapability {
  final RoutePlugin plugin;

  ShellRouteCapability(this.plugin);

  @override
  String get name => 'shell';

  @override
  String get description =>
      'Generate a StatefulShellRoute.indexedStack shell with one branch '
      'per --branch <Label>:<path>, plus an optional bottom navigation '
      'bar (Material 3 NavigationBar) or desktop NavigationRail '
      '(--adaptive). Registers the shell in getAllRoutes().';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'PascalCase shell name (e.g. Main, App).',
      },
      'branch': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'One entry per bottom-nav tab, formatted as '
            '"<Label>:<path>" (e.g. "Home:/home"). An optional third '
            'colon-separated segment specifies the Material icon '
            '(e.g. "Home:/home:Icons.home"). Repeat the flag once per '
            'branch: --branch Home:/home --branch Deals:/deal.',
      },
      'bottomNav': {
        'type': 'boolean',
        'description': 'Emit a Material 3 NavigationBar bound to '
            'navigationShell.currentIndex + goBranch (default: true).',
        'default': true,
      },
      'adaptive': {
        'type': 'boolean',
        'description': 'Also emit a <Name>ShellDesktop variant with a '
            'NavigationRail for wide layouts; the shell builder picks '
            'between them via LayoutBuilder.',
        'default': false,
      },
      'dryRun': {'type': 'boolean', 'default': false},
      'force': {'type': 'boolean', 'default': false},
      'verbose': {'type': 'boolean', 'default': false},
    },
    'required': ['name', 'branch'],
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'files': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final files = await _generateFiles(args, dryRun: true);

    return EffectReport(
      planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: files
          .map((f) => Effect(file: f.path, action: f.action, diff: null))
          .toList(),
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final files = await _generateFiles(args, dryRun: args['dryRun'] ?? false);

    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {'generatedFiles': files},
    );
  }

  /// Generates:
  ///  1. `<name_snake>_shell.dart` in `<outputDir>/routing/`
  ///  2. Regenerated `routing/index.dart` aggregating the new shell module.
  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final name = args['name'] as String;
    final branchesRaw = (args['branch'] as List?)?.cast<String>() ?? const [];
    final bottomNav = (args['bottomNav'] as bool?) ?? true;
    final adaptive = (args['adaptive'] as bool?) ?? false;
    final force = (args['force'] as bool?) ?? false;
    final verbose = (args['verbose'] as bool?) ?? false;

    final branches = branchesRaw
        .map(ShellRoutesBuilder.parseBranchArg)
        .toList(growable: false);

    final builder = const ShellRoutesBuilder();
    final content = builder.buildFile(
      namePascal: name,
      branches: branches,
      bottomNav: bottomNav,
      adaptive: adaptive,
    );

    final nameSnake = StringUtils.camelToSnake(name);
    final routesPath = path.join(
      plugin.outputDir,
      'routing',
      '${nameSnake}_shell.dart',
    );

    // Ensure the routing directory exists (mirrors DeepLinkRouteCapability).
    // Go through plugin.fileSystem (not dart:io Directory) so the
    // capability honors injected/transactional file systems.
    final routingDir = path.join(plugin.outputDir, 'routing');
    if (!await plugin.fileSystem.exists(routingDir)) {
      await plugin.fileSystem.createDir(routingDir, recursive: true);
    }

    final routeFile = await FileUtils.writeFile(
      routesPath,
      content,
      'shell_routes',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
      fileSystem: plugin.fileSystem,
    );

    // Regenerate the routing index so getAllRoutes() picks up the new
    // shell module (the regenerator scans for *_shell.dart files too —
    // added in this PR).
    final indexBuilder = RouteBuilder(
      outputDir: plugin.outputDir,
      options: GeneratorOptions(dryRun: dryRun, verbose: verbose),
      fileSystem: plugin.fileSystem,
    );
    final indexFile = await indexBuilder.regenerateIndex();

    return [
      routeFile,
      if (indexFile != null) indexFile,
    ];
  }
}
