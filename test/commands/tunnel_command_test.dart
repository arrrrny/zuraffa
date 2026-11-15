import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';
import 'package:zuraffa/src/commands/tunnel_command.dart';
import 'package:zuraffa/src/plugins/tunnel/tunnel_plugin.dart';
import 'package:zuraffa/src/tunnel/cloudflared_locator.dart';
import 'package:zuraffa/src/tunnel/endpoint_auth_probe.dart';
import 'package:zuraffa/src/tunnel/tunnel_state.dart';
import 'package:zuraffa/src/tunnel/tunnel_supervisor.dart';

/// `zfa tunnel` command-level behavior: usage/validation refusals, the
/// unauthenticated-endpoint guard, status, and the guarded happy path with
/// an injected fake cloudflared. The tunnel LIFECYCLE itself (spawn, URL
/// discovery, restart) is covered by `test/tunnel/tunnel_supervisor_test.dart`.
void main() {
  late CliRunner runner;
  late Directory tmp;
  HttpServer? server;

  setUp(() async {
    runner = CliRunner(exitOnCompletion: false);
    tmp = await Directory.systemTemp.createTemp('tunnel_command_');
    await File(
      p.join(tmp.path, 'pubspec.yaml'),
    ).writeAsString('name: sandbox\nenvironment:\n  sdk: \'>=3.0.0 <4.0.0\'\n');
  });

  tearDown(() async {
    exitCode = 0;
    if (server != null) {
      try {
        await server!.close(force: true);
      } on StateError {
        // already closed
      }
    }
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<String> drive(List<String> args) =>
      runner.runCapturing(['-C', tmp.path, 'tunnel', ...args]);

  /// A local endpoint answering [status] to everything.
  Future<int> serve(int status) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server!.listen((request) async {
      request.response.statusCode = status;
      await request.response.close();
    });
    return server!.port;
  }

  /// A port that refuses connections (bound, then released).
  Future<int> deadPort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  group('zfa tunnel — usage and refusals (never reach cloudflared)', () {
    test(
      'bare invocation is a usage refusal listing the subcommands',
      () async {
        final out = await drive([]);
        // package:args refuses a parent command without its subcommand.
        expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage);
        expect(out, contains('run'));
        expect(out, contains('status'));
      },
    );

    test('run without --port is a usage refusal', () async {
      final out = await drive(['run']);
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage);
      expect(out, contains('--port'));
      expect(out, contains('--> fix:'));
    });

    test('run with an out-of-range port is a usage refusal', () async {
      final out = await drive(['run', '--port', '0']);
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage);
      expect(out, contains('--> fix:'));

      await drive(['run', '--port', '70000']);
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage);
    });

    test('named mode missing its requirements names them all', () async {
      final port = await serve(HttpStatus.ok);
      final out = await drive([
        'run',
        '--port',
        '$port',
        '--mode',
        'named',
        '--i-know-its-unauthenticated',
      ]);
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage);
      expect(out, contains('--tunnel-name'));
      expect(out, contains('--hostname'));
      expect(out, contains('--credentials-file'));
    });

    test(
      'an unauthenticated endpoint is refused with the override named',
      () async {
        final port = await serve(HttpStatus.ok);
        final out = await drive(['run', '--port', '$port']);
        expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage);
        expect(out, contains('--i-know-its-unauthenticated'));
        expect(out, contains('--> fix:'));
      },
    );

    test(
      'a dead endpoint is an operational failure, not a usage error',
      () async {
        final port = await deadPort();
        final out = await drive(['run', '--port', '$port']);
        expect(CliRunner.lastDispatchedExitCode, ExitProtocol.failure);
        expect(out, contains('--> fix:'));
      },
    );

    test('status without recorded state says so and exits 1', () async {
      final out = await drive(['status']);
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.failure);
      expect(out, contains('--> fix:'));
    });

    test('with recorded state it reports mode, port and url', () async {
      final stateFile = File(p.join(tmp.path, '.zfa', 'tunnel', 'state.json'));
      await stateFile.create(recursive: true);
      await stateFile.writeAsString(
        jsonEncode({
          'mode': 'quick',
          'port': 8080,
          // A loopback dead port keeps the live-check hermetic: connection
          // refused, offline, instant.
          'url': 'http://127.0.0.1:1',
          'pid': 1234,
          'restarts': 0,
          'startedAt': '2026-11-04T10:00:00.000Z',
          'running': false,
        }),
      );
      // The recorded URL is unreachable here (no cloudflared) — status is a
      // REPORT: it must still exit 0 and say the tunnel is not reachable.
      final out = await drive(['status']);
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.success);
      expect(out, contains('quick'));
      expect(out, contains('8080'));
      expect(out, contains('http://127.0.0.1:1'));
      expect(out, contains('unreachable'));
    });
  });

  // Tagged `spawn` (#2092): wrap mode launches a REAL child (`sleep 30`)
  // through the command, so this group needs the 8x loaded-host budget
  // (240s) rather than the bare root ceiling. The B12 census cannot see that
  // spawn — it lives in the lib, not in this file — and pin B14 keeps the
  // tag from drifting away again.
  group('zfa tunnel — guarded happy path (injected fake cloudflared)', () {
    late FakeTunnelProcess fake;
    late Completer<void> interrupt;

    setUp(() {
      fake = FakeTunnelProcess();
      interrupt = Completer<void>();
    });

    Future<({int exit, String output})> runDirect(
      List<String> args, {
      EndpointProbeResult probeResult = EndpointProbeResult.unauthenticated,
    }) async {
      final buffer = StringBuffer();
      // The command resolves its TunnelState from Directory.current at
      // construction — chdir into the sandbox BEFORE building it (the
      // CliRunner path does this via -C).
      final prior = Directory.current;
      Directory.current = tmp.path;
      try {
        final cr = CommandRunner<void>('zfa-test', 'test')
          ..addCommand(
            TunnelCommand(
              TunnelPlugin(outputDir: 'lib/src'),
              locator: StubLocator('/fake/cloudflared'),
              probe: EndpointProbeStub(probeResult),
              processFactory: (executable, arguments) async => fake,
              interrupt: interrupt,
            ),
          );
        final exit = await runZoned(
          () => cr.run(['tunnel', ...args]).then((_) => exitCode),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => buffer.writeln(line),
          ),
        );
        return (exit: exit, output: buffer.toString());
      } finally {
        Directory.current = prior;
      }
    }

    test(
      'override + guard pass + URL raised + interrupt shuts everything down',
      () async {
        final port = await serve(HttpStatus.ok);
        final run = runDirect([
          'run',
          '--port',
          '$port',
          '--i-know-its-unauthenticated',
        ]);
        // Give the run a moment to raise the tunnel, then interrupt.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(fake.killCalled, isFalse, reason: 'still serving mid-run');
        interrupt.complete();
        final result = await run.timeout(const Duration(seconds: 10));

        expect(result.exit, ExitProtocol.success);
        expect(
          result.output,
          contains('https://quick-words-here.trycloudflare.com'),
          reason: 'the raised URL is surfaced to the operator',
        );
        expect(
          fake.killCalled,
          isTrue,
          reason: 'clean shutdown kills the tunnel process',
        );
        final record = TunnelState(projectRoot: tmp.path).read();
        expect(record, isNotNull);
        expect(record!.running, isFalse);
      },
    );

    test('the token never reaches the output surface (SC-005)', () async {
      final port = await serve(HttpStatus.unauthorized);
      const token = 'eyJcommandtesttoken';
      final run = runDirect([
        'run',
        '--port',
        '$port',
        '--mode',
        'token',
        '--token',
        token,
      ], probeResult: EndpointProbeResult.authenticated);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      interrupt.complete();
      final result = await run.timeout(const Duration(seconds: 10));

      expect(result.exit, ExitProtocol.success);
      expect(result.output, isNot(contains(token)));
    });

    // One startup budget for BOTH waits below: the handshake and the run
    // share it (review #2093), because a per-wait budget lets the handshake
    // give up while the run is still legitimately starting up — a 16s spawn
    // then failed the `raised` assertion although the run itself completed
    // fine, and raising only the run timeout never extended the handshake.
    const startup = Duration(seconds: 60);

    test(
      'wrap mode: an interrupt stops the tunnel AND kills the app',
      () async {
        // The test's server holds the port; the "wrapped app" is a bare
        // sleeper. The run must treat the interrupt as a shutdown source even
        // in wrap mode — otherwise SIGINT/SIGTERM hit the VM's default
        // disposition and orphan cloudflared AND the wrapped app.
        final port = await serve(HttpStatus.ok);
        // The wrapped child must OUTLIVE the startup budget: the command
        // races the app's exit against the interrupt (Future.any over
        // appExitedFirst / stopSignal / failed), so a child that exits mid-
        // handshake — the old fixed `sleep 30` against a 60s budget — hands
        // the run the app-exit branch and the interrupt assertion below
        // fails even though startup stayed within budget (review #2093).
        // Derive the lifetime from `startup` so the two cannot drift; the
        // child is killed on the shutdown path regardless, so the extra
        // minute is only a guard against that race.
        final childLifetime = startup.inSeconds + 60;
        final run = runDirect([
          'run',
          '--port',
          '$port',
          '--i-know-its-unauthenticated',
          '--',
          'sleep',
          '$childLifetime',
        ]);
        // Handshake, not a guess (#2092): interrupt only once the wrapper has
        // RECORDED the tunnel as running. A fixed sleep put the interrupt
        // wherever host speed happened to leave startup, so a loaded host
        // reported an opaque exit-code mismatch instead of the real cause.
        final raised = await _waitForTunnelUp(run, tmp.path, bound: startup);
        // The interrupt also settles the FAILURE path: a run that never
        // opened the tunnel (a refused spawn) is shut down here instead of
        // holding the wrapped `sleep` child until the suite's own ceiling.
        interrupt.complete();
        final result = await run.timeout(startup);

        expect(
          raised,
          isTrue,
          reason:
              'the tunnel never came up, so there was nothing to interrupt — '
              'the run exited ${result.exit} and printed:\n${result.output}',
        );
        expect(result.exit, ExitProtocol.success);
        expect(
          result.output,
          contains('tunnel shut down (interrupt)'),
          reason: 'the interrupt was observed in wrap mode too',
        );
        expect(fake.killCalled, isTrue, reason: 'the tunnel is stopped too');
        final record = TunnelState(projectRoot: tmp.path).read();
        expect(record, isNotNull);
        expect(record!.running, isFalse);
        expect(result.output, isNot(contains('❌')));
      },
    );
  }, tags: ['spawn']);

  // Issue #2092: the wrap-mode startup gets ONE more attempt when the spawn
  // itself was refused (EAGAIN / EMFILE — the loaded-host spawn ceiling),
  // which used to end the run with `❌ the wrapped app command failed to
  // start` and exit 1. Pinned on the helper so the policy needs no real
  // child.
  group('spawnAppWithRetry', () {
    test(
      'a refused spawn is retried exactly once, then the refusal stands',
      () async {
        var attempts = 0;
        await expectLater(
          spawnAppWithRetry(
            (executable, arguments, {mode = ProcessStartMode.normal}) async {
              attempts++;
              throw ProcessException(
                executable,
                arguments,
                'Resource temporarily unavailable (os error 11)',
                11,
              );
            },
            const ['sleep', '30'],
            retryDelay: Duration.zero,
          ),
          throwsA(isA<ProcessException>()),
        );
        expect(
          attempts,
          2,
          reason: 'the refused spawn was retried exactly once',
        );
      },
    );

    test('a failure that is not a spawn refusal is not retried', () async {
      // Only a crowded host gets a second attempt — a programming error must
      // surface at once instead of being masked by a retry.
      var attempts = 0;
      await expectLater(
        spawnAppWithRetry(
          (executable, arguments, {mode = ProcessStartMode.normal}) async {
            attempts++;
            throw StateError('boom');
          },
          const ['sleep', '30'],
          retryDelay: Duration.zero,
        ),
        throwsA(isA<StateError>()),
      );
      expect(attempts, 1, reason: 'a non-spawn failure was not retried');
    });
  });
}

