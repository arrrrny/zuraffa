/// The five certified external-service simulation adapter families
/// (bug #832, VISION §9 "simulation worlds").
///
/// Every family implements the SAME production interface a live binding
/// implements — the TDD loop's data sources consume the adapters through
/// those contracts (DI in the test bootstrap, `SimulationWorld.bindTo`),
/// so swapping the certified simulation for the production binding is a
/// container registration change, never a code change:
///
/// | Family     | Adapter               | Production interface            |
/// |------------|-----------------------|---------------------------------|
/// | Firebase   | `FirebaseAuthAdapter` | `AuthContract`                  |
/// | Vendure    | `VendureAdapter`      | `VendureContract` (GraphQL)     |
/// | REST       | `RestAdapter`         | `RestContract` (JSON transport) |
/// | AdMob      | `AdMobAdapter`        | `AdContract`                    |
/// | OTel       | `OtelAdapter`         | `SpanExporter` (real OTel SDK)  |
///
/// The adapters are fixture-driven and scriptable: latency is injected
/// deterministically, failures replay the recorded error surfaces, and
/// identical calls return identical bytes. "Mock the framework certifies"
/// means the fixture worlds these adapters replay are committed, hashed,
/// and verified — see `fixture_registry.dart` / `simulation_world.dart`.
library;

import 'dart:async';

import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;

// ---------------------------------------------------------------------------
// Shared error surfaces
// ---------------------------------------------------------------------------

/// A scripted HTTP failure replayed by [RestAdapter].
final class SimulatedHttpException implements Exception {
  const SimulatedHttpException(
    this.statusCode,
    this.method,
    this.path,
    this.message,
  );

  /// The scripted HTTP status code (e.g. 404, 500).
  final int statusCode;
  final String method;
  final String path;

  /// Why this failure was recorded in the fixture world.
  final String message;

  @override
  String toString() =>
      'SimulatedHttpException($statusCode): $method $path — $message';
}

/// A scripted GraphQL failure replayed by [VendureAdapter], carrying the
/// recorded `errors` payload exactly as a live Vendure node would return.
final class SimulatedGraphQLError implements Exception {
  const SimulatedGraphQLError(this.errors);

  /// The GraphQL `errors` array from the recorded golden contract.
  final List<Map<String, dynamic>> errors;

  @override
  String toString() => 'SimulatedGraphQLError: ${errors.toString()}';
}

/// A scripted auth failure replayed by [FirebaseAuthAdapter]. [code]
/// mirrors the Firebase Auth error codes the production binding surfaces
/// (`user-not-found`, `wrong-password`, `user-disabled`,
/// `email-already-in-use`, `requires-recent-login`, `no-current-user`).
final class SimulatedAuthException implements Exception {
  const SimulatedAuthException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'SimulatedAuthException($code): $message';
}

// ---------------------------------------------------------------------------
// REST family (Market Fiyati / Google Shopping / generic JSON services)
// ---------------------------------------------------------------------------

/// The production REST transport contract. A live binding would dial the
/// real API; the certified [RestAdapter] replays recorded JSON fixtures.
abstract interface class RestContract {
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query});
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body});
  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body});
  Future<Map<String, dynamic>> delete(String path);
}

/// Certified REST simulation: recorded JSON fixtures keyed by
/// `"<METHOD> <path>"`, scripted faults, deterministic latency.
final class RestAdapter implements RestContract {
  RestAdapter({required Map<String, dynamic> world})
    : _fixtures = (world['fixtures'] as Map<String, dynamic>? ?? const {})
          .cast<String, dynamic>(),
      _faults = (world['scriptedFaults'] as Map<String, dynamic>? ?? const {})
          .cast<String, dynamic>(),
      _latency = Duration(
        milliseconds: (world['latencyMs'] as num?)?.toInt() ?? 0,
      );

  final Map<String, dynamic> _fixtures;
  final Map<String, dynamic> _faults;
  final Duration _latency;

