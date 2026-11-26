// dart format off
part of '../../../../src/core/params/credentials.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class Credentials implements ZorphyValueBase {
  const Credentials.fromTrusted();

  const Credentials();

  Credentials copyWith() {
    return Credentials.fromTrusted();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Credentials;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Credentials';

  static ZorphyBoundaryResult<Credentials> fromWire(Map<String, Object?> raw) {
    final violations = <FieldViolation>[];
    if (violations.isNotEmpty) {
      return BoundaryErr<Credentials>(
        targetType: 'Credentials',
        violations: violations,
      );
    }
    return BoundaryOk<Credentials>(Credentials.fromTrusted());
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{};
    return map;
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [Credentials].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<Credentials, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      _ => null,
    };
  }
}

class CredentialsMockData {
  CredentialsMockData._();

  static Credentials single({int seed = 0}) {
    return const Credentials();
  }

  static List<Credentials> list({int count = 10}) {
    return List<Credentials>.generate(count, (index) => single(seed: index));
  }
}

