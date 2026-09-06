/// Strict parser for adaptive-skin-contract.v1 yaml declarations
/// (issue #1004).
///
/// The declaration is the spec's `## Skin Contract` section, authored
/// as a yaml block — fenced (```yaml, the canonical form) or bare —
/// whose top-level key may repeat the section name (`Skin Contract:`,
/// skipped exactly like `Lanes:` is in the lanes grammar). A fenced
/// yaml block carrying the `Skin Contract:` key parses standalone too
/// (no heading required), so the declaration can ride any spec shape.
///
/// Every failure names the offending key — never a silent default
/// (#1111: unknown fields are contract drift, not future proofing).
/// The json-fenced form belongs to skin-contract.v1 (issue #1164) and
/// returns null here: one section, one form, never a guess.
library;

import 'adaptive_skin_contract.dart';

/// A parse failure naming the offending section and key.
class AdaptiveSkinContractParseException implements Exception {
  final String message;
  AdaptiveSkinContractParseException(this.message);

  @override
  String toString() => message;
}

/// The yaml top-level keys of the contract grammar.
const Set<String> _contractKeys = {
  'adaptive_slots',
  'platform_overrides',
  'states',
  'routes',
};

/// A `## Skin Contract` heading (colon optional, case-insensitive) —
/// the section the declaration lives in.
final RegExp _skinContractHeading = RegExp(
  r'^#{1,6}\s+skin contract\b',
  caseSensitive: false,
);

/// Any markdown heading — the section boundary.
final RegExp _anyHeading = RegExp(r'^#{1,6}\s+');

/// A yaml fence open: ```yaml / ```yml / ``` (language optional — a
/// json fence is the #1164 form and is never ours).
final RegExp _yamlFenceOpen = RegExp(r'^```(yaml|yml)?\s*$');

/// The `Skin Contract:` key line inside the body (indented or not) —
/// skipped like `Lanes:` is in the lanes grammar.
final RegExp _contractKeyLine = RegExp(
  r'^\s*skin contract\s*:\s*$',
  caseSensitive: false,
);

/// A top-level contract key line: `key: value` (or `key:` opening a
/// nested block), at indent 0 of the contract body.
final RegExp _topLevelKey = RegExp(r'^([a-z_]+):\s*(.*)$');

/// Parses the adaptive skin contract declaration out of a spec
/// markdown. Returns null when the spec declares no adaptive
/// contract — including the json-fenced skin-contract.v1 form
/// (issue #1164): that declaration belongs to the typed JSON
/// contract, not this one.
AdaptiveSkinContract? parseAdaptiveSkinContract(String specMarkdown) {
  final body = _locateDeclarationBody(specMarkdown);
  if (body == null) return null;
  return _parseBody(body);
}

/// Locates the contract body: the yaml lines that carry the
/// declaration, or null when the spec has none.
List<String>? _locateDeclarationBody(String specMarkdown) {
  final lines = specMarkdown.split('\n');

  // Form 1: a `## Skin Contract` heading section. The section runs to
  // the next heading; inside it the declaration is the first yaml
  // fence, or — lenient like the lanes grammar — the bare body lines.
  for (var i = 0; i < lines.length; i++) {
    if (!_skinContractHeading.hasMatch(lines[i].trim())) continue;
    final section = <String>[];
    for (var j = i + 1; j < lines.length; j++) {
      final trimmed = lines[j].trim();
      if (_anyHeading.hasMatch(trimmed)) break;
      section.add(lines[j]);
    }
    final body = _extractFencedOrBare(section);
    if (body == null) continue; // json fence or nothing usable — skip
    return body;
  }

  // Form 2: a fenced yaml block carrying the `Skin Contract:` key —
  // the deliverable's literal shape, no heading required.
  for (var i = 0; i < lines.length; i++) {
    if (!_yamlFenceOpen.hasMatch(lines[i].trim())) continue;
    final block = <String>[];
    var closed = false;
    for (var j = i + 1; j < lines.length; j++) {
      if (lines[j].trim().startsWith('```')) {
        closed = true;
        break;
      }
      block.add(lines[j]);
    }
    if (!closed) continue;
    if (!block.any((l) => _contractKeyLine.hasMatch(l))) continue;
    return block;
  }
  return null;
}

