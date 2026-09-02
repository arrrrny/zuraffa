import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/capability_command.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';

/// Regression tests for issue #773: `zfa sync enable --name Auth` crashed with
/// `type 'String' is not a subtype of type 'int'` because CapabilityCommand
/// passed schema-typed (`integer`) values through as raw Strings — option
/// defaults are registered as `def?.toString()` and CLI flags always arrive
/// as strings, and nothing coerced them to the schema-declared type.
class _IntSchemaCapability implements ZuraffaCapability {
  Map<String, dynamic>? lastArgs;

  @override
  String get name => 'enable';

  @override
  String get description => 'Mirrors CreateSyncCapability input schema';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'direction': {'type': 'string', 'default': 'push'},
      'batchSize': {'type': 'integer', 'default': 50},
      'maxRetries': {'type': 'integer', 'default': 5},
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => {};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: '1',
    pluginId: 'p1',
    capabilityName: name,
    args: args,
    changes: [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    lastArgs = args;
    return ExecutionResult(success: true, files: []);
  }
}

CapabilityCommand _command(_IntSchemaCapability capability) {
  final command = CapabilityCommand(capability);
  return command;
}

void main() {
  test('explicit integer flag arrives as int, not String', () async {
    final capability = _IntSchemaCapability();
    final runner = CommandRunner<void>('test', 'test')
      ..addCommand(_command(capability));

    await runner.run(['enable', 'Auth', '--batch-size', '30']);

    expect(capability.lastArgs?['batchSize'], isA<int>());
    expect(capability.lastArgs?['batchSize'], equals(30));
  });

  test(
    'integer schema defaults arrive as int even with no flags (#773)',
    () async {
      final capability = _IntSchemaCapability();
      final runner = CommandRunner<void>('test', 'test')
        ..addCommand(_command(capability));

      await runner.run(['enable', 'Auth']);

      expect(capability.lastArgs?['batchSize'], isA<int>());
      expect(capability.lastArgs?['batchSize'], equals(50));
      expect(capability.lastArgs?['maxRetries'], isA<int>());
      expect(capability.lastArgs?['maxRetries'], equals(5));
    },
  );

  test('string-typed properties stay String (no over-coercion)', () async {
    final capability = _IntSchemaCapability();
    final runner = CommandRunner<void>('test', 'test')
      ..addCommand(_command(capability));

    await runner.run(['enable', 'Auth']);

    expect(capability.lastArgs?['direction'], equals('push'));
    expect(capability.lastArgs?['direction'], isA<String>());
    expect(capability.lastArgs?['name'], equals('Auth'));
  });

  test(
    'unparseable integer input passes through unchanged (no new contract)',
    () async {
      final capability = _IntSchemaCapability();
      final runner = CommandRunner<void>('test', 'test')
        ..addCommand(_command(capability));

      await runner.run(['enable', 'Auth', '--batch-size', 'lots']);

      expect(capability.lastArgs?['batchSize'], equals('lots'));
    },
  );
}