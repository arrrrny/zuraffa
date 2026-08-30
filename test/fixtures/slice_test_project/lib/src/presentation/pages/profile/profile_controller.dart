/// ProfileController (fixture for spec 043).
library;

import 'profile_presenter.dart';
import 'profile_state.dart';

/// Drives the profile page.
class ProfileController {
  /// Creates the controller.
  ProfileController([ProfilePresenter? presenter])
    : _presenter = presenter ?? ProfilePresenter();

  final ProfilePresenter _presenter;

  /// Current state.
  ProfileState state = const ProfileState();

  /// Loads the profile and updates [state].
  Future<void> load() async {
    state = await _presenter.loadProfile();
  }
}
