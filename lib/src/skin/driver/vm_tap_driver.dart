/// VmTapDriver — the `zfa skin drive` engine (issue #1112).
///
/// Wraps `package:vm_service` against a live Dart VM — the VM service
/// `flutter run` (or the widget-test runner) exposes — enumerates the
/// target isolate's libraries, finds the one carrying the emitted
/// kit's driver seam, evaluates `debugTapAnchorJson('<anchor>')`, and
/// returns the parsed [TapResult]. The CLI prints that verdict's JSON
/// verbatim as its final stdout line — byte-identical on every host
/// OS, so agents can branch on it without host-specific parsing.
///
/// This is the pilot's proven driver, productized: synthetic clicks
/// (cliclick, CGEvent, AX press) never reached the Flutter macOS
/// view; `vm_service.evaluate` finding the anchor and invoking its
/// REAL onPressed does — the genuine engine flow on every platform.
library;

import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart' as vm_io;

import '../tap_result.dart';

/// The library-file suffix the emitted kit lands under in the target
/// app (the seam's canonical home).
const String kitLibrarySuffix = 'skin_contract_auditor.dart';

/// The evaluate expression template — [anchorExpr] is a safely quoted
/// Dart string literal.
String _evalExpression(String anchorExpr) => 'debugTapAnchorJson($anchorExpr)';

/// Quotes [value] as a single-quoted Dart string literal (the anchor
/// keys are simple identifiers, but the quoting keeps the evaluate
/// injection-proof regardless of what a caller passes).
String _dartStringLiteral(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\$', r'\$')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return "'$escaped'";
}

/// Converts a `dartUri` — the `http://127.0.0.1:PORT/TOKEN/` URI
/// `flutter run --print-dtd` / the VM banner prints — into the
/// WebSocket URI package:vm_service connects over. `ws://` and
/// `wss://` URIs pass through untouched.
Uri toWebSocketUri(Uri dartUri) {
  if (dartUri.scheme == 'ws' || dartUri.scheme == 'wss') {
    return dartUri;
  }
  if (dartUri.scheme != 'http' && dartUri.scheme != 'https') {
    throw FormatException(
      'unsupported VM service URI scheme: "${dartUri.scheme}" '
      '(expected http, https, ws or wss)',
    );
  }
  final wsScheme = dartUri.scheme == 'https' ? 'wss' : 'ws';
  var path = dartUri.path;
  if (path.isEmpty) {
    path = '/ws';
  } else if (path.endsWith('/')) {
    path = '${path}ws';
  } else if (!path.endsWith('ws')) {
    path = '$path/ws';
  }
  return dartUri.replace(scheme: wsScheme, path: path);
}

/// One drive: connect → locate the seam library → evaluate → verdict.
final class VmTapDriver {
  const VmTapDriver();

