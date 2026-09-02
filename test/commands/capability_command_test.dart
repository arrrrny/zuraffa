@Tags(['slow'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import 'package:zuraffa/src/commands/capability_command.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/models/generated_file.dart';

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

  test(
    'CapabilityCommand prints success for "updated" files (issue #414)',
    () async {
      final capability = UpdatedCapability();
      final command = CapabilityCommand(capability);
      final runner = CommandRunner<void>('test', 'test')..addCommand(command);

      await expectLater(
        () => runner.run(['update']),
        prints(
          allOf(
            contains('✅ Success! Created/Modified:'),
            contains('lib/src/domain/services/foo_service.dart'),
          ),
        ),
      );
    },
  );

  // ------------------------------------------------------------------
  // Issue #769 — a successful execution that generated ZERO files (e.g.
  // the pure-Dart guard skipping presenter/controller/view generation)
  // must not be reported as success. Executable spec:
  //
  //   FR-1: the empty path prints no '✅ Success!' framing; it prints a
  //         warning explaining that nothing was generated and pointing
  //         at the skip note the generator already emitted.
  //   FR-2: the command exits non-zero (exitCode = 1) so automation can
  //         distinguish declined generation from success.
  //   FR-3: the file-bearing success path is unchanged (regression
  //         guard: the issue #414 test above).
  // ------------------------------------------------------------------
  test(
    'issue #769 — zero-file execution is not a success: no ✅ claim, '
    'non-zero exit',
    () async {
      final capability = SkippingCapability();
      final command = CapabilityCommand(capability);
      final runner = CommandRunner<void>('test', 'test')..addCommand(command);

      exitCode = 0;
      await expectLater(
        () => runner.run(['skip']),
        prints(
          allOf(
            isNot(contains('✅ Success!')),
            contains('No files were generated'),
          ),
        ),
      );
      final code = exitCode;
      exitCode = 0; // hermetic: never leak a failure code into the suite
      expect(code, equals(1),
          reason: 'generation was declined/skipped — automation must not '
              'read this as success (issue #769)');
    },
  );

  test(
    'issue #769 — file-bearing execution keeps exit code 0 and the '
    'success framing',
    () async {
      final capability = UpdatedCapability();
      final command = CapabilityCommand(capability);
      final runner = CommandRunner<void>('test', 'test')..addCommand(command);

      exitCode = 0;
      await expectLater(
        () => runner.run(['update']),
        prints(contains('✅ Success! Created/Modified:')),
      );
      final code = exitCode;
      exitCode = 0;
      expect(code, equals(0));
    },
  );
}

/// A capability that reports success but generates no files — the shape
/// returned by the presentation generators when a guard skips generation
/// (e.g. a pure-Dart target package for presenter/controller/view, the
/// repro of issue #769).
class SkippingCapability implements ZuraffaCapability {
  @override
  String get name => 'skip_cap';
  @override
  String get description => 'Skip Description';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': <String, dynamic>{},
    'required': [],
  };

  @override
  JsonSchema get outputSchema => <String, dynamic>{};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: '1',
    pluginId: 'p1',
    capabilityName: 'c1',
    args: args,
    changes: [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(
        success: true,
        data: {
          'generatedFiles': <GeneratedFile>[],
        },
      );
}

/// A capability whose execute returns a file with the `updated` action, which is
/// what the append-family capabilities (e.g. `zfa service method`) emit when
/// appending to an existing host file.
class UpdatedCapability implements ZuraffaCapability {
  @override
  String get name => 'update_cap';
  @override
  String get description => 'Update Description';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': <String, dynamic>{},
    'required': [],
  };

  @override
  JsonSchema get outputSchema => <String, dynamic>{};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: '1',
    pluginId: 'p1',
    capabilityName: 'c1',
    args: args,
    changes: [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(
        success: true,
        data: {
          'generatedFiles': [
            GeneratedFile(
              path: 'lib/src/domain/services/foo_service.dart',
              type: 'service',
              action: 'updated',
            ),
          ],
        },
      );
}
