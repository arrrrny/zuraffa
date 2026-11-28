import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

// Pure-Dart replacement: no Flutter dependency needed.
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import 'api_endpoint.dart';
import 'failure.dart';
import 'result.dart';
import 'signals/zfa_signal.dart';
import 'zuraffa_bridge_facade.dart';

// ---------------------------------------------------------------------------
// Private subscription record — holds the cancel handle and latest value.
// Streams and signals share the poll/cancel lifecycle, so the record stores
// one normalized async cancellation callback instead of either concrete type.
// ---------------------------------------------------------------------------
class _StreamRecord {
  final Future<void> Function() cancel;

  /// The last value emitted by the stream or signal, serialized to JSON form.
  /// Null until the subscription emits its first event.
  dynamic latestValue;

  _StreamRecord(this.cancel);
}

/// VM Service extension bridge for Zuraffa.
///
/// Exposes every registered UseCase as a `dart:developer` extension
/// (`ext.zuraffa.<domain>.<usecase>`) callable from the VM Service protocol
/// (Dart DevTools, custom VM Service clients, or integration tests).
///
/// ## Usage
///
/// ```dart
/// // In main() — before runApp():
/// ZuraffaApiBridge.init();
/// ```

///
/// ## Release mode safety
///
/// `init()` and all generated `register*ApiBridge()` functions guard with
/// `if (const bool.fromEnvironment('dart.vm.product')) return;` as their very first statement.  No extension
/// is ever registered in release builds.
///
/// ## Profile mode opt-in
///
/// Profile mode is development-adjacent but not always safe for exposure.
/// Set `Zuraffa.enableApiInProfile = true` before calling `init()` to enable
/// the bridge in profile builds.
class ZuraffaApiBridge {
  ZuraffaApiBridge._();

  static bool _initialized = false;
  static final List<ApiEndpoint> _endpoints = [];
  static final Map<String, _StreamRecord> _streamSubscriptions = {};

  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Initialize the three bridge meta-extensions.
  ///
  /// Must be called **once**, before any `register*ApiBridge()` call.
  /// No-op in release mode or if already called.
  static void init() {
    // Release builds never expose extensions — non-negotiable.
    if (const bool.fromEnvironment('dart.vm.product')) return;

    // Profile mode is opt-in via Zuraffa.enableApiInProfile.
    if (const bool.fromEnvironment('dart.vm.profile') &&
        !ZuraffaBridgeFacade.enableApiInProfile) {
      return;
    }

    // Idempotent — calling init() twice must be harmless.
    if (_initialized) return;
    _initialized = true;

    developer.registerExtension('ext.zuraffa._list', _handleList);
    developer.registerExtension('ext.zuraffa._pollStream', _handlePollStream);
    developer.registerExtension(
      'ext.zuraffa._cancelStream',
      _handleCancelStream,
    );

    developer.log('ZuraffaApiBridge initialized', name: 'ZuraffaApiBridge');
  }

  /// Register a UseCase as a VM Service extension.
  ///
  /// Called exclusively from generated `register*ApiBridge()` functions.
  /// Appends [endpoint] metadata to the catalog and registers [handler]
  /// with `dart:developer`.
  static void registerEndpoint({
    required ApiEndpoint endpoint,
    required Future<developer.ServiceExtensionResponse> Function(
      String,
      Map<String, String>,
    )
    handler,
  }) {
    _endpoints.add(endpoint);
    developer.registerExtension(endpoint.method, handler);
  }

  /// Register a stream subscription so it can be polled and cancelled.
  ///
  /// Called from generated legacy stream handlers. Returns [subscriptionId]
  /// so the generated handler can include it in its initial response.
  static String registerStreamSubscription(
    String subscriptionId,
    StreamSubscription<dynamic> subscription,
    void Function(dynamic latestValue) onValue,
  ) {
    _streamSubscriptions[subscriptionId] = _StreamRecord(subscription.cancel);
    return subscriptionId;
  }

  /// Register a WatchUseCase signal subscription for polling and cancellation.
  ///
  /// The record is installed before [signal.listen] because signal listeners
  /// receive the current value synchronously.
  static String registerSignalSubscription(
    String subscriptionId,
    ZfaSignal<dynamic> signal,
    void Function(dynamic value) onValue,
  ) {
    ZfaSignalSubscription? subscription;
    _streamSubscriptions[subscriptionId] = _StreamRecord(() async {
      subscription?.cancel();
      signal.dispose();
    });
    subscription = signal.listen(onValue);
    return subscriptionId;
  }

  /// Serialize a `Result<T, AppFailure>` to a `ServiceExtensionResponse`.
  ///
  /// This is the SINGLE authoritative serialization implementation.
  /// Generated handlers MUST call this — never re-implement serialization
  /// locally in the generated file.
  ///
  /// [toJson] is provided by the generated caller because only the generated
  /// code knows the concrete return type T at code-generation time.  Passing
  /// `(p) => p.toJson()` keeps the type system intact and avoids reflection.
  static developer.ServiceExtensionResponse serializeResult<T>(
    Result<T, AppFailure> result,
    Map<String, dynamic> Function(T value) toJson,
  ) {
    return result.fold(
      (value) => developer.ServiceExtensionResponse.result(
        jsonEncode({'status': 'success', 'data': toJson(value)}),
      ),
      (failure) => developer.ServiceExtensionResponse.result(
        jsonEncode({
          'status': 'error',
          'failure': {
            'type': failure.runtimeType.toString(),
            'message': failure.message,
          },
        }),
      ),
    );
  }

