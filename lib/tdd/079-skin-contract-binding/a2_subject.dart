// GENERATED TEST SUBJECT — `zfa tdd gen A2` (spec 044-test-tdd-generation).
//
// behavior_id: A2
// Implemented for feature 079-skin-contract-binding (issue #1165): the
// subject drives the REAL runtime binding — the TDD green step.
// ignore_for_file: non_constant_identifier_names
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_parser.dart';
import 'package:zuraffa/src/skin/skin_contract_binding.dart';

const twoRouteContractJson = '''
{
  "schemaVersion": "1",
  "routes": [
    { "path": "/login", "view": "LoginPage" },
    { "path": "/register", "view": "RegisterPage" }
  ],
  "states": [
    { "view": "LoginPage", "loading": true, "error": "toaster", "empty": false },
    { "view": "RegisterPage", "loading": true, "error": "inline", "empty": true }
  ],
  "platformRows": [],
  "stateRows": [
    { "view": "LoginPage", "row": "error-toaster", "kind": "observer" },
    { "view": "RegisterPage", "row": "error-inline", "kind": "listener" }
  ]
}
''';

Future<void> subject_a2() async {
  final empty = twoRouteContractJson.replaceFirst(
    RegExp(r'"routes": \[[\s\S]*?\],'),
    '"routes": [],',
  );
  final contract = parseSkinContractJson(empty);
  final binding = SkinContractRuntimeBinding.fromContract(
    name: 'empty',
    contract: contract,
  );
  expect(binding.routeTable.allows('/'), isTrue);
  expect(binding.routeTable.allows('/login'), isFalse);
}
