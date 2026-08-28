/// LLM client interface (FR-007). Real implementations delegate to
/// `dart_agent_core`'s `FallbackLLMClient`.
abstract class LlmClient {
  /// Generates a completion for [prompt]. Returns the assistant message.
  Future<String> complete(String prompt);
}

/// Default LLM client wired by [AgentRuntimePlugin] (FR-007). Mirrors
/// `dart_agent_core`'s `FallbackLLMClient`: tries the primary client; on
/// failure, falls back to the secondary.
class FallbackLLMClient implements LlmClient {
  FallbackLLMClient({this.primary, this.secondary});

  final LlmClient? primary;
  final LlmClient? secondary;

  @override
  Future<String> complete(String prompt) async {
    if (primary != null) {
      try {
        return await primary!.complete(prompt);
      } catch (_) {
        // Fall through to secondary.
      }
    }
    if (secondary != null) {
      return secondary!.complete(prompt);
    }
    // No clients configured — return empty (degraded mode).
    return '';
  }
}
