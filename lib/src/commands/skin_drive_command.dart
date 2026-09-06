/// `zfa skin drive` — the VM-service skin driver (issue #1112).
///
/// Replaces the pilot's ad-hoc `tool/drive_guest.dart` AND the
/// synthetic-click driving that never reached the Flutter macOS view
/// (cliclick/CGEvent/AX press): the driver connects to a LIVE debug
/// app's VM service, evaluates the emitted `debugTapAnchorJson`
/// seam against the app's skin kit library, and prints the TapResult
/// JSON — the SAME envelope on every host OS, so sub-agents and CI
/// need no platform-specific input synthesis. The real `onPressed`
/// runs inside the app (presenter → certified mock → push).
///
/// ```text
/// zfa skin drive --dart-uri=<vm-service-uri> --anchor=zfa:signin-guest
/// ```
///
/// Machine contract (final stdout line is ALWAYS the JSON envelope):
/// - `{"result":"found","tapped":true}`    → exit 0
/// - `{"result":"disabled","tapped":false}` / notFound → exit 1
/// - `{"result":"error", ...}` (or an unusable connection/evaluation)
///                                          → exit 2
/// - missing `--dart-uri` / `--anchor`      → exit 64 (usage), and the
///   VM service is never contacted.
///
/// The URI comes from `flutter run --print-dtd` (or DevTools). The
/// auditor library is auto-discovered among the isolate's libraries
/// (`.../skin_contract_auditor.dart`); `--library` overrides, `--isolate-id`
/// selects a non-main isolate.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// The minimal VM-service surface the driver needs — injectable so
/// the wire contract is testable without a device.
abstract class ZfaDriveVmClient {
  /// The isolate ids visible to this connection.
  Future<List<String>> isolateIds();

  /// The libraries loaded in [isolateId].
  Future<List<String>> isolateLibraries(String isolateId);

  /// Evaluates [expression] against [targetId] (a library URI) inside
  /// [isolateId]. Returns the resulting string, or null when the
  /// evaluation produced no string (an ErrorRef, a non-string
  /// instance) — the driver refuses honestly either way.
  Future<String?> evaluate(
    String isolateId,
    String targetId,
    String expression,
  );
}

/// Opens a connection for a `--dart-uri`.
typedef ZfaDriveVmConnector = Future<ZfaDriveVmClient> Function(String dartUri);

/// The real [ZfaDriveVmClient] over `package:vm_service` (issue
/// #1112): connects via the websocket URI `flutter run --print-dtd`
/// prints, lists the VM's isolates, inspects libraries, evaluates.
class ZfaDriveVmAdapter implements ZfaDriveVmClient {
  ZfaDriveVmAdapter._(this._service, this._isolateIds);

  final VmService _service;
  final List<String> _isolateIds;

  /// Connects to [dartUri] and snapshots the isolate list.
  static Future<ZfaDriveVmClient> connect(String dartUri) async {
    final service = await vmServiceConnectUri(dartUri);
    final vm = await service.getVM();
    final ids = (vm.isolates ?? const [])
        .map((isolate) => isolate.id ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    return ZfaDriveVmAdapter._(service, ids);
  }

  @override
  Future<List<String>> isolateIds() async => _isolateIds;

  @override
  Future<List<String>> isolateLibraries(String isolateId) async {
    final isolate = await _service.getIsolate(isolateId);
    return (isolate.libraries ?? const [])
        .map((library) => library.uri ?? '')
        .where((uri) => uri.isNotEmpty)
        .toList();
  }

  @override
  Future<String?> evaluate(
    String isolateId,
    String targetId,
    String expression,
  ) async {
    final response = await _service.evaluate(isolateId, targetId, expression);
    if (response is InstanceRef) return response.valueAsString;
    return null;
  }
}

/// The `zfa skin drive` command.
class SkinDriveCommand extends Command<void> {
  /// Production wiring: the real vm_service adapter, stdout output.
  SkinDriveCommand({void Function(String message)? sink})
    : _connector = ZfaDriveVmAdapter.connect,
      _sink = sink ?? _stdoutSink {
    _buildParser();
  }

  /// Test wiring: an injected connector + output sink.
  SkinDriveCommand.vmConnector(
    ZfaDriveVmConnector connector, {
    void Function(String message)? sink,
  }) : _connector = connector,
       _sink = sink ?? _silent {
    _buildParser();
  }

  /// The default stdout sink (the CLI contract: lines on stdout, the
  /// JSON envelope last).
  static void _stdoutSink(String message) => stdout.writeln(message);

  /// The silent sink (tests inject a recording sink instead).
  static void _silent(String message) {}

  void _buildParser() {
    argParser
      ..addOption(
        'dart-uri',
        valueHelp: 'uri',
        help:
            'The VM-service URI of the LIVE debug app (flutter run '
            '--print-dtd, or DevTools).',
      )
      ..addOption(
        'anchor',
        valueHelp: 'zfa-key',
        help:
            "The anchor to tap (e.g. zfa:signin-guest — the bare id "
            "'signin-guest' is accepted too).",
      )
      ..addOption(
        'library',
        valueHelp: 'uri',
        help:
            'The library URI that owns the emitted debugTapAnchor seam '
            '(default: the isolate skin_contract_auditor.dart library).',
      )
      ..addOption(
        'isolate-id',
        valueHelp: 'id',
        help: 'The isolate to drive (default: the first visible isolate).',
      );
  }

  final ZfaDriveVmConnector _connector;
  final void Function(String message) _sink;

