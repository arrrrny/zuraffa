import '../utils/string_utils.dart';

/// Platforms a federated plugin family can ship adapters for
/// (spec 1601 — the set the zuraffa_auth family covers).
enum PluginPlatform { android, ios, macos }

/// Role of one package inside a federated plugin family.
enum PackageRole { app, core, adapter }

/// Name derivation for a federated plugin family (spec 1601).
///
/// `zuraffa_ffi` yields the app-facing package `zuraffa_ffi`, the shared
/// platform core `zuraffa_ffi_platform`, and adapters
/// `zuraffa_ffi_<platform>` — the zuraffa_auth family shape. Pascal forms
/// drive class names in the generated sources, so the derivation lives in
/// one place the scaffold and its tests share.
class PluginFamilyNames {
  PluginFamilyNames(this.baseName);

  /// The validated snake_case plugin base name.
  final String baseName;

  /// App-facing package: `<name>`.
  String get app => baseName;

  /// Shared platform-core package: `<name>_platform`.
  String get core => '${baseName}_platform';

  /// Adapter package for [platform]: `<name>_<platform>`.
  String adapter(PluginPlatform platform) => '${baseName}_${platform.name}';

  /// Pascal base name (`zuraffa_ffi` → `ZuraffaFfi`).
  String get appPascal => StringUtils.convertToPascalCase(baseName);

  /// Pascal core name (`zuraffa_ffi_platform` → `ZuraffaFfiPlatform`).
  String get corePascal => StringUtils.convertToPascalCase(core);

  /// Pascal adapter class prefix (`zuraffa_ffi_android` → `ZuraffaFfiAndroid`).
  String adapterPascal(PluginPlatform platform) =>
      StringUtils.convertToPascalCase(adapter(platform));

  /// Every package name in the family for [platforms], app first.
  List<String> packageNames(Iterable<PluginPlatform> platforms) => [
        app,
        core,
        ...platforms.map(adapter),
      ];
}