  /// Drives [anchor] against the live VM at [dartUri].
  ///
  /// Never throws for a drive failure — every failure mode is an
  /// honest [TapError] (the CLI maps it to exit 3); [TapNotFound] and
  /// [TapDisabled] are LIVE-VM verdicts (the app answered).
  ///
  /// The drive is a BOUNDED POLL, not a single shot: the driver
  /// resumes a paused-at-start runner (`flutter test --start-paused`,
  /// issue #1112's widget-test-runner lane) and keeps evaluating until
  /// the anchor answers [TapFound]/[TapDisabled] or [driveTimeout]
  /// elapses — a booting runner pumps its tree late, and an instant
  /// notFound there would be a false negative.
  static Future<TapResult> drive({
    required String dartUri,
    required String anchor,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration driveTimeout = const Duration(seconds: 20),
    void Function(String line)? log,
  }) async {
    final deadline = DateTime.now().add(driveTimeout);
    TapResult last = const TapError('drive never attempted');
    while (true) {
      last = await _attempt(
        dartUri: dartUri,
        anchor: anchor,
        connectTimeout: connectTimeout,
        log: log,
      );
      final settled = last is TapFound || last is TapDisabled;
      if (settled || DateTime.now().isAfter(deadline)) return last;
      log?.call(
        'verdict ${last.label} — target may still be booting; '
        'polling until ${driveTimeout.inSeconds}s deadline',
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  /// One connect → locate the seam library → evaluate pass.
  static Future<TapResult> _attempt({
    required String dartUri,
    required String anchor,
    required Duration connectTimeout,
    required void Function(String line)? log,
  }) async {
    final Uri wsUri;
    try {
      wsUri = toWebSocketUri(Uri.parse(dartUri.trim()));
    } on FormatException catch (e) {
      return TapError('invalid --dart-uri: ${e.message}');
    }

    vm.VmService? service;
    try {
      final connected = _connect(wsUri, log);
      service = await connected.timeout(
        connectTimeout,
        onTimeout: () => throw StateError(
          'timed out connecting to $wsUri after '
          '${connectTimeout.inSeconds}s',
        ),
      );
      final vmId = await service.getVM();
      final isolates = vmId.isolates ?? const <vm.IsolateRef>[];
      if (isolates.isEmpty) {
        return const TapError('the VM reports no isolates to drive');
      }
      log?.call('connected: ${isolates.length} isolate(s)');

      var lastEvalFailure = 'no library carried the driver seam';
      for (final isolateRef in isolates) {
        final isolateId = isolateRef.id;
        if (isolateId == null) continue;

        vm.Isolate? isolate;
        try {
          isolate = await service.getIsolate(isolateId);
        } on vm.RPCError catch (e) {
          // System/service isolates refuse getIsolate — skip honestly.
          lastEvalFailure = 'getIsolate failed: ${e.message}';
          continue;
        }
        final libraries = isolate.libraries ?? const <vm.LibraryRef>[];
        // The `flutter test --start-paused` lane boots PAUSED at start
        // — the test (and its kit seam) is not loaded until resumed.
        // A driver that refuses to resume would be useless there; a
        // live `flutter run` app is never paused, so this is a no-op
        // on that lane.
        final resumed = await _resumeIfPaused(service, isolate, log);
        final finalLibraries = resumed?.libraries ?? libraries;
        final candidates = _seamCandidates(finalLibraries);
        log?.call(
          'isolate $isolateId: ${libraries.length} library/libraries, '
          '${candidates.length} seam candidate(s)',
        );

        for (final lib in candidates) {
          final libId = lib.id;
          if (libId == null) continue;
          try {
            final response = await service.evaluate(
              isolateId,
              libId,
              _evalExpression(_dartStringLiteral(anchor)),
            );
            if (response is vm.InstanceRef) {
              final value = response.valueAsString;
              if (value == null) {
                lastEvalFailure =
                    'seam library ${lib.uri} returned a non-string instance';
                continue;
              }
              return TapResult.fromJsonString(value);
            }
            if (response is vm.ErrorRef) {
              lastEvalFailure = _brief(response.message ?? 'unknown error');
              continue;
            }
            lastEvalFailure =
                'seam library ${lib.uri} returned ${response.runtimeType}';
          } on vm.RPCError catch (e) {
            // EvaluationError == the function is not defined in THIS
            // library — try the next candidate.
            lastEvalFailure = _brief(e.message);
            continue;
          }
        }
      }
      return TapError(
        'debugTapAnchorJson seam not reachable: $lastEvalFailure. '
        'Is the target the debug build of an app that emitted the skin kit '
        '(zfa skin kit / zfa make --skin)?',
      );
    } catch (e) {
      return TapError('cannot connect to $wsUri: $e');
    } finally {
      try {
        await service?.dispose();
      } catch (_) {
        // The socket may already be gone — the verdict stands either way.
      }
    }
  }

  /// Resumes a paused-at-start (or paused-at-breakpoint) isolate and
  /// waits for it to run again — the `flutter test --start-paused`
  /// drive lane (issue #1112). Returns the refreshed isolate view.
  static Future<vm.Isolate?> _resumeIfPaused(
    vm.VmService service,
    vm.Isolate isolate,
    void Function(String line)? log,
  ) async {
    final kind = isolate.pauseEvent?.kind;
    final paused =
        kind == vm.EventKind.kPauseStart ||
        kind == vm.EventKind.kPauseBreakpoint ||
        kind == vm.EventKind.kPauseException;
    if (!paused) return isolate;
    log?.call('isolate is paused ($kind) — resuming');
    try {
      await service.resume(isolate.id!);
    } on vm.RPCError catch (e) {
      log?.call('resume refused: ${_brief(e.message)}');
      return isolate;
    }
    // Wait until the isolate reports running again (bounded).
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      try {
        final fresh = await service.getIsolate(isolate.id!);
        final freshKind = fresh.pauseEvent?.kind;
        if (freshKind != vm.EventKind.kPauseStart &&
            freshKind != vm.EventKind.kPauseBreakpoint &&
            freshKind != vm.EventKind.kPauseException) {
          log?.call('isolate resumed and running');
          return fresh;
        }
      } on vm.RPCError {
        return null;
      }
    }
    return isolate;
  }

  /// Orders the isolate's libraries so the kit file (the seam's
  /// canonical home) is tried first, then the app's own `package:` /
  /// `file:` libraries (a hand-hosted seam also evaluates fine).
  static List<vm.LibraryRef> _seamCandidates(List<vm.LibraryRef?> libraries) {
    final kit = <vm.LibraryRef>[];
    final rest = <vm.LibraryRef>[];
    for (final lib in libraries) {
      final uri = lib?.uri ?? '';
      if (uri.endsWith(kitLibrarySuffix)) {
        kit.add(lib!);
      } else if (uri.startsWith('package:') || uri.startsWith('file:')) {
        rest.add(lib!);
      }
    }
    return [...kit, ...rest];
  }

  static Future<vm.VmService> _connect(Uri wsUri, void Function(String)? log) {
    log?.call('connecting to $wsUri');
    return vm_io.vmServiceConnectUri(wsUri.toString());
  }

  static String _brief(String message) {
    final oneLine = message.replaceAll('\n', ' ').trim();
    return oneLine.length <= 200 ? oneLine : '${oneLine.substring(0, 200)}…';
  }
}
