// Regression guard for issue #2095.
//
// `lib/src/version.dart` is the single source of truth for "which zuraffa
// version is running" — `PackageCompatibility.check` compares a package's
// generated-against constraint against it (spec 025, FR-015). The constant
// sat at '7.2.0' while `pubspec.yaml` moved on to 7.3.x/7.4.x/7.5.0, so
// every consumer on 7.3.0+ was told:
//
//   ⚠️  Package "pkg": package was generated against zuraffa 7.3.0 which
//       is newer than the running 7.2.0 — some generated features may be
//       missing
//
// i.e. the opposite of the truth: a package generated against an OLDER
// zuraffa than the one running was reported as newer.
//
// Two layers:
//  1. the reported symptom — a package generated against an older zuraffa
//     must NOT warn against the running version;
//  2. the drift guard the issue asks for — the constant must equal the
//     pubspec version, so a release that bumps one and forgets the other
//     fails here instead of shipping a false warning to every consumer.

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/package/package_compatibility.dart';
import 'package:zuraffa/src/version.dart';

import '../helpers/project_root.dart';

/// Reads `version:` out of the repo's own `pubspec.yaml`.
Future<String> _pubspecVersion() async {
  final root = await findProjectRoot();
  final pubspec = File('$root/pubspec.yaml');
  expect(
    pubspec.existsSync(),
    isTrue,
    reason: 'pubspec.yaml must exist at the project root ($root)',
  );
  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());
  expect(
    match,
    isNotNull,
    reason: 'pubspec.yaml must declare a `version:` line',
  );
  return match!.group(1)!;
}

void main() {
  group('running version constant (issue #2095)', () {
    test('lib/src/version.dart equals the pubspec version', () async {
      final pubspecVersion = await _pubspecVersion();
      expect(
        version,
        pubspecVersion,
        reason:
            'lib/src/version.dart is frozen at $version while pubspec.yaml '
            'declares $pubspecVersion — every consumer is told the wrong '
            'running version (issue #2095). Bump the constant, or make the '
            'release path stamp it from pubspec.yaml.',
      );
    });

    test('is a parseable semantic version', () {
      expect(
        version,
        matches(RegExp(r'^\d+\.\d+\.\d+([+-].+)?$')),
        reason:
            'PackageCompatibility parses `major.minor.patch`; a constant it '
            'cannot parse degrades every check to a warning',
      );
    });

    test('a package generated against an older zuraffa does not warn', () async {
      final pubspecVersion = await _pubspecVersion();
      final segments = pubspecVersion.split(RegExp(r'[.\-+]'));
      expect(
        segments.length,
        greaterThanOrEqualTo(3),
        reason: 'cannot derive a constraint from "$pubspecVersion"',
      );

      // The same major, a strictly older minor — the shape the false warning
      // was reported for (a package generated against 7.3.0, running 7.5.0).
      final major = int.parse(segments[0]);
      final minor = int.parse(segments[1]);
      final olderMinor = minor - 1;
      if (olderMinor < 0) return; // 0.x: no older minor in the same major.

      // The constraint a package generated from THIS pubspec declares, and
      // the version the runtime actually reports (`registerPackage` passes
      // the constant, engine.dart:181).
      final generatedAgainst = '$major.$minor.${segments[2]}';
      final result = PackageCompatibility.check(
        packageConstraint: '^$generatedAgainst',
        appVersion: version,
      );
      expect(
        result.status,
        PackageCompatibilityStatus.compatible,
        reason:
            'a package generated against $generatedAgainst must be compatible '
            'with the running $version, got ${result.status}: '
            '"${result.message}"',
      );

      final older = PackageCompatibility.check(
        packageConstraint: '^$major.$olderMinor.0',
        appVersion: version,
      );
      expect(
        older.status,
        PackageCompatibilityStatus.compatible,
        reason:
            'a package generated against $major.$olderMinor.0 must be '
            'compatible with the running $version, got ${older.status}: '
            '"${older.message}"',
      );
    });
  });
}
