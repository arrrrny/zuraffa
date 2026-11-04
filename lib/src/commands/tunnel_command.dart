import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli/exit_protocol.dart';
import '../tunnel/cloudflared_locator.dart';
import '../tunnel/endpoint_auth_probe.dart';
import '../tunnel/tunnel_config.dart';
import '../tunnel/tunnel_state.dart';
import '../tunnel/tunnel_supervisor.dart';
import 'base_plugin_command.dart';

/// `zfa tunnel` — wrap a Zuraffa app (or any local HTTP surface) for remote
/// access via a Cloudflare tunnel (specs/1724-zuraffa-tunnel, issue #2045).
///
///  * `zfa tunnel run --port <n> [--mode quick|named|token] [flags]
///     [-- <app start command…>]` — raises the tunnel in the foreground and
///     prints the public URL; ctrl-c (or the wrapped app exiting) shuts
///     everything down cleanly.
///  * `zfa tunnel status` — reports the recorded tunnel state under
///     `.zfa/tunnel/state.json` and live-checks the recorded URL.
///
/// Security posture (FR-004): an endpoint that does not answer an
/// authentication challenge is refused unless
/// `--i-know-its-unauthenticated` is passed. Secrets (FR-003) are never
/// printed: the supervisor redacts them from every output line.
class TunnelCommand extends PluginCommand {
  TunnelCommand(
    super.plugin, {
    CloudflaredLocator? locator,
    EndpointAuthProbe? probe,
    TunnelProcessFactory? processFactory,
    TunnelState? state,
    Completer<void>? interrupt,
  }) : _locator = locator ?? const CloudflaredLocator(),
       _probe = probe ?? const EndpointAuthProbe(),
       _processFactory = processFactory,
       _state = state,
       _interrupt = interrupt {
    addSubcommand(
      _TunnelRunCommand(
        locator: _locator,
        probe: _probe,
        processFactory: _processFactory,
        state: _state,
        interrupt: _interrupt,
      ),
    );
    addSubcommand(_TunnelStatusCommand(state: _state));
  }

  final CloudflaredLocator _locator;
  final EndpointAuthProbe _probe;
  final TunnelProcessFactory? _processFactory;
  final TunnelState? _state;
  final Completer<void>? _interrupt;

  @override
  String get name => 'tunnel';

  @override
  String get description =>
      'Wrap a local app port with a Cloudflare tunnel — an ephemeral '
      'trycloudflare.com URL (quick mode, zero config) or a user-defined '
      'named hostname (issue #2045). Composes with `zfa mcp serve` for a '
      'web-based MCP.';

  @override
  Future<void> run() async {
    print(usage);
  }
}

class _TunnelRunCommand extends Command<void> {
  _TunnelRunCommand({
    required CloudflaredLocator locator,
    required EndpointAuthProbe probe,
    TunnelProcessFactory? processFactory,
    TunnelState? state,
    Completer<void>? interrupt,
  }) : _locator = locator,
       _probe = probe,
       _processFactory = processFactory,
       _state = state ?? TunnelState(),
       _interrupt = interrupt {
    argParser.addOption(
      'port',
      help: 'The ONLY local port to expose (1-65535). Required.',
    );
    argParser.addOption(
      'mode',
      allowed: ['quick', 'named', 'token'],
      defaultsTo: 'quick',
      help:
          'quick: ephemeral trycloudflare.com URL (zero config). '
          'named: user-defined DNS with a credentials file. '
          'token: remotely-managed named tunnel (dashboard-configured).',
    );
    argParser.addOption(
      'host',
      defaultsTo: 'localhost',
      help: 'Loopback origin host (never a wildcard bind).',
    );
    argParser.addOption('tunnel-name', help: 'Named mode: the tunnel name.');
    argParser.addOption(
      'hostname',
      help: 'Named mode: the public DNS hostname.',
    );
    argParser.addOption(
      'credentials-file',
      help: 'Named mode: path to the tunnel credentials JSON.',
    );
    argParser.addOption(
      'token',
      help: 'Token mode: the Cloudflare-issued tunnel token (never logged).',
    );
    argParser.addFlag(
      'i-know-its-unauthenticated',
      negatable: false,
      help: 'Explicit override for the unauthenticated-endpoint guard.',
    );
  }