  static String _full(String path, Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return path;
    final encoded = query.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent('${e.value}')}',
        )
        .join('&');
    return '$path?$encoded';
  }

  /// Candidate fixture keys for [method] + [path] + [query], most
  /// specific first: exact `METHOD path?query`, the full path under any
  /// recorded method, `METHOD path`, the base path under any method.
  List<String> _candidates(String method, String path, String full) {
    final base = path.split('?').first;
    final keys = <String>[
      '$method $full',
      full,
      '$method $path',
      path,
      '$method $base',
      base,
    ];
    if (full != base && full != path && path != base) {
      keys.addAll(<String>['$method $base', base]);
    }
    return keys;
  }

  String? _resolveKey(Map<String, dynamic> table, List<String> candidates) {
    for (final candidate in candidates) {
      if (table.containsKey(candidate)) return candidate;
    }
    return null;
  }

  /// Last-resort resolution: the same path recorded under ANY method
  /// (resource-level contract). Method-specific keys always win.
  String? _anyMethodKey(
    Map<String, dynamic> table,
    String method,
    String path,
    String full,
  ) {
    final base = path.split('?').first;
    for (final key in table.keys) {
      final space = key.indexOf(' ');
      if (space <= 0) continue;
      final recordedPath = key.substring(space + 1);
      if (recordedPath == full ||
          recordedPath == base ||
          recordedPath == path) {
        return key;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _dispatch(
    String method,
    String path,
    Map<String, dynamic>? query,
  ) async {
    if (_latency > Duration.zero) await Future<void>.delayed(_latency);
    final candidates = _candidates(method, path, _full(path, query));
    final fixtureKey =
        _resolveKey(_fixtures, candidates) ??
        _anyMethodKey(_fixtures, method, path, _full(path, query));
    if (fixtureKey != null) {
      final fixture = _fixtures[fixtureKey] as Map<String, dynamic>;
      final status = (fixture['status'] as num?)?.toInt() ?? 200;
      if (status >= 400) {
        throw SimulatedHttpException(
          status,
          method,
          path,
          fixture['body']?.toString() ?? 'scripted fault',
        );
      }
      return (fixture['body'] as Map<String, dynamic>? ?? const {})
          .cast<String, dynamic>();
    }
    final faultKey =
        _resolveKey(_faults, candidates) ??
        _anyMethodKey(_faults, method, path, _full(path, query));
    if (faultKey != null) {
      throw SimulatedHttpException(
        (_faults[faultKey] as num).toInt(),
        method,
        path,
        'scripted fault',
      );
    }
    throw SimulatedHttpException(
      404,
      method,
      path,
      "no certified fixture for '$method $path' — record it in the "
      'simulation world and re-certify with `zfa simulate --scaffold`',
    );
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _dispatch('GET', path, query);

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) => _dispatch('POST', path, body);

  @override
  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _dispatch('PUT', path, body);

  @override
  Future<Map<String, dynamic>> delete(String path) =>
      _dispatch('DELETE', path, null);
}

// ---------------------------------------------------------------------------
// Vendure family (GraphQL golden fixtures)
// ---------------------------------------------------------------------------

/// The production Vendure (GraphQL) contract. A live binding posts the
/// document to the real Shop API; the certified [VendureAdapter] replays
/// recorded golden responses.
abstract interface class VendureContract {
  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic>? variables,
  });
  Future<Map<String, dynamic>> mutation(
    String document, {
    Map<String, dynamic>? variables,
  });
}

/// Certified Vendure simulation: GraphQL golden files keyed by operation
/// name, recorded error surfaces, deterministic latency.
final class VendureAdapter implements VendureContract {
  VendureAdapter({required Map<String, dynamic> world})
    : _queries = (world['goldenQueries'] as Map<String, dynamic>? ?? const {})
          .cast<String, dynamic>(),
      _mutations =
          (world['goldenMutations'] as Map<String, dynamic>? ?? const {})
              .cast<String, dynamic>(),
      _errors = (world['scriptedErrors'] as Map<String, dynamic>? ?? const {})
          .cast<String, dynamic>(),
      _latency = Duration(
        milliseconds: (world['latencyMs'] as num?)?.toInt() ?? 0,
      );

  final Map<String, dynamic> _queries;
  final Map<String, dynamic> _mutations;
  final Map<String, dynamic> _errors;
  final Duration _latency;

