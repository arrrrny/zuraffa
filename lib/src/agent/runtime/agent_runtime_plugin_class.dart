import 'agent_kernel.dart';
import 'agent_hook.dart';
import 'kernel_status.dart';
import 'llm_client.dart';
import 'mcp_tool_provider.dart';
import 'mcp_tool_registry.dart';
import 'state_storage.dart';
import 'stateful_agent.dart';
import 'system_prompt_composer.dart';

/// The runtime module plugin that assembles the tool registry, wires
/// the kernel, and manages the agent lifecycle (issue #386).
class AgentRuntimePlugin {
  AgentRuntimePlugin({
    List<McpToolProvider>? spiProviders,
    List<McpTool> usecaseTools = const <McpTool>[],
    List<RemoteMcpServer> remoteServers = const <RemoteMcpServer>[],
    StatefulAgent? statefulAgent,
    LlmClient? llmClient,
    FileStateStorage? stateStorage,
    List<AgentHook> hooks = const <AgentHook>[],
    String playbook = '',
  }) {
    _registry = McpToolRegistry();
    _assembleRegistry(
      spiProviders: spiProviders ?? const <McpToolProvider>[],
      usecaseTools: usecaseTools,
      remoteServers: remoteServers,
    );

    _kernel = AgentKernel(
      registry: _registry,
      statefulAgent: statefulAgent ?? StubStatefulAgent(),
      llmClient: llmClient,
      promptComposer: SystemPromptComposer(playbook: playbook),
      stateStorage: stateStorage,
      hooks: hooks,
    );

    _providers = <String, String>{
      for (final p in spiProviders ?? const <McpToolProvider>[])
        p.namespace: p.runtimeType.toString(),
    };
    _remoteServerHealth = <String, String>{
      for (final s in remoteServers) s.id: s.healthStatus,
    };
  }

  late final McpToolRegistry _registry;
  late final AgentKernel _kernel;
  late final Map<String, String> _providers;
  late final Map<String, String> _remoteServerHealth;

  /// The assembled tool registry (FR-003).
  McpToolRegistry get registry => _registry;

  /// The wired kernel (FR-005).
  AgentKernel get kernel => _kernel;

  /// Assembles the registry from three sources (FR-003):
  /// 1. SPI providers (in-proc, FR-001)
  /// 2. Generated usecase tools from AgentPlugin
  /// 3. Remote MCP servers via `dart_agent_core`'s McpManager
  ///
  /// Throws [NamespaceCollisionException] on collision (FR-012).
  void _assembleRegistry({
    required List<McpToolProvider> spiProviders,
    required List<McpTool> usecaseTools,
    required List<RemoteMcpServer> remoteServers,
  }) {
    // 1. SPI providers (in-proc) — FR-001, FR-002.
    final ctx = McpToolContext();
    for (final provider in spiProviders) {
      final tools = provider.buildTools(ctx);
      for (final tool in tools) {
        _registry.register(
          namespace: provider.namespace,
          tool: tool,
          source: 'spi:${provider.namespace}',
        );
      }
    }

    // 2. Generated usecase tools (under the `usecase` namespace).
    for (final tool in usecaseTools) {
      _registry.register(namespace: 'usecase', tool: tool, source: 'usecase');
    }

    // 3. Remote MCP servers (under `remote:<serverId>` namespaces).
    for (final server in remoteServers) {
      for (final tool in server.tools) {
        _registry.register(
          namespace: 'remote:${server.id}',
          tool: tool,
          source: 'remote:${server.id}',
        );
      }
    }
  }

  /// Returns the kernel status (FR-011).
  KernelStatus status() => _kernel.status(
    providers: _providers,
    remoteServerHealth: _remoteServerHealth,
  );
}

/// A remote MCP server registered with the runtime plugin.
class RemoteMcpServer {
  RemoteMcpServer({
    required this.id,
    required this.tools,
    this.healthStatus = 'unknown',
  });

  /// Stable server identifier.
  final String id;

  /// Tools contributed by this server.
  final List<McpTool> tools;

  /// Health status string (e.g. `'healthy'`, `'unreachable'`).
  final String healthStatus;
}
