import 'dart:io';

import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import 'package:zuraffa/src/commands/capability_command.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/models/generated_file.dart';

/// Issue #767 — systemic exit-code contract of the SHARED capability
/// runner (every manifest-driven generator command routes through
/// [CapabilityCommand]: usecase, repository, provider, presenter,
/// controller, view, cache, sqlite, mcp, ...).
///
/// Automation layered on zfa (scripts, CI, MCP harnesses) reads the
/// process exit code; an ❌-prefixed error printed while exiting 0 tells
/// them a failed invocation succeeded. The contract:
///
///   FR-1: missing required arguments → exit 64 (usage-error family;
///         already implemented — regression-guarded here).
///   FR-2: capability execute() reports success: false (capability-owned
///         validation, e.g. "Entity not found") → `❌ Failed:` printed
///         AND exit 1 (runtime failure — distinct from 64).
///   FR-3: success keeps exit 0 and the ✅ framing (guarded by the #769
///         and #414 tests in capability_command_test.dart).
///
/// Fast tier: pure in-memory mocks, no filesystem, no temp projects.
void main() {
  test(
    'FR-1 — missing required arguments exits 64 (usage-error family)',
    () async {
      final command = CapabilityCommand(RequiredNameCapability());
      final runner = CommandRunner<void>('test', 'test')..addCommand(command);

      exitCode = 0;
      late int code;
      await expectLater(
        () => runner.run(['req']).then((_) {
          // Capture inside the same microtask — exitCode is process-global
          // and parallel test isolates can reset it before the read after
          // expectLater returns (parallel-load flaky, issue #767).
          code = exitCode;
        }),
        prints(contains('Missing required arguments: name')),
      );
      exitCode = 0; // hermetic: never leak a failure code into the suite
      expect(
        code,
        equals(64),
        reason:
            'usage errors exit 64 — the missing-args contract predates '
            '#767 and must not regress while the failure paths are fixed',
      );
    },
  );

  test('FR-2 — capability failure prints ❌ Failed and exits 1', () async {
    final command = CapabilityCommand(FailingCapability());
    final runner = CommandRunner<void>('test', 'test')..addCommand(command);

    exitCode = 0;
    late int code;
    await expectLater(
      () => runner.run(['fail']).then((_) {
        code = exitCode;
      }),
      prints(
        allOf(
          contains('❌ Failed:'),
          contains("Entity 'MissingEntity' not found"),
        ),
      ),
    );
    exitCode = 0;
    expect(
      code,
      equals(1),
      reason:
          'the capability reported success: false — printing ❌ and '
          'exiting 0 tells scripts/CI/MCP clients a failed invocation '
          'succeeded (issue #767)',
    );
  });

  test('FR-3 — success keeps exit 0 (fast-tier regression guard)', () async {
    final command = CapabilityCommand(SucceedingCapability());
    final runner = CommandRunner<void>('test', 'test')..addCommand(command);

    exitCode = 0;
    late int code;
    await expectLater(
      () => runner.run(['ok']).then((_) {
        code = exitCode;
      }),
      prints(contains('✅ Success!')),
    );
    exitCode = 0;
    expect(code, equals(0));
  });
}

/// Capability whose execute() reports FAILURE — the shape capability-owned
/// validation returns (e.g. `cache create --name MissingEntity` outside a
/// workspace: "Entity 'MissingEntity' not found."). Issue #767's repro.
class FailingCapability implements ZuraffaCapability {
  @override
  String get name => 'fail_cap';
  @override
  String get description => 'Failing Description';

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
        success: false,
        message: "Exception: Entity 'MissingEntity' not found.",
      );
}

/// Capability declaring a required `name` property — the missing-args
/// path of the shared runner (usage-error family, exit 64).
class RequiredNameCapability implements ZuraffaCapability {
  @override
  String get name => 'req_cap';
  @override
  String get description => 'Required Description';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
    },
    'required': ['name'],
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
      ExecutionResult(success: true, files: []);
}

/// Capability reporting plain success WITH files — regression guard that
/// the failure-path fixes leave the ✅ success framing and exit 0 intact.
class SucceedingCapability implements ZuraffaCapability {
  @override
  String get name => 'ok_cap';
  @override
  String get description => 'Succeeding Description';

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
        files: ['lib/generated/thing.dart'],
        data: {
          'generatedFiles': [
            GeneratedFile(
              path: 'lib/generated/thing.dart',
              type: 'service',
              action: 'created',
            ),
          ],
        },
      );
}
