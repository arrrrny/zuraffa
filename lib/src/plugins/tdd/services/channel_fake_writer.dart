/// ChannelFakeWriter — emits the framework-certified platform-channel
/// fake for `zfa tdd fake <channel>` (issue #831 — platform-channel test
/// harness, VISION §9 simulation worlds).
///
/// The emitted file is a SELF-CONTAINED test-side handler:
///
///   - registered via `TestDefaultBinaryMessengerBinding` (the
///     framework-sanctioned seam — not a hand-rolled mock class);
///   - replays a COMMITTED scenario script (responses, errors, permission
///     states) loaded from `specs/<feature>/tdd/scenarios/<slug>.json` —
///     the scenario is intent, the fake is generated code; changing what
///     the channel says means editing the scenario, never the fake;
///   - records every observed call (method + arguments, in invocation
///     order) so gen'd tests can assert on what the subject actually
///     asked the platform for;
///   - fails LOUDLY on unscripted methods (the scenario's required
///     default response) and on channel drift (a scenario whose
///     `channel` no longer matches the fake's channel refuses to load).
///
/// The fake is NOT registered in the feature's artifact registry: it is
/// harness infrastructure (like cycle-log), not a behavior pair. It
/// carries a `// GENERATED FAKE` provenance header naming the command,
/// channel, and scenario path.
library;

import 'dart:io';

/// Writes the certified fake dart file at [fakePath].
class ChannelFakeWriter {
  const ChannelFakeWriter();

  Future<void> write({
    required String fakePath,
    required String channel,
    required String slug,
    required String feature,
    required List<String> platforms,
  }) async {
    final file = File(fakePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      render(
        channel: channel,
        slug: slug,
        feature: feature,
        platforms: platforms,
      ),
    );
  }

  String render({
    required String channel,
    required String slug,
    required String feature,
    required List<String> platforms,
  }) {
    final className = fakeClassName(slug);
    final escapedChannel = _escapeSingleQuoted(channel);
    final scenarioRelative = 'specs/$feature/tdd/scenarios/$slug.json';
    final platformNote = platforms.isEmpty
        ? '(none declared — the scenario runs platform-agnostically; '
              'declare a hosted matrix with --platforms)'
        : platforms.join(', ');
    return '''
// GENERATED FAKE — `zfa tdd fake $escapedChannel` (issue #831).
//
// channel: $escapedChannel
// certified platforms: $platformNote
// scenario: $scenarioRelative
//
// Framework-certified platform-channel fake (VISION §9 simulation
// worlds). A TEST-SIDE handler registered via
// TestDefaultBinaryMessengerBinding that:
//
//   1. replays the committed scenario script — responses, errors and
//      permission states — from `$scenarioRelative`;
//   2. records every observed call (method, arguments) in invocation
//      order so tests assert on what the subject asked the platform for;
//   3. fails LOUDLY on unscripted methods (the scenario's required
//      default response is an error) and on channel drift (a scenario
//      whose "channel" no longer matches refuses to load).
//
// NOT an agent-written mock: the responses come from the scenario file
// committed as intent — extend THAT file to change what the channel
// says, never this class.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// One observed platform-channel call, in invocation order (issue #831).
class RecordedChannelCall {
  const RecordedChannelCall(this.method, this.arguments);

  final String method;
  final Object? arguments;

  @override
  String toString() => 'RecordedChannelCall(\$method, \$arguments)';
}

/// Certified fake for the `$escapedChannel` platform channel (issue
/// #831). Install it inside a flutter test binding:
///
/// ```dart
/// TestWidgetsFlutterBinding.ensureInitialized();
/// final fake = $className(scenarioPath: '$scenarioRelative');
/// fake.install();
/// // ... drive the subject; assert on fake.recordedCalls ...
/// // uninstall in tearDown to keep suites hermetic.
/// ```
class $className {
  /// The platform channel this fake certifies (matches the committed
  /// scenario's "channel" — the load-time drift check below enforces it).
  static const MethodChannel channel = MethodChannel('$escapedChannel');

  /// Every observed call, in invocation order (arguments recorded).
  final List<RecordedChannelCall> recordedCalls = <RecordedChannelCall>[];

  Map<String, Map<String, Object?>> _responses = const {};
  late Map<String, Object?> _default;

  $className({required String scenarioPath}) {
    final decoded = _loadScenario(scenarioPath);
    final responses = decoded['responses'];
    _responses = responses is Map<String, Map<String, Object?>>
        ? responses
        : <String, Map<String, Object?>>{};
    final fallback = decoded['default'];
    if (fallback is! Map<String, Object?>) {
      throw StateError(
        'scenario at \$scenarioPath has no usable "default" response — '
        'unscripted methods must fail loudly, not silently (issue #831)',
      );
    }
    _default = fallback;
  }

  /// Register the test-side handler for [channel].
  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, _handle);
  }

  /// Remove the handler — call in tearDown to keep suites hermetic.
  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }

  /// The scenario response for [method]: the scripted one, or the
  /// required default for unscripted methods.
  Map<String, Object?> responseFor(String method) =>
      _responses[method] ?? _default;

  Future<Object?> _handle(MethodCall call) async {
    recordedCalls.add(RecordedChannelCall(call.method, call.arguments));
    final response = responseFor(call.method);
    final error = response['error'];
    if (error is Map<String, Object?>) {
      throw PlatformException(
        code: error['code']! as String,
        message: error['message']! as String,
        details: error['details'],
      );
    }
    return response['value'];
  }

  /// Load + validate the committed scenario. The fake replays intent, so
  /// a missing or drifted scenario is a HARD error — never silently
  /// improvised (no grading your own homework, VISION §9).
  static Map<String, Object?> _loadScenario(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError(
        'scenario script not found at \$path — the certified fake '
        'replays a committed scenario; generate/commit it first with '
        '`zfa tdd fake $escapedChannel` (issue #831)',
      );
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw StateError(
        'scenario at \$path must be a JSON object (issue #831 schema)',
      );
    }
    final scenarioChannel = decoded['channel'];
    if (scenarioChannel != channel.name) {
      throw StateError(
        'scenario channel "\$scenarioChannel" does not match the fake '
        'channel "$escapedChannel" — the scenario drifted; re-commit it '
        '(issue #831)',
      );
    }
    final rawResponses = decoded['responses'];
    final parsed = <String, Map<String, Object?>>{};
    if (rawResponses is Map<String, Object?>) {
      rawResponses.forEach((method, response) {
        if (response is Map<String, Object?>) parsed[method] = response;
      });
    }
    return <String, Object?>{
      'responses': parsed,
      'default': decoded['default'],
    };
  }
}
''';
  }

  /// The fake class name for [slug]: `t1` -> `T1Fake`,
  /// `dev_zuraffa_camera` -> `DevZuraffaCameraFake`.
  static String fakeClassName(String slug) {
    final pascal = slug
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join();
    return '${pascal}Fake';
  }

  /// The file slug for a channel name: non-alphanumerics collapse to `_`
  /// (`dev.zuraffa/camera` -> `dev_zuraffa_camera`).
  static String slugForChannel(String channel) => channel
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+\$'), '');

  String _escapeSingleQuoted(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}
