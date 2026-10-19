// Issue #1892 — inline-code backticks in External Dependencies & Contracts
// cells. `zfa tdd plan` round-trips the cell verbatim (backticks included)
// into the engine plan, so the mock parser and the slice composition helper
// must accept the same grammar.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/models/dependency_contract.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_composition.dart';

void main() {
  group('issue #1892 — backticked dependency contract cells', () {
    test('a single backticked method parses like its plain form', () {
      final backticked = DependencyContract.parseRow(
        name: 'UserLocationDataSource',
        type: 'service',
        contract: '`read() -> Future<UserLocation?>`',
        priority: 'P1',
      );
      final plain = DependencyContract.parseRow(
        name: 'UserLocationDataSource',
        type: 'service',
        contract: 'read() -> Future<UserLocation?>',
        priority: 'P1',
      );

      expect(
        backticked.signatures.map((s) => s.toString()),
        plain.signatures.map((s) => s.toString()),
      );
    });

    test('per-method backticks parse like the un-backticked form', () {
      const backticked =
          '`read() -> Future<UserLocation?>`, '
          '`write(UserLocation) -> Future<void>`';
      const plain =
          'read() -> Future<UserLocation?>, '
          'write(UserLocation) -> Future<void>';
      final a = DependencyContract.parseRow(
        name: 'UserLocationDataSource',
        type: 'service',
        contract: backticked,
      );
      final b = DependencyContract.parseRow(
        name: 'UserLocationDataSource',
        type: 'service',
        contract: plain,
      );

      expect(a.signatures, hasLength(2));
      expect(
        a.signatures.map((s) => s.toString()),
        b.signatures.map((s) => s.toString()),
      );
    });

    test('one backtick pair around the whole cell is accepted', () {
      final contract = DependencyContract.parseRow(
        name: 'UserLocationDataSource',
        type: 'service',
        contract: '`read() -> X, write(Y) -> void`',
      );

      expect(contract.signatures.map((s) => s.toString()), [
        'read() -> X',
        'write(Y) -> void',
      ]);
    });

    test('DependencySignature.parse refuses a comma-separated list', () {
      expect(
        () => DependencySignature.parse('`a() -> X`, `b() -> Y`'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('split the contract at top-level commas first'),
          ),
        ),
      );
    });

    test('a comma inside a generic return type is not a boundary', () {
      final contract = DependencyContract.parseRow(
        name: 'Store',
        type: 'service',
        contract: 'read() -> Map<String, int>, tick() -> void',
      );

      expect(contract.signatures, hasLength(2));
      expect(contract.signatures.first.returnType, 'Map<String, int>');
    });

    test('declaredSignatures tolerates per-method backticks', () {
      expect(
        SandboxComposition.declaredSignatures(
          '`read() -> X`, `write(Y) -> void`',
        ),
        [(name: 'read', params: ''), (name: 'write', params: 'Y')],
      );
    });

    test('declaredSignatures accepts a whole-cell backtick span', () {
      expect(
        SandboxComposition.declaredSignatures(
          '`read() -> X, write(Y) -> void`',
        ),
        [(name: 'read', params: ''), (name: 'write', params: 'Y')],
      );
    });
  });
}