  /// Extract the operation name from a GraphQL document: a named
  /// operation (`query Product { ... }`) wins; an anonymous operation
  /// falls back to its first root field.
  static String? operationNameOf(String document) {
    final named = RegExp(
      r'\b(?:query|mutation)\s+([A-Za-z_][A-Za-z0-9_]*)',
    ).firstMatch(document);
    if (named != null) return named.group(1);
    return RegExp(
      r'\{\s*([A-Za-z_][A-Za-z0-9_]*)',
    ).firstMatch(document)?.group(1);
  }

  Future<Map<String, dynamic>> _execute(
    String kind,
    Map<String, dynamic> golden,
    String document,
  ) async {
    if (_latency > Duration.zero) await Future<void>.delayed(_latency);
    final operation = operationNameOf(document);
    if (_errors.containsKey(operation)) {
      final errors = (_errors[operation] as List)
          .cast<Map<String, dynamic>>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      throw SimulatedGraphQLError(errors);
    }
    final response = golden[operation];
    if (response == null) {
      throw SimulatedGraphQLError([
        {
          'message':
              "Unknown operation '$operation' — not in the certified "
              'golden fixtures. Record it and re-certify with '
              '`zfa simulate --scaffold`.',
        },
      ]);
    }
    return response.cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic>? variables,
  }) => _execute('query', _queries, document);

  @override
  Future<Map<String, dynamic>> mutation(
    String document, {
    Map<String, dynamic>? variables,
  }) => _execute('mutation', _mutations, document);
}

// ---------------------------------------------------------------------------
// Firebase Auth family (scriptable auth states)
// ---------------------------------------------------------------------------

/// The certified simulated auth user.
final class SimulatedAuthUser {
  const SimulatedAuthUser({required this.uid, this.email, this.displayName});

  final String uid;
  final String? email;
  final String? displayName;

  Map<String, dynamic> toJson() => {
    'uid': uid,
    if (email != null) 'email': email,
    if (displayName != null) 'displayName': displayName,
  };
}

/// The production auth contract (Firebase Auth-shaped). A live binding
/// fronts Firebase; the certified [FirebaseAuthAdapter] scripts auth
/// states: signed-in/out, credential errors, deletion flows.
abstract interface class AuthContract {
  SimulatedAuthUser? get currentUser;
  bool get isSignedIn;
  Future<SimulatedAuthUser> signIn({
    required String email,
    required String password,
  });
  Future<SimulatedAuthUser> register({
    required String email,
    required String password,
  });
  Future<void> signOut();
  Future<void> deleteAccount();
}

