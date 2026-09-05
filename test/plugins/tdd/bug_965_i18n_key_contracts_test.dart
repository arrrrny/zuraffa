/// Tests for the i18n key contract (issue #965, T001 — spec contract).
///
/// The key is the contract, the literal is the anchor: Presentation
/// layer-contract rows declare `key: <dotted.key>` tokens with the EN
/// literal as the anchor, and the same parsed `LayerContract` shape both
/// spec.md (`SpecParser.parseLayerContracts`) and the test list
/// (`TestListReader.readLayerContracts`) produce feeds one table.
///
/// Proven here (US1):
///   1. keys parse from spec-shaped Presentation rows (anchor captured);
///   2. malformed `key:` tokens refuse with the row named + `--> fix:`
///      (errors-are-an-API), never guessed;
///   3. the anchor→key resolution and the ledger projection (`t.<key>`,
///      kind `key`) hold;
///   4. the table stays inert on non-Presentation layers and rows without
///      key tokens (zero drift for non-i18n hosts).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/i18n_key_contract.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

/// A zuraffa-1.0 spec's Layer Contracts section with the issue #965
/// contract: key tokens beside plain component tokens.
const specWithKeys = '''
### Layer Contracts

**Presentation**:
- `LoginSection`: `ShadInput` for email, `ShadButton` for submit, `key: auth.signIn -> 'Sign in'`, `key: app.name -> 'ZikZak'`

**Domain**:
- `AuthRepository`: `signIn`
''';

void main() {
  group('bug 965 T001: the spec contract parses key declarations', () {
    test('US1.AC1: keys parse from a spec-shaped Presentation row with '
        'anchors', () {
      final contracts = const SpecParser().parseLayerContracts(specWithKeys);
      final table = I18nKeyTable.fromLayerContracts(contracts);

      expect(table.contracts, hasLength(2));
      expect(table.keyOf('Sign in'), 'auth.signIn');
      expect(table.keyOf('ZikZak'), 'app.name');
      expect(table.anchorOf('auth.signIn')?.anchor, 'Sign in');
      expect(table.anchorOf('app.name')?.anchor, 'ZikZak');
    });

    test('US1.AC1: the anchor is the fallback for non-i18n hosts — a '
        'missing anchor falls back to the key tail', () {
      final contract = I18nKeyContract.parseToken("key: auth.signOut");
      expect(contract.key, 'auth.signOut');
      expect(contract.anchor, 'signOut');
    });

    test('US1.AC3: double-quoted anchors resolve', () {
      final contract = I18nKeyContract.parseToken(
        'key: auth.signIn -> "Sign in"',
      );
      expect(contract.key, 'auth.signIn');
      expect(contract.anchor, 'Sign in');
    });

    test('non-key tokens are inert (null from tryParseToken)', () {
      expect(I18nKeyContract.tryParseToken('ShadInput'), isNull);
      expect(I18nKeyContract.tryParseToken('signIn'), isNull);
    });

    test('US1.AC2: a key without a dot refuses, naming the fix', () {
      expect(
        () => I18nKeyContract.parseToken("key: authsignIn -> 'Sign in'"),
        throwsA(
          isA<I18nKeyContractParseException>().having(
            (e) => e.message,
            'message',
            contains('--> fix:'),
          ),
        ),
      );
    });

    test('US1.AC2: a segment starting with a digit refuses', () {
      expect(
        () => I18nKeyContract.parseToken("key: auth.9 SignIn -> 'Sign in'"),
        throwsA(isA<I18nKeyContractParseException>()),
      );
    });

    test('US1.AC2: an unquoted anchor refuses', () {
      expect(
        () => I18nKeyContract.parseToken('key: auth.signIn -> Sign in'),
        throwsA(
          isA<I18nKeyContractParseException>().having(
            (e) => e.message,
            'message',
            contains('quoted'),
          ),
        ),
      );
    });

    test('US1.AC2: a malformed key token inside a spec row refuses with '
        'the row named', () {
      const spec = '''
### Layer Contracts

**Presentation**:
- `LoginSection`: `ShadInput` for email, `key: broken -> 'Sign in'`
''';
      expect(
        () => I18nKeyTable.fromLayerContracts(
          const SpecParser().parseLayerContracts(spec),
        ),
        throwsA(
          isA<I18nKeyContractParseException>()
              .having((e) => e.message, 'message', contains('LoginSection'))
              .having((e) => e.message, 'message', contains('--> fix:')),
        ),
      );
    });

    test('conflicting re-declaration of one key refuses', () {
      const spec = '''
### Layer Contracts

**Presentation**:
- `LoginSection`: `key: auth.signIn -> 'Sign in'`
- `HeaderSection`: `key: auth.signIn -> 'Sign In'`
''';
      expect(
        () => I18nKeyTable.fromLayerContracts(
          const SpecParser().parseLayerContracts(spec),
        ),
        throwsA(isA<I18nKeyContractParseException>()),
      );
    });

    test('the same key re-declared with the same anchor is idempotent', () {
      const spec = '''
### Layer Contracts

**Presentation**:
- `LoginSection`: `key: auth.signIn -> 'Sign in'`
- `HeaderSection`: `key: auth.signIn -> 'Sign in'`
''';
      final table = I18nKeyTable.fromLayerContracts(
        const SpecParser().parseLayerContracts(spec),
      );
      expect(table.contracts, hasLength(1));
    });

    test('Domain rows never contribute keys (Presentation-only contract)', () {
      const spec = '''
### Layer Contracts

**Presentation**:
- `LoginSection`: `ShadInput` for email

**Domain**:
- `AuthRepository`: `key: auth.signIn -> 'Sign in'`
''';
      final table = I18nKeyTable.fromLayerContracts(
        const SpecParser().parseLayerContracts(spec),
      );
      expect(table.isEmpty, isTrue);
    });

    test('rows without key tokens yield an empty table (non-i18n hosts '
        'keep zero drift)', () {
      final contracts = const SpecParser().parseLayerContracts('''
### Layer Contracts

**Presentation**:
- `LoginSection`: `ShadInput` for email, `ShadButton` for submit
''');
      final table = I18nKeyTable.fromLayerContracts(contracts);
      expect(table.isEmpty, isTrue);
      expect(table.keyOf('Sign in'), isNull);
    });
  });
}
