import 'mcp_tool_registry.dart';

/// Composes the system prompt from playbook text + tool manifests (FR-006).
class SystemPromptComposer {
  SystemPromptComposer({this.playbook = ''});

  /// Playbook text describing the agent's role, rules, and constraints.
  final String playbook;

  /// Composes the system prompt for a mission with [registry] tools.
  String compose(McpToolRegistry registry) {
    final buffer = StringBuffer();
    if (playbook.isNotEmpty) {
      buffer.writeln(playbook);
      buffer.writeln();
    }
    buffer.writeln('# Available tools');
    for (final entry in registry.all.entries) {
      final tool = entry.value;
      buffer.writeln('- ${entry.key}: ${tool.description}');
    }
    return buffer.toString();
  }
}