/// Certified Firebase Auth simulation driven by the committed auth world:
///
/// ```json
/// {
///   "initialUser": null,
///   "users": [{"email": "...", "password": "...", "uid": "...", "displayName": "..."}],
///   "scriptedErrors": [{"email": "...", "code": "user-disabled"}],
///   "deletionRequiresRecentLogin": false,
///   "latencyMs": 0
/// }
/// ```
final class FirebaseAuthAdapter implements AuthContract {
  FirebaseAuthAdapter({required Map<String, dynamic> world})
    : _users = [
        for (final u
            in (world['users'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          Map<String, dynamic>.of(u),
      ],
      _scriptedErrors = {
        for (final e
            in (world['scriptedErrors'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          (e['email'] as String): (e['code'] as String),
      },
      _deletionRequiresRecentLogin =
          (world['deletionRequiresRecentLogin'] as bool?) ?? false,
      _latency = Duration(
        milliseconds: (world['latencyMs'] as num?)?.toInt() ?? 0,
      ) {
    final initial = world['initialUser'] as Map<String, dynamic>?;
    if (initial != null) {
      _currentUser = SimulatedAuthUser(
        uid: initial['uid'] as String,
        email: initial['email'] as String?,
        displayName: initial['displayName'] as String?,
      );
    }
  }

  final List<Map<String, dynamic>> _users;
  final Map<String, String> _scriptedErrors;
  final bool _deletionRequiresRecentLogin;
  final Duration _latency;
  SimulatedAuthUser? _currentUser;

  @override
  SimulatedAuthUser? get currentUser => _currentUser;

  @override
  bool get isSignedIn => _currentUser != null;

  static String _uidFor(String email) =>
      'u-${email.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-')}'
          .replaceAll(RegExp(r'-+$'), '');

  SimulatedAuthUser _userOf(Map<String, dynamic> record) => SimulatedAuthUser(
    uid: record['uid'] as String,
    email: record['email'] as String?,
    displayName: record['displayName'] as String?,
  );

  Map<String, dynamic>? _find(String email) {
    for (final u in _users) {
      if ((u['email'] as String).toLowerCase() == email.toLowerCase()) {
        return u;
      }
    }
    return null;
  }

  Future<SimulatedAuthUser> _settle(Map<String, dynamic> record) async {
    if (_latency > Duration.zero) await Future<void>.delayed(_latency);
    _currentUser = _userOf(record);
    return _currentUser!;
  }

  @override
  Future<SimulatedAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final scripted = _scriptedErrors[email];
    if (scripted != null) {
      throw SimulatedAuthException(scripted, 'scripted auth state for $email');
    }
    final record = _find(email);
    if (record == null) {
      throw SimulatedAuthException(
        'user-not-found',
        'no certified user for $email',
      );
    }
    if (record['password'] != password) {
      throw SimulatedAuthException(
        'wrong-password',
        'scripted credential mismatch for $email',
      );
    }
    return _settle(record);
  }

  @override
  Future<SimulatedAuthUser> register({
    required String email,
    required String password,
  }) async {
    if (_scriptedErrors.containsKey(email)) {
      throw SimulatedAuthException(
        _scriptedErrors[email]!,
        'scripted auth state for $email',
      );
    }
    if (_find(email) != null) {
      throw SimulatedAuthException(
        'email-already-in-use',
        '$email already registered',
      );
    }
    final record = {
      'email': email,
      'password': password,
      'uid': _uidFor(email),
      'displayName': null,
    };
    _users.add(record);
    return _settle(record);
  }

  @override
  Future<void> signOut() async {
    if (_latency > Duration.zero) await Future<void>.delayed(_latency);
    _currentUser = null;
  }

  @override
  Future<void> deleteAccount() async {
    if (_latency > Duration.zero) await Future<void>.delayed(_latency);
    final user = _currentUser;
    if (user == null) {
      throw const SimulatedAuthException(
        'no-current-user',
        'deletion requires a signed-in user',
      );
    }
    if (_deletionRequiresRecentLogin) {
      throw const SimulatedAuthException(
        'requires-recent-login',
        'scripted deletion flow: recent login required first',
      );
    }
    _users.removeWhere((u) => u['uid'] == user.uid);
    _currentUser = null;
  }
}

// ---------------------------------------------------------------------------
// AdMob family (load/show/fail callbacks)
// ---------------------------------------------------------------------------

/// Lifecycle states of the certified AdMob simulation.
enum AdLoadState { idle, loading, loaded, failed, shown, dismissed }

/// The load/show/fail callbacks fired by [AdMobAdapter].
final class AdCallbacks {
  const AdCallbacks({
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdShown,
    this.onAdDismissed,
  });

  final void Function()? onAdLoaded;
  final void Function(String errorCode)? onAdFailed;
  final void Function()? onAdShown;
  final void Function()? onAdDismissed;
}

/// The production ads contract. A live binding fronts the Google Mobile
/// Ads SDK; the certified [AdMobAdapter] scripts load/show/fail callbacks.
abstract interface class AdContract {
  AdLoadState get state;
  Future<void> load({AdCallbacks callbacks});
  Future<void> show({AdCallbacks callbacks});
}

/// Certified AdMob simulation: deterministic load/show/fail callback
/// replay with scriptable failures (`scriptLoadFailure` /
/// `scriptShowFailure` / `clearScripts`).
final class AdMobAdapter implements AdContract {
  AdMobAdapter({required Map<String, dynamic> world})
    : _scriptedLoadFailure = world['scriptedLoadFailure'] as String?,
      _scriptedShowFailure = world['scriptedShowFailure'] as String?,
      _latency = Duration(
        milliseconds: (world['latencyMs'] as num?)?.toInt() ?? 0,
      );

  final String? _scriptedLoadFailure;
  final String? _scriptedShowFailure;
  final Duration _latency;

  String? _nextLoadFailure;
  String? _nextShowFailure;
  AdLoadState _state = AdLoadState.idle;

  @override
  AdLoadState get state => _state;

  /// Script the next [load] to fail with [errorCode].
  void scriptLoadFailure(String errorCode) => _nextLoadFailure = errorCode;

  /// Script the next [show] to fail with [errorCode].
  void scriptShowFailure(String errorCode) => _nextShowFailure = errorCode;

  /// Clear scripted failures (the committed world default is the
  /// deterministic happy path).
  void clearScripts() {
    _nextLoadFailure = null;
    _nextShowFailure = null;
  }

  @override
  Future<void> load({AdCallbacks callbacks = const AdCallbacks()}) async {
    _state = AdLoadState.loading;
    if (_latency > Duration.zero) await Future<void>.delayed(_latency);
    final failure = _nextLoadFailure ?? _scriptedLoadFailure;
    if (failure != null) {
      _state = AdLoadState.failed;
      callbacks.onAdFailed?.call(failure);
      return;
    }
    _state = AdLoadState.loaded;
    callbacks.onAdLoaded?.call();
  }

  @override
  Future<void> show({AdCallbacks callbacks = const AdCallbacks()}) async {
    if (_latency > Duration.zero) await Future<void>.delayed(_latency);
    final failure = _nextShowFailure ?? _scriptedShowFailure;
    if (failure != null) {
      callbacks.onAdFailed?.call(failure);
      return;
    }
    if (_state != AdLoadState.loaded) {
      callbacks.onAdFailed?.call('ad-not-ready');
      return;
    }
    _state = AdLoadState.shown;
    callbacks.onAdShown?.call();
    _state = AdLoadState.dismissed;
    callbacks.onAdDismissed?.call();
  }
}

// ---------------------------------------------------------------------------
// OTel family (capture-and-assert exporter)
// ---------------------------------------------------------------------------

/// One span captured by [OtelAdapter].
final class SpanRecord {
  const SpanRecord({
    required this.name,
    required this.statusCode,
    required this.attributes,
  });

  final String name;
  final otel_api.StatusCode statusCode;
  final Map<String, Object> attributes;
}

/// Certified OpenTelemetry simulation: a capture-and-assert exporter.
///
/// Implements the REAL production [otel_sdk.SpanExporter] interface — the
/// same interface the live OTLP/collector exporter implements — so
/// `TelemetryHook`/`OtelTracer` pipelines run unchanged against it and
/// every span ends up asserted from memory instead of shipped over the
/// network.
final class OtelAdapter implements otel_sdk.SpanExporter {
  final List<SpanRecord> _captured = <SpanRecord>[];
  bool _shutdown = false;

  /// All captured span records, in export order.
  List<SpanRecord> get captured => List.unmodifiable(_captured);

  /// Names of every captured span, in export order.
  List<String> get spanNames => List.unmodifiable(_captured.map((r) => r.name));

  /// The first captured record named [name], or `null`.
  SpanRecord? byName(String name) {
    for (final record in _captured) {
      if (record.name == name) return record;
    }
    return null;
  }

  /// Whether a span named [name] was captured.
  bool hasSpan(String name) => byName(name) != null;

  /// Whether [shutdown] was called.
  bool get isShutdown => _shutdown;

  /// Forget everything captured so far (between scenarios).
  void reset() => _captured.clear();

  @override
  void export(List<otel_sdk.ReadOnlySpan> spans) {
    if (_shutdown) return;
    for (final span in spans) {
      final attributes = <String, Object>{};
      for (final key in span.attributes.keys) {
        final value = span.attributes.get(key);
        if (value != null) attributes[key] = value;
      }
      _captured.add(
        SpanRecord(
          name: span.name,
          statusCode: span.status.code,
          attributes: attributes,
        ),
      );
    }
  }

  @override
  void forceFlush() {
    // In-memory capture: nothing to flush.
  }

  @override
  void shutdown() {
    _shutdown = true;
  }
}
