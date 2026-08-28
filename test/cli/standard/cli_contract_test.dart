// Tests for CliContract (FR-002, FR-008, FR-009).
//
// Covers U1-U9 in the test-list.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('CliContract', () {
    group('standard exit codes (FR-002)', () {
      final contract = CliContract.standard;
      final codes = contract.exitCode;

      test('U1: success exit code is 0', () {
        expect(codes.success, equals(0));
      });

      test('U2: usage exit code is 64', () {
        expect(codes.usage, equals(64));
      });

      test('U3: runtime exit code is 1', () {
        expect(codes.runtime, equals(1));
      });

      test('U4: notFound exit code is 2', () {
        expect(codes.notFound, equals(2));
      });

      test('U5: conflict exit code is 3', () {
        expect(codes.conflict, equals(3));
      });

      test('U6: versionMismatch exit code is 4', () {
        expect(codes.versionMismatch, equals(4));
      });

      test('U7: circularRef exit code is 5', () {
        expect(codes.circularRef, equals(5));
      });

      test('vocabulary has all seven codes', () {
        expect(
          codes.vocabulary.keys,
          containsAll(const [
            'success',
            'usage',
            'runtime',
            'notFound',
            'conflict',
            'versionMismatch',
            'circularRef',
          ]),
        );
      });
    });

    group('standard global flags (FR-002)', () {
      final contract = CliContract.standard;

      test('U8: global flag set is the standard five', () {
        final names = contract.globalFlags.map((f) => f.name).toList();
        expect(
          names,
          containsAll(const [
            '--help',
            '--version',
            '--verbose',
            '--output',
            '--no-color',
          ]),
        );
        expect(names.length, equals(5));
      });

      test('--help has abbreviation h', () {
        final help = contract.globalFlags.firstWhere((f) => f.name == '--help');
        expect(help.abbr, equals('h'));
        expect(help.negatable, isFalse);
      });

      test('--output takes a value', () {
        final output = contract.globalFlags.firstWhere(
          (f) => f.name == '--output',
        );
        expect(output.takesValue, isTrue);
      });
    });

    group('error shape (FR-002, FR-008)', () {
      final contract = CliContract.standard;

      test('U9: error shape has required fields', () {
        expect(
          contract.errorShapeFields,
          containsAll(const ['code', 'message', 'details']),
        );
        expect(contract.errorShapeFields.length, equals(3));
      });
    });

    group('consistency surface (SC-002)', () {
      final contract = CliContract.standard;

      test('consistency surface lists every field SC-002 checks', () {
        expect(
          contract.consistencySurface,
          containsAll(const [
            'exitCode.success',
            'exitCode.usage',
            'exitCode.runtime',
            'exitCode.notFound',
            'exitCode.conflict',
            'exitCode.versionMismatch',
            'exitCode.circularRef',
            'globalFlags.names',
            'errorShapeFields',
            'outputSchemaName',
            'helpHeader',
          ]),
        );
      });

      test('two standard contracts compare equal', () {
        // Two apps with the same standard contract share 100% of the
        // consistency surface — SC-002 ≥ 80% target trivially met.
        expect(CliContract.standard, equals(CliContract.standard));
      });

      test('a custom contract differs from standard', () {
        final custom = CliContract(
          exitCode: CliExitCodes.standard,
          globalFlags: const [
            CliGlobalFlag(
              name: '--help',
              abbr: 'h',
              help: 'Show help',
              negatable: false,
            ),
          ],
          errorShapeFields: const ['code', 'message', 'details'],
          outputSchemaName: 'custom.cli.v1',
          helpHeader: 'USAGE:\n  custom',
        );
        expect(custom, isNot(equals(CliContract.standard)));
      });
    });
  });
}
