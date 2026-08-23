import 'session_exception.dart';

/// A named, reusable template for a common session kind (spec FR-002).
///
/// A preset defines which fields a session of its type may carry
/// ([fields] — an empty list means "anything"), an optional default expiry
/// ([defaultExpiryMs]) applied at creation, and an optional [validate]
/// hook for domain-specific checks. Built-ins ship with zero required
/// configuration; applications register custom presets through
/// [SessionPresetRegistry.register] (spec FR-003).
class SessionPreset {
  /// The preset name — also the session `type` identifier.
  final String name;

  /// Human-readable description of what this preset holds.
  final String description;

  /// Optional whitelist of allowed payload field names. Empty = unbounded.
  final List<String> fields;

  /// Optional default expiry in milliseconds applied when a session of
  /// this preset is created without an explicit expiry.
  final int? defaultExpiryMs;

  /// Optional validation hook; return an error message to reject the
  /// payload, or `null` to accept it.
  final String? Function(Map<String, dynamic> payload)? validate;

  const SessionPreset({
    required this.name,
    required this.description,
    this.fields = const [],
    this.defaultExpiryMs,
    this.validate,
  });

  /// Checks [payload] against this preset's rules. Returns an error
  /// message when the payload is invalid, `null` when accepted.
  String? validatePayload(Map<String, dynamic> payload) {
    if (fields.isNotEmpty) {
      final unknown = payload.keys.where((field) => !fields.contains(field));
      if (unknown.isNotEmpty) {
        return 'Preset "$name" does not allow fields: ${unknown.join(', ')}';
      }
    }
    return validate?.call(payload);
  }
}

/// Built-in session presets, instantiable with zero configuration
/// (spec FR-002 / SC-006): anonymous, authentication token, cookie,
/// header, OAuth, and API key.
abstract final class BuiltInSessionPresets {
  /// A session with no identity attached (guest browsing, anonymous usage).
  static const SessionPreset anonymous = SessionPreset(
    name: 'anonymous',
    description: 'Anonymous session — no identity attached.',
  );

  /// A bearer-style authentication token.
  static const SessionPreset authToken = SessionPreset(
    name: 'authToken',
    description: 'Authentication token session (bearer token + provider).',
    fields: ['token', 'provider', 'refreshToken'],
    validate: _requireToken,
  );

  /// A single cookie (name/value + optional attributes).
  static const SessionPreset cookie = SessionPreset(
    name: 'cookie',
    description: 'Cookie session — a single named cookie.',
    fields: [
      'name',
      'value',
      'domain',
      'path',
      'expiresAt',
      'secure',
      'httpOnly',
    ],
    validate: _requireCookieName,
  );

  /// A header-based session (e.g. a custom auth header).
  static const SessionPreset header = SessionPreset(
    name: 'header',
    description: 'Header session — a name/value header pair.',
    fields: ['name', 'value'],
    validate: _requireHeaderName,
  );

  /// An OAuth flow session (token, refresh, scopes, expiry).
  static const SessionPreset oauth = SessionPreset(
    name: 'oauth',
    description: 'OAuth session — access/refresh tokens, scopes and expiry.',
    fields: [
      'accessToken',
      'refreshToken',
      'tokenType',
      'scope',
      'expiresIn',
      'idToken',
    ],
  );

  /// An API key session (key + optional secret).
  static const SessionPreset apiKey = SessionPreset(
    name: 'apiKey',
    description: 'API key session — key and optional secret.',
    fields: ['key', 'secret'],
    validate: _requireApiKey,
  );

  /// All built-ins in registration order.
  static const List<SessionPreset> all = [
    anonymous,
    authToken,
    cookie,
    header,
    oauth,
    apiKey,
  ];

  static String? _requireToken(Map<String, dynamic> payload) {
    if (!_isNonEmptyString(payload['token'])) {
      return 'authToken sessions require a non-empty "token" field.';
    }
    return null;
  }

  static String? _requireCookieName(Map<String, dynamic> payload) {
    if (!_isNonEmptyString(payload['name'])) {
      return 'cookie sessions require a non-empty "name" field.';
    }
    return null;
  }

  static String? _requireHeaderName(Map<String, dynamic> payload) {
    if (!_isNonEmptyString(payload['name'])) {
      return 'header sessions require a non-empty "name" field.';
    }
    return null;
  }

  static String? _requireApiKey(Map<String, dynamic> payload) {
    if (!_isNonEmptyString(payload['key'])) {
      return 'apiKey sessions require a non-empty "key" field.';
    }
    return null;
  }

  static bool _isNonEmptyString(Object? value) =>
      value is String && value.isNotEmpty;
}

/// Registry of known session presets: the built-ins plus any custom
/// presets applications register (spec FR-003).
class SessionPresetRegistry {
  final Map<String, SessionPreset> _presets = {};

  SessionPresetRegistry({Iterable<SessionPreset> additional = const []}) {
    for (final preset in BuiltInSessionPresets.all) {
      _presets[preset.name] = preset;
    }
    for (final preset in additional) {
      register(preset);
    }
  }

  /// A registry with only the built-in presets.
  factory SessionPresetRegistry.withBuiltIns() => SessionPresetRegistry();

  /// Registers a custom preset. Duplicate names are rejected with a
  /// [ZuraffaSessionException.duplicatePreset] (prevents one domain from
  /// silently shadowing another's session type).
  void register(SessionPreset preset) {
    if (_presets.containsKey(preset.name)) {
      throw ZuraffaSessionException.duplicatePreset(preset.name);
    }
    _presets[preset.name] = preset;
  }

  /// Looks up a preset by name, or `null` when unknown.
  SessionPreset? lookup(String name) => _presets[name];

  /// Whether a preset with [name] is registered.
  bool contains(String name) => _presets.containsKey(name);

  /// All registered preset names.
  Iterable<String> get names => List.unmodifiable(_presets.keys);

  /// All registered presets.
  Iterable<SessionPreset> get all => List.unmodifiable(_presets.values);
}
