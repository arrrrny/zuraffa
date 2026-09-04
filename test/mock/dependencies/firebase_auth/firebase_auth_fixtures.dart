// GENERATED — fixture lane for FirebaseAuth (issue #960).

// Declared: service | priority: p1 | spec line 125
import 'firebase_auth_fake.dart';

class FirebaseAuthFixtures {
  /// Staged scenario for `signIn` — deterministic staging from the
  /// declared signature; the response is supplied by the test.
  static void signIn(
    FirebaseAuthFake fake,
    Future<User> response,
  ) {
    fake.scriptSignIn(response);
  }

  /// Staged scenario for `signOut` — deterministic staging from the
  /// declared signature; the response is supplied by the test.
  static void signOut(
    FirebaseAuthFake fake,
    Future<void> response,
  ) {
    fake.scriptSignOut(response);
  }

}
