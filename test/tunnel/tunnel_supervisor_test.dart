import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/tunnel/tunnel_config.dart';
import 'package:zuraffa/src/tunnel/tunnel_state.dart';
import 'package:zuraffa/src/tunnel/tunnel_supervisor.dart';

/// A scripted stand-in for the spawned cloudflared process.
class FakeTunnelProcess implements ManagedProcess {
  FakeTunnelProcess({this.pid = 4242});

  @override
  final int pid;

  // Single-subscription (buffering) controllers — a real Process's stdout
  // pipe buffers until listened; the fake must too, or lines emitted
  // between spawn and subscribe are lost (broadcast drops them).
  final _stdout = StreamController<String>();
  final _stderr = StreamController<String>();
  final _exit = Completer<int>();
  bool killCalled = false;

  @override
  Stream<String> get stdoutLines => _stdout.stream;

  @override
  Stream<String> get stderrLines => _stderr.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill() {
    killCalled = true;
    if (!_exit.isCompleted) _exit.complete(0);
    return true;
  }

  void emitStdout(String line) => _stdout.add(line);

  void emitStderr(String line) => _stderr.add(line);

  void exitWith(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }
}

class Spawn {
  Spawn(this.executable, this.arguments);
  final String executable;
  final List<String> arguments;
}

/// Stream<T>.whereType does not exist — filter+cast helper for events.
Stream<X> ofType<X>(Stream<TunnelEvent> events) =>
    events.where((e) => e is X).cast<X>();

