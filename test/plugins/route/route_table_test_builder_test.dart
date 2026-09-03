import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/route/builders/route_builder.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;
  late RoutePlugin plugin;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('route_table_tdd_');
    projectRoot = tempDir.path;
    outputDir = '$projectRoot/lib/src';
    await Directory('$outputDir/routing').create(recursive: true);
    plugin = RoutePlugin(
      outputDir: outputDir,
      projectRoot: projectRoot,
      fileSystem: const DefaultFileSystem(),
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  RouteBuilder routeBuilder({bool dryRun = false}) => RouteBuilder(
    outputDir: outputDir,
    options: GeneratorOptions(dryRun: dryRun, force: true, verbose: false),
  );

  /// Runs the deep-link capability and returns the generated files.
  Future<List<GeneratedFile>> runDeepLink({
    String name = 'ScanBarcode',
    String path = '/scan/barcode/:barcode',
    String scheme = 'gozuzu',
  }) async {
    final capability = plugin.capabilities.firstWhere(
      (c) => c.name == 'deep-link',
    );
    final result = await capability.execute({
      'name': name,
      'path': path,
      'scheme': scheme,
      'dryRun': false,
      'force': true,
      'verbose': false,
    });
    expect(result.success, isTrue);
    return (result.data?['generatedFiles'] as List?)?.cast<GeneratedFile>() ??
        <GeneratedFile>[];
  }

  /// Runs the shell capability and returns the generated files.
  Future<List<GeneratedFile>> runShell({
    required bool adaptive,
    List<String> branches = const ['Home:/home', 'Profile:/profile'],
  }) async {
    final capability = plugin.capabilities.firstWhere((c) => c.name == 'shell');
    final result = await capability.execute({
      'name': 'Main',
      'branch': branches,
      'bottomNav': true,
      'adaptive': adaptive,
      'dryRun': false,
      'force': true,
      'verbose': false,
    });
    expect(result.success, isTrue);
    return (result.data?['generatedFiles'] as List?)?.cast<GeneratedFile>() ??
        <GeneratedFile>[];
  }

  group('#842 route-table test emission (zfa make --route / zfa route)', () {
    test(
      'RouteBuilder.generate emits a route-table test alongside routes',
      () async {
        final files = await routeBuilder().generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'create', 'getList'],
            generateRoute: true,
            outputDir: outputDir,
          ),
        );

        final testFiles = files
            .where((f) => f.path.endsWith('test/routing/route_table_test.dart'))
            .toList();
        expect(
          testFiles,
          hasLength(1),
          reason:
              'zfa make --route must emit a route-table test alongside the '
              'route modules (closes the "routes with no TDD surface" gap)',
        );
        expect(testFiles.first.type, equals('route_table_test'));
        expect(
          File(testFiles.first.path).existsSync(),
          isTrue,
          reason: 'the route-table test must be written to disk',
        );
      },
    );

    test('emitted route-table test parses cleanly', () async {
      final files = await routeBuilder().generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get', 'create'],
          generateRoute: true,
          outputDir: outputDir,
        ),
      );

      final testFile = files
          .firstWhere((f) => f.path.endsWith('route_table_test.dart'))
          .path;
      final errors = syntaxErrors(File(testFile).readAsStringSync());
      expect(
        errors,
        isEmpty,
        reason:
            'generated route-table test must parse cleanly; got: '
            '${errors.map((e) => e.message).join(', ')}',
      );
    });

    test('emitted test embeds the declared route manifest as data', () async {
      final files = await routeBuilder().generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get', 'create', 'getList'],
          generateRoute: true,
          outputDir: outputDir,
        ),
      );

      final testFile = files
          .firstWhere((f) => f.path.endsWith('route_table_test.dart'))
          .path;
      final content = File(testFile).readAsStringSync();

      // Manifest as data — every declared constant path is embedded.
      expect(content.contains("'/product'"), isTrue);
      expect(content.contains("'/product/create'"), isTrue);
      // Resolution sweep drives the REAL aggregator, not a re-declaration.
      expect(content.contains('getAllRoutes'), isTrue);
      // Unknown paths must hit the 404 handler — the sweep includes a
      // declared unknown literal.
      expect(content.contains('/__zfa_unknown_404__'), isTrue);
      // go_router public API surface (deterministic, no platform channel).
      expect(content.contains('onException'), isTrue);
      expect(content.contains('routeInformationProvider'), isTrue);
    });

    test('emitted test proves deep-link patterns parse typed params', () async {
      // A deep-link module on disk must be picked up by the next
      // route-table regeneration (the manifest is refreshed on every
      // route run).
      await runDeepLink();

      final files = await routeBuilder().generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          generateRoute: true,
          outputDir: outputDir,
        ),
      );

      final testFile = files
          .firstWhere((f) => f.path.endsWith('route_table_test.dart'))
          .path;
      final content = File(testFile).readAsStringSync();

      // Deep-link pattern + typed params from URI fixtures.
      expect(content.contains('/scan/barcode/:barcode'), isTrue);
      expect(content.contains('pathParameters'), isTrue);
      // Barcode path fixture + URL-encoded fixture (issue #842's examples).
      expect(content.contains('/scan/barcode/123456'), isTrue);
      expect(
        content.contains(RegExp('9%3A30|a%20b')),
        isTrue,
        reason: 'a URL-encoded deep-link fixture must be generated',
      );
    });

    test('dry run reports the route-table test without writing it '
        '(issue #912 defect 5)', () async {
      final files = await routeBuilder(dryRun: true).generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          generateRoute: true,
          outputDir: outputDir,
          dryRun: true,
        ),
      );

      // The dry-run changes list must CARRY the route-table test the real
      // run emits (issue #912 defect 5: a dry-run that omits it reports a
      // different change set than the real run).
      expect(files.where((f) => f.type == 'route_table_test'), hasLength(1));
      // ... and a dry run still writes nothing.
      expect(
        File('$projectRoot/test/routing/route_table_test.dart').existsSync(),
        isFalse,
      );
    });
  });

  group('#842 deep-link route-table test (routeInformationProvider)', () {
    test('deep-link capability emits a dedicated URI-fixture test', () async {
      final files = await runDeepLink();

      final testFiles = files
          .where((f) => f.path.endsWith('scan_barcode_deep_link_test.dart'))
          .toList();
      expect(
        testFiles,
        hasLength(1),
        reason:
            'zfa route deep-link must emit a test driving '
            'routeInformationProvider with URI fixtures',
      );
      expect(testFiles.first.type, equals('deep_link_route_table_test'));

      final content = File(testFiles.first.path).readAsStringSync();
      expect(content.contains('routeInformationProvider'), isTrue);
      expect(content.contains('pathParameters'), isTrue);
      expect(content.contains('/scan/barcode/123456'), isTrue);
      // URL-encoded query fixture.
      expect(content.contains(RegExp('9%3A30|a%20b')), isTrue);
      // Destination + 404 discrimination.
      expect(content.contains('getAllRoutes'), isTrue);

      final errors = syntaxErrors(content);
      expect(
        errors,
        isEmpty,
        reason:
            'generated deep-link test must parse cleanly; got: '
            '${errors.map((e) => e.message).join(', ')}',
      );
    });
  });

  group('#842 platform-divergence test (adaptive layout manifest)', () {
    test('adaptive shell capability emits a layout matrix test', () async {
      final files = await runShell(adaptive: true);

      final testFiles = files
          .where((f) => f.path.endsWith('main_shell_layout_test.dart'))
          .toList();
      expect(
        testFiles,
        hasLength(1),
        reason:
            'zfa route shell --adaptive must emit a platform-divergence '
            'test (macOS sidebar vs mobile bottom nav)',
      );
      expect(testFiles.first.type, equals('shell_layout_test'));

      final content = File(testFiles.first.path).readAsStringSync();

      // Adaptive layout manifest as data: target -> nav widget matrix.
      expect(content.contains('NavigationRail'), isTrue);
      expect(content.contains('NavigationBar'), isTrue);
      // Widget-level presence checks.
      expect(content.contains('find.byType'), isTrue);
      // Deterministic surface forcing (no platform channel).
      expect(content.contains('physicalSize'), isTrue);

      final errors = syntaxErrors(content);
      expect(
        errors,
        isEmpty,
        reason:
            'generated shell layout test must parse cleanly; got: '
            '${errors.map((e) => e.message).join(', ')}',
      );
    });

    test('non-adaptive shell emits no layout matrix test', () async {
      final files = await runShell(adaptive: false);

      expect(files.where((f) => f.type == 'shell_layout_test'), isEmpty);
    });
  });
}

/// Returns the syntax (parse) diagnostics from [source]. A syntactically
/// valid file yields an empty list.
List<Diagnostic> syntaxErrors(String source) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  return result.errors.cast<Diagnostic>();
}
