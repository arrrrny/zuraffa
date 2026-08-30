/// ProfileState (fixture for spec 043).
library;

import '../../../domain/entities/profile/profile.dart';

/// Immutable UI state for the profile page.
class ProfileState {
  /// Creates the state.
  const ProfileState({this.profile, this.settings});

  /// The loaded profile, if any.
  final Profile? profile;

  /// Shared settings, if loaded.
  final Map<String, dynamic>? settings;

  /// Returns a copy with the given fields replaced.
  ProfileState copyWith({Profile? profile, Map<String, dynamic>? settings}) =>
      ProfileState(
        profile: profile ?? this.profile,
        settings: settings ?? this.settings,
      );
}
