import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/datasource_verify_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';
import 'package:zuraffa/src/utils/string_utils.dart';

/// Spec #1131 (order 1) — `zfa datasource verify <Entity>`.
///
/// The gate verifies that the generated datasource INTERFACE matches the
/// ENTITY's field signatures: the entity class must exist and parse, the
/// id-field type the interface wires into UpdateParams/DeleteParams/
/// ToggleParams must be the type the entity actually declares, and every
/// standard CRUD method the interface declares must reference the entity
/// type it serves. Exit 0 on clean; exit 1 with `--> fix:` on drift;
/// `--json` emits the single canonical zuraffa.verdict.v1 envelope (issue #1105).
void main() {
  late Directory tempDir;
  late String originalCwd;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_1131_verify_');
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

  /// Generates the real datasource interface for [entityName] with the
  /// default id-field type (String).
  Future<void> generateDatasource(
    String entityName, {
    List<String> methods = const ['get', 'update', 'delete', 'getList'],
  }) async {
    final plugin = DataSourcePlugin(
      outputDir: '${tempDir.path}/lib/src',
      options: const GeneratorOptions(),
    );
    await plugin.generate(
      GeneratorConfig(
        name: entityName,
        outputDir: '${tempDir.path}/lib/src',
        generateDataSource: true,
        generateRemote: true,
        methods: methods,
        force: true,
      ),
    );
  }

  void writeEntity(String entityName, String source) {
    final snake = StringUtils.camelToSnake(entityName);
    final dir = Directory('${tempDir.path}/lib/src/domain/entities/$snake');
    dir.createSync(recursive: true);
    File('${dir.path}/$snake.dart').writeAsStringSync(source);
  }

  test(
    'clean conformance: interface generated from the entity passes (exit 0)',
    () async {
      writeEntity(
        'Product',
        'class Product {\n'
            '  const Product({required this.id, required this.name});\n'
            '  final String id;\n'
            '  final String name;\n'
            '}\n',
      );
      await generateDatasource('Product');
      final result = await DatasourceVerifyHarness.verify(tempDir.path, [
        'Product',
      ]);
      expect(result.exitCode, 0, reason: result.output);
      expect(result.output, contains('✅'));
    },
  );

  test(
    'id-field type drift: entity id is int, interface wires String → exit 1 + fix line',
    () async {
      writeEntity(
        'Product',
        'class Product {\n'
            '  const Product({required this.id, required this.name});\n'
            '  final int id;\n'
            '  final String name;\n'
            '}\n',
      );
      // Generated with the default idFieldType (String) — drifts from the
      // entity's actual `int id`.
      await generateDatasource('Product');
      final result = await DatasourceVerifyHarness.verify(tempDir.path, [
        'Product',
      ]);
      expect(result.exitCode, 1, reason: result.output);
      expect(result.output, contains('--> fix:'));
      expect(result.output, contains('id'));
    },
  );

  test('missing interface: exit 1 + fix line pointing at create', () async {
    writeEntity('Product', 'class Product {\n  final String id;\n}\n');
    final result = await DatasourceVerifyHarness.verify(tempDir.path, [
      'Product',
    ]);
    expect(result.exitCode, 1);
    expect(result.output, contains('--> fix:'));
    expect(result.output, contains('zfa datasource create Product'));
  });

  test('missing entity source: exit 1 + fix line, never a crash', () async {
    await generateDatasource('Product');
    final result = await DatasourceVerifyHarness.verify(tempDir.path, [
      'Product',
    ]);
    expect(result.exitCode, 1);
    expect(result.output, contains('--> fix:'));
  });

  test(
    'malformed entity source: exit 1 with a finding — never an uncaught exception',
    () async {
      // Syntax-broken entity (missing closing brace) must be REPORTED,
      // not crash the process.
      final snake = StringUtils.camelToSnake('Product');
      final dir = Directory('${tempDir.path}/lib/src/domain/entities/$snake');
      dir.createSync(recursive: true);
      File(
        '${dir.path}/$snake.dart',
      ).writeAsStringSync('class Product {\n  final String id;\n');
      await generateDatasource('Product');
      final result = await DatasourceVerifyHarness.verify(tempDir.path, [
        'Product',
      ]);
      expect(result.exitCode, 1, reason: result.output);
      expect(result.output, contains('--> fix:'));
    },
  );

  test('missing entity argument: usage exit (2), never a crash', () async {
    final result = await DatasourceVerifyHarness.verify(tempDir.path, []);
    expect(result.exitCode, 2);
  });

  test(
    '--json: exactly one canonical zuraffa.verdict.v1 envelope, pass shape',
    () async {
      writeEntity(
        'Product',
        'class Product {\n'
            '  const Product({required this.id, required this.name});\n'
            '  final String id;\n'
            '  final String name;\n'
            '}\n',
      );
      await generateDatasource('Product');
      final result = await DatasourceVerifyHarness.verify(tempDir.path, [
        '--json',
        'Product',
      ]);
      expect(result.exitCode, 0, reason: result.output);
      final envelope = jsonDecode(result.output) as Map<String, dynamic>;
      expect(envelope['schema'], 'zuraffa.verdict.v1');
      expect(envelope['result'], 'ok');
      expect(envelope['exit_class'], 0);
      final data = envelope['data'] as Map;
      expect((data['subject'] as Map)['kind'], 'datasource');
      expect((data['subject'] as Map)['entity'], 'Product');
    },
  );

  test(
    '--json: drift emits fail envelope with structured findings (kind/file/member/fix)',
    () async {
      writeEntity(
        'Product',
        'class Product {\n'
            '  const Product({required this.id, required this.name});\n'
            '  final int id;\n'
            '}\n',
      );
      await generateDatasource('Product');
      final result = await DatasourceVerifyHarness.verify(tempDir.path, [
        '--json',
        'Product',
      ]);
      expect(result.exitCode, 1);
      final envelope = jsonDecode(result.output) as Map<String, dynamic>;
      expect(envelope['schema'], 'zuraffa.verdict.v1');
      expect(envelope['result'], 'error');
      final data = envelope['data'] as Map;
      final findings = (data['findings'] as List).cast<Map<String, dynamic>>();
      expect(findings, isNotEmpty);
      expect(findings.first['kind'], isA<String>());
      expect(findings.first['fix'], isA<String>());
      expect(envelope['drifts'], isA<List>());
    },
  );

  test(
    '--json with a malformed entity: fail envelope, no uncaught exception',
    () async {
      final snake = StringUtils.camelToSnake('Product');
      final dir = Directory('${tempDir.path}/lib/src/domain/entities/$snake');
      dir.createSync(recursive: true);
      File('${dir.path}/$snake.dart').writeAsStringSync('class %%Product');
      await generateDatasource('Product');
      final result = await DatasourceVerifyHarness.verify(tempDir.path, [
        '--json',
        'Product',
      ]);
      expect(result.exitCode, 1);
      final envelope = jsonDecode(result.output) as Map<String, dynamic>;
      expect(envelope['schema'], 'zuraffa.verdict.v1');
      expect(envelope['result'], 'error');
    },
  );

  test('verify is registered as a datasource subcommand', () {
    final plugin = DataSourcePlugin(
      outputDir: '${tempDir.path}/lib/src',
      options: const GeneratorOptions(),
    );
    final cmd = plugin.createCommand();
    expect(cmd.subcommands.containsKey('verify'), isTrue);
  });
}

/// Test harness: runs [DataSourceVerifyCommand] with a hand-parsed
/// ArgResults (the subcommand is dispatched by package:args in production)
/// and captures stdout + the process exit code.
class DatasourceVerifyHarness {
  static Future<({int exitCode, String output})> verify(
    String projectRoot,
    List<String> args,
  ) async {
    final command = _InjectableVerifyCommand(projectRoot: projectRoot)
      ..accept(args);
    final output = <String>[];
    var crashed = false;
    try {
      await runZonedGuarded(
        () => command.run(),
        (error, stack) {
          crashed = true;
          output.add('UNCAUGHT: $error');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => output.add(line),
        ),
      );
    } catch (e) {
      crashed = true;
      output.add('THROWN: $e');
    }
    if (crashed) {
      return (exitCode: -1, output: output.join('\n'));
    }
    return (exitCode: exitCode, output: output.join('\n'));
  }
}

class _InjectableVerifyCommand extends DataSourceVerifyCommand {
  _InjectableVerifyCommand({super.projectRoot});

  ArgResults? injected;

  @override
  ArgResults? get argResults => injected ?? super.argResults;

  void accept(List<String> args) => injected = argParser.parse(args);
}