  final CloudflaredLocator _locator;
  final EndpointAuthProbe _probe;
  final TunnelProcessFactory? _processFactory;
  final TunnelState _state;
  final Completer<void>? _interrupt;

  static const _wrapWindow = Duration(seconds: 30);

  @override
  String get name => 'run';

  @override
  String get description =>
      'Raise the tunnel around --port and keep it up until interrupted.';

  @override
  String get invocation =>
      'zfa tunnel run --port <n> [--mode quick|named|token] [flags] '
      '[-- <app start command…>]';

  @override
  Future<void> run() async {
    final args = argResults!;
    final port = int.tryParse(args['port'] as String? ?? '');
    if (port == null) {
      _usageRefusal(
        '--port is required — the tunnel scope is always exactly one '
            'declared local port.',
        'zfa tunnel run --port <1-65535> [--mode quick|named|token]',
      );
      return;
    }
    final config = TunnelConfig(
      mode: TunnelMode.values.byName(args['mode'] as String),
      port: port,
      host: args['host'] as String? ?? 'localhost',
      tunnelName: args['tunnel-name'] as String?,
      hostname: args['hostname'] as String?,
      credentialsFile: args['credentials-file'] as String?,
      token: args['token'] as String?,
      allowUnauthenticated:
          args['i-know-its-unauthenticated'] as bool? ?? false,
    );
    final errors = config.validationErrors();
    if (errors.isNotEmpty) {
      _usageRefusal(
        'invalid tunnel configuration:\n${errors.map((e) => '  - $e').join('\n')}',
        _fixLineFor(config),
      );
      return;
    }

    // FR-010: wrap mode — start the app, await its port, then raise the
    // tunnel. Attach mode: probe whatever is already listening.
    Process? appProcess;
    if (args.rest.isNotEmpty) {
      final opened = await _startWrappedApp(args.rest, config);
      if (opened == null) {
        exitCode = ExitProtocol.failure;
        return;
      }
      appProcess = opened;
    }
    final appExitedFirst = Completer<void>();
    if (appProcess != null) {
      unawaited(
        appProcess.exitCode.then((_) {
          if (!appExitedFirst.isCompleted) appExitedFirst.complete();
        }),
      );
    }

    final probeResult = await _probe.probe(config.target);
    if (probeResult == EndpointProbeResult.unreachable) {
      await _kill(appProcess);
      print(
        '❌ nothing is listening on ${config.target} — there is no local '
        'surface to tunnel.\n'
        '--> fix: start the app first (or wrap it: `zfa tunnel run '
        '--port <n> -- <app start command…>`), then re-run.',
      );
      exitCode = ExitProtocol.failure;
      return;
    }
    if (probeResult == EndpointProbeResult.unresponsive) {
      await _kill(appProcess);
      print(
        '❌ something IS listening on ${config.target}, but it never answered '
        'a plain GET — the probe cannot verify an authentication challenge '
        'there.\n'
        '--> fix: check the endpoint answers a GET (an MCP streamable '
        'endpoint speaks POST); if it is intentionally unauthenticated, '
        'pass --i-know-its-unauthenticated.',
      );
      exitCode = ExitProtocol.failure;
      return;
    }
    if (probeResult == EndpointProbeResult.unauthenticated &&
        !config.allowUnauthenticated) {
      await _kill(appProcess);
      print(
        '❌ ${config.target} answered without an authentication challenge — '
        'tunneling it would publish an open service to the internet.\n'
        '--> fix: enable auth on the app (e.g. `zfa mcp serve --token <t>`), '
        'or pass --i-know-its-unauthenticated if you accept the risk.',
      );
      exitCode = ExitProtocol.usage;
      return;
    }

    final info = _locator.locate();
    if (info == null) {
      await _kill(appProcess);
      print('❌ ${CloudflaredLocator.installRemediation}');
      exitCode = ExitProtocol.failure;
      return;
    }

    final supervisor = TunnelSupervisor(
      cloudflaredPath: info.path,
      processFactory: _processFactory,
      state: _state,
    );
    final Uri? url;
    try {
      url = await supervisor.start(config);
    } on TunnelStartFailed catch (e) {
      await _kill(appProcess);
      print(
        '❌ tunnel failed to come up: ${e.reason}\n'
        '--> fix: re-run `zfa tunnel run` once the tunnel binary and the '
        'local endpoint are healthy (see `zfa tunnel status`).',
      );
      exitCode = ExitProtocol.failure;
      return;
    }

    final versionSuffix = info.version == null ? '' : ' (${info.version})';
    print(
      '🌐 tunnel up$versionSuffix — '
      '${url?.toString() ?? 'remotely-managed named tunnel (hostname is '
              'configured in the Cloudflare dashboard)'}',
    );
    print('   forwarding ${config.target} — ctrl-c to shut everything down.');

    // FR-008: one owner owns both lifetimes. The tunnel dies when the
    // wrapped app exits; the app dies when the wrapper is interrupted or
    // the tunnel fails for good. Race ALL THREE shutdown sources and
    // subscribe to the event stream before the wait: waiting on app exit
    // alone left SIGINT/SIGTERM on the VM's default disposition (cloudflared
    // and the app orphaned, state claiming running: true), and a spent
    // restart budget produced a TunnelFailed nobody observed — the command
    // hung with a dead tunnel and exit code 0.
    TunnelFailed? failure;
    final failed = Completer<_ShutdownCause>();
    final eventSub = supervisor.events.listen((event) {
      if (event is TunnelFailed && !failed.isCompleted) {
        failure = event;
        failed.complete(_ShutdownCause.tunnelFailed);
      }
    });
    // An injected interrupt (tests, embedders) or a real signal — watching
    // the OS signals here is what takes them off the VM's default kill.
    final interrupt = _interrupt;
    final stopSignal = interrupt != null
        ? interrupt.future
        : Future.any([
            ProcessSignal.sigint.watch().first,
            ProcessSignal.sigterm.watch().first,
          ]);
    final cause = await Future.any<_ShutdownCause>([
      if (appProcess != null)
        appExitedFirst.future.then((_) => _ShutdownCause.appExit),
      stopSignal.then((_) => _ShutdownCause.interrupt),
      failed.future,
    ]);
    await eventSub.cancel();

    if (cause == _ShutdownCause.tunnelFailed) {
      // The supervisor already killed cloudflared and recorded the failure
      // (_fail: state flushed before the event) — the wrapped app is the
      // only process left to own.
      await _kill(appProcess);
      print(
        '❌ the tunnel failed: ${failure?.reason}\n'
        '--> fix: see `zfa tunnel status` for the recorded failure, then '
        're-run `zfa tunnel run`.',
      );
      exitCode = ExitProtocol.failure;
      return;
    }
    final appExited = cause == _ShutdownCause.appExit;

    await supervisor.stop(
      reason: appExited ? 'the wrapped app exited' : 'operator interrupt',
    );
    if (!appExited) {
      await _kill(appProcess);
    }
    print('tunnel shut down (${appExited ? 'app exited' : 'interrupt'}).');
    exitCode = ExitProtocol.success;
  }

