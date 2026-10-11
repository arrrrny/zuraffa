// Issue found live (#1194 mocked-tier migration, zik_zak app): the
// adaptive layout scaffold emitted a REAL newline inside the
// `ValueKey('...')` string — `ValueKey('desktop_layout_\nController')`
// — producing a file the analyzer (and the zorphy build scan over
// lib/) rejects with `Expected to find ','`. The key must be a
// single-line string. Fixed in the emitter (single-line interpolation).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/view/builders/adaptive_layout_scaffold_builder.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_layout_key_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
    'generated adaptive layouts carry no newline inside a string literal',
    () async {
      final context = PluginContext(
        core: CoreConfig(
          name: 'Login',
          projectRoot: tempDir.path,
          outputDir: tempDir.path,
          dryRun: false,
        ),
        discovery: DiscoveryEngine(projectRoot: tempDir.path),
        fileSystem: FileSystem.create(root: tempDir.path),
        data: const {'adaptive-layouts': true, 'platform-shells': true},
      );
      final generated =
          await AdaptiveLayoutScaffoldBuilder(
            outputDir: tempDir.path,
            options: const GeneratorOptions(dryRun: false, force: true),
            fileSystem: FileSystem.create(root: tempDir.path),
          ).generate(
            GeneratorConfig(
              name: 'Login',
              methods: const ['get', 'getList'],
              outputDir: tempDir.path,
            ),
            viewName: 'LoginView',
            domainSnake: 'login',
            controllerName: 'LoginController',
            presenterName: 'LoginPresenter',
            withState: false,
            context: context,
          );

      expect(
        generated,
        isNotEmpty,
        reason:
            'the scaffold produced nothing — the pin would pass '
            'vacuously',
      );
      final offenders = <String>[];
      for (final file in generated) {
        final src = File(file.path).readAsStringSync();
        // A single-quoted string must never span lines: a `'` opened on
        // one line must close on the same line.
        final brokenKey = RegExp(r"ValueKey\('[^']*$", multiLine: true);
        if (brokenKey.hasMatch(src)) {
          offenders.add(file.path);
        }
        // Layout class files use StatelessWidget/Widget/BuildContext —
        // they must import material (found live: the template shipped
        // without it and every generated layout failed analyze). The
        // barrel export files are exempt.
        if (src.contains('class ') && !src.startsWith('export')) {
          expect(
            src,
            contains("import 'package:flutter/material.dart';"),
            reason: file.path,
          );
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'newline inside a string literal = uncompilable '
            'layout: ${offenders.join(', ')}',
      );
    },
  );
}
