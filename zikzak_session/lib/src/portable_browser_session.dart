import 'package:zuraffa/zuraffa.dart';

/// A single cookie in a [PortableBrowserSession].
@immutable
class ZikZakCookie {
  /// Cookie name.
  final String name;

  /// Cookie value.
  final String value;

  /// Optional domain the cookie is scoped to.
  final String? domain;

  /// Optional path the cookie is scoped to.
  final String? path;

  /// Optional expiry (epoch ms); `null` = session cookie.
  final int? expiresAt;

  const ZikZakCookie({
    required this.name,
    required this.value,
    this.domain,
    this.path,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    if (domain != null) 'domain': domain,
    if (path != null) 'path': path,
    if (expiresAt != null) 'expiresAt': expiresAt,
  };

  factory ZikZakCookie.fromJson(Map<String, dynamic> json) => ZikZakCookie(
    name: json['name'] as String,
    value: json['value'] as String,
    domain: json['domain'] as String?,
    path: json['path'] as String?,
    expiresAt: json['expiresAt'] as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is ZikZakCookie &&
      other.name == name &&
      other.value == value &&
      other.domain == domain &&
      other.path == path &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(name, value, domain, path, expiresAt);
}

/// The `browser` session preset backing [PortableBrowserSession].
///
/// Registered into any [SessionPresetRegistry] handed to
/// [PortableBrowserSession.attach]; the payload fields are internal to this
/// package (`cookies`, `headers`, `token`) and are managed exclusively
/// through the typed API, never hand-written by callers.
const SessionPreset browserSessionPreset = SessionPreset(
  name: 'browser',
  description: 'Portable browser session — cookies, headers, and a token.',
  fields: ['cookies', 'headers', 'token'],
);

/// A portable browser session: cookies, headers, and a token, movable
/// between runtimes and devices through the zuraffa session plugin's
/// portable envelope (spec 015, FR-009).
///
/// Usage:
/// ```dart
/// final session = PortableBrowserSession(
///   cookies: [ZikZakCookie(name: 'sid', value: 'abc')],
///   headers: {'X-Client': 'zikzak'},
///   token: 'tok-1',
/// );
/// final wire = session.serialize();          // JSON string, portable
/// final back = PortableBrowserSession.deserialize(wire);
/// ```
class PortableBrowserSession {
  /// Cookies carried by the session.
  final List<ZikZakCookie> cookies;

  /// Headers applied to requests made with this session.
  final Map<String, String> headers;

  /// Optional bearer/CSRF token.
  final String? token;

  const PortableBrowserSession({
    this.cookies = const [],
    this.headers = const {},
    this.token,
  });

  /// An empty (anonymous) browser session — valid and portable.
  const PortableBrowserSession.anonymous() : this();

  /// Copies this session with an additional (or replaced) [cookie].
  PortableBrowserSession withCookie(ZikZakCookie cookie) {
    final next = [
      ...cookies.where((existing) => existing.name != cookie.name),
      cookie,
    ]..sort((a, b) => a.name.compareTo(b.name));
    return PortableBrowserSession(
      cookies: next,
      headers: headers,
      token: token,
    );
  }

  /// Copies this session with an additional (or replaced) header.
  PortableBrowserSession withHeader(String name, String value) =>
      PortableBrowserSession(
        cookies: cookies,
        headers: {...headers, name: value},
        token: token,
      );

  /// Copies this session with [token] set.
  PortableBrowserSession withToken(String token) =>
      PortableBrowserSession(cookies: cookies, headers: headers, token: token);

  /// The underlying core [Session] for [container] under [key]/[scope].
  ///
  /// Registers the `browser` preset on the container's registry (idempotent
  /// — a domain may attach more than once) and stores the session, so the
  /// standard container CRUD, scoping, and persistence all apply.
  Session attach(
    SessionContainer container, {
    String key = 'browser',
    String scope = 'default',
    String? id,
  }) {
    _ensurePreset(container.registry);
    final session = Session(
      type: browserSessionPreset.name,
      id: id ?? 'zikzak-${_sequence++}',
      key: key,
      payload: _payload,
      metadata: SessionMetadata.now(),
    );
    return container.put(session, scope: scope);
  }

  /// Reads a [PortableBrowserSession] previously [attach]ed to
  /// [container] under [key]/[scope], or `null` when absent.
  static PortableBrowserSession? read(
    SessionContainer container, {
    String key = 'browser',
    String scope = 'default',
  }) {
    _ensurePreset(container.registry);
    final session = container.get(browserSessionPreset.name, key, scope: scope);
    if (session == null) return null;
    return _fromPayload(session.payload);
  }

  /// Serializes to the portable JSON envelope (a single-session
  /// [Session.encode] wire form).
  String serialize() => Session(
    type: browserSessionPreset.name,
    id: 'zikzak-browser',
    key: 'browser',
    payload: _payload,
    metadata: SessionMetadata.now(),
  ).encode();

  /// Deserializes from [PortableBrowserSession.serialize] output; the
  /// cookies, headers, and token restore exactly. Throws
  /// [ZuraffaSessionException] on malformed input (recoverable, never a
  /// crash).
  factory PortableBrowserSession.deserialize(String source) {
    final session = Session.decode(source);
    return _fromPayload(session.payload);
  }

  Map<String, dynamic> get _payload => {
    'cookies': cookies.map((cookie) => cookie.toJson()).toList(),
    'headers': headers,
    if (token != null) 'token': token,
  };

  static PortableBrowserSession _fromPayload(Map<String, dynamic> payload) {
    final rawCookies = payload['cookies'];
    final cookies = rawCookies is List
        ? rawCookies
              .whereType<Map>()
              .map(
                (raw) => ZikZakCookie.fromJson(Map<String, dynamic>.from(raw)),
              )
              .toList()
        : <ZikZakCookie>[];
    final rawHeaders = payload['headers'];
    final headers = rawHeaders is Map
        ? rawHeaders.map((k, v) => MapEntry(k.toString(), v.toString()))
        : <String, String>{};
    final token = payload['token'];
    return PortableBrowserSession(
      cookies: cookies,
      headers: headers,
      token: token is String ? token : null,
    );
  }

  static void _ensurePreset(SessionPresetRegistry registry) {
    if (!registry.contains(browserSessionPreset.name)) {
      registry.register(browserSessionPreset);
    }
  }

  static int _sequence = 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortableBrowserSession &&
          _listEquals(other.cookies, cookies) &&
          _mapEquals(other.headers, headers) &&
          other.token == token;

  @override
  int get hashCode => Object.hash(cookies.length, headers.length, token);

  static bool _listEquals(List<ZikZakCookie> a, List<ZikZakCookie> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    return a.entries.every((entry) => b[entry.key] == entry.value);
  }
}