/// From a heading section's lines: the first yaml/plain fence's body,
/// or the bare body when no fence exists and the body speaks the
/// contract grammar. Returns null for a json fence (the #1164 form)
/// and for bodies that declare none of the contract keys.
List<String>? _extractFencedOrBare(List<String> section) {
  for (var i = 0; i < section.length; i++) {
    final trimmed = section[i].trim();
    if (trimmed.startsWith('```json')) return null; // the #1164 form
    if (_yamlFenceOpen.hasMatch(trimmed)) {
      final body = <String>[];
      for (var j = i + 1; j < section.length; j++) {
        if (section[j].trim().startsWith('```')) return body;
        body.add(section[j]);
      }
      return body; // unterminated fence: parse what is there
    }
  }
  // Bare body: the contract keys must be present directly. The raw
  // (indented) lines are returned — the platform-override block needs
  // the relative indentation. (The fence loop above already returned
  // for every fence form, so no fence lines remain here.)
  final bare = section.where((l) => l.trim().isNotEmpty).toList();
  if (bare.isEmpty) return null;
  final hasKeys = bare.any((l) {
    final m = _topLevelKey.firstMatch(l.trim());
    return m != null && _contractKeys.contains(m.group(1));
  });
  if (!hasKeys) return null;
  return bare;
}

/// Parses the contract body lines into the typed contract. Strict:
/// unknown keys, duplicates, and missing keys refuse naming the key.
AdaptiveSkinContract _parseBody(List<String> body) {
  final seen = <String>{};
  final values = <String, String>{};
  final platformOverrides = <String, Map<String, String>>{};

  for (var i = 0; i < body.length; i++) {
    final raw = body[i];
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;
    if (_contractKeyLine.hasMatch(trimmed)) continue; // the name key

    final m = _topLevelKey.firstMatch(trimmed);
    if (m == null) {
      throw AdaptiveSkinContractParseException(
        'skin contract: unrecognized line "${trimmed.trim()}" — the '
        'contract body must carry only the yaml keys '
        '(${_contractKeys.join(', ')})',
      );
    }
    final key = m.group(1)!;
    final value = (m.group(2) ?? '').trim();
    if (key == 'skin contract') continue;
    if (!_contractKeys.contains(key)) {
      throw AdaptiveSkinContractParseException(
        'skin contract: unknown field "$key" (known: '
        '${_contractKeys.join(', ')}) — unknown fields are contract '
        'drift, not future proofing',
      );
    }
    if (!seen.add(key)) {
      throw AdaptiveSkinContractParseException(
        'skin contract: duplicate field "$key" — one declaration per '
        'key, never last-wins',
      );
    }
    if (key == 'platform_overrides') {
      if (value.isNotEmpty && value != '{}') {
        throw AdaptiveSkinContractParseException(
          'skin contract: platform_overrides: "$value" — overrides are '
          'a nested platform map, never an inline value',
        );
      }
      if (value == '{}') continue; // empty map declared inline
      final (overrides, consumed) = _parsePlatformOverrides(body, i + 1);
      platformOverrides.addAll(overrides);
      i += consumed;
      continue;
    }
    values[key] = value;
  }

  for (final required in _contractKeys) {
    if (required == 'platform_overrides') continue; // may be `{}`-empty
    if (!values.containsKey(required)) {
      throw AdaptiveSkinContractParseException(
        'skin contract: $required: missing (required list) — the '
        'contract must declare ${_contractKeys.join(', ')}',
      );
    }
  }

  final slots = _parseNames('adaptive_slots', values['adaptive_slots']!);
  final states = _parseNames('states', values['states']!);
  final routes = _parseNames('routes', values['routes']!);

  // A platform override refines a declared adaptive slot — an override
  // for a platform outside the matrix is drift naming the platform.
  for (final platform in platformOverrides.keys) {
    if (!slots.contains(platform)) {
      throw AdaptiveSkinContractParseException(
        'skin contract: platform_overrides.$platform: platform '
        '"$platform" is not declared in adaptive_slots — overrides '
        'refine declared slots',
      );
    }
  }

  return AdaptiveSkinContract(
    adaptiveSlots: slots,
    platformOverrides: platformOverrides,
    states: states,
    routeNames: routes,
  );
}

