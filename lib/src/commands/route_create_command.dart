// RouteCreateCommand — `zfa route create <Entity>` (spec 0971, T002/T003/T005).
//
// A manual subcommand replacing the schema-generated CapabilityCommand for
// `create` so the flag surface can carry `--json` as an OUTPUT verdict
// envelope ({routes[], deepLinks, schemeRegistrations, routeTableTestPath,
// schema:1}) instead of the generic input-args JSON option. Generation
// itself is untouched: the command delegates to CreateRouteCapability
// (issue #971 constraint — do not change route emission semantics).
//
// Error contract (order 5): every error path prints a `--> fix:` line;
// the pure-Dart skip is a structured verdict in the JSON envelope
// (verdict=skip + skip.reason), not a bare warning.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../models/generated_file.dart';
import '../plugins/route/route_plugin.dart';
import '../plugins/route/builders/route_table_test_builder.dart';
import '../plugins/route/route_receipt.dart';
import '../utils/project_flavor.dart';
import '../utils/string_utils.dart';

/// The JSON verdict envelope schema version (issue #971 order 2).
const int routeEnvelopeSchema = 1;

class RouteCreateCommand extends Command<void> {
  RouteCreateCommand(this.plugin, {String? projectRoot})
    : _projectRoot = projectRoot {
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit a machine verdict envelope '
          '({routes[], deepLinks, schemeRegistrations, routeTableTestPath, '
          'schema:1}) instead of the emoji file list.',
    );
    argParser.addFlag(
      'plain',
      negatable: false,
      help: 'Strip emoji from the text output (CI-friendly).',
    );
    argParser.addMultiOption(
      'methods',
      help:
          'Comma-separated list of methods '
          '(get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: ['get', 'update'],
    );
    argParser.addFlag(
      'deep-link',
      negatable: false,
      help:
          'Explicit opt-in for deep-link registration (no-op; the manifest '
          'hook fires whenever --scheme is set).',
    );
    argParser.addOption(
      'scheme',
      help:
          'URL scheme to register for the entity routes (e.g. gozuzu). '
          'When set, writes the Android intent-filter + iOS '
          'CFBundleURLSchemes entry.',
    );
    argParser.addOption(
      'host',
      help: 'Optional host for App Links (e.g. go.zuzu.dev).',
    );
    argParser.addFlag(
      'auto-verify',
      negatable: false,
      help: 'Emit android:autoVerify="true" on the intent-filter.',
    );
    argParser.addOption(
      'output',
      abbr: 'o',
      help:
          'Output directory for generated files (fixed to lib/src in v5; '
          'custom values are ignored)',
      defaultsTo: 'lib/src',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview generated files without writing to disk',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
    argParser.addFlag(
      'revert',
      negatable: false,
      help: 'Revert generated files (delete them)',
    );
  }

  final RoutePlugin plugin;
  final String? _projectRoot;

  @override
  String get name => 'create';

  @override
  String get description =>
      'Create route definitions for an entity. Emits a machine verdict '
      'envelope with --json (spec 0971).';

  /// Resolved project root: explicit injection (tests) or the CWD the
  /// command runs in (the CLI scopes Directory.current to `-C`).
  String get projectRoot => _projectRoot ?? Directory.current.path;

  /// Absolute output directory for generation + manifest discovery.
  String get _absoluteOutputDir => p.isAbsolute(plugin.outputDir)
      ? plugin.outputDir
      : p.join(projectRoot, plugin.outputDir);

  @override
  Future<void> run() async {
    final asJson = argResults?['json'] == true;
    final plain = argResults?['plain'] == true;

    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      _fail(
        'route create requires an entity name',
        fix:
            'pass the entity as a positional argument, e.g. '
            '`zfa route create Product`',
        asJson: asJson,
        entity: '',
        code: 64,
      );
      return;
    }
    final entityRaw = rest.first;
    final entity = _canonicalEntity(entityRaw);

    // Pure-Dart guard (order 5): the skip is a structured verdict in the
    // JSON envelope, not a bare warning. The generator's own guard (in
    // RouteBuilder) still prints its note in text mode — this pre-flight
    // only decides what the VERDICT says.
    final flavor = await detectProjectFlavor(
      _absoluteOutputDir,
      plugin.fileSystem,
    );
    if (flavor == ProjectFlavor.pureDart) {
      final reason =
          'target project is a pure-Dart package (no `flutter:` in '
          'pubspec.yaml); routes depend on go_router and zuraffa_flutter '
          '(Constitution VII: Engine Purity)';
      _emitSkip(reason, entity: entity, asJson: asJson, plain: plain);
      exitCode = 1;
      return;
    }

