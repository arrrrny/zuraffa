import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Blocking (awaited) lifecycle hooks for the classic UseCase — issue #2032.
///
/// https://github.com/arrrrny/zuraffa/issues/2032
///
/// The contract pinned here: a `pre` hook that opts in via [Hook.blocking] is
/// awaited to completion by `UseCase.call` BEFORE `execute` begins, with a
/// per-hook abandonment timeout ([Hook.blockingTimeout]) and a per-hook error
/// policy ([Hook.onError]). Non-blocking hooks keep today's fire-and-forget
/// semantics. `UseCase.execute` is a stand-in for the consumer's repository
/// write throughout this suite.
class _SettleParams {
  const _SettleParams(this.taskId, this.status);

  final String taskId;
  final String status;
}

/// A UseCase whose `execute` is the "status write" under observation.
class _WriteUseCase extends UseCase<String, Object?> {
  _WriteUseCase(this.onExecute);

  /// Runs at the moment `execute` begins.
  final void Function() onExecute;

  @override
  Future<String> execute(Object? params, CancelToken? cancelToken) async {
    onExecute();
    return 'landed';
  }
}

/// Scriptable hook: every lifecycle knob is overridable, the body injected.
class _ScriptedHook extends Hook {
  _ScriptedHook(
    this.id, {
    this.blocking = false,
    this.blockingTimeout,
    this.onError = HookErrorPolicy.continue_,
    this.phases = const {HookPhase.pre},
    this.priority = 0,
    this.matches,
    this.body,
  });

  @override
  final String id;

  @override
  final bool blocking;

  @override
  final Duration? blockingTimeout;

  @override
  final HookErrorPolicy onError;

  @override
  final Set<HookPhase> phases;

  @override
  final int priority;

  final bool Function(HookContext context)? matches;
  final Future<void> Function(HookContext context)? body;

  @override
  bool shouldTrigger(HookContext context, HookPhase phase) =>
      matches?.call(context) ?? true;

  @override
  Future<void> execute(HookContext context, HookPhase phase) =>
      body?.call(context) ?? Future.value();
}