void main() {
  late Directory tmp;
  late TunnelState state;
  final spawned = <Spawn>[];
  final fakes = <FakeTunnelProcess>[];

  FakeTunnelProcess nextFake() {
    final fake = FakeTunnelProcess(pid: 4000 + fakes.length);
    fakes.add(fake);
    return fake;
  }

  TunnelSupervisor buildSupervisor({
    int maxRestarts = 5,
    Duration backoffBase = const Duration(milliseconds: 1),
    Duration startTimeout = const Duration(seconds: 10),
    void Function(String line)? onOutput,
  }) {
    return TunnelSupervisor(
      cloudflaredPath: '/fake/cloudflared',
      processFactory: (executable, arguments) async {
        spawned.add(Spawn(executable, arguments));
        return nextFake();
      },
      state: state,
      maxRestarts: maxRestarts,
      backoffBase: backoffBase,
      startTimeout: startTimeout,
      onOutput: onOutput,
    );
  }

  /// Waits until the supervisor has spawned process [n] (1-based).
  Future<void> awaitSpawn(int n) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (spawned.length < n) {
      if (DateTime.now().isAfter(deadline)) {
        fail('process #$n was never spawned (have ${spawned.length})');
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// The supervisor persists asynchronously — poll for the expected record
  /// instead of racing the flush.
  Future<TunnelStateRecord> awaitState(
    bool Function(TunnelStateRecord) test,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (true) {
      final record = state.read();
      if (record != null && test(record)) return record;
      if (DateTime.now().isAfter(deadline)) {
        fail('state never matched: ${record?.toJson()}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tunnel_supervisor_');
    state = TunnelState(projectRoot: tmp.path);
    spawned.clear();
    fakes.clear();
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  const quickConfig = TunnelConfig(mode: TunnelMode.quick, port: 8080);

  group('TunnelSupervisor — quick mode', () {
    test('start resolves with the URL parsed from process output', () async {
      final supervisor = buildSupervisor();
      final events = <TunnelEvent>[];
      supervisor.events.listen(events.add);

      final startFuture = supervisor.start(quickConfig);
      await awaitSpawn(1);
      fakes.first.emitStdout(
        '|  https://quick-words-1234.trycloudflare.com  |',
      );

      final url = await startFuture;
      expect(url.toString(), 'https://quick-words-1234.trycloudflare.com');
      expect(
        supervisor.handle!.url.toString(),
        'https://quick-words-1234.trycloudflare.com',
      );
      expect(
        events.whereType<TunnelStarted>().length,
        1,
        reason: 'exactly one TunnelStarted once the URL is derived',
      );
    });

    test('start also reads the URL when cloudflared logs on stderr', () async {
      final supervisor = buildSupervisor();
      final startFuture = supervisor.start(quickConfig);
      await awaitSpawn(1);
      fakes.first.emitStderr(
        'INF |  https://stderr-origin.trycloudflare.com  |',
      );
      final url = await startFuture;
      expect(url.toString(), 'https://stderr-origin.trycloudflare.com');
    });

    test('spawned args target the declared loopback port only', () async {
      final supervisor = buildSupervisor();
      final startFuture = supervisor.start(quickConfig);
      await awaitSpawn(1);
      fakes.first.emitStdout('https://x-y.trycloudflare.com');
      await startFuture;

      final spawn = spawned.single;
      expect(spawn.executable, '/fake/cloudflared');
      expect(spawn.arguments, contains('tunnel'));
      expect(spawn.arguments, contains('--url'));
      expect(spawn.arguments, contains('http://localhost:8080'));
      expect(spawn.arguments, contains('--no-autoupdate'));
    });

    test('a raised tunnel is persisted as running with its URL', () async {
      final supervisor = buildSupervisor();
      final startFuture = supervisor.start(quickConfig);
      await awaitSpawn(1);
      fakes.first.emitStdout('https://persisted-url.trycloudflare.com');
      await startFuture;

      final record = await awaitState(
        (r) => r.running && r.url == 'https://persisted-url.trycloudflare.com',
      );
      expect(record.pid, fakes.first.pid);
      expect(record.mode, 'quick');
      expect(record.port, 8080);
    });

    test(
      'a killed process is restarted and re-registered with the new URL',
      () async {
        final supervisor = buildSupervisor();
        // Subscribe BEFORE the kill — the restart event may otherwise fire
        // before a late listener attaches.
        final restarted = supervisor.events
            .firstWhere((e) => e is TunnelStarted && e.restart == 1)
            .timeout(const Duration(seconds: 10));

        final startFuture = supervisor.start(quickConfig);
        await awaitSpawn(1);
        fakes.first.emitStdout('https://first-try.trycloudflare.com');
        await startFuture;

        fakes.first.exitWith(1); // kill -9 by the operator

        await awaitSpawn(2);
        fakes.last.emitStdout('https://second-try.trycloudflare.com');

        expect(
          (await restarted as TunnelStarted).url.toString(),
          'https://second-try.trycloudflare.com',
          reason: 'the restarted tunnel re-registers under its own new URL',
        );
        expect(supervisor.handle!.restarts, 1);
        expect(
          supervisor.handle!.url.toString(),
          'https://second-try.trycloudflare.com',
        );
        expect(spawned.length, 2, reason: 'a second cloudflared was spawned');
        final record = await awaitState(
          (r) =>
              r.url == 'https://second-try.trycloudflare.com' &&
              r.restarts == 1,
        );
        expect(record.running, isTrue);
      },
    );

    test('restarts observe exponential backoff capped at the cap', () async {
      final delays = <Duration>[];
      final supervisor = buildSupervisor();
      supervisor.events.listen((e) {
        if (e is TunnelRestarting) delays.add(e.delay);
      });

      final startFuture = supervisor.start(quickConfig);
      await awaitSpawn(1);
      fakes.first.emitStdout('https://backoff-1.trycloudflare.com');
      await startFuture;

      final first = supervisor.events
          .firstWhere((e) => e is TunnelStarted && e.restart == 1)
          .timeout(const Duration(seconds: 10));
      final second = supervisor.events
          .firstWhere((e) => e is TunnelStarted && e.restart == 2)
          .timeout(const Duration(seconds: 10));

      fakes.first.exitWith(1);
      await awaitSpawn(2);
      fakes.last.emitStdout('https://backoff-2.trycloudflare.com');
      await first;

      fakes.last.exitWith(1);
      await awaitSpawn(3);
      fakes.last.emitStdout('https://backoff-3.trycloudflare.com');
      await second;

      expect(delays.length, 2);
      expect(delays[0], const Duration(milliseconds: 1));
      expect(
        delays[1],
        const Duration(milliseconds: 2),
        reason: 'backoff doubles per attempt',
      );
    });

    test(
      'exhausting the restart budget fails with a recorded reason',
      () async {
        final supervisor = buildSupervisor(maxRestarts: 1);
        final failed = ofType<TunnelFailed>(
          supervisor.events,
        ).first.timeout(const Duration(seconds: 10));

        final startFuture = supervisor.start(quickConfig);
        await awaitSpawn(1);
        fakes.first.emitStdout('https://budget-1.trycloudflare.com');
        await startFuture;

        fakes.first.exitWith(1);
        await awaitSpawn(2);
        fakes.last.emitStdout('https://budget-2.trycloudflare.com');
        await awaitState((r) => r.restarts == 1);

        fakes.last.exitWith(1);

        final failure = await failed;
        expect(failure.reason, isNotEmpty);

        await awaitState(
          (r) => !r.running && (r.failureReason?.isNotEmpty ?? false),
        );
      },
    );

    test(
      'stop() kills the process, emits stopped and persists the shutdown',
      () async {
        final supervisor = buildSupervisor();
        final stopped = ofType<TunnelStopped>(
          supervisor.events,
        ).first.timeout(const Duration(seconds: 5));

        final startFuture = supervisor.start(quickConfig);
        await awaitSpawn(1);
        fakes.first.emitStdout('https://stop-me.trycloudflare.com');
        await startFuture;

        await supervisor.stop(reason: 'operator interrupt');

        expect(fakes.first.killCalled, isTrue);
        await stopped;
        final record = await awaitState((r) => !r.running);
        expect(
          record.url,
          'https://stop-me.trycloudflare.com',
          reason: 'the URL stays resurfaced in state after a clean stop',
        );
        expect(supervisor.handle!.running, isFalse);
      },
    );

    test(
      'a start that never derives a URL times out and kills the process',
      () async {
        final supervisor = buildSupervisor(
          startTimeout: const Duration(milliseconds: 120),
        );
        await expectLater(
          supervisor.start(quickConfig),
          throwsA(isA<TunnelStartFailed>()),
        );
        expect(fakes.first.killCalled, isTrue);
        final record = await awaitState(
          (r) => !r.running && (r.failureReason?.isNotEmpty ?? false),
        );
        expect(record.failureReason, isNotEmpty);
      },
    );
  });

  group('TunnelSupervisor — named mode', () {
    const namedConfig = TunnelConfig(
      mode: TunnelMode.named,
      port: 8080,
      tunnelName: 'dws-playground',
      hostname: 'dws.example.com',
      credentialsFile: '/home/op/.cloudflared/dws.json',
    );

    test('start resolves with the declared hostname once registered', () async {
      final supervisor = buildSupervisor();
      final startFuture = supervisor.start(namedConfig);
      await awaitSpawn(1);
      fakes.first.emitStdout('INF Registered tunnel connection');

      final url = await startFuture;
      expect(url.toString(), 'https://dws.example.com');
      expect(spawned.single.arguments, contains('--credentials-file'));
      expect(
        spawned.single.arguments,
        contains('/home/op/.cloudflared/dws.json'),
      );
      expect(spawned.single.arguments, contains('dws-playground'));
    });

    test('a restart serves the SAME hostname (state carries it)', () async {
      final supervisor = buildSupervisor();
      final restarted = supervisor.events
          .firstWhere((e) => e is TunnelStarted && e.restart == 1)
          .timeout(const Duration(seconds: 10));

      final startFuture = supervisor.start(namedConfig);
      await awaitSpawn(1);
      fakes.first.emitStdout('INF Registered tunnel connection');
      final first = await startFuture;

      fakes.first.exitWith(1);
      await awaitSpawn(2);
      fakes.last.emitStdout('INF Registered tunnel connection');
      await restarted;

      expect(
        supervisor.handle!.url,
        first,
        reason: 'named mode keeps the stable hostname across restarts',
      );
    });
  });

  group('TunnelSupervisor — token mode', () {
    const token = 'eyJtunneltoken';
    const tokenConfig = TunnelConfig(
      mode: TunnelMode.token,
      port: 8080,
      token: token,
    );

    test(
      'runs remotely-managed: the token rides the args, never the output',
      () async {
        final seen = <String>[];
        final supervisor = buildSupervisor(onOutput: seen.add);
        final startFuture = supervisor.start(tokenConfig);
        await awaitSpawn(1);
        fakes.first.emitStdout('INF Registered tunnel connection');
        // A log line that would leak the token.
        fakes.first.emitStderr('INF exec --token $token');

        final url = await startFuture;
        expect(url, isNull, reason: 'a token tunnel has no local URL contract');
        expect(spawned.single.arguments, contains('--token'));
        expect(
          spawned.single.arguments,
          contains(token),
          reason: 'the real binary needs the real token',
        );
        expect(
          seen.join('\n'),
          isNot(contains(token)),
          reason: 'SC-005: no token ever reaches the output surface',
        );
      },
    );
  });
}