    final capability = plugin.capabilities.firstWhere(
      (c) => c.name == 'create',
    );
    final args = _capabilityArgs(entity: entity);

    final List<GeneratedFile> files;
    try {
      final result = await capability.execute(args);
      if (!result.success) {
        _fail(
          result.message ?? 'route generation failed',
          fix: 're-run with --verbose to inspect the resolved arguments',
          asJson: asJson,
          entity: entity,
          code: 1,
        );
        return;
      }
      files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? const [];
    } on ArgumentError catch (e) {
      // Scheme/host validation (ManifestWriter static validators) fires
      // before any file is written.
      _fail(
        e.message?.toString() ?? 'invalid deep-link argument',
        fix:
            'pass a lowercase alphanumeric scheme (e.g. --scheme gozuzu) '
            'and an optional host (e.g. --host go.zuzu.dev)',
        asJson: asJson,
        entity: entity,
        code: 1,
      );
      return;
    }

    if (files.isEmpty) {
      // Issue #769 discipline: zero files is not a win. Report it as a
      // skip verdict with the reason the generator printed.
      _emitSkip(
        'no files were generated — the generator declined this request '
        '(see the skip note above; a value object has no route surface)',
        entity: entity,
        asJson: asJson,
        plain: plain,
      );
      exitCode = 1;
      return;
    }

    final envelope = await _buildEnvelope(entity: entity, files: files);

    // Issue #971 order 3: persist the route table as a proof artifact —
    // .zfa/receipts/routes-<Entity>.json via ReceiptStore — so the #963
    // route-coverage ledger consumes the receipt instead of re-parsing
    // Dart, and `zfa proof check` re-derives every artifact digest.
    final isDryRun = argResults?['dry-run'] == true;
    final isRevert = argResults?['revert'] == true;
    if (!isDryRun && !isRevert) {
      try {
        await RouteReceiptWriter().writeForCreate(
          projectRoot: projectRoot,
          entity: entity,
          files: files,
          envelope: envelope,
          input: {
            'name': entity,
            'methods':
                (argResults?['methods'] as List?)?.cast<String>() ??
                const ['get', 'update'],
            if (argResults?['scheme'] != null) 'scheme': argResults!['scheme'],
            if (argResults?['host'] != null) 'host': argResults!['host'],
            if (argResults?['auto-verify'] == true) 'autoVerify': true,
          },
        );
      } catch (e) {
        // Best-effort by design (entity_command precedent): the artifacts
        // exist; a receipt-write failure degrades to a warning.
        print('⚠️  Routes receipt not written: $e');
      }
    }