void main() {
  setUp(() {
    HookRegistry.instance.clear();
    HookRegistry.instance.isEnabled = true;
  });

  tearDown(() {
    HookRegistry.instance.clear();
  });

  group('blocking (awaited) pre hooks — issue #2032', () {
    test(
      'blocking pre hook completes before execute runs (acceptance)',
      () async {
        final events = <String>[];
        String? violation;

        HookRegistry.instance.register(
          _ScriptedHook(
            'egress-rotation',
            blocking: true,
            body: (context) async {
              events.add('hook-start');
              // The issue's acceptance test: sleep 300ms, then write the marker.
              await Future<void>.delayed(const Duration(milliseconds: 300));
              events.add('hook-end'); // the marker
            },
          ),
        );

        final useCase = _WriteUseCase(() {
          events.add('execute'); // the "repository write"
          if (!events.contains('hook-end')) {
            violation = 'write landed before the blocking hook marker';
          }
        });

        final result = await useCase('task-1');

        expect(
          result.isSuccess,
          isTrue,
          reason: 'continue_ policy keeps the result sacred',
        );
        expect(violation, isNull, reason: 'the write must observe the marker');
        expect(events, ['hook-start', 'hook-end', 'execute']);
      },
    );

    test('non-blocking pre hooks keep fire-and-forget semantics', () async {
      final events = <String>[];
      final hookDone = Completer<void>();

      HookRegistry.instance.register(
        _ScriptedHook(
          'telemetry',
          // blocking defaults to false — today's behavior, unchanged
          body: (context) async {
            events.add('hook-start');
            await Future<void>.delayed(const Duration(milliseconds: 120));
            events.add('hook-end');
            hookDone.complete();
          },
        ),
      );

      final useCase = _WriteUseCase(() => events.add('execute'));

      final result = await useCase('task-1');

      expect(result.isSuccess, isTrue);
      // execute ran while the hook was still pending — call did not block
      expect(events, contains('execute'));
      expect(events, isNot(contains('hook-end')));
      expect(events, containsAllInOrder(['hook-start', 'execute']));

      await hookDone.future; // settle the fire-and-forget hook
      expect(events, contains('hook-end'));
    });

    test(
      'blockingTimeout abandons the wait; continue_ lands the result',
      () async {
        final events = <String>[];
        final hookFinished = Completer<void>();

        HookRegistry.instance.register(
          _ScriptedHook(
            'slow-rotation',
            blocking: true,
            blockingTimeout: const Duration(milliseconds: 60),
            // onError defaults to HookErrorPolicy.continue_
            body: (context) async {
              await Future<void>.delayed(const Duration(milliseconds: 500));
              events.add('hook-done');
              hookFinished.complete();
            },
          ),
        );

        final useCase = _WriteUseCase(() => events.add('execute'));

        final result = await useCase('task-1');

        expect(
          result.isSuccess,
          isTrue,
          reason: 'abandonment + continue_ keeps the result sacred',
        );
        expect(events, contains('execute'));
        expect(
          events,
          isNot(contains('hook-done')),
          reason: 'the registry stopped waiting at the 60ms timeout',
        );

        await hookFinished.future;
        expect(
          events,
          contains('hook-done'),
          reason: 'timeout is abandonment, not cancellation: the hook runs on',
        );
      },
    );

    test('blockingTimeout under veto fails the call without execute', () async {
      final events = <String>[];

      HookRegistry.instance.register(
        _ScriptedHook(
          'slow-rotation',
          blocking: true,
          blockingTimeout: const Duration(milliseconds: 60),
          onError: HookErrorPolicy.veto,
          body: (context) async {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            events.add('hook-done');
          },
        ),
      );

      final useCase = _WriteUseCase(() => events.add('execute'));

      final result = await useCase('task-1');

      expect(
        result.isSuccess,
        isFalse,
        reason: 'a vetoed hook that never completed must not land the result',
      );
      expect(events, isNot(contains('execute')));

      // Let the abandoned hook finish so no timer outlives the test.
      await Future<void>.delayed(const Duration(milliseconds: 520));
      expect(events, isNot(contains('execute')));
    });

    test(
      'veto fails the call with the hook failure and never runs execute',
      () async {
        final events = <String>[];

        HookRegistry.instance.register(
          _ScriptedHook(
            'rotation',
            blocking: true,
            onError: HookErrorPolicy.veto,
            body: (context) async {
              throw ServerFailure('proxy rotation failed');
            },
          ),
        );

        final useCase = _WriteUseCase(() => events.add('execute'));

        final result = await useCase('task-1');

        expect(result.isSuccess, isFalse);
        result.fold((_) => fail('veto must fail the call'), (failure) {
          expect(
            failure,
            isA<ServerFailure>(),
            reason: 'an AppFailure from the hook passes through as-is',
          );
          expect(failure.message, contains('proxy rotation failed'));
        });
        expect(events, isNot(contains('execute')));
      },
    );

    test('veto wraps a non-AppFailure throw into an AppFailure', () async {
      HookRegistry.instance.register(
        _ScriptedHook(
          'rotation',
          blocking: true,
          onError: HookErrorPolicy.veto,
          body: (context) async {
            throw StateError('egress exited 1');
          },
        ),
      );

      final useCase = _WriteUseCase(() {});
      final result = await useCase('task-1');

      expect(result.isSuccess, isFalse);
      result.fold((_) => fail('veto must fail the call'), (failure) {
        expect(failure, isA<AppFailure>());
        expect(failure.message, contains('egress exited 1'));
      });
    });

    test(
      'veto proceeds no further: success/failure phase hooks never fire',
      () async {
        final latePhases = <String>[];

        HookRegistry.instance.register(
          _ScriptedHook(
            'rotation',
            blocking: true,
            onError: HookErrorPolicy.veto,
            body: (context) async => throw StateError('no-go'),
          ),
        );
        HookRegistry.instance.register(
          _ScriptedHook(
            'observer',
            phases: const {HookPhase.success, HookPhase.failure},
            body: (context) async => latePhases.add('fired'),
          ),
        );

        final useCase = _WriteUseCase(() {});
        final result = await useCase('task-1');

        expect(result.isSuccess, isFalse);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          latePhases,
          isEmpty,
          reason: 'veto proceeds no further — no execute, no later phases',
        );
      },
    );

    test(
      'a throwing blocking hook under continue_ is contained; others run',
      () async {
        final events = <String>[];

        HookRegistry.instance.register(
          _ScriptedHook(
            'broken',
            blocking: true,
            // onError defaults to HookErrorPolicy.continue_
            body: (context) async {
              events.add('broken-attempt');
              throw StateError('boom');
            },
          ),
        );
        HookRegistry.instance.register(
          _ScriptedHook(
            'healthy',
            blocking: true,
            priority: 10,
            body: (context) async => events.add('healthy-run'),
          ),
        );

        final useCase = _WriteUseCase(() => events.add('execute'));
        final result = await useCase('task-1');

        expect(
          result.isSuccess,
          isTrue,
          reason: 'continue_ keeps the result sacred',
        );
        expect(events, [
          'broken-attempt',
          'healthy-run',
          'execute',
        ], reason: 'the failed hook did not stop the next blocking hook');
      },
    );

    test(
      'blocking hooks run sequentially in priority order before execute',
      () async {
        final events = <String>[];

        _ScriptedHook scripted(String id, int priority) => _ScriptedHook(
          id,
          blocking: true,
          priority: priority,
          body: (context) async {
            events.add('$id-start');
            await Future<void>.delayed(const Duration(milliseconds: 40));
            events.add('$id-end');
          },
        );

        HookRegistry.instance.register(scripted('second', 20));
        HookRegistry.instance.register(scripted('first', 10));

        final useCase = _WriteUseCase(() => events.add('execute'));
        final result = await useCase('task-1');

        expect(result.isSuccess, isTrue);
        expect(events, [
          'first-start',
          'first-end',
          'second-start',
          'second-end',
          'execute',
        ], reason: 'sequential in priority order (lower first), execute last');
      },
    );

    test('disabled registry short-circuits blocking hooks too', () async {
      final events = <String>[];

      HookRegistry.instance.register(
        _ScriptedHook(
          'rotation',
          blocking: true,
          body: (context) async => events.add('hook'),
        ),
      );
      HookRegistry.instance.isEnabled = false;

      final useCase = _WriteUseCase(() => events.add('execute'));
      final result = await useCase('task-1');

      expect(result.isSuccess, isTrue);
      expect(events, [
        'execute',
      ], reason: 'isEnabled = false still short-circuits everything');
    });

    test(
      'metadata bag unchanged: blocking pre writes, success reads',
      () async {
        final seen = <String?>[];

        HookRegistry.instance.register(
          _ScriptedHook(
            'rotation',
            blocking: true,
            body: (context) async {
              await Future<void>.delayed(const Duration(milliseconds: 10));
              context.metadata['proxy'] = 'fresh';
            },
          ),
        );
        HookRegistry.instance.register(
          _ScriptedHook(
            'observer',
            phases: const {HookPhase.success},
            body: (context) async =>
                seen.add(context.metadata['proxy'] as String?),
          ),
        );

        final useCase = _WriteUseCase(() {});
        final result = await useCase('task-1');

        expect(result.isSuccess, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(seen, [
          'fresh',
        ], reason: 'blocking pre hooks write; success hooks read — unchanged');
      },
    );

    test(
      'blocking flag is honored only in pre: success stays fire-and-forget',
      () async {
        final events = <String>[];
        final done = Completer<void>();

        HookRegistry.instance.register(
          _ScriptedHook(
            'late-observer',
            blocking: true, // must be IGNORED outside the pre phase
            phases: const {HookPhase.success},
            body: (context) async {
              await Future<void>.delayed(const Duration(milliseconds: 120));
              events.add('observer-done');
              done.complete();
            },
          ),
        );

        final useCase = _WriteUseCase(() => events.add('execute'));
        final result = await useCase('task-1');

        expect(result.isSuccess, isTrue);
        expect(events, contains('execute'));
        expect(
          events,
          isNot(contains('observer-done')),
          reason: 'success phase dispatch never blocks, even when flagged',
        );
        await done.future;
        expect(events, contains('observer-done'));
      },
    );

    test(
      'forklift-shaped case: rotation lands before the status write',
      () async {
        // The lane label lives on the task ROW, not in the params — the hook
        // looks the entity up itself (params-only context reality, #2032 §4).
        final laneByTask = <String, String>{
          'task-1': 'opencode',
          'task-2': 'local',
        };
        final writes = <String>[];
        final rotatedFor = <String>[];
        String? violation;

        HookRegistry.instance.register(
          _ScriptedHook(
            'egress-rotation',
            blocking: true,
            // matcher: cheap check on params only (target status)
            matches: (context) {
              final params = context.paramsAs<_SettleParams>();
              return params.status == 'done' || params.status == 'failed';
            },
            body: (context) async {
              final params = context.paramsAs<_SettleParams>();
              final lane = laneByTask[params.taskId]; // hook-side entity lookup
              if (lane != 'opencode') return;
              await Future<void>.delayed(
                const Duration(milliseconds: 40),
              ); // rotate
              rotatedFor.add(params.taskId);
              context.metadata['proxy_rotated'] = params.taskId;
            },
          ),
        );

        Future<Result<String, AppFailure>> settle(_SettleParams p) {
          return _WriteUseCase(() {
            writes.add(p.status);
            final needsRotation = p.status == 'done' || p.status == 'failed';
            if (needsRotation &&
                laneByTask[p.taskId] == 'opencode' &&
                !rotatedFor.contains(p.taskId)) {
              violation = 'status write landed before rotation for ${p.taskId}';
            }
          })(p);
        }

        final doneResult = await settle(const _SettleParams('task-1', 'done'));
        final openResult = await settle(const _SettleParams('task-2', 'open'));

        expect(doneResult.isSuccess, isTrue);
        expect(openResult.isSuccess, isTrue);
        expect(
          violation,
          isNull,
          reason: 'the status write must wait for the rotation to finish',
        );
        expect(rotatedFor, [
          'task-1',
        ], reason: 'non-settling params never trigger the blocking hook');
        expect(writes, ['done', 'open']);
      },
    );

    test(
      'a throwing shouldTrigger is contained; a veto hook after it still vetoes',
      () async {
        final events = <String>[];

        HookRegistry.instance.register(
          _ScriptedHook(
            'broken-matcher',
            blocking: true, // irrelevant — it never matches
            matches: (_) {
              throw StateError('matcher boom');
            },
            body: (context) async => events.add('broken-matcher-ran'),
          ),
        );
        HookRegistry.instance.register(
          _ScriptedHook(
            'veto',
            blocking: true,
            priority: 10,
            onError: HookErrorPolicy.veto,
            body: (context) async => throw ServerFailure('vetoed'),
          ),
        );

        final useCase = _WriteUseCase(() => events.add('execute'));
        final result = await useCase('task-1');

        expect(
          result.isSuccess,
          isFalse,
          reason: 'the veto hook ordered after the broken matcher still fired',
        );
        expect(events, isNot(contains('execute')));
        expect(events, isNot(contains('broken-matcher-ran')));
      },
    );

    test('a synchronously-throwing execute is contained; a veto hook after it '
        'still vetoes', () async {
      final events = <String>[];

      HookRegistry.instance.register(
        _ScriptedHook(
          'sync-boom',
          // non-blocking on purpose: the fire-and-forget path must
          // contain a synchronous throw from a non-async execute
          body: (context) {
            throw StateError('sync boom');
          },
        ),
      );
      HookRegistry.instance.register(
        _ScriptedHook(
          'veto',
          blocking: true,
          priority: 10,
          onError: HookErrorPolicy.veto,
          body: (context) async => throw ServerFailure('vetoed'),
        ),
      );

      final useCase = _WriteUseCase(() => events.add('execute'));
      final result = await useCase('task-1');

      expect(
        result.isSuccess,
        isFalse,
        reason: 'the veto hook ordered after the sync throw still fired',
      );
      expect(events, isNot(contains('execute')));
    });

    test('a veto skips subsequent blocking hooks', () async {
      final events = <String>[];

      HookRegistry.instance.register(
        _ScriptedHook(
          'veto',
          blocking: true,
          onError: HookErrorPolicy.veto,
          body: (context) async => throw ServerFailure('no-go'),
        ),
      );
      HookRegistry.instance.register(
        _ScriptedHook(
          'after-veto',
          blocking: true,
          priority: 10,
          body: (context) async => events.add('after-veto-ran'),
        ),
      );

      final useCase = _WriteUseCase(() => events.add('execute'));
      final result = await useCase('task-1');

      expect(result.isSuccess, isFalse);
      expect(
        events,
        isNot(contains('after-veto-ran')),
        reason:
            'a veto stops the dispatch immediately — no later blocking hook',
      );
      expect(events, isNot(contains('execute')));
    });
  });
}