  /// Build a structured error response.
  ///
  /// Generated catch blocks call this — never construct the JSON inline.
  /// This ensures every error response has the same shape, making client-side
  /// parsing predictable.
  static developer.ServiceExtensionResponse errorResponse(
    String type,
    String message,
  ) {
    return developer.ServiceExtensionResponse.result(
      jsonEncode({
        'status': 'error',
        'failure': {'type': type, 'message': message},
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Meta-extension handlers (private — registered by init())
  // ---------------------------------------------------------------------------

  /// Returns a JSON array of all registered endpoint metadata.
  ///
  /// Exposed as `ext.zuraffa._list` — callers can use this to discover every
  /// registered UseCase without hardcoding names.
  static Future<developer.ServiceExtensionResponse> _handleList(
    String method,
    Map<String, String> parameters,
  ) async {
    return developer.ServiceExtensionResponse.result(
      jsonEncode(_endpoints.map((e) => e.toJson()).toList()),
    );
  }

  /// Public, test-only accessor for [_handleList] (the `ext.zuraffa._list`
  /// meta-extension handler). Mirrors [handlePollStream]/[handleCancelStream].
  @visibleForTesting
  static Future<developer.ServiceExtensionResponse> handleList(
    String method,
    Map<String, String> parameters,
  ) => _handleList(method, parameters);

  /// Poll the latest value emitted by a stream or signal subscription.
  ///
  /// Exposed as `ext.zuraffa._pollStream`.
  ///
  /// Response shapes:
  /// - `{'status': 'pending'}` — subscription exists but no value yet
  /// - `{'status': 'success', 'data': <latestValue>}` — value available
  /// - `{'status': 'error', 'failure': {...}}` — subscription not found
  @visibleForTesting
  static Future<developer.ServiceExtensionResponse> handlePollStream(
    String method,
    Map<String, String> parameters,
  ) => _handlePollStream(method, parameters);

  static Future<developer.ServiceExtensionResponse> _handlePollStream(
    String method,
    Map<String, String> parameters,
  ) async {
    final subscriptionId = parameters['subscriptionId'];
    if (subscriptionId == null || subscriptionId.isEmpty) {
      return errorResponse('badRequest', 'subscriptionId is required');
    }

    final record = _streamSubscriptions[subscriptionId];
    if (record == null) {
      return errorResponse(
        'notFound',
        'No active subscription: $subscriptionId',
      );
    }

    final latest = record.latestValue;
    if (latest == null) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'status': 'pending'}),
      );
    }

    return developer.ServiceExtensionResponse.result(jsonEncode(latest));
  }

  /// Cancel a stream or signal subscription and remove it from the registry.
  ///
  /// Exposed as `ext.zuraffa._cancelStream`.
  @visibleForTesting
  static Future<developer.ServiceExtensionResponse> handleCancelStream(
    String method,
    Map<String, String> parameters,
  ) => _handleCancelStream(method, parameters);

  static Future<developer.ServiceExtensionResponse> _handleCancelStream(
    String method,
    Map<String, String> parameters,
  ) async {
    final subscriptionId = parameters['subscriptionId'];
    if (subscriptionId == null || subscriptionId.isEmpty) {
      return errorResponse('badRequest', 'subscriptionId is required');
    }

    final record = _streamSubscriptions.remove(subscriptionId);
    await record?.cancel();

    return developer.ServiceExtensionResponse.result(
      jsonEncode({'status': 'cancelled'}),
    );
  }

  // ---------------------------------------------------------------------------
  // Internal helpers used by generated stream handlers
  // ---------------------------------------------------------------------------

  /// Generate a new unique subscription ID.
  static String generateSubscriptionId() => _uuid.v4();

  /// Update the cached latest value for an active subscription.
  ///
  /// Called by the `.listen()` callback in generated stream handlers.
  static void updateStreamValue(String subscriptionId, dynamic value) {
    final record = _streamSubscriptions[subscriptionId];
    if (record != null) {
      record.latestValue = value;
    }
  }

  // ---------------------------------------------------------------------------
  // Test-only helpers — do NOT call in production code
  // ---------------------------------------------------------------------------

  /// Expose the registered endpoints list for test verification.
  @visibleForTesting
  static List<ApiEndpoint> getRegisteredEndpoints() =>
      List.unmodifiable(_endpoints);

  /// Reset all bridge state.
  ///
  /// Only for use in tests that need a clean slate between test cases.
  @visibleForTesting
  static Future<void> resetForTesting() async {
    for (final record in _streamSubscriptions.values) {
      await record.cancel();
    }
    _streamSubscriptions.clear();
    _endpoints.clear();
    _initialized = false;
  }
}