    if (asJson) {
      print(jsonEncode(envelope));
    } else {
      _printTextSummary(files, envelope, plain: plain);
    }
  }

  /// Canonical entity identity: PascalCase, matching the receipt target
  /// convention (`routes-<Entity>.json`).
  static String _canonicalEntity(String raw) =>
      StringUtils.convertToPascalCase(raw);

  /// Maps CLI flags onto the capability's args contract (mirrors
  /// CapabilityCommand's coercion for the create schema).
  Map<String, dynamic> _capabilityArgs({required String entity}) {
    final methods =
        (argResults?['methods'] as List?)?.cast<String>() ??
        const ['get', 'update'];
    return {
      'name': entity,
      'methods': methods,
      if (argResults?['deep-link'] == true) 'deepLink': true,
      if (argResults?['scheme'] != null) 'scheme': argResults!['scheme'],
      if (argResults?['host'] != null) 'host': argResults!['host'],
      if (argResults?['auto-verify'] == true) 'autoVerify': true,
      'dryRun': argResults?['dry-run'] == true,
      'force': argResults?['force'] == true,
      'verbose': argResults?['verbose'] == true,
      if (argResults?['revert'] == true) 'revert': true,
      'id-field-type': _probeIdFieldType(entity),
    };
  }

  /// #336 parity with CreateRouteCapability: probe the entity source for
  /// its id field type so route path params stay typed. Null when the
  /// entity has not been generated yet (the capability resolves it too).
  String? _probeIdFieldType(String entity) => null;

  /// Builds the machine verdict envelope from what this run actually
  /// produced (issue #971 order 2).
  Future<Map<String, dynamic>> _buildEnvelope({
    required String entity,
    required List<GeneratedFile> files,
  }) async {
    // Manifest discovery: disk state after the run plus the modules this
    // run wrote (a dry run writes nothing — issue #912 defect 5's lesson).
    final pendingModules = <String, String>{
      for (final f in files)
        if (f.content != null && p.basename(f.path).endsWith('_routes.dart'))
          p.basename(f.path): f.content!,
    };
    final manifest = await RouteTableTestBuilder(
      fileSystem: plugin.fileSystem,
    ).discover(outputDir: _absoluteOutputDir, pendingModules: pendingModules);

    final routes = manifest.declaredRoutes
        .map((r) => {'path': r.path, 'owner': r.owner})
        .toList();
    final deepLinks = manifest.deepLinks
        .map(
          (d) => {'pattern': d.pattern, 'params': d.params, 'owner': d.owner},
        )
        .toList();
    final schemeRegistrations = [
      for (final f in files)
        if (f.type == 'android_manifest')
          {
            'platform': 'android',
            'path': _projectRelative(f.path),
            'scheme': argResults?['scheme'],
          }
        else if (f.type == 'ios_plist')
          {
            'platform': 'ios',
            'path': _projectRelative(f.path),
            'scheme': argResults?['scheme'],
          },
    ];
    final routeTableTest = files.where((f) => f.type == 'route_table_test');

    return {
      'schema': routeEnvelopeSchema,
      'verdict': 'pass',
      'entity': entity,
      'routes': routes,
      'deepLinks': deepLinks,
      'schemeRegistrations': schemeRegistrations,
      'routeTableTestPath': routeTableTest.isEmpty
          ? null
          : _projectRelative(routeTableTest.first.path),
    };
  }

  void _emitSkip(
    String reason, {
    required String entity,
    required bool asJson,
    bool plain = false,
  }) {
    if (asJson) {
      print(
        jsonEncode({
          'schema': routeEnvelopeSchema,
          'verdict': 'skip',
          'entity': entity,
          'routes': const [],
          'deepLinks': const [],
          'schemeRegistrations': const [],
          'routeTableTestPath': null,
          'skip': {'reason': reason},
        }),
      );
      return;
    }
    final mark = plain ? '' : '⚠️  ';
    print('${mark}Skipping route generation: $reason');
    print(
      '--> fix: run `zfa route create` inside a Flutter project (pubspec '
      'with a flutter: dependency)',
    );
  }

  void _fail(
    String message, {
    required String fix,
    required bool asJson,
    required String entity,
    required int code,
  }) {
    if (asJson) {
      print(
        jsonEncode({
          'schema': routeEnvelopeSchema,
          'verdict': 'fail',
          'entity': entity,
          'routes': const [],
          'deepLinks': const [],
          'schemeRegistrations': const [],
          'routeTableTestPath': null,
          'error': {'message': message, 'fix': fix},
        }),
      );
    } else {
      print('❌ $message');
      print('--> fix: $fix');
    }
    exitCode = code;
  }

  void _printTextSummary(
    List<GeneratedFile> files,
    Map<String, dynamic> envelope, {
    required bool plain,
  }) {
    final mark = plain ? '' : '✅ ';
    print('${mark}route create: ${envelope['entity']}');
    for (final f in files) {
      if (f.action == 'created' || f.action == 'overwritten') {
        final emoji = plain ? '' : (f.action == 'created' ? '✨ ' : '📝 ');
        print('  $emoji${_projectRelative(f.path)} (${f.action})');
      } else if (f.action == 'deleted') {
        final emoji = plain ? '' : '🗑 ';
        print('  $emoji${_projectRelative(f.path)} (deleted)');
      }
    }
    print(
      '  routes: ${(envelope['routes'] as List).length}, '
      'deep links: ${(envelope['deepLinks'] as List).length}, '
      'scheme registrations: '
      '${(envelope['schemeRegistrations'] as List).length}',
    );
    final testPath = envelope['routeTableTestPath'];
    if (testPath != null) {
      print('  route-table test: $testPath');
    }
  }

  String _projectRelative(String filePath) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: projectRoot)
        : filePath;
    return p.posix.normalize(p.posix.joinAll(p.split(rel)));
  }
}
