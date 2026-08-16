import 'package:get_it/get_it.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/di_container.dart';
import 'package:zuraffa/src/core/module/engine.dart';
import 'package:zuraffa/src/core/module/mcp_server_plugin.dart';
import 'package:zuraffa/src/core/module/mcp_tool.dart';
import 'package:zuraffa/src/core/module/mcp_tool_registry.dart';

void main() {
  group('McpServerPlugin', () {
    /// Builds an isolated ZuraffaDIContainer (fresh GetIt) so tests
    /// don't pollute the process-wide GetIt.instance singleton.
    ZuraffaDIContainer freshDi() {
      return ZuraffaDIContainer(getIt: GetIt.asNewInstance());
    }

    test('pluginId defaults to "mcp"', () {
      final p = McpServerPlugin(tools: const []);
      expect(p.pluginId, 'mcp');
    });

    test('pluginId can be overridden for multi-server setups', () {
      final p = McpServerPlugin(pluginId: 'mcp_secondary', tools: const []);
      expect(p.pluginId, 'mcp_secondary');
    });

    test('routes returns an empty map (no route contribution)', () {
      final p = McpServerPlugin(tools: const []);
      expect(p.routes, isEmpty);
    });

    test('listTools() pre-bootstrap returns the static tools list', () {
      final p = McpServerPlugin(tools: [_EchoTool()]);
      expect(p.listTools().length, 1);
      expect(p.listTools().first.name, 'echo');
    });

    test('listTools() post-bootstrap returns the live registry', () async {
      final di = freshDi();
      final engine = ZuraffaEngine(di: di)
        ..register(McpServerPlugin(tools: [_EchoTool()]));
      await engine.bootstrap();
      final mcp = engine['mcp'] as McpServerPlugin;
      final tools = mcp.listTools();
      expect(tools.length, 1);
      expect(tools.first.name, 'echo');
    });

    test('registerDependencies populates the DI container with McpToolRegistry', () {
      final di = freshDi();
      final p = McpServerPlugin(tools: [_EchoTool(), _PingTool()]);
      p.registerDependencies(di);
      final registry = di.get<McpToolRegistry>();
      expect(registry.length, 2);
      expect(registry.find('echo'), isNotNull);
      expect(registry.find('ping'), isNotNull);
    });

    test('bootstrap + lookup via engine yields the McpServerPlugin', () async {
      final di = freshDi();
      final engine = ZuraffaEngine(di: di)
        ..register(McpServerPlugin(tools: [_EchoTool()]));
      await engine.bootstrap();
      final p = engine['mcp'];
      expect(p, isA<McpServerPlugin>());
      expect((p as McpServerPlugin).listTools().length, 1);
    });

    test('registry getter throws StateError pre-bootstrap', () {
      final p = McpServerPlugin(tools: const []);
      expect(() => p.registry, throwsA(isA<StateError>()));
    });

    test('serveStdio() throws StateError pre-bootstrap', () async {
      final p = McpServerPlugin(tools: const []);
      expect(
        () => p.serveStdio(),
        throwsA(isA<StateError>()),
      );
    });

    test('the registry persists across engine bootstrap (DI singleton)', () async {
      final di = freshDi();
      final engine = ZuraffaEngine(di: di)
        ..register(McpServerPlugin(tools: [_EchoTool()]));
      await engine.bootstrap();
      final r1 = di.get<McpToolRegistry>();
      final r2 = di.get<McpToolRegistry>();
      expect(identical(r1, r2), isTrue);
    });

    test('a second McpServerPlugin can override the registry (override=true)', () async {
      // Verify that re-registering McpToolRegistry in the same GetIt
      // doesn't blow up on "already registered" — registerDependencies
      // removes the prior registration synchronously before re-registering.
      // This is the test-isolation path (tests share GetIt.instance
      // unless they pass GetIt.asNewInstance()).
      final di = freshDi();
      final p1 = McpServerPlugin(tools: [_EchoTool()]);
      final p2 = McpServerPlugin(tools: [_PingTool()]);
      p1.registerDependencies(di);
      // The second registration should succeed synchronously.
      p2.registerDependencies(di);
      final registry = di.get<McpToolRegistry>();
      expect(registry.find('ping'), isNotNull);
      expect(registry.find('echo'), isNull);
    });

    test('registerDependencies only unregisters McpToolRegistry, not other types', () {
      final di = freshDi();
      di.getIt.registerSingleton<String>('unrelated');
      final p = McpServerPlugin(tools: [_EchoTool()]);
      p.registerDependencies(di);
      expect(di.getIt.isRegistered<String>(), isTrue);
      expect(di.get<McpToolRegistry>().length, 1);
    });
  });
}

class _EchoTool implements McpTool {
  @override
  String get name => 'echo';
  @override
  String get description => 'Echoes the message argument.';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'message': {'type': 'string'},
    },
    'required': ['message'],
  };
  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async {
    return McpToolResult.ok('echo: ${arguments['message']}');
  }
}

class _PingTool implements McpTool {
  @override
  String get name => 'ping';
  @override
  String get description => 'Returns pong + the url.';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'url': {'type': 'string'},
    },
    'required': ['url'],
  };
  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async {
    return McpToolResult.ok('pong ${arguments['url']}');
  }
}