  @override
  String get name => 'drive';

  @override
  String get description =>
      'Tap a skin anchor in a LIVE debug app through the VM service '
      '(issue #1112) — no synthetic clicks, the real onPressed runs. '
      'Prints the TapResult JSON as the final stdout line; exit 0 '
      'found / 1 not tapped / 2 error.';

  @override
  String get invocation =>
      'zfa skin drive --dart-uri=<vm-service-uri> --anchor=<zfa-key>';

  @override
  Future<void> run() async {
    final results = argResults!;
    exitCode = await drive(
      dartUri: results['dart-uri'] as String?,
      anchor: results['anchor'] as String?,
      library: results['library'] as String?,
      isolateId: results['isolate-id'] as String?,
    );
  }

  /// The driver core (also the testable seam): returns the exit code
  /// and emits the JSON envelope as the final output line.
  Future<int> drive({
    String? dartUri,
    String? anchor,
    String? library,
    String? isolateId,
  }) async {
    if (dartUri == null || dartUri.isEmpty) {
      return _usage('missing --dart-uri (the VM-service URI of the '
          'running app — flutter run --print-dtd)');
    }
    if (anchor == null || anchor.isEmpty) {
      return _usage('missing --anchor (e.g. zfa:signin-guest)');
    }

    final ZfaDriveVmClient client;
    try {
      client = await _connector(dartUri);
    } catch (error) {
      return _failure('cannot connect to $dartUri: $error');
    }

    // Resolve the isolate.
    final ids = await client.isolateIds();
    if (ids.isEmpty) {
      return _failure('no isolates are visible at $dartUri (is the app '
          'a DEBUG build?)');
    }
    final resolvedIsolate =
        (isolateId != null && isolateId.isNotEmpty) ? isolateId : ids.first;

    // Resolve the seam library: explicit --library, else the emitted
    // skin kit.
    final libraries = await client.isolateLibraries(resolvedIsolate);
    final skinKitLibraries = libraries.where(_isSkinKitLibrary).toList();
    final target = library ?? (skinKitLibraries.isEmpty
        ? null
        : skinKitLibraries.first);
    if (target == null) {
      return _failure(
        'no skin_contract_auditor.dart library is loaded in isolate '
        '$resolvedIsolate — is the skin kit emitted (zfa skin kit) and '
        'the app built with it?',
      );
    }

    // Evaluate the emitted seam — the expression a sub-agent can
    // reproduce verbatim in DevTools.
    final expression = "debugTapAnchorJson('$anchor')";
    String? answer;
    try {
      answer = await client.evaluate(resolvedIsolate, target, expression);
    } catch (error) {
      return _failure('evaluate failed on $target: $error');
    }
    if (answer == null) {
      return _failure(
        'the evaluation produced no string — is $target the emitted '
        'skin kit (debugTapAnchorJson) and the app a DEBUG build?',
      );
    }

    final normalized = _normalizeEnvelope(answer);
    if (normalized == null) {
      return _failure('the evaluation result is not a TapResult JSON '
          'envelope: $answer');
    }

    _sink('zfa skin drive: isolate=$resolvedIsolate library=$target '
        'anchor=$anchor');
    _sink(normalized.json);
    return switch (normalized.verdict) {
      TapVerdict.found => 0,
      TapVerdict.disabled || TapVerdict.notFound => 1,
      TapVerdict.error || TapVerdict.unknown => 2,
    };
  }

  /// The emitted kit's file name (the library the seam lives in).
  static bool _isSkinKitLibrary(String uri) =>
      uri.endsWith('/skin_contract_auditor.dart') ||
      uri == 'skin_contract_auditor.dart';

  /// Re-encodes the app's answer canonically (fixed key order, no
  /// host-specific whitespace) — the SAME bytes on every platform.
  /// Null when the answer is not a TapResult envelope.
  ({String json, TapVerdict verdict})? _normalizeEnvelope(String answer) {
    final Object? decoded;
    try {
      decoded = jsonDecode(answer);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    final result = decoded['result'];
    final tapped = decoded['tapped'];
    if (result is! String || tapped is! bool) return null;
    final message = decoded['message'];
    return (
      json: _encodeJson(<String, Object?>{
        'result': result,
        'tapped': tapped,
        if (message is String && message.isNotEmpty) 'message': message,
      }),
      verdict: TapVerdictNames.of(result),
    );
  }

  int _usage(String reason) {
    _sink('zfa skin drive: $reason');
    _sink('   --> fix: $invocation');
    return 64;
  }

  int _failure(String reason) {
    _sink('zfa skin drive: $reason');
    _sink('   --> fix: rebuild the app with the emitted skin kit and a '
        'DEBUG VM uri, then retry.');
    _sink(_encodeJson(<String, Object?>{
      'result': 'error',
      'tapped': false,
      'message': reason,
    }));
    return 2;
  }

  /// Canonical JSON encoding (the driver's bytes are deterministic).
  String _encodeJson(Map<String, Object?> envelope) => jsonEncode(envelope);
}

/// The verdict vocabulary the envelope's `result` field carries.
enum TapVerdict { found, disabled, notFound, error, unknown }

/// Verdict-name helpers (JSON string → enum).
abstract final class TapVerdictNames {
  static TapVerdict of(Object? name) => switch (name) {
    'found' => TapVerdict.found,
    'disabled' => TapVerdict.disabled,
    'notFound' => TapVerdict.notFound,
    'error' => TapVerdict.error,
    _ => TapVerdict.unknown,
  };
}
