/// `zfa skin sim` — the deterministic simulate-side skin lane
/// (issue #1112, the `zfa simulate` integration).
///
/// Skin behaviors are driven through the SAME anchor protocol the
/// live driver uses — the [ZfaAnchorRegistry] behind the emitted
/// `debugTapAnchor` — with zero synthetic clicks and zero host
/// dependencies: no VM service, no device, no macOS. A committed,
/// diffable manifest declares the anchor population and the taps
/// with their EXPECTED verdicts; the sim replays it and emits one
/// TapResult JSON line per tap (the same envelope `zfa skin drive`
/// prints), then the summary.
///
/// ```text
/// zfa skin sim --manifest tdd/skin-sim.json
/// ```
///
/// Manifest shape:
/// ```json
/// {
///   "scenario": "signin-guest-flow",
///   "anchors": [
///     {"id": "signin-guest", "enabled": true},
///     {"id": "signin-log-out", "enabled": false}
///   ],
///   "taps": [
///     "zfa:signin-guest",
///     {"tap": "zfa:signin-log-out", "expect": "disabled"}
///   ]
/// }
/// ```
///
/// Machine contract: exit 0 when every tap matched its expectation
/// (default expectation: `found`), 1 on drift (drift lines name the
/// tap, the expected and the actual verdict), 2 when the manifest is
/// missing or malformed. The final stdout line is always a summary
/// (`skin sim: scenario=<s> taps=<n> found=<n> disabled=<n>
/// notFound=<n> error=<n> drift=<d>`); the error envelope
/// (`{"result":"error",...}`) is the final line on exit 2.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../skin/anchors.dart';

/// The `zfa skin sim` command.
class SkinSimCommand extends Command<void> {
  SkinSimCommand({void Function(String message)? sink})
    : _sink = sink ?? _stdoutSink {
    argParser.addOption(
      'manifest',
      valueHelp: 'path',
      help:
          'Path to the committed sim manifest (JSON: scenario, anchors, '
          'taps). Defaults to tdd/skin-sim.json under the project root.',
    );
  }

  /// The default stdout sink.
  static void _stdoutSink(String message) => stdout.writeln(message);

  final void Function(String message) _sink;

  @override
  String get name => 'sim';

  @override
  String get description =>
      'Replay a skin-behavior manifest through the anchor-tap protocol '
      '(issue #1112) — the deterministic simulate lane: no synthetic '
      'clicks, the same TapResult JSON as zfa skin drive, CI-runnable '
      'on every host OS.';

  @override
  String get invocation => 'zfa skin sim --manifest=<path>';

  @override
  Future<void> run() async {
    final results = argResults!;
    exitCode = await simulate(
      manifestPath: results['manifest'] as String?,
      sink: _sink,
    );
  }

  /// The sim core (also the testable seam): returns the exit code and
  /// emits the JSON lines + summary through [sink].
  Future<int> simulate({
    String? manifestPath,
    void Function(String message)? sink,
  }) async {
    final emit = sink ?? _sink;
    final path = manifestPath ?? 'tdd/skin-sim.json';

    final file = File(path);
    if (!file.existsSync()) {
      emit('zfa skin sim: manifest not found: $path');
      emit(
        '   --> fix: commit a skin sim manifest (scenario, anchors, '
        'taps) next to the feature\'s tdd/ artifacts.',
      );
      emit(_errorEnvelope('manifest not found: $path'));
      return 2;
    }

    Map<String, Object?> manifest;
    try {
      final dynamic decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?>) throw const FormatException();
      manifest = decoded;
    } on FormatException {
      emit('zfa skin sim: the manifest at $path is malformed');
      emit(
        '   --> fix: the manifest is JSON — scenario, anchors '
        '[{id, enabled}], taps (a zfa: key or {tap, expect}).',
      );
      emit(_errorEnvelope('invalid JSON'));
      return 2;
    }

    final scenario = '${manifest['scenario'] ?? 'unnamed'}';
    final anchors =
        (manifest['anchors'] as List<Object?>?)?.whereType<Map>().toList() ??
        const [];
    final taps =
        (manifest['taps'] as List<Object?>?)?.whereType<Object>().toList() ??
        const <Object>[];

    // Populate the SAME registry the live app's debugTapAnchor reads
    // — the simulation IS the protocol, just without a device.
    final registry = ZfaAnchorRegistry();
    for (final anchor in anchors) {
      final id = '${anchor['id'] ?? ''}';
      if (id.isEmpty) continue;
      registry.register(id, () {}, enabled: anchor['enabled'] != false);
    }

    var found = 0;
    var disabled = 0;
    var notFound = 0;
    var errors = 0;
    var drift = 0;

    for (final tap in taps) {
      final String key;
      final String expect;
      if (tap is Map) {
        key = '${tap['tap'] ?? ''}';
        expect = '${tap['expect'] ?? 'found'}';
      } else {
        key = '$tap';
        expect = 'found';
      }
      if (key.isEmpty) continue;

      final result = registry.tapResult(key);
      emit(_encode(result.toJson()));

      switch (result.name) {
        case 'found':
          found++;
        case 'disabled':
          disabled++;
        case 'notFound':
          notFound++;
        default:
          errors++;
      }
      if (result.name != expect) {
        drift++;
        emit('   [drift] $key — expected $expect, observed ${result.name}');
      }
    }

    emit(
      'skin sim: scenario=$scenario taps=${taps.length} found=$found '
      'disabled=$disabled notFound=$notFound error=$errors drift=$drift',
    );
    return drift == 0 ? 0 : (errors > 0 ? 2 : 1);
  }

  String _encode(Map<String, Object?> envelope) => jsonEncode(envelope);

  String _errorEnvelope(String message) => jsonEncode(<String, Object?>{
    'result': 'error',
    'tapped': false,
    'message': message,
  });
}
