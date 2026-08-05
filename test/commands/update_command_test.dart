import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/update_command.dart';

void main() {
  group('UpdateCommand', () {
    group('_compareVersions', () {
      test('equal versions return 0', () {
        expect(UpdateCommand.compareVersions('1.0.0', '1.0.0'), 0);
        expect(UpdateCommand.compareVersions('2.3.4', '2.3.4'), 0);
      });

      test('major version difference', () {
        expect(UpdateCommand.compareVersions('1.0.0', '2.0.0'), isNegative);
        expect(UpdateCommand.compareVersions('2.0.0', '1.0.0'), isPositive);
      });

      test('minor version difference', () {
        expect(UpdateCommand.compareVersions('1.1.0', '1.2.0'), isNegative);
        expect(UpdateCommand.compareVersions('1.2.0', '1.1.0'), isPositive);
      });

      test('patch version difference', () {
        expect(UpdateCommand.compareVersions('1.0.1', '1.0.2'), isNegative);
        expect(UpdateCommand.compareVersions('1.0.2', '1.0.1'), isPositive);
      });

      test('handles pre-release suffixes', () {
        // Per SemVer: pre-release versions have lower precedence than stable
        expect(UpdateCommand.compareVersions('1.0.0-alpha', '1.0.0'), isNegative);
        expect(UpdateCommand.compareVersions('1.0.0-beta', '1.0.0'), isNegative);
        expect(UpdateCommand.compareVersions('1.0.0', '1.0.0-alpha'), isPositive);
        // Build metadata is ignored
        expect(UpdateCommand.compareVersions('1.0.0+build', '1.0.0'), 0);
      });

      test('pre-release ordering', () {
        // Pre-release versions with same numeric part are compared lexically
        expect(UpdateCommand.compareVersions('1.0.0-alpha', '1.0.0-beta'), isNegative);
        expect(UpdateCommand.compareVersions('1.0.0-beta', '1.0.0-alpha'), isPositive);
        expect(UpdateCommand.compareVersions('1.0.0-alpha', '1.0.0-alpha'), 0);
      });

      test('handles missing parts', () {
        expect(UpdateCommand.compareVersions('1', '1.0.0'), 0);
        expect(UpdateCommand.compareVersions('1.2', '1.2.0'), 0);
        expect(UpdateCommand.compareVersions('1', '2.0.0'), isNegative);
      });

      test('handles non-numeric gracefully', () {
        expect(UpdateCommand.compareVersions('unknown', '0.0.0'), 0);
        expect(UpdateCommand.compareVersions('1.0.0', 'unknown'), isPositive);
      });
      
      test('complex comparison chain', () {
        expect(UpdateCommand.compareVersions('5.1.0', '6.0.0'), isNegative);
        expect(UpdateCommand.compareVersions('6.0.0', '5.1.0'), isPositive);
        expect(UpdateCommand.compareVersions('6.0.0', '6.0.1'), isNegative);
        expect(UpdateCommand.compareVersions('6.0.1', '6.0.0'), isPositive);
      });
    });

    group('_parseVersion', () {
      test('parses standard version', () {
        final result = UpdateCommand.parseVersion('1.2.3');
        expect(result.numeric, [1, 2, 3]);
        expect(result.preRelease, isNull);
      });

      test('parses version with pre-release', () {
        final result = UpdateCommand.parseVersion('1.2.3-alpha.1');
        expect(result.numeric, [1, 2, 3]);
        expect(result.preRelease, 'alpha.1');
      });

      test('parses version with build metadata', () {
        final result = UpdateCommand.parseVersion('1.2.3+build.42');
        expect(result.numeric, [1, 2, 3]);
        expect(result.preRelease, isNull);
      });

      test('parses version with both pre-release and build metadata', () {
        final result = UpdateCommand.parseVersion('1.2.3-alpha+build.42');
        expect(result.numeric, [1, 2, 3]);
        expect(result.preRelease, 'alpha');
      });

      test('handles short versions', () {
        var result = UpdateCommand.parseVersion('1');
        expect(result.numeric, [1, 0, 0]);
        expect(result.preRelease, isNull);

        result = UpdateCommand.parseVersion('1.2');
        expect(result.numeric, [1, 2, 0]);
        expect(result.preRelease, isNull);
      });

      test('handles empty string', () {
        final result = UpdateCommand.parseVersion('');
        expect(result.numeric, [0, 0, 0]);
        expect(result.preRelease, isNull);
      });
    });
  });
}
