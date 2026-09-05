// skin-contract.v1 parser behavioral tests (issue #1164).
//
// Valid input parses to a fully populated model; malformed input fails
// NAMING the offending section/key — never a silent default (US1/A1/A2,
// U1-U3). The shared fixture mirrors contracts/skin-contract-v1.md.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_parser.dart';

const validContractJson = '''
{
  "schemaVersion": "1",
  "routes": [
    { "path": "/login", "view": "LoginPage" }
  ],
  "states": [
    { "view": "LoginPage", "loading": false, "error": "toaster", "empty": false }
  ],
  "platformRows": [
    { "view": "LoginPage", "mobile": true, "ios": true, "android": true, "macos": false }
  ],
  "stateRows": [
    { "view": "LoginPage", "row": "error-toaster", "kind": "observer" }
  ]
}
''';

void main() {
  group('A1/U1: a valid contract parses fully populated', () {
    test('every field is populated and the schema version is reported', () {
      final contract = parseSkinContractJson(validContractJson);
      expect(contract.schemaVersion, '1');
      expect(contract.routes, hasLength(1));
      expect(contract.routes.single.path, '/login');
      expect(contract.routes.single.view, 'LoginPage');
      expect(contract.states.single.error, 'toaster');
      expect(contract.states.single.loading, isFalse);
      expect(contract.platformRows.single.macos, isFalse);
      expect(contract.stateRows.single.kind, 'observer');
    });
  });

  group('A2/U2: malformed input fails naming the culprit', () {
    test('missing section is named', () {
      final json = validContractJson.replaceFirst(
        RegExp(r',\s*"stateRows"[\s\S]*\]'),
        '',
      );
      expect(
        () => parseSkinContractJson(json),
        throwsA(
          isA<SkinContractParseException>().having(
            (e) => e.message,
            'message',
            contains('stateRows'),
          ),
        ),
      );
    });

    test('unknown field is named', () {
      final json = validContractJson.replaceFirst(
        '"view": "LoginPage" }',
        '"view": "LoginPage", "extra": 1 }',
      );
      expect(
        () => parseSkinContractJson(json),
        throwsA(
          isA<SkinContractParseException>().having(
            (e) => e.message,
            'message',
            contains('"extra"'),
          ),
        ),
      );
    });

    test('unknown top-level section is named', () {
      final json = validContractJson.replaceFirst(
        '\n  ]\n}',
        '\n  ],\n  "rogueSection": []\n}',
      );
      expect(
        () => parseSkinContractJson(json),
        throwsA(
          isA<SkinContractParseException>().having(
            (e) => e.message,
            'message',
            contains('"rogueSection"'),
          ),
        ),
      );
    });

    test('unsupported schemaVersion is named', () {
      final json = validContractJson.replaceFirst('"1"', '"9"');
      expect(
        () => parseSkinContractJson(json),
        throwsA(
          isA<SkinContractParseException>().having(
            (e) => e.message,
            'message',
            allOf(contains('schemaVersion'), contains('"9"')),
          ),
        ),
      );
    });

    test('route path not starting with / is named', () {
      final json = validContractJson.replaceFirst('/login', 'login');
      expect(
        () => parseSkinContractJson(json),
        throwsA(
          isA<SkinContractParseException>().having(
            (e) => e.message,
            'message',
            allOf(contains('"path"'), contains('login')),
          ),
        ),
      );
    });

    test('state error outside the v1 vocabulary is named', () {
      final json = validContractJson.replaceFirst('"toaster"', '"banner"');
      expect(
        () => parseSkinContractJson(json),
        throwsA(
          isA<SkinContractParseException>().having(
            (e) => e.message,
            'message',
            allOf(contains('"error"'), contains('"banner"')),
          ),
        ),
      );
    });

    test('invalid JSON names the JSON error', () {
      expect(
        () => parseSkinContractJson('{not json'),
        throwsA(isA<SkinContractParseException>()),
      );
    });
  });

  group('U3: round-trip is lossless', () {
    test('model -> JSON -> model is equal field-for-field', () {
      final contract = parseSkinContractJson(validContractJson);
      final reparsed = parseSkinContractJson(
        const JsonEncoder.withIndent('  ').convert(contract.toJson()),
      );
      expect(reparsed, equals(contract));
    });
  });
}
