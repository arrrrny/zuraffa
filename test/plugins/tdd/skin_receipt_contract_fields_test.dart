// Issue #1167 (stage 4/4 of #1111): the skin receipt proves the
// contract was ENFORCED, not just declared — `contract_schema_version`
// and `contract_rows_audited` derived from the feature's declared
// contract and the cycle's conformed behaviors, plus the runtime-row ↔
// schema-row parity the contract-schema-parity proof requires.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/skin_receipt.dart';
import 'package:zuraffa/src/skin/contract/skin_contract.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_parser.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_schema.dart';

const contractJson = '''
{
  "schemaVersion": "1",
  "routes": [{ "path": "/login", "view": "LoginPage" }],
  "states": [
    { "view": "LoginPage", "loading": true, "error": "toaster", "empty": false }
  ],
  "platformRows": [],
  "stateRows": [
    { "view": "LoginPage", "row": "error-toaster", "kind": "observer" }
  ]
}
''';

const specWithContract =
    '# S\n\n## Skin Contract: login-seam\n\n```json\n$contractJson\n```\n';

SkinReceipt _row(String behavior, {bool conformance = true}) => SkinReceipt(
  behavior: behavior,
  conformance: conformance,
  testPath: 'test/tdd/x/${behavior.toLowerCase()}_test.dart',
  subjectPath: 'lib/tdd/x/login_page_${behavior.toLowerCase()}.dart',
  platformSlotFills: const [],
);

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('skin-receipt-'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('issue #1167 — receipt carries contract enforcement fields', () {
    test('a conformed cycle on a contract-bearing feature records the schema '
        'version and the audited row count', () async {
      final writer = SkinReceiptWriter(featureDir: tmp.path);
      await writer.write(
        SkinReceiptDocument(
          feature: '006-login-skin',
          command: 'zfa tdd run-skin 006-login-skin',
          behaviors: [_row('W1'), _row('W2', conformance: false)],
          handEdits: const [],
          skinEventTraceDigest: 'deadbeef',
          redWitness: true,
          generatedAt: '2026-09-05T00:00:00.000Z',
          contractSchemaVersion: SkinContract.schemaVersionV1,
          contractRowsAudited: 1,
        ),
      );
      final receipt =
          jsonDecode(
                File(
                  p.join(tmp.path, 'tdd', '04-skin-receipt.json'),
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(receipt['contract_schema_version'], '1');
      expect(receipt['contract_rows_audited'], 1);
    });

    test('a feature without a contract omits the fields additively', () async {
      final writer = SkinReceiptWriter(featureDir: tmp.path);
      await writer.write(
        SkinReceiptDocument(
          feature: '004-engine',
          command: 'zfa tdd run-skin 004-engine',
          behaviors: const [],
          handEdits: const [],
          skinEventTraceDigest: 'cafe',
          redWitness: false,
          generatedAt: '2026-09-05T00:00:00.000Z',
        ),
      );
      final receipt =
          jsonDecode(
                File(
                  p.join(tmp.path, 'tdd', '04-skin-receipt.json'),
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(receipt.containsKey('contract_schema_version'), isFalse);
      expect(receipt['contract_rows_audited'], 0);
      expect(receipt['schema'], 'skin.v1');
    });
  });

  group(
    'issue #1167 — contract-schema parity (every runtime row has a schema row)',
    () {
      test(
        'SC-4: the audited count cross-checks against the declared rows',
        () {
          final declaration = parseSkinContractDeclaration(specWithContract);
          final declaredRows = declaration.contract.stateRows.length;
          // One conformed behavior covering LoginPage enforces exactly the
          // rows declared for that view — here 1:1.
          final audited = declaration.contract.stateRows
              .where((row) => row.view == 'LoginPage')
              .length;
          expect(audited, lessThanOrEqualTo(declaredRows));
          expect(
            audited,
            declaredRows,
            reason: 'every declared row for a conformed view was audited',
          );
        },
      );

      test('every runtime row (stateRows) has a schema row', () {
        final contract = parseSkinContractJson(contractJson);
        final schema = skinContractSchema();
        final defs = schema[r'$defs'] as Map<String, dynamic>;
        final rowDef =
            defs[skinContractDefName('stateRows')] as Map<String, dynamic>;
        final properties = rowDef['properties'] as Map<String, dynamic>;
        for (final row in contract.stateRows) {
          for (final key in row.toJson().keys) {
            expect(
              properties.containsKey(key),
              isTrue,
              reason: 'runtime row field "$key" has no schema row',
            );
          }
        }
      });
    },
  );
}
