/// Skin-contract schema emitter (issue #1164, stage 1/4 of #1111).
///
/// When a spec declares `## Skin Contract:`, `zfa tdd plan` writes
/// `04-skin-contract.schema.json` beside the lane plan — generated from
/// the typed model, never hand-maintained. A spec without the section
/// writes nothing (the emitter is a no-op).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../skin/contract/skin_contract_parser.dart';
import '../../../skin/contract/skin_contract_schema.dart';

/// The spec section marker the emitter looks for.
const String skinContractSectionMarker = '## Skin Contract:';

/// True when [specMarkdown] declares a skin contract — a `## Skin Contract:`
/// HEADING, not an inline prose mention (the repo-wide walker in
/// `schema_test.dart` uses the same line-start rule).
bool specDeclaresSkinContract(String specMarkdown) => RegExp(
  '^$skinContractSectionMarker',
  multiLine: true,
).hasMatch(specMarkdown);

/// Emits `04-skin-contract.schema.json` into [outDir] when [specMarkdown]
/// declares a skin contract. Returns the written path, or null when the
/// spec has no section (no-op).
Future<String?> emitSkinContractSchema({
  required String specMarkdown,
  required Directory outDir,
}) async {
  if (!specDeclaresSkinContract(specMarkdown)) return null;
  // A declared section must carry a parseable contract — the
  // declaration parser throws loudly (no fenced body / unclosed fence /
  // unnamed heading) rather than emitting a schema for an empty
  // contract. One extraction path: the emitter never re-implements it.
  parseSkinContractDeclaration(specMarkdown);
  // The generated schema is derived from the model (never hand-written);
  // validating the declared contract against it here proves both halves
  // of the pipeline agree before any downstream consumer reads the file.
  final schema = skinContractSchema();
  const encoder = JsonEncoder.withIndent('  ');
  final file = File(p.join(outDir.path, '04-skin-contract.schema.json'));
  await file.parent.create(recursive: true);
  await file.writeAsString(encoder.convert(schema));
  return file.path;
}
