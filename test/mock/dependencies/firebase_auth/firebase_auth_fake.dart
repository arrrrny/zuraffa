// GENERATED — certified fake for FirebaseAuth (issue #960).
//
// Scriptable per-method responses + a call recorder (method, named
// arguments, invocation order). An unscripted call is a NAMED error —
// a green here means the staged scenario happened.

// Declared: service | priority: p1 | spec line 125
import 'firebase_auth.dart';
import 'user.dart';

class FirebaseAuthFake implements FirebaseAuth {
  final _CallRecorder _recorder = _CallRecorder();
  Future<User> Function()? _scriptedSignIn;
  Future<void> Function()? _scriptedSignOut;

  /// Script the response for `signIn` — the fake returns exactly
  /// this value (and records the call) while the script is set.
  void scriptSignIn(Future<User> response) {
    _scriptedSignIn = () => response;
  }

  /// Script a THROWING outcome for `signIn`.
  void scriptSignInError(Object error) {
    _scriptedSignIn = () => throw error;
  }

  /// Script the response for `signOut` — the fake returns exactly
  /// this value (and records the call) while the script is set.
  void scriptSignOut(Future<void> response) {
    _scriptedSignOut = () => response;
  }

  /// Script a THROWING outcome for `signOut`.
  void scriptSignOutError(Object error) {
    _scriptedSignOut = () => throw error;
  }

  @override
  Future<User> signIn(String email, String password) {
    _recorder.add('signIn', arguments: {'email': email, 'password': password});
    final scripted = _scriptedSignIn;
    if (scripted == null) {
      throw StateError(
        'unscripted call: FirebaseAuth.signIn — script it with '
        'scriptSignIn() (an unscripted call is a test bug, '
        'never a silent default)',
      );
    }
    return scripted();
  }

  @override
  Future<void> signOut() {
    _recorder.add('signOut');
    final scripted = _scriptedSignOut;
    if (scripted == null) {
      throw StateError(
        'unscripted call: FirebaseAuth.signOut — script it with '
        'scriptSignOut() (an unscripted call is a test bug, '
        'never a silent default)',
      );
    }
    return scripted();
  }
}

/// Call recorder: (method, named arguments, invocation order) — query
/// per method for interaction assertions.
class _CallRecorder {
  final List<({String method, Map<String, Object?> arguments})> calls =
      <({String method, Map<String, Object?> arguments})>[];

  void add(String method, {Map<String, Object?> arguments = const {}}) =>
      calls.add((method: method, arguments: arguments));

  List<({String method, Map<String, Object?> arguments})> callsTo(
    String method,
  ) => calls.where((c) => c.method == method).toList();
}
