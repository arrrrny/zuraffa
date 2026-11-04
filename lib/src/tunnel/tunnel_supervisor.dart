/// The tunnel lifecycle (specs/1724-zuraffa-tunnel - issue #2045, FR-001/
/// 002/003/006/008).
///
/// Spawns the cloudflared process around the declared origin, derives the
/// public URL (quick) or the registration signal (named/token), restarts
/// with capped exponential backoff when the process dies, and owns the
/// persisted state record. The wrapper is the ONE owner of both lifetimes
/// (tunnel process and, at the command level, the wrapped app).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'tunnel_config.dart';
import 'tunnel_secrets.dart';
import 'tunnel_state.dart';
import 'tunnel_url_parser.dart';

/// A started tunnel process, abstracted so tests can script it.
abstract interface class ManagedProcess {
  int? get pid;
  Stream<String> get stdoutLines;
  Stream<String> get stderrLines;
  Future<int> get exitCode;
  bool kill();
}

/// Spawns the tunnel binary. Injectable so tests stay hermetic.
typedef TunnelProcessFactory =
    Future<ManagedProcess> Function(String executable, List<String> arguments);

/// The real seam: a dart:io [Process] with line-decoded streams.
class IoManagedProcess implements ManagedProcess {
  IoManagedProcess._(Process process) : _process = process;

  static Future<ManagedProcess> spawn(
    String executable,
    List<String> arguments,
  ) async => IoManagedProcess._(await Process.start(executable, arguments));

  final Process _process;

  @override
  int? get pid => _process.pid;

  @override
  Stream<String> get stdoutLines =>
      _process.stdout.transform(utf8.decoder).transform(const LineSplitter());

  @override
  Stream<String> get stderrLines =>
      _process.stderr.transform(utf8.decoder).transform(const LineSplitter());

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool kill() => _process.kill();
}

sealed class TunnelEvent {
  const TunnelEvent();
}

/// The tunnel is up: a quick URL was derived (or the named/token tunnel
/// registered with the edge). [restart] is 0 for the first raise.
class TunnelStarted extends TunnelEvent {
  const TunnelStarted({required this.url, this.restart = 0});

  final Uri? url;
  final int restart;
}

/// The process died and a restart is scheduled after [delay].
class TunnelRestarting extends TunnelEvent {
  const TunnelRestarting({
    required this.attempt,
    required this.delay,
    required this.reason,
  });

  final int attempt;
  final Duration delay;
  final String reason;
}

/// The restart budget was exhausted (or the initial start timed out).
class TunnelFailed extends TunnelEvent {
  const TunnelFailed({required this.reason});

  final String reason;
}

/// The wrapper shut the tunnel down on purpose.
class TunnelStopped extends TunnelEvent {
  const TunnelStopped({required this.reason});

  final String reason;
}

/// `start()` gave up before the tunnel ever came up.
class TunnelStartFailed implements Exception {
  const TunnelStartFailed(this.reason);

  final String reason;

  @override
  String toString() => 'TunnelStartFailed: $reason';
}

class TunnelHandle {
  TunnelHandle({required this.config}) : startedAt = DateTime.now();

  final TunnelConfig config;
  final DateTime startedAt;
  Uri? url;
  int? pid;
  int restarts = 0;
  bool running = false;

  /// Whether THIS launch has already raised the tunnel — reset on every
  /// (re)launch so the repeated-line guard below never eats the first
  /// raise of a launch (token mode raises with url == null, and a named
  /// restart serves the same hostname as the launch before it).
  bool raised = false;
}

class TunnelSupervisor {
  TunnelSupervisor({
    required this.cloudflaredPath,
    TunnelProcessFactory? processFactory,
    TunnelUrlParser? urlParser,
    TunnelState? state,
    this.backoffBase = const Duration(milliseconds: 500),
    this.backoffCap = const Duration(seconds: 8),
    this.maxRestarts = 5,
    this.startTimeout = const Duration(seconds: 45),
    void Function(String line)? onOutput,
  }) : _processFactory = processFactory ?? IoManagedProcess.spawn,
       _urlParser = urlParser ?? const TunnelUrlParser(),
       _state = state,
       _onOutput = onOutput;

  final String cloudflaredPath;
  final TunnelProcessFactory _processFactory;
  final TunnelUrlParser _urlParser;
  final TunnelState? _state;
  final void Function(String line)? _onOutput;

  /// Backoff schedule: base * 2^(attempt-1), capped.
  final Duration backoffBase;
  final Duration backoffCap;
  final int maxRestarts;

  /// How long `start()` waits for the first raise before giving up.
  final Duration startTimeout;

  final _events = StreamController<TunnelEvent>.broadcast();
  Stream<TunnelEvent> get events => _events.stream;