  void _usageRefusal(String message, String fix) {
    print('❌ $message\n--> fix: $fix');
    exitCode = ExitProtocol.usage;
  }

  String _fixLineFor(TunnelConfig config) => switch (config.mode) {
    TunnelMode.named =>
      'zfa tunnel run --port <n> --mode named --tunnel-name <name> '
          '--hostname <host> --credentials-file <path>',
    TunnelMode.token =>
      'zfa tunnel run --port <n> --mode token --token <cloudflare-tunnel-token>',
    TunnelMode.quick => 'zfa tunnel run --port <1-65535>',
  };

  /// Wrap mode: spawn [rest], await the declared port inside the bounded
  /// window (FR-010). Returns the started process, or `null` after printing
  /// the failure.
  Future<Process?> _startWrappedApp(
    List<String> rest,
    TunnelConfig config,
  ) async {
    final Process appProcess;
    try {
      // inheritStdio: the wrapped app's output belongs to the operator's
      // terminal, and an unread Pipe stdout/stderr fills the OS pipe buffer
      // (~64 KB) and blocks the app mid-write — the tunnel would serve a
      // stuck app.
      appProcess = await Process.start(
        rest.first,
        rest.skip(1).toList(),
        mode: ProcessStartMode.inheritStdio,
      );
    } on ProcessException catch (e) {
      print(
        '❌ the wrapped app command failed to start: ${e.executable}\n'
        '--> fix: pass a runnable command after `--`, e.g. `zfa tunnel run '
        '--port <n> -- dart run bin/server.dart`.',
      );
      return null;
    }
    final appExit = Completer<int>();
    unawaited(appProcess.exitCode.then(appExit.complete));
    final deadline = DateTime.now().add(_wrapWindow);
    while (DateTime.now().isBefore(deadline)) {
      if (appExit.isCompleted) {
        final code = await appExit.future;
        print(
          '❌ the wrapped app exited (code $code) before opening '
          '${config.target}.\n'
          '--> fix: check the app command; the port it listens on must '
          'match --port.',
        );
        return null;
      }
      if (await _portOpen(config.target)) {
        return appProcess;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await _kill(appProcess);
    print(
      '❌ the wrapped app did not open ${config.target} within '
      '${_wrapWindow.inSeconds}s.\n'
      '--> fix: make sure the app listens on --port before re-running.',
    );
    return null;
  }

  Future<bool> _portOpen(Uri target) async {
    try {
      final socket = await Socket.connect(
        target.host,
        target.port,
        timeout: const Duration(milliseconds: 500),
      );
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> _kill(Process? process) async {
    if (process == null) return;
    // kill() on an already-exited process is a harmless no-op (false).
    process.kill();
    await process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () => -1,
    );
  }
}

class _TunnelStatusCommand extends Command<void> {
  _TunnelStatusCommand({TunnelState? state}) : _state = state ?? TunnelState();

  final TunnelState _state;

  @override
  String get name => 'status';

  @override
  String get description =>
      'Report the recorded tunnel state (.zfa/tunnel/state.json) and '
      'live-check the recorded URL.';

  @override
  Future<void> run() async {
    final record = _state.read();
    if (record == null) {
      print(
        '❌ no tunnel has been recorded in this project yet '
        '(${_state.stateFilePath}).\n'
        '--> fix: raise one with `zfa tunnel run --port <n>`, then check '
        'status here.',
      );
      exitCode = ExitProtocol.failure;
      return;
    }
    print('mode: ${record.mode}');
    print('port: ${record.port}');
    print('running: ${record.running}');
    print('restarts: ${record.restarts}');
    print('started at: ${record.startedAt.toIso8601String()}');
    if (record.failureReason != null) {
      print('last failure: ${record.failureReason}');
    }
    if (record.url != null) {
      print('url: ${record.url}');
      print(
        'reachability: ${await _reachable(Uri.parse(record.url!)) ? 'reachable' : 'unreachable'}',
      );
    }
    exitCode = ExitProtocol.success;
  }

  Future<bool> _reachable(Uri url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client
          .openUrl('GET', url)
          .timeout(const Duration(seconds: 3));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      await response.drain<void>();
      // 530 = the Cloudflare edge reports NO active tunnel connector (error
      // 1033): the edge answered, not the tunneled app — a dead tunnel must
      // not report reachable.
      return response.statusCode != 530;
    } on Exception {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}

/// Which shutdown source won the three-way race in `tunnel run`.
enum _ShutdownCause { appExit, interrupt, tunnelFailed }
