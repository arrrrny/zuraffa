// Emitter behavioral tests for the skin-contract schema (issue #1164,
// US2/A3-A5, U4-U5): `zfa tdd plan` writes `04-skin-contract.schema.json`
// ONLY when the spec carries `## Skin Contract:`, generated FROM the
// model (no drift, no orphans).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/skin_contract_emit.dart';
import 'package:zuraffa/src/skin/contract/skin_contract.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_parser.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_schema.dart';

const contractSpec = '''
# Spec

## Skin Contract: login

```json
{
  "schemaVersion": "1",
  "routes": [{ "path": "/login", "view": "LoginPage" }],
  "states": [{ "view": "LoginPage", "loading": false, "error": "toaster", "empty": false }],
  "platformRows": [{ "view": "LoginPage", "mobile": true, "ios": true, "android": true, "macos": false }],
  "stateRows": [{ "view": "LoginPage", "row": "error-toaster", "kind": "observer" }]
}
```
''';

const plainSpec = '''
# Spec

No skin contract here.
''';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('skin-contract-emit-'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('A3/U4: a contract-bearing spec writes the schema file', () async {
    final written = await emitSkinContractSchema(
      specMarkdown: contractSpec,
      outDir: tmp,
    );
    expect(written, isNotNull);
    final file = File(written!);
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('"const": "1"'));
    expect(file.readAsStringSync(), contains('"additionalProperties": false'));
  });

  test('A5/U4: a spec without the section writes nothing', () async {
    final written = await emitSkinContractSchema(
      specMarkdown: plainSpec,
      outDir: tmp,
    );
    expect(written, isNull);
    expect(tmp.listSync(), isEmpty);
  });

  test('U4: re-running overwrites deterministically', () async {
    final first = await emitSkinContractSchema(
      specMarkdown: contractSpec,
      outDir: tmp,
    );
    final second = await emitSkinContractSchema(
      specMarkdown: contractSpec,
      outDir: tmp,
    );
    expect(first, second);
    expect(File(first!).readAsStringSync(), File(second!).readAsStringSync());
  });

  test('U4: a declared section without a JSON body fails loudly', () async {
    expect(
      () => emitSkinContractSchema(
        specMarkdown: '## Skin Contract: empty\n\nno fence\n',
        outDir: tmp,
      ),
      throwsA(
        isA<SkinContractParseException>().having(
          (e) => e.message,
          'message',
          contains('no fenced JSON body'),
        ),
      ),
    );
  });

  test(
    'U5/A4: the schema is generated from the model — no drift, no orphans',
    () {
      final schema = skinContractSchema();
      // Every model section has a schema property — and vice versa.
      final properties = schema['properties'] as Map<String, dynamic>;
      expect(properties.keys, containsAll(SkinContract.sections.keys));
      expect(
        properties.keys.where((k) => k != 'schemaVersion'),
        hasLength(SkinContract.sections.length),
      );
      // Every row field has a schema property, required fields are listed.
      for (final entry in SkinContract.sections.entries) {
        final defs = schema[r'$defs'] as Map<String, dynamic>;
        final rowDef =
            defs[skinContractDefName(entry.key)] as Map<String, dynamic>;
        final props = rowDef['properties'] as Map<String, dynamic>;
        expect(
          props.keys,
          equals(entry.value.map((f) => f.name)),
          reason: 'section ${entry.key}',
        );
        final required = rowDef['required'] as List<dynamic>;
        expect(
          required,
          containsAll(entry.value.where((f) => f.required).map((f) => f.name)),
          reason: 'section ${entry.key}',
        );
      }
    },
  );
}
