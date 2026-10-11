import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

/// Issue #978, order 1 — kill the legacy silent no-op.
///
/// `ServicePlugin.generate` historically returned `[]` without a trace when
/// no service name was resolvable (the `serviceSnake == null` path), and the
/// backward-compat guard above it (93-99) was dead code. An empty success is
/// the #769 anti-pattern family: automation reads a declined generation as a
/// win.
///
/// The contract after this spec:
///   FR-1: the decline prints a skip NOTE naming the reason (never silent).
///   FR-2: the note ends with a machine-actionable `--> fix:` line naming
///         the invocation that would produce a service artifact.
///   FR-3: the returned list stays empty so the CLI zero-file guard
///         (CapabilityCommand, issue #769) exits 1 — a skip is never dressed
///         up as success at any layer.
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_service_skip_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  ServicePlugin plugin() => ServicePlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: false),
  );

  group('issue #978 — legacy silent no-op becomes a structured skip', () {
    test('FR-1/FR-2: generate() with no resolvable service name logs the skip '
        'reason and a --> fix: hint (never silent)', () async {
      // The legacy shape: an entity-flavored config with NO service name
      // and NO useService flag. Before #978 this returned [] with zero
      // output — the silent empty success.
      final config = GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateService: false,
        outputDir: outputDir,
      );

      await expectLater(
        () => plugin().generate(config),
        prints(
          allOf(
            contains('Skipping service generation'),
            contains('service name'),
            contains('--> fix:'),
            contains('zfa service create --name'),
          ),
        ),
      );
    });

    test('FR-3: the declined request still returns an empty file list so the '
        'CLI #769 zero-file guard stays armed', () async {
      final config = GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateService: false,
        outputDir: outputDir,
      );

      final files = await plugin().generate(config);

      expect(files, isEmpty);
      // And nothing was written — a skip must not leave artifacts behind.
      expect(
        File('$outputDir/domain/services/product_service.dart').existsSync(),
        isFalse,
      );
    });

    test(
      'generateWithContext with no service in context data hits the same '
      'structured skip (make path: service plugin active, no --service value)',
      () async {
        // Mimic PluginManager.buildContext for `zfa make Product service`
        // (positional, no --service value): the activation sync writes
        // `data['__active_service'] = true` (#412) and the string-typed
        // `service` slot stays absent.
        final context = PluginContext(
          core: CoreConfig(
            name: 'Product',
            projectRoot: tempDir.path,
            outputDir: outputDir,
          ),
          discovery: DiscoveryEngine(projectRoot: tempDir.path),
          data: <String, dynamic>{'__active_service': true},
        );

        await expectLater(
          () => plugin().generateWithContext(context),
          prints(
            allOf(
              contains('Skipping service generation'),
              contains('--> fix:'),
            ),
          ),
        );
      },
    );

    test('generate() with a resolvable service name still generates (no '
        'regression: the skip only replaces the silent decline)', () async {
      final config = GeneratorConfig(
        name: 'SendEmail',
        methods: const [],
        service: 'Email',
        paramsType: 'EmailParams',
        returnsType: 'SendResult',
        outputDir: outputDir,
      );

      final files = await plugin().generate(config);

      expect(files, hasLength(1));
      expect(files.first.action, 'created');
      expect(
        File('$outputDir/domain/services/email_service.dart').existsSync(),
        isTrue,
      );
    });
  });
}
