/// Emits the tool manifest barrel file (FR-007).
///
/// The barrel lives at `lib/src/agent/tools/manifest.dart` and exports:
///   - `const List<ToolManifestEntry> agentTools = [...]`
///   - `const Map<String, List<ToolManifestEntry>> agentToolsByEntity = {...}`
///
/// Each entry carries the tool's canonical name, owning entity (snake),
/// and risk tier (`'safe'` or `'admin'`).
library;

import 'manifest_entry.dart';

/// Builds the manifest barrel source for [entries].
String buildManifestSource(List<ToolManifestEntry> entries) {
  // Group by entity.
  final byEntity = <String, List<ToolManifestEntry>>{};
  for (final e in entries) {
    byEntity.putIfAbsent(e.entity, () => []).add(e);
  }

  final entriesLiteral = entries.map((e) => _entryLiteral(e)).join(',\n  ');
  final byEntityLiteral = byEntity.entries
      .map((grp) {
        final list = grp.value.map((e) => _entryLiteral(e)).join(',\n    ');
        return "    '${grp.key}': <ToolManifestEntry>[\n    $list\n    ]";
      })
      .join(',\n');

  return '''
import 'package:zuraffa/src/agent/plugin/manifest_entry.dart';

/// Auto-generated tool manifest (FR-007).
///
/// Lists every generated MCP tool with its owning entity and default
/// risk tier (`safe` or `admin`). The agent runtime consumes this list
/// for tool discovery and gating.
const List<ToolManifestEntry> agentTools = <ToolManifestEntry>[
  $entriesLiteral,
];

/// Tools grouped by owning entity — convenience surface for the
/// agent runtime to scope a tool discovery request to a single domain.
const Map<String, List<ToolManifestEntry>> agentToolsByEntity =
    <String, List<ToolManifestEntry>>{
$byEntityLiteral
};
''';
}

String _entryLiteral(ToolManifestEntry e) {
  return "ToolManifestEntry(name: '${_escape(e.name)}', entity: '${_escape(e.entity)}', riskTier: '${_escape(e.riskTier)}')";
}

String _escape(String s) => s.replaceAll("'", r"\'");
