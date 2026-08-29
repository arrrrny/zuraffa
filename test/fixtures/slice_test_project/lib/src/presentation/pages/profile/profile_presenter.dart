/// ProfilePresenter (fixture for spec 043) — shares FetchSettingsUseCase with
/// ProductPresenter so multi-entry cuts dedup it (US4, U26, A12).
library;

import 'package:get_it/get_it.dart';

import '../../../domain/entities/profile/profile.dart';
import '../../../domain/usecases/shared/fetch_settings_usecase.dart';
import 'profile_state.dart';

final getIt = GetIt.instance;

/// Presents profile data for the view.
class ProfilePresenter {
  /// Creates the presenter, resolving usecases via the service locator.
  ProfilePresenter() {
    _fetchSettings = getIt<FetchSettingsUseCase>();
  }

  late final FetchSettingsUseCase _fetchSettings;

  /// Loads profile and settings into a state.
  Future<ProfileState> loadProfile() async {
    final settings = await _fetchSettings.execute();
    return const ProfileState().copyWith(settings: settings);
  }
}
