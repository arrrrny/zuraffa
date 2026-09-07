import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/capabilities/create_datasource_capability.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';

/// Spec #1131 (order 4) — the full generate() path is wrapped in
/// try/catch and every exception becomes
/// `ExecutionResult(success: false, ...)` — a malformed request or a
/// throwing generator is an HONEST failure with a message, never an
/// uncaught exception that crashes the process.
void main() {
  late Directory tempDir;
  late String originalCwd;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_1131_errors_');
    originalCwd = Directory.current.path;
    Directory.current = tempDir.path;
  });

  tearDown(() async {
    Directory.current = originalCwd;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    exitCode = 0;
  });

  test(
    'missing required name: execute returns success:false, does not throw',
    () async {
      final plugin = DataSourcePlugin(
        outputDir: '${tempDir.path}/lib/src',
        options: const GeneratorOptions(),
      );
      final capability = CreateDataSourceCapability(plugin);

      // `name` is absent — the config build must not leak a TypeError out
      // of execute(); the failure is reported with a reason instead.
      final result = await capability.execute({});
      expect(result.success, isFalse);
      expect(result.message, isNotNull);
    },
  );

  test(
    'type-hostile args (methods as String): execute returns success:false, does not throw',
    () async {
      final plugin = DataSourcePlugin(
        outputDir: '${tempDir.path}/lib/src',
        options: const GeneratorOptions(),
      );
      final capability = CreateDataSourceCapability(plugin);

      // `--json '{"methods": "get,update"}'` hands the capability a String
      // where a List is declared — the cast must not escape execute().
      final result = await capability.execute({
        'name': 'Product',
        'methods': 'get,update',
      });
      expect(result.success, isFalse, reason: result.message);
      expect(result.message, isNotNull);
    },
  );

  test(
    'a throwing generator: execute catches and returns success:false with the reason',
    () async {
      final plugin = _ThrowingDataSourcePlugin(
        outputDir: '${tempDir.path}/lib/src',
      );
      final capability = CreateDataSourceCapability(plugin);

      final result = await capability.execute({'name': 'Product'});
      expect(result.success, isFalse);
      expect(result.message, contains('boom'));
      expect(result.files, isEmpty);
    },
  );

  test(
    'plan() with hostile args: returns an invalid EffectReport, does not throw',
    () async {
      final plugin = DataSourcePlugin(
        outputDir: '${tempDir.path}/lib/src',
        options: const GeneratorOptions(),
      );
      final capability = CreateDataSourceCapability(plugin);

      final report = await capability.plan({'methods': 'get'});
      expect(report.isValid, isFalse);
      expect(report.message, isNotNull);
      expect(report.changes, isEmpty);
    },
  );

  test(
    'a malformed entity on disk does not crash capability execution',
    () async {
      // The generators only probe the entity file for imports; a
      // syntax-broken entity must not escape an uncaught parse failure.
      final snakeDir = Directory(
        '${tempDir.path}/lib/src/domain/entities/product',
      );
      snakeDir.createSync(recursive: true);
      File(
        '${snakeDir.path}/product.dart',
      ).writeAsStringSync('class Product { final String');

      final plugin = DataSourcePlugin(
        outputDir: '${tempDir.path}/lib/src',
        options: const GeneratorOptions(),
      );
      final capability = CreateDataSourceCapability(plugin);

      final result = await capability.execute({
        'name': 'Product',
        'remote': true,
        'force': true,
      });
      // Either the generation honestly fails (success:false + reason) or
      // succeeds — but it must not THROW.
      // (success itself is not asserted: generation semantics unchanged.)
      // ignore: avoid_dynamic_calls
      expect(result, isA<ExecutionResult>());
    },
  );
}

/// A plugin whose generate() always throws — simulates any internal
/// generator crash (filesystem, template, AST engine).
class _ThrowingDataSourcePlugin extends DataSourcePlugin {
  _ThrowingDataSourcePlugin({required super.outputDir});

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    throw StateError('boom: generator exploded');
  }
}
