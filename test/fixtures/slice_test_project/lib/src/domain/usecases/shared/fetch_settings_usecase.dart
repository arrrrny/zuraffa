/// FetchSettingsUseCase (fixture for spec 043 slice tests) — shared by the
/// product and profile features so multi-entry cuts exercise dedup.
library;

/// Loads user settings shared across features.
class FetchSettingsUseCase {
  /// Creates the usecase.
  const FetchSettingsUseCase();

  /// Executes the load.
  Future<Map<String, dynamic>> execute() async => {'theme': 'dark'};
}
