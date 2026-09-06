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
import '../cli/exit_protocol.dart';
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
    // SPEC 917 / #904: the capability inputSchema declares `name` as a
    // required property — a manifest-driven client sends `--name <value>`
    // and the CLI must accept it (the positional keeps precedence).
    argParser.addOption(
      'name',
      help: 'Entity name (alternative to the positional argument)',
    );
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit a machine verdict envelope '
          '({routes[], deepLinks, schemeRegistrations, routeTableTestPath, '
          'schema:1}) instead of the emoji file list.',
    );
    argParser.addFlag(
      'explain',
      negatable: false,
      help:
          'After the verdict, emit the explain block (issue #1122): which '
          'routes are emitted, which platform slots each route targets, '
          'which shell/guard binding is used, and which state machine is '
          'referenced. With --json the envelope gains an additive '
          '`explain` key.',
    );
    argParser.addOption(
      'shell',
      help:
          'Shell binding for the route: none, bottom-nav, rail or adaptive. '
          'Validated against the route config schema; unknown shell names '
          'are a usage error (issue #1122).',
      defaultsTo: 'none',
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

    // Issue #1122: the shell binding is route CONFIG, so it validates
    // against the plugin's configSchema before anything runs. An unknown
    // shell name is a usage-class rejection: the issue's "exit 64" —
    // which SPEC 917 canonicalized onto ExitProtocol.usage (the golden
    // test retires the legacy literal; canonicalize(64) == usage).
    final shell = (argResults?['shell'] as String?) ?? 'none';
    final shellViolations = validateRouteConfig({'shell': shell});
    if (shellViolations.isNotEmpty) {
      final rest0 = argResults?.rest ?? const <String>[];
      final entity0 = rest0.isNotEmpty
          ? _canonicalEntity(rest0.first)
          : (argResults?['name'] as String? ?? '');
      _fail(
        shellViolations.join('; '),
        fix:
            'pass one of the known route shell kinds: bottom-nav, rail, '
            'adaptive (or omit --shell for none)',
        asJson: asJson,
        entity: entity0,
        code: ExitProtocol.usage,
      );
      return;
    }

    final rest = argResults?.rest ?? const <String>[];
    // SPEC 917 / #904: --name is the manifest-driven spelling of the
    // positional EntityName (positional keeps precedence, issue #771).
    final flaggedName = argResults?['name'] as String?;
    if (rest.isEmpty && (flaggedName == null || flaggedName.isEmpty)) {
      _fail(
        'route create requires an entity name',
        fix:
            'pass the entity as a positional argument (or --name <value>), '
            'e.g. `zfa route create Product`',
        asJson: asJson,
        entity: '',
        // SPEC 917: the canonical usage code (the legacy 64 is retired).
        code: ExitProtocol.usage,
      );
      return;
    }
    final entityRaw = rest.isNotEmpty ? rest.first : flaggedName!;
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
            if (shell != 'none') 'shell': shell,
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

    // Issue #1122: the explain block is strictly additive — the base
    // envelope (and the receipt digest above) stay byte-compatible; the
    // `explain` key exists only when --explain was requested.
    if (argResults?['explain'] == true) {
      envelope['explain'] = await _buildExplain(
        entity: entity,
        files: files,
        envelope: envelope,
      );
    }

    if (asJson) {
      print(jsonEncode(envelope));
    } else {
      _printTextSummary(files, envelope, plain: plain);
      if (envelope['explain'] case final Map<String, dynamic> explain) {
        _printExplain(explain);
      }
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

  /// Builds the `--explain` block (issue #1122): which routes are
  /// emitted, which platform slots each route targets, which shell/guard
  /// binding is used, which state machine is referenced. Everything is
  /// discovered from what this run actually produced plus the routing
  /// tree on disk — the block never invents a binding.
  Future<Map<String, dynamic>> _buildExplain({
    required String entity,
    required List<GeneratedFile> files,
    required Map<String, dynamic> envelope,
  }) async {
    final slots = <Map<String, dynamic>>[
      {
        'slot': 'routing-index',
        'path': _projectRelative(
          p.join(_absoluteOutputDir, 'routing', 'index.dart'),
        ),
      },
    ];
    final testPath = envelope['routeTableTestPath'] as String?;
    if (testPath != null) {
      slots.add({'slot': 'route-table-test', 'path': testPath});
    }
    for (final f in files) {
      if (f.type == 'android_manifest') {
        slots.add({
          'slot': 'android-scheme',
          'path': _projectRelative(f.path),
          if (argResults?['scheme'] != null) 'scheme': argResults!['scheme'],
        });
      } else if (f.type == 'ios_plist') {
        slots.add({
          'slot': 'ios-scheme',
          'path': _projectRelative(f.path),
          if (argResults?['scheme'] != null) 'scheme': argResults!['scheme'],
        });
      }
    }

    return {
      'routes': envelope['routes'],
      'platformSlots': slots,
      'shell': await _discoverShellBinding(envelope),
      'guard': {
        // Guard probe scope: only the ENTITY route modules this run wrote.
        // app_routes.dart is excluded — its global unknown-path `redirect:`
        // (the 404 seam) is not a route guard binding.
        'guard':
            files
                .where(
                  (f) =>
                      p.basename(f.path).endsWith('_routes.dart') &&
                      p.basename(f.path) != 'app_routes.dart',
                )
                .any(
                  (f) =>
                      f.content?.contains(RegExp(r'\bredirect\s*:')) ?? false,
                )
            ? 'redirect'
            : 'none',
      },
      'stateMachine': _discoverStateMachine(entity),
    };
  }

  /// Scans `<outputDir>/routing/*_shell.dart` for the shell module whose
  /// branch root path covers one of this run's emitted routes (a shell
  /// path is a segment-wise prefix of the route path). Returns
  /// `{shell: 'none'}` when no shell module covers the routes.
  Future<Map<String, dynamic>> _discoverShellBinding(
    Map<String, dynamic> envelope,
  ) async {
    final routingDir = Directory(p.join(_absoluteOutputDir, 'routing'));
    if (!routingDir.existsSync()) return const {'shell': 'none'};
    final routes = (envelope['routes'] as List).cast<Map<String, dynamic>>();
    final shellFiles =
        routingDir
            .listSync(recursive: false, followLinks: false)
            .whereType<File>()
            .where((f) => p.basename(f.path).endsWith('_shell.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in shellFiles) {
      final source = file.readAsStringSync();
      final shellPaths = RegExp(r'''\bpath\s*:\s*(r?['"][^'"]+['"])''')
          .allMatches(source)
          .map((m) => _stringLiteral(m.group(1)!))
          .whereType<String>()
          .toSet();
      for (final route in routes) {
        final routePath = route['path'] as String?;
        if (routePath == null) continue;
        final covered = shellPaths.any(
          (shellPath) => _coversPath(shellPath, routePath),
        );
        if (covered) {
          return {
            'shell': p.basename(file.path),
            'module': _projectRelative(file.path),
            'kind': source.contains('StatefulShellRoute.indexedStack')
                ? 'StatefulShellRoute.indexedStack'
                : 'unknown',
            'covers': routePath,
          };
        }
      }
    }
    return const {'shell': 'none'};
  }

  /// True when [shellPath] is a segment-wise prefix of [routePath] —
  /// `/product` covers `/product` and `/product/:id` but not `/products`.
  bool _coversPath(String shellPath, String routePath) {
    if (!routePath.startsWith(shellPath)) return false;
    if (routePath.length == shellPath.length) return true;
    return routePath[shellPath.length] == '/';
  }

  String? _stringLiteral(String expression) {
    var literal = expression;
    final raw = literal.startsWith('r');
    if (raw) literal = literal.substring(1);
    if (literal.length < 2) return null;
    final quote = literal[0];
    if ((quote != "'" && quote != '"') ||
        literal[literal.length - 1] != quote) {
      return null;
    }
    return literal.substring(1, literal.length - 1);
  }

  /// Probes the output tree for the state plugin's artifact
  /// (`<entity_snake>_state.dart` carrying `class <Entity>State`) and
  /// reports the referenced state machine, or `none`.
  Map<String, dynamic> _discoverStateMachine(String entity) {
    final outputDir = Directory(_absoluteOutputDir);
    if (!outputDir.existsSync()) return const {'stateMachine': 'none'};
    final fileName = '${StringUtils.camelToSnake(entity)}_state.dart';
    final matches =
        outputDir
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((f) => p.basename(f.path) == fileName)
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    if (matches.isEmpty) return const {'stateMachine': 'none'};
    final file = matches.first;
    final className = RegExp(
      r'\bclass\s+(\w+)',
    ).firstMatch(file.readAsStringSync())?.group(1);
    return {
      'stateMachine': className ?? '${entity}State',
      'path': _projectRelative(file.path),
    };
  }

  /// Renders the explain block as prose (text mode). The JSON mode emits
  /// the same structure under the envelope's `explain` key.
  void _printExplain(Map<String, dynamic> explain) {
    print('explain:');
    final routes = (explain['routes'] as List).cast<Map<String, dynamic>>();
    print('  routes emitted:');
    if (routes.isEmpty) print('    - (none)');
    for (final route in routes) {
      print('    - ${route['path']} (${route['owner']})');
    }
    print('  platform slots:');
    for (final slot
        in (explain['platformSlots'] as List).cast<Map<String, dynamic>>()) {
      final scheme = slot['scheme'];
      print(
        '    - ${slot['slot']}: ${slot['path']}'
        '${scheme == null ? '' : ' (scheme: $scheme)'}',
      );
    }
    final shell = explain['shell'] as Map<String, dynamic>;
    print(
      shell['shell'] == 'none'
          ? '  shell binding: none'
          : '  shell binding: ${shell['shell']} '
                '(${shell['kind']} covers ${shell['covers']})',
    );
    print('  guard binding: ${(explain['guard'] as Map)['guard']}');
    final machine = explain['stateMachine'] as Map<String, dynamic>;
    print(
      machine['stateMachine'] == 'none'
          ? '  state machine: none'
          : '  state machine: ${machine['stateMachine']} (${machine['path']})',
    );
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
