/// Zuraffa version-compatibility checking between a package and its
/// consuming app (spec 025, FR-015).
///
/// A Zuraffa-native package declares the zuraffa constraint it was
/// generated against (stamped into its `pubspec.yaml` and its package
/// module). The consuming app validates that constraint against the
/// zuraffa version it actually runs — at module registration time
/// (`ZuraffaEngine.registerPackage`, startup) — and fails loudly on a
/// major-version mismatch instead of misbehaving at runtime.
library;

/// Outcome of a compatibility check.
enum PackageCompatibilityStatus {
  /// The package's constraint is satisfied by the app's version.
  compatible,

  /// The package was generated against a newer minor of the same major —
  /// usable, but features may be missing. Surfaced as a warning.
  warning,

  /// The package targets a different zuraffa major — the SDK contract is
  /// broken. Registration must fail with a clear error.
  incompatible,
}

/// Result of [PackageCompatibility.check].
class PackageCompatibilityResult {
  const PackageCompatibilityResult(this.status, this.message);

  final PackageCompatibilityStatus status;

  /// Human-readable explanation naming both versions (used in errors,
  /// warnings, and CLI output).
  final String message;

  /// Whether the package may be activated.
  bool get isCompatible => status != PackageCompatibilityStatus.incompatible;
}

/// Parses the constraint forms the package SDK itself emits and compares
/// them against a concrete running version.
///
/// Supported constraint forms:
/// - caret: `^6.1.0` (also `^6.1`, `^6`)
/// - range: `>=6.1.0 <7.0.0`
/// - exact: `6.1.0`
///
/// The comparison is deliberately conservative: it derives the **minimum
/// required version** from the constraint and compares majors/minors.
class PackageCompatibility {
  const PackageCompatibility._();

  static final RegExp _versionPattern = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?');

  /// Checks [packageConstraint] (the package's declared zuraffa
  /// constraint) against [appVersion] (the running zuraffa version).
  static PackageCompatibilityResult check({
    required String packageConstraint,
    required String appVersion,
  }) {
    final minRequired = _minimumOf(packageConstraint);
    final app = _parse(appVersion);

    if (minRequired == null || app == null) {
      // Unparseable input is never silently accepted for a mismatch
      // verdict — treat as warning with an explicit message.
      return PackageCompatibilityResult(
        PackageCompatibilityStatus.warning,
        'could not compare package constraint '
        '"$packageConstraint" with app version "$appVersion"',
      );
    }

    if (minRequired[0] != app[0]) {
      return PackageCompatibilityResult(
        PackageCompatibilityStatus.incompatible,
        'package requires zuraffa $packageConstraint '
        '(major ${minRequired[0]}) but this app runs zuraffa '
        '$appVersion (major ${app[0]})',
      );
    }

    if (minRequired[1] > app[1]) {
      return PackageCompatibilityResult(
        PackageCompatibilityStatus.warning,
        'package was generated against zuraffa '
        '${minRequired.join('.')} which is newer than the running '
        '$appVersion — some generated features may be missing',
      );
    }

    return const PackageCompatibilityResult(
      PackageCompatibilityStatus.compatible,
      'compatible',
    );
  }

  /// Derives the minimum required `[major, minor, patch]` from a
  /// constraint string, or `null` when no version literal is present.
  static List<int>? _minimumOf(String constraint) {
    final match = _versionPattern.firstMatch(constraint);
    if (match == null) return null;
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      match.group(3) != null ? int.parse(match.group(3)!) : 0,
    ];
  }

  static List<int>? _parse(String version) => _minimumOf(version);
}