  TunnelHandle? _handle;
  TunnelHandle? get handle => _handle;

  ManagedProcess? _process;
  bool _stopping = false;

  /// Persist calls are serialized behind this chain: `_raise` is fired
  /// unawaited, so an unserialized write could complete AFTER a later
  /// stop/failure write and leave the record claiming `running: true` for
  /// a tunnel that is down. Call order is enqueue order; errors never
  /// break the chain (they are handled in [_persist]).
  Future<void> _persistQueue = Future<void>.value();

  /// Spawns the tunnel and resolves with the public URL once raised
  /// (`null` for token mode, which has no local URL contract). Throws
  /// [TunnelStartFailed] on the start timeout.
  Future<Uri?> start(TunnelConfig config) {
    final completer = Completer<Uri?>();
    _handle = TunnelHandle(config: config);
    _stopping = false;
    // A spawn failure (executable missing its +x bit, a wrapped binary that
    // cannot launch) throws ProcessException from the factory — routed to
    // `_fail` here so it is a recorded failure with a remediation, never an
    // uncaught async error on an unawaited future.
    unawaited(
      _launch(config, 0, completer).catchError((Object e) async {
        final reason = 'could not start cloudflared: $e';
        await _fail(config, reason);
        if (!completer.isCompleted) {
          completer.completeError(TunnelStartFailed(reason));
        }
      }),
    );
    Timer(startTimeout, () {
      unawaited(() async {
        if (completer.isCompleted || _stopping) return;
        final reason =
            'the tunnel did not come up within '
            '${startTimeout.inSeconds}s (start timeout)';
        await _fail(config, reason);
        if (!completer.isCompleted) {
          completer.completeError(TunnelStartFailed(reason));
        }
      }());
    });
    return completer.future;
  }

