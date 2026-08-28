import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import 'package:zuraffa/src/commands/generate_commands_command.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/models/generator_config.dart';

class _MockCapability implements ZuraffaCapability {
  _MockCapability(this.name, this.description);
  @override
  final String name;
  @override
  final String description;

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': <String, dynamic>{},
    'required': <String>[],
  };
  @override
  Map<String, dynamic> get outputSchema => <String, dynamic>{};
  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: '1',
    pluginId: 'p',
    capabilityName: name,
    args: args,
    changes: [],
  );
  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(success: true);
}

class _MockPlugin extends FileGeneratorPlugin {
  _MockPlugin(this.id, this.capabilities);
  @override
  final String id;
  @override
  String get name => id;
  @override
  String get version => '1.0.0';
  @override
  final List<ZuraffaCapability> capabilities;
  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async => [];
}

PluginRegistry _registry() {
  final registry = PluginRegistry();
  registry.register(
    _MockPlugin('repository', [
      _MockCapability('repository', 'Generate repository interface'),
    ]),
  );
  registry.register(
    _MockPlugin('usecase', [
      _MockCapability('usecase', 'Generate usecase'),
      _MockCapability('usecase_method', 'Append a usecase method'),
    ]),
  );
  return registry;
}

CommandRunner<void> _runner(PluginRegistry registry) =>
    CommandRunner<void>('zfa', 'test')
      ..addCommand(GenerateCommandsCommand(registry));

int _countMd(Directory dir) => dir.existsSync()
    ? dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .length
    : 0;

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('gen-cmds-');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('zfa generate-commands no longer reports "Unknown command"', () async {
    final runner = CommandRunner<void>('zfa', 'test')
      ..addCommand(GenerateCommandsCommand(_registry()));
    // Should register without throwing UsageException for an unknown command.
    expect(runner.commands.containsKey('generate-commands'), isTrue);
  });

  test('--dry-run previews files without writing to disk', () async {
    final runner = _runner(_registry());
    await expectLater(
      () =>
          runner.run(['generate-commands', '--output', tmp.path, '--dry-run']),
      prints(
        allOf(
          contains('data/repository.md'),
          contains('domain/usecase.md'),
          contains('domain/usecase_method.md'),
          contains('command_registry.json'),
        ),
      ),
    );
    // Nothing was actually written to disk (only previewed).
    expect(_countMd(tmp), equals(0));
    expect(File('${tmp.path}/command_registry.json').existsSync(), isFalse);
  });

  test(
    'generates one .md per capability + command_registry.json (SC-002)',
    () async {
      final runner = _runner(_registry());
      await runner.run(['generate-commands', '--output', tmp.path]);

      expect(_countMd(tmp), equals(3));
      expect(File('${tmp.path}/data/repository.md').existsSync(), isTrue);
      expect(File('${tmp.path}/domain/usecase.md').existsSync(), isTrue);
      expect(File('${tmp.path}/domain/usecase_method.md').existsSync(), isTrue);
      final registryFile = File('${tmp.path}/command_registry.json');
      expect(registryFile.existsSync(), isTrue);

      final decoded = jsonDecode(registryFile.readAsStringSync()) as Map;
      final commands = (decoded['commands'] as List).cast<Map>();
      expect(commands.length, equals(3));
      // Sorted, stable names.
      expect(commands.first['name'], equals('speckit.zuraffa.repository'));
    },
  );

  test('generated .md files carry consistent frontmatter (SC-005)', () async {
    final runner = _runner(_registry());
    await runner.run(['generate-commands', '--output', tmp.path]);

    final content = File('${tmp.path}/data/repository.md').readAsStringSync();
    expect(content, contains('name: "speckit.zuraffa.repository"'));
    expect(content, contains('category: "data"'));
    expect(content, contains('## Flags'));
    expect(content, contains('| `--dry-run` |'));
  });

  test('is idempotent — re-running does not duplicate files', () async {
    final runner = _runner(_registry());
    await runner.run(['generate-commands', '--output', tmp.path]);
    await runner.run(['generate-commands', '--output', tmp.path]);

    expect(_countMd(tmp), equals(3));
  });
}
