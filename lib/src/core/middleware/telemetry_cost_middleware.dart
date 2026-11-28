import 'dart:async';

import '../context/telemetry_span.dart';
import '../failure.dart';
import '../result.dart';
import 'zfa_middleware.dart';

/// Typed replay metadata a v8 intent exposes to the built-in middleware.
///
/// Generated `@ZorphyIntent` classes carry `replaySafe`, `intentName` and an
/// `intentDigest()` method (see `zorphy_annotation`). They do not all share a
/// common Dart supertype that declares those members — [ZorphyIntentBase] is a
/// bare marker — so the built-in middleware read them through this capability
/// interface when an intent implements it, and fall back to a structural read
/// (and then to a safe default) when it does not.
abstract interface class ZfaIntentMetadata {
  /// Whether replaying this intent is side-effect-safe.
  bool get replaySafe;

  /// The canonical intent name.
  String get intentName;

  /// The canonical digest of this intent's name and field values.
  String intentDigest();
}

/// Reads [ZfaIntentMetadata.replaySafe] from [intent], or `false` when the
/// intent exposes no replay metadata.
bool zfaIntentReplaySafe(Object intent) {
  if (intent is ZfaIntentMetadata) return intent.replaySafe;
  try {
    final dynamic value = intent;
    final replaySafe = value.replaySafe;
    if (replaySafe is bool) return replaySafe;
  } on NoSuchMethodError {
    // No such member — fall through to the safe default. Any other error from
    // a real getter propagates instead of being masked as "no metadata".
  }
  return false;
}

/// Reads [ZfaIntentMetadata.intentName] from [intent], falling back to the
/// runtime type name when the intent exposes no name.
String zfaIntentName(Object intent) {
  if (intent is ZfaIntentMetadata) return intent.intentName;
  try {
    final dynamic value = intent;
    final name = value.intentName;
    if (name is String) return name;
  } on NoSuchMethodError {
    // No such member — fall through to the runtime type. Any other error from
    // a real getter propagates instead of being masked as "no name".
  }
  return intent.runtimeType.toString();
}

/// Reads [ZfaIntentMetadata.intentDigest] from [intent], or `null` when the
/// intent exposes no digest.
String? zfaIntentDigest(Object intent) {
  if (intent is ZfaIntentMetadata) return intent.intentDigest();
  try {
    final dynamic value = intent;
    final digest = value.intentDigest();
    if (digest is String) return digest;
  } on NoSuchMethodError {
    // No such member — the intent carries no digest. Any other error from a
    // real `intentDigest()` propagates instead of being masked as "no digest".
  }
  return null;
}

/// Built-in middleware that opens a child [TelemetrySpan] around `next`
/// (ZFA-006).
///
/// The span is tagged with the intent's name and digest (read through
/// [ZfaIntentMetadata], with a structural fallback), and is linked to the
/// parent span carried on [ZfaMiddlewareContext.metadata] under `'span'` when
/// one is present — otherwise it is a root span. The span is always ended once
/// `next` settles, so its duration is recorded whether the call succeeds or
/// fails.
class TelemetryCostMiddleware<I, O> implements ZfaMiddleware<I, O> {
  /// Creates a telemetry-cost middleware.
  const TelemetryCostMiddleware();

  @override
  Future<Result<O, AppFailure>> intercept(
    I intent,
    ZfaMiddlewareContext ctx,
    NextUseCase<I, O> next,
  ) async {
    final parent = ctx.metadata['span'];
    final intentName = zfaIntentName(intent as Object);
    final intentDigest = zfaIntentDigest(intent as Object);
    final span = TelemetrySpan(
      operation: intentName,
      parent: parent is TelemetrySpan ? parent : null,
      attributes: <String, String>{
        'intentName': intentName,
        if (intentDigest case final String digest) 'intentDigest': digest,
      },
    );
    try {
      return await next(intent, ctx);
    } finally {
      span.end();
    }
  }
}
