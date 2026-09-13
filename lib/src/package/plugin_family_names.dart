import '../utils/string_utils.dart';

/// The platform adapters a federated plugin family can ship (spec 1601 —
/// the set the zuraffa_auth family covers).
enum PluginPlatform {
  android('android', 'Android', 'Android'),
  ios('ios', 'Ios', 'iOS'),
  macos('macos', 'Macos', 'macOS');

  const PluginPlatform(this.dirSuffix, this.classPrefix, this.label);

  /// Adapter package suffix + file-name prefix (`zuraffa_ffi_android`).
  final String dirSuffix;

  /// Dart identifier prefix (`AndroidFfiPort`).
  final String classPrefix;

  /// Human label for READMEs and docs (`iOS`).
  final String label;
}

/// Name derivation for a federated plugin family (spec 1601).
///
/// One place for the family vocabulary the scaffold and its tests share:
/// `zuraffa_ffi` yields the app-facing package `zuraffa_ffi`, the shared
/// platform core `zuraffa_ffi_platform`, and adapters
/// `zuraffa_ffi_<platform>` — the zuraffa_auth family shape. The class
/// noun strips the `zuraffa_` prefix (`Ffi`, not `ZuraffaFfi`) so
/// generated symbols read `FfiPort`, `AndroidFfiChannel`.
class PluginFamilyNames {
  PluginFamilyNames(this.baseName, [List<PluginPlatform>? platforms])
    : platforms = platforms ?? const [];

  /// The validated snake_case plugin base name.
  final String baseName;

  /// The selected adapter platforms, in scaffold (normalized) order.
  final List<PluginPlatform> platforms;

  /// Class noun: `zuraffa_ffi` → `ffi` → `Ffi`; non-prefixed names keep
  /// their full noun.
  String get noun => baseName.startsWith('zuraffa_')
      ? baseName.substring('zuraffa_'.length)
      : baseName;

  /// App-facing package: `<name>`.
  String get app => baseName;

  /// Shared platform-core package: `<name>_platform`.
  String get core => '${baseName}_platform';

  /// Adapter package for [platform]: `<name>_<platform>`.
  String adapter(PluginPlatform platform) =>
      '${baseName}_${platform.dirSuffix}';

  /// Pascal class noun (`ffi` → `Ffi`).
  String get appPascal => StringUtils.convertToPascalCase(noun);

  /// Every package name in the family, publish order: app-facing first
  /// (every sibling declares it hosted), then the core, then the adapters.
  List<String> get packageNames => [
    app,
    core,
    for (final platform in platforms) adapter(platform),
  ];
}
