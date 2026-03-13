import 'package:flutter_test/flutter_test.dart';
import 'package:args/command_runner.dart';
import 'package:zuraffa/src/commands/capability_command.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';

class MockCapability implements ZuraffaCapability {
  @override
  String get name => 'mock_cap';
  @override
  String get description => 'Mock Description';

  Map<String, dynamic>? lastArgs;

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'useMock': {'type': 'boolean', 'default': false},
      'someOtherField': {'type': 'string'},
    },
    'required': [],
  };

  @override
  JsonSchema get outputSchema => {};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: '1',
    pluginId: 'p1',
    capabilityName: 'c1',
    args: args,
    changes: [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    lastArgs = args;
    return ExecutionResult(success: true, files: []);
  }
}

void main() {
  test(
    'CapabilityCommand parses hyphenated flags correctly into camelCase args',
    () async {
      final capability = MockCapability();
      final command = CapabilityCommand(capability);
      final runner = CommandRunner<void>('test', 'test')..addCommand(command);

      await runner.run(['mock', '--use-mock', '--some-other-field', 'value']);

      expect(capability.lastArgs?['useMock'], isTrue);
      expect(capability.lastArgs?['someOtherField'], equals('value'));
    },
  );
}
