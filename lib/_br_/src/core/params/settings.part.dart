// dart format off
part of '../../../../src/core/params/settings.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class Settings implements ZorphyValueBase {
  const Settings.fromTrusted();

  const Settings();

  Settings copyWith() {
    return Settings.fromTrusted();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Settings;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Settings';

  static ZorphyBoundaryResult<Settings> fromWire(Map<String, Object?> raw) {
    final violations = <FieldViolation>[];
    if (violations.isNotEmpty) {
      return BoundaryErr<Settings>(
        targetType: 'Settings',
        violations: violations,
      );
    }
    return BoundaryOk<Settings>(Settings.fromTrusted());
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{};
    return map;
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [Settings].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<Settings, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      _ => null,
    };
  }
}

class SettingsMockData {
  SettingsMockData._();

  static Settings single({int seed = 0}) {
    return const Settings();
  }

  static List<Settings> list({int count = 10}) {
    return List<Settings>.generate(count, (index) => single(seed: index));
  }
}