/// Parses the nested platform-override block following
/// `platform_overrides:` — `platform:` lines each opening a deeper
/// `key: value` run. Returns the overrides and the line count
/// consumed. A valueless line at the platform indent opens the next
/// platform; a deeper valueless line is drift (an override key must
/// carry a value).
(Map<String, Map<String, String>>, int) _parsePlatformOverrides(
  List<String> body,
  int start,
) {
  final overrides = <String, Map<String, String>>{};
  String? platform;
  var platformIndent = 0;
  var consumed = 0;
  for (var i = start; i < body.length; i++) {
    final raw = body[i];
    if (raw.trim().isEmpty) {
      consumed++;
      continue;
    }
    final line = RegExp(r'^(\s*)([A-Za-z0-9_]+):\s*(.*)$').firstMatch(raw);
    if (line == null) break; // not a key line — the block is over
    final indent = line.group(1)!.length;
    final name = line.group(2)!.trim();
    final value = (line.group(3) ?? '').trim();

    if (platform == null) {
      // The first nested line names a platform; it must carry no
      // inline value (its overrides follow, deeper).
      if (value.isNotEmpty) break; // a top-level key resumed
      platformIndent = indent;
      platform = _validateName(name, 'platform_overrides.$name');
      overrides[platform] = {};
    } else if (indent > platformIndent) {
      // An override key: value line under the active platform.
      if (value.isEmpty) {
        throw AdaptiveSkinContractParseException(
          'skin contract: platform_overrides.$platform.$name: an '
          'override key must carry a value',
        );
      }
      final key = _validateName(name, 'platform_overrides.$platform.$name');
      if (value.contains(':')) {
        throw AdaptiveSkinContractParseException(
          'skin contract: platform_overrides.$platform.$key: value '
          '"$value" must be a single token (no colon)',
        );
      }
      if (overrides[platform]!.containsKey(key)) {
        throw AdaptiveSkinContractParseException(
          'skin contract: platform_overrides.$platform.$key: duplicate '
          'override key',
        );
      }
      overrides[platform]![key] = value;
    } else if (value.isEmpty) {
      // The next platform at the platform indent (or shallower).
      platformIndent = indent;
      platform = _validateName(name, 'platform_overrides.$name');
      overrides[platform] = {};
    } else {
      break; // a top-level key resumed — the block is over
    }
    consumed++;
  }
  return (overrides, consumed);
}

/// Parses an inline yaml list value (`[a, b]` or a bare comma list)
/// into validated names; the list must be non-empty and every name
/// must match the contract name pattern.
List<String> _parseNames(String section, String value) {
  var v = value.trim();
  if (v.startsWith('[')) v = v.substring(1);
  if (v.endsWith(']')) v = v.substring(0, v.length - 1);
  final names = v
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  if (names.isEmpty) {
    throw AdaptiveSkinContractParseException(
      'skin contract: $section: "$value" declares no names — the '
      'contract is a typed declaration, not an empty gesture',
    );
  }
  return [for (final n in names) _validateName(n, '$section.$n')];
}

String _validateName(String name, String where) {
  if (!RegExp(AdaptiveSkinContract.namePattern).hasMatch(name)) {
    throw AdaptiveSkinContractParseException(
      'skin contract: $where: "$name" does not match '
      '${AdaptiveSkinContract.namePattern} (lowercase snake-case '
      'identifiers)',
    );
  }
  return name;
}
