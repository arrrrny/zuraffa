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

import '../../../skin/contract/skin_contract_schema.dart';

/// The spec section marker the emitter looks for.
const String skinContractSectionMarker = '## Skin Contract:';

/// True when [specMarkdown] declares a skin contract.
bool specDeclaresSkinContract(String specMarkdown) =>
    specMarkdown.contains(skinContractSectionMarker);

/// Extracts the contract JSON body from the spec's `## Skin Contract:`
/// section — the first fenced ```json block after the marker. Returns
/// null when the section is absent; throws [StateError] when the section
/// exists but carries no fenced JSON body (an empty contract is not a
/// valid contract).
String? skinContractJsonFromSpec(String specMarkdown) {
  final markerIndex = specMarkdown.indexOf(skinContractSectionMarker);
  if (markerIndex < 0) return null;
  final after = specMarkdown.substring(markerIndex);
  // Search the close fence in the SAME substring the open fence matched
  // in — mixing index spaces reads the wrong body (found by the 078
  // repo-wide walker).
  final bodyRegion = after.substring(after.indexOf('\n') + 1);
  final fence = RegExp(r'^```json\s*$', multiLine: true);
  final open = fence.firstMatch(bodyRegion);
  if (open == null) {
    throw StateError(
      'skin contract: the "## Skin Contract:" section carries no fenced '
      'JSON body — an empty contract is not a valid contract',
    );
  }
  final bodyStart = open.end;
  final close = bodyRegion.indexOf('```', bodyStart);
  if (close < 0) {
    throw StateError(
      'skin contract: the "## Skin Contract:" JSON fence is not closed',
    );
  }
  return bodyRegion.substring(bodyStart, close).trim();
}

/// Emits `04-skin-contract.schema.json` into [outDir] when [specMarkdown]
/// declares a skin contract. Returns the written path, or null when the
/// spec has no section (no-op).
Future<String?> emitSkinContractSchema({
  required String specMarkdown,
  required Directory outDir,
}) async {
  if (!specDeclaresSkinContract(specMarkdown)) return null;
  // A declared section must carry a parseable contract — fail loudly
  // here rather than emitting a schema for an empty contract.
  final json = skinContractJsonFromSpec(specMarkdown);
  if (json == null || json.isEmpty) {
    throw StateError(
      'skin contract: the "## Skin Contract:" section carries no JSON '
      'body — an empty contract is not a valid contract',
    );
  }
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
