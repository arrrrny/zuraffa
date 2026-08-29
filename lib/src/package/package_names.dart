import '../utils/string_utils.dart';

/// Naming conventions shared by the v6 package SDK (spec 025).
///
/// The scaffold and the DI plugin's registrar builder MUST derive identical
/// names from a package name — the scaffolded module calls the registrar
/// function the generator later regenerates — so the derivation lives here,
/// in one place.
class PackageNames {
  const PackageNames._();

  /// The Pascal-case base name for [packageName], with a redundant trailing
  /// `Package` folded away so `notes_package` yields `Notes` (module
  /// `NotesPackageModule`, registrar `registerNotesPackage`) instead of the
  /// stuttering `NotesPackagePackageModule`.
  static String pascalFor(String packageName) {
    var pascal = StringUtils.convertToPascalCase(packageName);
    if (pascal.length > 'Package'.length && pascal.endsWith('Package')) {
      pascal = pascal.substring(0, pascal.length - 'Package'.length);
    }
    return pascal.isEmpty ? 'Package' : pascal;
  }

  /// The runtime module class name for [packageName]
  /// (e.g. `notes_package` → `NotesPackageModule`).
  static String moduleClassFor(String packageName) =>
      '${pascalFor(packageName)}PackageModule';

  /// The package registrar function name for [packageName]
  /// (e.g. `notes_package` → `registerNotesPackagePackage` is avoided;
  /// yields `registerNotesPackage`).
  static String registrarFunctionFor(String packageName) =>
      'register${pascalFor(packageName)}Package';
}
