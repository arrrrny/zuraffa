/// Profile entity (fixture for spec 043 slice tests).
library;

/// The user's profile.
class Profile {
  /// Creates a profile.
  const Profile({required this.displayName, required this.email});

  /// Shown name.
  final String displayName;

  /// Contact email.
  final String email;
}
