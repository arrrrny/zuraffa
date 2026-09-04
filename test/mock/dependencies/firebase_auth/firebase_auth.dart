// GENERATED — `zfa mock dependency FirebaseAuth` (issue #960).
//
// Declared interface: exactly the members the External Dependencies &
// Contracts row declares — no invented, missing, or renamed members.
// Regenerating from an unchanged row is byte-for-byte identical.
library;

import 'user.dart';

// Declared: service | priority: p1 | spec line 125
abstract class FirebaseAuth {
  Future<User> signIn(String email, String password);
  Future<void> signOut();
}
