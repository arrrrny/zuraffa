import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/capability_command.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/models/generated_file.dart';

/// Spec 0996 (issue #996) — the thin hook: `CapabilityCommand.run()`
/// executes the capability through the [CapabilityInvocationWrapper] so
/// every successful standalone invocation ships a receipt.
///
/// Fast tier: a writing capability stub + an injected project root; the
/// real 12-capability end-to-end matrix lives in
/// `test/commands/capability_receipt_test.dart` (slow tier).
void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_996_hook_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: hook_fixture
environment:
  sdk: ^3.11.0
''');
  });

  tearDown(() {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  test('zfa <plugin> create <Entity> via CapabilityCommand persists a '
      'receipt for the run (issue #996)', () async {
    final capability = _WritingCapability(projectRoot: workspace.path);
    final command = CapabilityCommand(
      capability,
      pluginId: 'di',
      projectRoot: workspace.path,
    );
    final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

    await runner.run(['create', 'Product']);

    final store = ReceiptStore(projectRoot: workspace.path);
    final records = await store.loadAll();
    expect(records, hasLength(1), reason: 'exactly one capability receipt');
    final receipt = records.single.receipt;
    expect(receipt.plugin, 'di');
    expect(receipt.capability, 'create');
    expect(receipt.entity, 'Product');
    expect(receipt.command, 'di create');
    expect(receipt.files, hasLength(1));
    expect(receipt.files.single.path, 'lib/src/domain/product_di.dart');

    // The stored document is machine-readable (issue #996 schema).
    final raw =
        jsonDecode(
              Directory(
                p.join(workspace.path, '.zfa', 'receipts'),
              ).listSync().whereType<File>().single.readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(raw['plugin'], 'di');
    expect(raw['capability'], 'create');
    expect(raw['entity'], 'Product');
    expect(raw['receipt_version'], 1);
  });

  test('pluginId falls back to the parent command name '
      '(PluginCommand registers plugin.id)', () async {
    final capability = _WritingCapability(projectRoot: workspace.path);
    final command = CapabilityCommand(capability, projectRoot: workspace.path);
    final parent = _NamedParent('repository');
    parent.addSubcommand(command);
    final runner = CommandRunner<void>('zfa', 'test')..addCommand(parent);

    await runner.run(['repository', 'create', 'Product']);

    final records = await ReceiptStore(projectRoot: workspace.path).loadAll();
    expect(records.single.receipt.plugin, 'repository');
  });

  test('a failed capability run writes no receipt and exits 1 '
      '(issue #767 protocol intact)', () async {
    final capability = _FailingCapability();
    final command = CapabilityCommand(
      capability,
      pluginId: 'di',
      projectRoot: workspace.path,
    );
    final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

    await runner.run(['create', 'Product']);

    expect(exitCode, 1);
    expect(
      Directory(p.join(workspace.path, '.zfa', 'receipts')).existsSync(),
      isFalse,
    );
  });
}

/// A parent command whose name emulates a PluginCommand (name ==
/// plugin.id) so the fallback chain is observable.
class _NamedParent extends Command<void> {
  _NamedParent(this._name);

  final String _name;

  @override
  String get name => _name;

  @override
  String get description => 'parent';
}

/// Writes the artifact for real (receipts bind final on-disk bytes).
class _WritingCapability implements ZuraffaCapability {
  _WritingCapability({required this.projectRoot});

  final String projectRoot;

  @override
  String get name => 'create';

  @override
  String get description => 'writing stub';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => const {};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: 'plan',
    pluginId: 'di',
    capabilityName: name,
    args: args,
    changes: [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final artifact = File(
      p.join(projectRoot, 'lib', 'src', 'domain', 'product_di.dart'),
    );
    await artifact.parent.create(recursive: true);
    await artifact.writeAsString('// di wiring for Product\n');
    return ExecutionResult(
      success: true,
      files: ['lib/src/domain/product_di.dart'],
      data: {
        'generatedFiles': [
          GeneratedFile(
            path: 'lib/src/domain/product_di.dart',
            type: 'di',
            action: 'created',
          ),
        ],
      },
    );
  }
}

class _FailingCapability implements ZuraffaCapability {
  @override
  String get name => 'create';

  @override
  String get description => 'failing stub';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => const {};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: 'plan',
    pluginId: 'di',
    capabilityName: name,
    args: args,
    changes: [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(success: false, message: 'declined');
}
