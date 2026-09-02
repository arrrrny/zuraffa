/// `ChannelScenario` — the committed-intent contract behind a certified
/// platform-channel fake (issue #831 — platform-channel test harness,
/// VISION §9 simulation worlds).
///
/// A scenario script is a JSON file at
/// `specs/<feature>/tdd/scenarios/<slug>.json`. It is INTENT, not test
/// code: humans (or the planner) commit what the channel should say, and
/// the generated fake replays exactly that — "fakes are NOT agent-written
/// mocks (no grading your own homework)". The schema is deliberately
/// small and machine-parseable:
///
/// ```json
/// {
///   "channel": "dev.zuraffa/barcode",
///   "platforms": ["ios", "android"],
///   "responses": {
///     "available":  {"value": true},
///     "takePicture": {"value": {"path": "/tmp/photo.jpg"}},
///     "request": {"error": {"code": "permission-denied",
///                           "message": "refused",
///                           "details": {"state": "denied"}}}
///   },
///   "default": {"error": {"code": "unscripted",
///                         "message": "No scripted response — extend the
///                                     scenario."}}
/// }
/// ```
///
/// Schema law (validated by [ChannelScenario.fromJson], which throws
/// [ChannelScenarioException] on any violation):
///   - `channel` — non-empty string, the full platform-channel name the
///     fake binds to.
///   - `platforms` — optional list of hosted-matrix targets; tokens from
///     the closed set {ios, android, macos, windows, linux, web}. An
///     empty/omitted list declares "no hosted matrix" and is valid.
///   - `responses` — method name → exactly ONE of `{"value": <any JSON>}`
///     or `{"error": {"code": <str>, "message": <str>, "details": <any>?}}`.
///     Permission states ("granted"/"denied"/"disabled") are plain
///     replayable values — no special-cased machinery.
///   - `default` — REQUIRED. The response for every method the script
///     does not name. The starter writes an error default: an unscripted
///     call fails LOUDLY (certified honesty) instead of returning a
///     plausible null.
library;

/// Thrown when a scenario JSON violates the schema law. The message
/// names the violated rule so the fake command can stop honestly before
/// writing any artifact.
class ChannelScenarioException implements Exception {
  const ChannelScenarioException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One scripted channel response: a replayed value OR a thrown platform
/// error. Exactly one of the two — the constructor pair
/// ([ChannelResponse.value]/[ChannelResponse.error]) makes the
/// representation unrepresentable either-way.
class ChannelResponse {
  const ChannelResponse.value(this.value)
    : isError = false,
      errorCode = null,
      errorMessage = null,
      errorDetails = null;

  const ChannelResponse.error({
    required this.errorCode,
    required this.errorMessage,
    this.errorDetails,
  }) : isError = true,
       value = null;

  final bool isError;
  final Object? value;
  final String? errorCode;
  final String? errorMessage;
  final Object? errorDetails;

  /// Build from the schema's response object (`{"value": ...}` xor
  /// `{"error": {...}}`).
  factory ChannelResponse.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const ChannelScenarioException(
        'response must be a JSON object with exactly one of '
        '"value" or "error"',
      );
    }
    final hasValue = raw.containsKey('value');
    final hasError = raw.containsKey('error');
    if (hasValue && hasError) {
      throw const ChannelScenarioException(
        'response must carry exactly one of "value" or "error", not both',
      );
    }
    if (hasValue) return ChannelResponse.value(raw['value']);
    if (!hasError) {
      throw const ChannelScenarioException(
        'response must carry exactly one of "value" or "error"',
      );
    }
    final error = raw['error'];
    if (error is! Map) {
      throw const ChannelScenarioException(
        '"error" must be a JSON object with "code" and "message"',
      );
    }
    final code = error['code'];
    final message = error['message'];
    if (code is! String || code.isEmpty) {
      throw const ChannelScenarioException(
        '"error.code" must be a non-empty string',
      );
    }
    if (message is! String || message.isEmpty) {
      throw const ChannelScenarioException(
        '"error.message" must be a non-empty string',
      );
    }
    return ChannelResponse.error(
      errorCode: code,
      errorMessage: message,
      errorDetails: error['details'],
    );
  }

  Map<String, Object?> toJson() => isError
      ? {
          'error': {
            'code': errorCode,
            'message': errorMessage,
            if (errorDetails != null) 'details': errorDetails,
          },
        }
      : {'value': value};
}

/// A parsed scenario script — see the library docs for the schema.
class ChannelScenario {
  const ChannelScenario({
    required this.channel,
    required this.platforms,
    required this.responses,
    required this.defaultResponse,
  });

  /// The hosted-matrix target set (issue #831 requirement 5): the same
  /// scenario runs on every platform it names. Closed token set so a
  /// typo cannot silently shrink the matrix.
  static const supportedPlatforms = {
    'ios',
    'android',
    'macos',
    'windows',
    'linux',
    'web',
  };

  final String channel;
  final List<String> platforms;
  final Map<String, ChannelResponse> responses;
  final ChannelResponse defaultResponse;

  /// Parse and VALIDATE a scenario from decoded JSON. Throws
  /// [ChannelScenarioException] naming the first violated rule.
  factory ChannelScenario.fromJson(Map<String, Object?> json) {
    final channel = json['channel'];
    if (channel is! String || channel.trim().isEmpty) {
      throw const ChannelScenarioException(
        '"channel" must be a non-empty string',
      );
    }
    final platformsRaw = json['platforms'];
    final platforms = <String>[];
    if (platformsRaw != null) {
      if (platformsRaw is! List) {
        throw const ChannelScenarioException(
          '"platforms" must be a JSON array of platform tokens',
        );
      }
      for (final token in platformsRaw) {
        if (token is! String || !supportedPlatforms.contains(token)) {
          throw ChannelScenarioException(
            'unknown platform "$token" — supported: '
            '${supportedPlatforms.toList()..sort()}',
          );
        }
        platforms.add(token);
      }
    }
    final responsesRaw = json['responses'];
    final responses = <String, ChannelResponse>{};
    if (responsesRaw != null) {
      if (responsesRaw is! Map) {
        throw const ChannelScenarioException(
          '"responses" must be a JSON object of method → response',
        );
      }
      responsesRaw.forEach((key, value) {
        if (key is! String || key.isEmpty) {
          throw const ChannelScenarioException(
            '"responses" keys must be non-empty method names',
          );
        }
        responses[key] = ChannelResponse.fromJson(value);
      });
    }
    final defaultRaw = json['default'];
    if (defaultRaw == null) {
      throw const ChannelScenarioException(
        '"default" response is required — unscripted methods must fail '
        'loudly, not return a plausible null',
      );
    }
    final defaultResponse = ChannelResponse.fromJson(defaultRaw);
    return ChannelScenario(
      channel: channel,
      platforms: platforms,
      responses: responses,
      defaultResponse: defaultResponse,
    );
  }

  Map<String, Object?> toJson() => {
    'channel': channel,
    'platforms': platforms,
    'responses': {
      for (final entry in responses.entries) entry.key: entry.value.toJson(),
    },
    'default': defaultResponse.toJson(),
  };

  /// The response the fake replays for [method]: the scripted one, or
  /// the required [defaultResponse] for unscripted methods.
  ChannelResponse responseFor(String method) =>
      responses[method] ?? defaultResponse;
}
