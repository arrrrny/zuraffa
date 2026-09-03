// Bug #912 defect 5 — `route create --dry-run` must report the
// route-table test in its changes list.
//
// The real run emits `test/routing/route_table_test.dart` (#842), but the
// dry-run computes the manifest from DISK, where the planned
// `<name>_routes.dart` does not exist yet — on a fresh project the
// manifest is empty and the route-table test silently vanishes from the
// changes list. The dry-run must discover the manifest from the PENDING
// route modules (the content this very run would write) and report the
// route-table test as a planned change — while still writing nothing.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/route/builders/route_builder.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;
  late RoutePlugin plugin;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bug912_route_dry_');
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

  group('bug 912 defect 5: dry-run reports the route-table test', () {
    test('RouteBuilder dry-run lists the route-table test as a planned '
        'change', () async {
      final files =
          await RouteBuilder(
            outputDir: outputDir,
            options: const GeneratorOptions(dryRun: true, force: true),
          ).generate(
            GeneratorConfig(
              name: 'Product',
              methods: const ['get'],
              generateRoute: true,
              outputDir: outputDir,
              dryRun: true,
            ),
          );

      final planned = files.where((f) => f.type == 'route_table_test').toList();
      expect(
        planned,
        hasLength(1),
        reason:
            'issue #912 defect 5: the dry-run changes list must include '
            'the route-table test the real run emits',
      );
      // ... and dry-run still writes nothing.
      expect(
        File('$projectRoot/test/routing/route_table_test.dart').existsSync(),
        isFalse,
        reason: 'a dry run must not write the route-table test',
      );
    });

    test('route create --dry-run (capability plan) includes the route-table '
        'test in its changes', () async {
      final report = await plugin.capabilities
          .firstWhere((c) => c.name == 'create')
          .plan({
            'name': 'Product',
            'methods': ['get'],
            'dryRun': true,
            'force': true,
            'verbose': false,
          });

      expect(
        report.changes.any((e) => e.file.endsWith('route_table_test.dart')),
        isTrue,
        reason:
            'the plan (dry-run) changes list must carry the route-table '
            'test the real run generates',
      );
      expect(
        File('$projectRoot/test/routing/route_table_test.dart').existsSync(),
        isFalse,
      );
    });

    test('the planned route-table test embeds the same manifest the real '
        'run writes', () async {
      final dryFiles =
          await RouteBuilder(
            outputDir: outputDir,
            options: const GeneratorOptions(dryRun: true, force: true),
          ).generate(
            GeneratorConfig(
              name: 'Product',
              methods: const ['get', 'create'],
              generateRoute: true,
              outputDir: outputDir,
              dryRun: true,
            ),
          );
      final dryContent = dryFiles
          .firstWhere((f) => f.type == 'route_table_test')
          .content!;
      // The manifest as data, discovered from the PENDING route modules.
      expect(dryContent.contains("'/product'"), isTrue);
      expect(dryContent.contains("'/product/create'"), isTrue);
    });
  });
}
