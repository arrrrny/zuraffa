import 'dart:convert';
import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/src/agent/policy/policy_shell.dart';

void main() {
  group('MissionTraceRecorder (FR-007, FR-008, FR-009)', () {
    test('records each tool call with hashed args by default (FR-008)',
        () async {
      final recorder = MissionTraceRecorder(
        missionId: 'm1',
        inputHash: 'hash-in',
        allowlist: <String>{},
      );
      await recorder.onMissionStart('m1');

      // 20+ tool calls (SC-003)
      for (var i = 0; i < 25; i++) {
        final ctx = ToolCallContext(
          missionId: 'm1',
          toolName: 'tool_$i',
          args: {'secret': 'value-$i', 'public': 'visible'},
          isInternalMission: false,
          toolAllowlist: null,
          toolClass: 'io',
        );
        await recorder.beforeToolCall(ctx);
        await recorder.afterToolCall(ctx, ToolResult(payload: 'ok', tokenUsage: 10));
      }

      final trace = recorder.materialize();
      expect(trace.toolCallRecords, hasLength(25));
      expect(trace.toolCallRecords.first.name, equals('tool_0'));

      // Args hashed by default — secret NOT in cleartext.
      final firstRecord = trace.toolCallRecords.first;
      expect(firstRecord.cleartextArgs['secret'], isA<String>());
      expect(
        firstRecord.cleartextArgs['secret'] as String,
        startsWith('__hashed__:'),
      );
      expect(
        firstRecord.argumentsHash,
        hasLength(64),
        reason: 'SHA-256 hex',
      );
    });

    test('allowlist fields recorded in cleartext (FR-008)', () async {
      final recorder = MissionTraceRecorder(
        missionId: 'm1',
        inputHash: 'hash-in',
        allowlist: <String>{'public'},
      );
      await recorder.onMissionStart('m1');

      final ctx = ToolCallContext(
        missionId: 'm1',
        toolName: 'tool_x',
        args: {'secret': 'value', 'public': 'visible'},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      );
      await recorder.beforeToolCall(ctx);
      await recorder.afterToolCall(ctx, ToolResult(payload: 'ok'));

      final trace = recorder.materialize();
      final record = trace.toolCallRecords.single;
      expect(record.cleartextArgs['public'], equals('visible'));
      expect(
        record.cleartextArgs['secret'] as String,
        startsWith('__hashed__:'),
      );
    });

    test('schema-valid JSON (SC-003)', () async {
      final recorder = MissionTraceRecorder(
        missionId: 'm1',
        inputHash: 'hash-in',
        planSteps: const ['step1', 'step2'],
        provider: 'test-provider',
      );
      await recorder.onMissionStart('m1');

      for (var i = 0; i < 25; i++) {
        final ctx = ToolCallContext(
          missionId: 'm1',
          toolName: 'tool_$i',
          args: {'k': i},
          isInternalMission: false,
          toolAllowlist: null,
          toolClass: 'io',
        );
        await recorder.beforeToolCall(ctx);
        await recorder.afterToolCall(ctx, ToolResult(payload: 'ok', tokenUsage: 5));
      }

      final trace = recorder.materialize(outcome: 'completed');
      final json = trace.toJson();
      final jsonStr = jsonEncode(json);

      // Round-trip through JSON — should be valid JSON.
      final decoded = jsonDecode(jsonStr);
      expect(decoded, isA<Map<String, Object?>>());
      expect(decoded['schemaVersion'], equals('1.0.0'));
      expect(decoded['missionId'], equals('m1'));
      expect(decoded['inputHash'], equals('hash-in'));
      expect(decoded['toolCalls'], hasLength(25));
      expect(decoded['tokens'], equals(25 * 5));
      expect(decoded['planSteps'], equals(['step1', 'step2']));
      expect(decoded['provider'], equals('test-provider'));
    });

    test('concurrent streaming — no corruption (FR-009)', () async {
      final recorder = MissionTraceRecorder(
        missionId: 'm1',
        inputHash: 'hash-in',
      );
      await recorder.onMissionStart('m1');

      // Schedule many concurrent tool calls — Dart's single-isolate scheduler
      // guarantees no real concurrency, but we exercise interleaved awaits.
      final futures = <Future<void>>[];
      for (var i = 0; i < 100; i++) {
        final ctx = ToolCallContext(
          missionId: 'm1',
          toolName: 'tool_$i',
          args: {'i': i},
          isInternalMission: false,
          toolAllowlist: null,
          toolClass: 'io',
        );
        futures.add((() async {
          await recorder.beforeToolCall(ctx);
          await recorder.afterToolCall(ctx, ToolResult(payload: null, tokenUsage: 1));
        })());
      }
      await Future.wait(futures);

      final trace = recorder.materialize();
      expect(trace.toolCallRecords, hasLength(100));
      // No duplicates and no missing records.
      final names = trace.toolCallRecords.map((r) => r.name).toSet();
      expect(names, hasLength(100));
    });
  });

  group('OversizedResultGuard (FR-010)', () {
    test('small result passes through unchanged', () async {
      final guard = OversizedResultGuard(
        threshold: 100,
        artifactStorage: (_) async => null,
      );
      final result = ToolResult(payload: 'small');
      final out = await guard.afterToolCall(
        ToolCallContext(
          missionId: 'm1',
          toolName: 't',
          args: {},
          isInternalMission: false,
          toolAllowlist: null,
          toolClass: 'io',
        ),
        result,
      );
      expect(out.payload, equals('small'));
    });

    test('oversized result → ArtifactReference (SC-004)', () async {
      final bigPayload = 'x' * 500;
      final guard = OversizedResultGuard(
        threshold: 100,
        artifactStorage: (_) async => 'artifact://stored/abc',
      );
      final result = ToolResult(payload: bigPayload);
      final out = await guard.afterToolCall(
        ToolCallContext(
          missionId: 'm1',
          toolName: 't',
          args: {},
          isInternalMission: false,
          toolAllowlist: null,
          toolClass: 'io',
        ),
        result,
      );
      expect(out.payload, isA<ArtifactReference>());
      final ref = out.payload as ArtifactReference;
      expect(ref.uri, equals('artifact://stored/abc'));
      expect(ref.size, equals(500));
      expect(ref.sha256, hasLength(64));
      // Verify the original large payload is NOT in the result.
      expect(out.payload.toString(), isNot(contains(bigPayload)));
    });

    test('artifact storage unavailable → truncated with marker (edge case)',
        () async {
      final bigPayload = 'x' * 500;
      final guard = OversizedResultGuard(
        threshold: 100,
        artifactStorage: (_) async => null, // unavailable
        truncationMarker: '<truncated>',
      );
      final result = ToolResult(payload: bigPayload);
      final out = await guard.afterToolCall(
        ToolCallContext(
          missionId: 'm1',
          toolName: 't',
          args: {},
          isInternalMission: false,
          toolAllowlist: null,
          toolClass: 'io',
        ),
        result,
      );
      expect(out.payload, equals('<truncated>'));
      expect(out.size, equals('<truncated>'.length));
    });

    test('oversized result never enters model context across 100 missions (SC-004)',
        () async {
      final guard = OversizedResultGuard(
        threshold: 100,
        artifactStorage: (_) async => 'artifact://x',
      );
      final bigPayload = 'x' * 1000;
      final ctx = ToolCallContext(
        missionId: 'm1',
        toolName: 't',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      );
      for (var i = 0; i < 100; i++) {
        final out = await guard.afterToolCall(ctx, ToolResult(payload: bigPayload));
        // The original large payload is never returned.
        expect(out.payload, isNot(equals(bigPayload)));
        expect(out.effectiveSize, lessThan(1000));
      }
    });
  });

  group('PolicyShell composition (FR-011)', () {
    test('runs hooks in registration order; first deny wins', () async {
      final allow = _AlwaysAllow();
      final deny = _AlwaysDeny('because');
      final shell = PolicyShell(hooks: [allow, deny]);

      final d = await shell.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 't',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(d, isA<HookDecisionDeny>());
      expect((d as HookDecisionDeny).reason, equals('because'));
    });

    test('disabled hooks are skipped', () async {
      final deny = _AlwaysDeny('should-not-fire');
      deny.enabled = false;
      final shell = PolicyShell(hooks: [deny]);

      final d = await shell.beforeToolCall(ToolCallContext(
        missionId: 'm1',
        toolName: 't',
        args: {},
        isInternalMission: false,
        toolAllowlist: null,
        toolClass: 'io',
      ));
      expect(d, isA<HookDecisionAllow>());
    });

    test('enable/disable by id', () {
      final deny = _AlwaysDeny('x');
      final shell = PolicyShell(hooks: [deny]);
      expect(deny.enabled, isTrue);
      shell.disable('test_deny');
      expect(deny.enabled, isFalse);
      shell.enable('test_deny');
      expect(deny.enabled, isTrue);
    });

    test('afterToolCall runs hooks in reverse order (middleware pattern)',
        () async {
      final order = <String>[];
      final a = _OrderRecording('a', order);
      final b = _OrderRecording('b', order);
      final shell = PolicyShell(hooks: [a, b]);

      await shell.afterToolCall(
        ToolCallContext(
          missionId: 'm1',
          toolName: 't',
          args: {},
          isInternalMission: false,
          toolAllowlist: null,
          toolClass: 'io',
        ),
        ToolResult(payload: null),
      );
      // Reverse order: b, then a.
      expect(order, equals(['b', 'a']));
    });
  });
}

class _AlwaysAllow extends PolicyHook {
  _AlwaysAllow();
  @override
  String get id => 'always_allow';
  @override
  Future<HookDecision> beforeToolCall(ToolCallContext ctx) async =>
      const HookDecisionAllow();
}

class _AlwaysDeny extends PolicyHook {
  _AlwaysDeny(this.reason);
  @override
  String get id => 'test_deny';
  final String reason;
  @override
  Future<HookDecision> beforeToolCall(ToolCallContext ctx) async =>
      HookDecisionDeny(reason);
}

class _OrderRecording extends PolicyHook {
  _OrderRecording(this.name, this.order);
  final String name;
  final List<String> order;
  @override
  String get id => 'order_$name';
  @override
  Future<ToolResult> afterToolCall(
    ToolCallContext ctx,
    ToolResult result,
  ) async {
    order.add(name);
    return result;
  }
}