/// Waits (bounded by [bound]) for the wrapper to RECORD the tunnel as running
/// — the observable "the tunnel is up" handshake, and the honest moment to
/// interrupt. Returns `false` when the run settles first (its own verdict is
/// then the interesting one, and reporting it beats a bare timeout) or when
/// [bound] elapses. Pass the SAME budget the caller gives the run wait: a
/// shorter handshake bound than the run budget makes a slow startup report a
/// false "nothing to interrupt" (review #2093).
Future<bool> _waitForTunnelUp(
  Future<({int exit, String output})> run,
  String projectRoot, {
  Duration bound = const Duration(seconds: 60),
}) async {
  final settled = Completer<void>();
  unawaited(run.then<void>((_) => settled.complete()));
  final deadline = DateTime.now().add(bound);
  while (DateTime.now().isBefore(deadline)) {
    final record = TunnelState(projectRoot: projectRoot).read();
    if (record != null && record.running) return true;
    if (settled.isCompleted) return false;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return false;
}

class FakeTunnelProcess implements ManagedProcess {
  @override
  final int pid = 4242;

  final _exit = Completer<int>();
  bool killCalled = false;

  @override
  Stream<String> get stdoutLines => Stream<String>.fromIterable(const [
    // Quick mode parses the URL; token mode takes the registration line —
    // one fake serves both modes.
    '|  https://quick-words-here.trycloudflare.com  |',
    'INF Registered tunnel connection',
  ]);

  @override
  Stream<String> get stderrLines => const Stream<String>.empty();

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill() {
    killCalled = true;
    if (!_exit.isCompleted) _exit.complete(0);
    return true;
  }
}

/// Endpoint probe with a scripted answer — the command-level tests own the
/// guard decision, not the network.
class EndpointProbeStub implements EndpointAuthProbe {
  EndpointProbeStub(this.result);
  final EndpointProbeResult result;

  @override
  Future<EndpointProbeResult> probe(
    Uri target, {
    HttpClient? client,
    Duration timeout = const Duration(seconds: 5),
  }) async => result;
}

/// A locator with a scripted answer — no binary is ever touched on disk.
class StubLocator extends CloudflaredLocator {
  StubLocator(this.path);
  final String path;

  @override
  CloudflaredInfo? locate() => CloudflaredInfo(path: path, version: 'test');
}
