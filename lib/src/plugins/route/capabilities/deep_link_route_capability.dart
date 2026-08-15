import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../core/generator_options.dart';
import '../../../core/plugin_system/capability.dart';
import '../../../models/generated_file.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/manifest_writer.dart';
import '../../../utils/string_utils.dart';
import '../builders/deep_link_routes_builder.dart';
import '../builders/route_builder.dart';
import '../route_plugin.dart';

/// `zfa route deep-link <Name> --path <path> --scheme <scheme> [--host <host>]`
///
/// Generates a deep-link GoRoute module registered in `getAllRoutes()`
/// (auto-discovered by `RouteBuilder._regenerateIndexFile`) and writes
/// the platform deep-link registration:
///
///  - Android: `<intent-filter>` with `<data android:scheme="..."/>`
///    appended to the `MainActivity` activity in
///    `android/app/src/main/AndroidManifest.xml` (idempotent).
///  - iOS: `CFBundleURLTypes` / `CFBundleURLSchemes` entry appended to
///    `ios/Runner/Info.plist` (idempotent).
///
/// When [autoVerify] is `true`, the Android intent-filter is emitted
/// with `android:autoVerify="true"` (App Links). When [host] is
/// provided, an additional `<data android:host="..."/>` is emitted so
/// `https://<host>/...` matches the App Link.
///
/// When [view] is supplied, the generated GoRoute builder
/// returns that view instead of the placeholder `SizedBox.shrink()`.
/// The caller is responsible for verifying the view exists on disk;
/// the capability does not probe the filesystem for the view (it only
/// probes for the platform manifest files, which are optional).
class DeepLinkRouteCapability implements ZuraffaCapability {
  final RoutePlugin plugin;

  DeepLinkRouteCapability(this.plugin);

  @override
  String get name => 'deep-link';

  @override
  String get description =>
      'Generate a deep-link GoRoute module and register the URL scheme '
      'in AndroidManifest.xml + Info.plist (idempotent)';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'PascalCase route name (e.g. ScanBarcode)',
      },
      'path': {
        'type': 'string',
        'description': 'URL path pattern (e.g. /scan/barcode/:barcode)',
      },
      'scheme': {
        'type': 'string',
        'description': 'URL scheme (e.g. gozuzu, https)',
      },
      'host': {
        'type': 'string',
        'description': 'Optional host (e.g. go.zuzu.dev) for App Links',
      },
      'autoVerify': {
        'type': 'boolean',
        'description': 'Emit android:autoVerify="true" (App Links)',
        'default': false,
      },
      'view': {
        'type': 'string',
        'description': 'Optional view class to render (default: '
            'SizedBox.shrink placeholder)',
      },
      'dryRun': {'type': 'boolean', 'default': false},
      'force': {'type': 'boolean', 'default': false},
      'verbose': {'type': 'boolean', 'default': false},
    },
    'required': ['name', 'path', 'scheme'],
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
  ///  1. `<name>_routes.dart` in `<outputDir>/routing/`
  ///  2. Regenerated `routing/index.dart` aggregating the new module
  ///  3. (optional) Updated `AndroidManifest.xml`
  ///  4. (optional) Updated `Info.plist`
  ///
  /// Platform files are skipped silently when absent (e.g. tests on
  /// temp directories, or pure-Dart packages). The route file is
  /// ALWAYS emitted because it lives under `lib/src/routing/` which
  /// is part of the zfa-managed tree.
  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final name = args['name'] as String;
    final routePath = args['path'] as String;
    final scheme = args['scheme'] as String;
    final host = args['host'] as String?;
    final autoVerify = (args['autoVerify'] as bool?) ?? false;
    final view = args['view'] as String?;
    final force = (args['force'] as bool?) ?? false;
    final verbose = (args['verbose'] as bool?) ?? false;

    DeepLinkRoutesBuilder.validate(
      namePascal: name,
      path: routePath,
      scheme: scheme,
    );

    final namePascal = name;
    final nameCamel = StringUtils.pascalToCamel(namePascal);
    final nameSnake = StringUtils.camelToSnake(namePascal);

    final builder = DeepLinkRoutesBuilder();
    final content = builder.buildFile(
      namePascal: namePascal,
      nameCamel: nameCamel,
      nameSnake: nameSnake,
      path: routePath,
      view: view,
    );

    final routesPath = path.join(
      plugin.outputDir,
      'routing',
      '${nameSnake}_routes.dart',
    );

    // Ensure the routing directory exists so the index regenerator
    // picks up the new module even on a fresh project (DefaultFileSystem
    // creates parent dirs implicitly via File.writeAsString, but an
    // injectable FileSystem in tests may not — make it explicit).
    final routingDir = path.join(plugin.outputDir, 'routing');
    if (!await plugin.fileSystem.exists(routingDir)) {
      await _ensureDir(routingDir);
    }

    final routeFile = await FileUtils.writeFile(
      routesPath,
      content,
      'deep_link_routes',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
      fileSystem: plugin.fileSystem,
    );

    // Trigger the routing index regeneration so `getAllRoutes()`
    // aggregates the new module. We construct a fresh RouteBuilder
    // with the runtime dryRun/verbose flags so the index writer
    // honors them (the plugin's late-final routeBuilder was built
    // with default options).
    final indexBuilder = RouteBuilder(
      outputDir: plugin.outputDir,
      options: GeneratorOptions(dryRun: dryRun, verbose: verbose),
      fileSystem: plugin.fileSystem,
    );
    final indexFile = await indexBuilder.regenerateIndex();

    // Platform manifest updates — best-effort, never block on missing
    // platform files (the route file is the primary deliverable).
    final manifestWriter = ManifestWriter(fileSystem: plugin.fileSystem);
    final androidFile = await manifestWriter.ensureAndroidIntentFilter(
      manifestPath: path.join(
        plugin.projectRoot,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
      scheme: scheme,
      host: host,
      autoVerify: autoVerify,
      dryRun: dryRun,
      verbose: verbose,
    );
    final iosFile = await manifestWriter.ensureIosUrlScheme(
      plistPath: path.join(
        plugin.projectRoot,
        'ios',
        'Runner',
        'Info.plist',
      ),
      scheme: scheme,
      dryRun: dryRun,
      verbose: verbose,
    );

    return [
      routeFile,
      if (indexFile != null) indexFile,
      if (androidFile != null) androidFile,
      if (iosFile != null) iosFile,
    ];
  }

  /// Ensures [dirPath] exists on the file system. Uses dart:io directly
  /// (the FileSystem interface doesn't expose a create-dir method, but
  /// all production callers either use DefaultFileSystem — which is
  /// backed by dart:io — or a test in-memory FS that pre-creates the
  /// routing dir before invoking the capability).
  Future<void> _ensureDir(String dirPath) async {
    try {
      await Directory(dirPath).create(recursive: true);
    } catch (_) {
      // Swallow — the route file write below will surface any real
      // permission issue, and tests that inject a non-dart:io file
      // system pre-create the routing dir anyway.
    }
  }
}
