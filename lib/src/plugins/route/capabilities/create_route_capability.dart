import 'package:path/path.dart' as path;

import '../../../core/plugin_system/capability.dart';
import '../../../utils/entity_id_type.dart';
import '../route_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class CreateRouteCapability implements ZuraffaCapability {
  final RoutePlugin plugin;

  CreateRouteCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create Route';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the entity (e.g. Product)',
      },
      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'List of methods (get,create,update,delete,list,watch,getList,watchList)',
        'default': ['get', 'update'],
      },
      // #358: `--deep-link` is an explicit opt-in flag that pairs with
      // `--scheme` to register the entity's routes for deep links. The
      // manifest hook fires whenever `scheme` is set, so this flag is
      // technically a no-op — it exists for UX clarity (the user
      // explicitly states intent: `zfa route create Product --deep-link
      // --scheme gozuzu`).
      'deepLink': {
        'type': 'boolean',
        'description': 'Explicit opt-in for deep-link registration '
            '(no-op; the manifest hook fires whenever --scheme is set).',
        'default': false,
      },
      // #358: when `scheme` is set, the route plugin writes the
      // platform deep-link registration (Android intent-filter + iOS
      // CFBundleURLSchemes) so external `<scheme>://<entity-path>`
      // links open the entity's routes. Idempotent — re-runs with the
      // same scheme are a no-op.
      'scheme': {
        'type': 'string',
        'description': 'URL scheme to register for the entity routes '
            '(e.g. gozuzu). When set, writes the Android intent-filter '
            '+ iOS CFBundleURLSchemes entry.',
      },
      'host': {
        'type': 'string',
        'description': 'Optional host for App Links (e.g. go.zuzu.dev). '
            'Paired with --scheme + --auto-verify.',
      },
      'autoVerify': {
        'type': 'boolean',
        'description': 'Emit android:autoVerify="true" on the intent-filter '
            '(App Links). Paired with --scheme.',
        'default': false,
      },
      'dryRun': {
        'type': 'boolean',
        'description': 'Run without writing files',
        'default': false,
      },
      'force': {
        'type': 'boolean',
        'description': 'Force overwrite existing files',
        'default': false,
      },
      'verbose': {
        'type': 'boolean',
        'description': 'Enable verbose logging',
        'default': false,
      },
    },
    'required': ['name'],
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
          .whereType<GeneratedFile>()
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

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final name = args['name'];
    final outputDir = plugin.outputDir;
    final methods =
        (args['methods'] as List?)?.cast<String>() ?? ['get', 'update'];
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    // #336: keep route id path params consistent with the view's id
    // field type (probe the entity source / last make plan) so int-id
    // entities get `int.parse(state.pathParameters['id']!)` instead of
    // assigning a String into an int-typed view param.
    final idFieldType =
        args['id-field-type'] as String? ??
        await resolveEntityIdFieldType(entityName: name);

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      methods: methods,
      generateRoute: true,
      generateDi: false, // Prevent repository injections in views
      idFieldType: idFieldType ?? 'String',
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    final files = <GeneratedFile>[
      ...(await plugin.generate(config)),
    ];

    // #358: post-generation manifest hook. When `scheme` is set, also
    // register the URL scheme in the platform manifest files so
    // external `<scheme>://<entity-path>` links open the entity's
    // routes. This is a no-op when the platform files don't exist
    // (pure-Dart packages, tests on temp dirs).
    final scheme = args['scheme'] as String?;
    if (scheme != null && scheme.isNotEmpty) {
      final host = args['host'] as String?;
      final autoVerify = (args['autoVerify'] as bool?) ?? false;
      final manifestWriter = plugin.manifestWriter;
      final projectRoot = plugin.projectRoot;

      final androidFile = await manifestWriter.ensureAndroidIntentFilter(
        manifestPath: path.join(
          projectRoot,
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
        plistPath: path.join(projectRoot, 'ios', 'Runner', 'Info.plist'),
        scheme: scheme,
        dryRun: dryRun,
        verbose: verbose,
      );

      if (androidFile != null) files.add(androidFile);
      if (iosFile != null) files.add(iosFile);
    }

    return files;
  }
}