  /// Shuts the tunnel down on purpose (FR-008). Idempotent.
  Future<void> stop({String reason = 'interrupted'}) async {
    if (_stopping) return;
    _stopping = true;
    final process = _process;
    final handle = _handle;
    if (handle != null) {
      handle.running = false;
    }
    if (process != null) {
      process.kill();
      // Give the process a grace window to exit; SIGKILL is not reachable
      // through [ManagedProcess] and a wedged kill is surfaced by the
      // caller's timeout, not silently swallowed here.
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () => -1,
      );
    }
    await _persist(
      _handle?.config,
      url: _handle?.url?.toString(),
      failureReason: null,
      running: false,
    );
    _events.add(TunnelStopped(reason: reason));
  }

  Future<void> _launch(
    TunnelConfig config,
    int restart,
    Completer<Uri?>? firstStart,
  ) async {
    final process = await _processFactory(cloudflaredPath, _argsFor(config));
    _process = process;
    final handle = _handle!;
    handle.pid = process.pid;
    handle.running = true;
    handle.raised = false;

    final lineSubscriptions = <StreamSubscription<String>>[
      process.stdoutLines.listen(
        (line) => _handleLine(line, config, restart, firstStart),
      ),
      process.stderrLines.listen(
        (line) => _handleLine(line, config, restart, firstStart),
      ),
    ];

    unawaited(
      process.exitCode.then((_) async {
        for (final sub in lineSubscriptions) {
          await sub.cancel();
        }
        if (_stopping) return; // a deliberate stop, not a death
        await _onDeath(config, restart, firstStart);
      }),
    );
  }

  Future<void> _onDeath(
    TunnelConfig config,
    int restart,
    Completer<Uri?>? firstStart,
  ) async {
    if (_stopping) return;
    final attempt = restart + 1;
    if (attempt > maxRestarts) {
      final reason =
          'the tunnel process kept dying — restart budget exhausted '
          'after ${_handle!.restarts} restart(s)';
      await _fail(config, reason);
      if (firstStart != null && !firstStart.isCompleted) {
        firstStart.completeError(TunnelStartFailed(reason));
      }
      return;
    }
    final delay = _backoff(attempt);
    _handle!.restarts = attempt;
    _events.add(
      TunnelRestarting(
        attempt: attempt,
        delay: delay,
        reason: 'the tunnel process exited unexpectedly',
      ),
    );
    await Future<void>.delayed(delay);
    if (_stopping) return;
    // The restart path carries the same spawn-failure guard as the first
    // launch — a ProcessException here must fail the tunnel (recorded via
    // `_fail`), not surface as an uncaught async error on the exitCode
    // callback's future.
    try {
      await _launch(config, attempt, firstStart);
    } on Object catch (e) {
      final reason =
          'could not restart cloudflared after '
          '$attempt failure(s): $e';
      await _fail(config, reason);
      if (firstStart != null && !firstStart.isCompleted) {
        firstStart.completeError(TunnelStartFailed(reason));
      }
    }
  }

  Duration _backoff(int attempt) {
    var milliseconds = backoffBase.inMilliseconds << (attempt - 1);
    if (milliseconds > backoffCap.inMilliseconds || milliseconds < 0) {
      milliseconds = backoffCap.inMilliseconds;
    }
    return Duration(milliseconds: milliseconds);
  }

  void _handleLine(
    String rawLine,
    TunnelConfig config,
    int restart,
    Completer<Uri?>? firstStart,
  ) {
    final line = TunnelSecrets.redact(rawLine, _secretsFor(config));
    _onOutput?.call(line);
    if (config.mode == TunnelMode.quick) {
      final url = _urlParser.parse(line);
      if (url != null) {
        unawaited(_raise(config, restart, url, firstStart));
      }
      return;
    }
    // named / token: cloudflared logs this exact signal when the tunnel is
    // serving on the edge.
    if (line.toLowerCase().contains('registered tunnel connection')) {
      final url = config.mode == TunnelMode.named && config.hostname != null
          ? Uri.parse('https://${config.hostname}')
          : null;
      unawaited(_raise(config, restart, url, firstStart));
    }
  }

  /// Marks the tunnel as raised. The state record is flushed BEFORE the
  /// event/first-start resolution: an operator (or test) that hears "tunnel
  /// up" can rely on `.zfa/tunnel/state.json` already carrying the URL.
  Future<void> _raise(
    TunnelConfig config,
    int restart,
    Uri? url,
    Completer<Uri?>? firstStart,
  ) async {
    final handle = _handle!;
    if (handle.raised) {
      return; // idempotent against repeated raise lines within one launch
    }
    handle.raised = true;
    handle.url = url;
    handle.running = true;
    await _persist(
      config,
      url: url?.toString(),
      failureReason: null,
      running: true,
      lastRestartAt: restart > 0,
    );
    _events.add(TunnelStarted(url: url, restart: restart));
    if (firstStart != null && !firstStart.isCompleted) {
      firstStart.complete(url);
    }
  }

  /// Fails the supervisor: state first, then the event, then (for a start
  /// still in flight) the error.
  Future<void> _fail(TunnelConfig config, String reason) async {
    _stopping = true;
    _process?.kill();
    _handle?.running = false;
    await _persist(
      config,
      url: _handle?.url?.toString(),
      failureReason: reason,
      running: false,
    );
    _events.add(TunnelFailed(reason: reason));
  }

  Future<void> _persist(
    TunnelConfig? config, {
    required String? url,
    required String? failureReason,
    required bool running,
    bool lastRestartAt = false,
  }) {
    final state = _state;
    final handle = _handle;
    if (state == null || config == null || handle == null) {
      return Future<void>.value();
    }
    // Serialized: every write waits behind the previous one, so a late
    // `_raise` flush can never land after a stop/failure flush and resurrect
    // `running: true` in the record.
    final write = _persistQueue.then((_) async {
      try {
        await state.save(
          TunnelStateRecord(
            mode: config.mode.name,
            port: config.port,
            url: url,
            pid: handle.pid,
            restarts: handle.restarts,
            startedAt: handle.startedAt,
            lastRestartAt: lastRestartAt ? DateTime.now() : null,
            failureReason: failureReason,
            running: running,
          ),
        );
      } on FileSystemException catch (e) {
        // State is observability, not the tunnel's lifeblood — a failed
        // write never takes a live tunnel down.
        _onOutput?.call('[tunnel] warning: could not persist tunnel state: $e');
      }
    });
    _persistQueue = write;
    return write;
  }

  List<String> _secretsFor(TunnelConfig config) => [
    if (config.token != null && config.token!.isNotEmpty) config.token!,
    if (config.credentialsFile != null && config.credentialsFile!.isNotEmpty)
      config.credentialsFile!,
  ];

  /// FR-009: the argv carries exactly the declared loopback origin — never
  /// a wildcard or a second port.
  List<String> _argsFor(TunnelConfig config) {
    final origin = 'http://${config.host}:${config.port}';
    switch (config.mode) {
      case TunnelMode.quick:
        return ['tunnel', '--url', origin, '--no-autoupdate'];
      case TunnelMode.named:
        return [
          'tunnel',
          'run',
          '--url',
          origin,
          '--credentials-file',
          config.credentialsFile!,
          config.tunnelName!,
        ];
      case TunnelMode.token:
        // Remotely-managed: ingress lives in the Cloudflare dashboard, so
        // no origin flag is passed (docs/tunnel.md covers the recipe).
        return ['tunnel', 'run', '--token', config.token!];
    }
  }
}
