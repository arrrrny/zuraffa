import 'package:test/test.dart';
import 'package:zuraffa/src/agent/runtime/agent_runtime_plugin.dart';

void main() {
  group('McpToolRegistry (FR-003, FR-012)', () {
    test('registers and looks up tools by canonical name', () {
      final r = McpToolRegistry();
      final tool = _FakeTool('scan');
      r.register(namespace: 'device', tool: tool, source: 'spi:device');

      expect(r.size, equals(1));
      expect(r.lookup('device.scan'), same(tool));
    });

    test('namespace collision throws (FR-012)', () {
      final r = McpToolRegistry();
      r.register(
        namespace: 'device',
        tool: _FakeTool('scan'),
        source: 'spi:device',
      );

      expect(
        () => r.register(
          namespace: 'device',
          tool: _FakeTool('scan'),
          source: 'remote:sse',
        ),
        throwsA(isA<NamespaceCollisionException>()),
      );
    });

    test('different namespaces do NOT collide', () {
      final r = McpToolRegistry();
      r.register(
        namespace: 'device',
        tool: _FakeTool('scan'),
        source: 'spi:device',
      );
      r.register(
        namespace: 'remote:sse',
        tool: _FakeTool('scan'),
        source: 'remote:sse',
      );
      expect(r.size, equals(2));
    });

    test('toolCountPerNamespace groups correctly (FR-011)', () {
      final r = McpToolRegistry();
      r.register(namespace: 'device', tool: _FakeTool('a'), source: 'spi:device');
      r.register(namespace: 'device', tool: _FakeTool('b'), source: 'spi:device');
      r.register(namespace: 'usecase', tool: _FakeTool('c'), source: 'usecase');

      final counts = r.toolCountPerNamespace;
      expect(counts['device'], equals(2));
      expect(counts['usecase'], equals(1));
    });
  });

  group('McpToolProvider SPI (FR-001, FR-002)', () {
    test('buildTools returns tools under a namespace', () {
      final provider = _DeviceProvider();
      final ctx = McpToolContext();
      final tools = provider.buildTools(ctx);

      expect(provider.namespace, equals('device'));
      expect(tools, hasLength(2));
      expect(tools.map((t) => t.name), containsAll(['scan', 'extract']));
    });

    test('DI context passes dependencies to providers (FR-002)', () {
      final dep = _MyDependency();
      final ctx = McpToolContext(
        resolve: (key) => key == 'dep' ? dep : null,
      );

      expect(ctx.dependency('dep'), same(dep));
      expect(ctx.dependency('missing'), isNull);
    });
  });

  group('AgentRuntimePlugin assembly (FR-003, FR-012)', () {
    test('assembles registry from SPI + usecase + remote sources', () {
      final plugin = AgentRuntimePlugin(
        spiProviders: [_DeviceProvider()],
        usecaseTools: [_FakeTool('generated_usecase')],
        remoteServers: [
          RemoteMcpServer(
            id: 'sse1',
            tools: [_FakeTool('remote_tool')],
            healthStatus: 'healthy',
          ),
        ],
        statefulAgent: StubStatefulAgent(),
      );

      final r = plugin.registry;
      expect(r.size, equals(4));
      expect(r.canonicalNames, containsAll([
        'device.scan',
        'device.extract',
        'usecase.generated_usecase',
        'remote:sse1.remote_tool',
      ]));
    });

    test('namespace collision prevents silent overwrite (FR-012, SC-002)', () {
      // Two SPI providers registering the same namespace + tool name →
      // collision on the second registration.
      expect(
        () => AgentRuntimePlugin(
          spiProviders: [
            _DeviceProvider(),
            _DeviceProvider(), // same namespace, same tools
          ],
        ),
        throwsA(isA<NamespaceCollisionException>()),
      );
    });

    test('remote SSE tools merged with collision prevention (SC-002)', () {
      final plugin = AgentRuntimePlugin(
        spiProviders: [_DeviceProvider()],
        remoteServers: [
          RemoteMcpServer(
            id: 'sse_remote',
            tools: [_FakeTool('weather')],
            healthStatus: 'healthy',
          ),
        ],
      );

      expect(plugin.registry.size, equals(3));
      expect(plugin.registry.canonicalNames, contains('remote:sse_remote.weather'));
      // Remote tool was merged alongside in-proc SPI tools.
      expect(plugin.registry.canonicalNames, contains('device.scan'));
    });
  });

  group('AgentKernel delegation (FR-005, FR-008, FR-013)', () {
    test('3-tool mission streams typed events (SC-001)', () async {
      final plugin = AgentRuntimePlugin(
        spiProviders: [_DeviceProvider()],
        usecaseTools: [_FakeTool('usecase_tool')],
        statefulAgent: StubStatefulAgent(outcome: 'done'),
      );

      final mission = Mission(
        missionId: 'm1',
        spark: 'scan',
        country: 'US',
      );

      final events = await plugin.kernel.runMission(mission).toList();
      expect(events, hasLength(2));
      expect(events[0], isA<MissionEventStarted>());
      expect(events[1], isA<MissionEventCompleted>());
      expect((events[1] as MissionEventCompleted).outcome, equals('done'));
    });

    test('zero agent-loop duplication (FR-013)', () async {
      final stub = StubStatefulAgent(outcome: 'ok');
      final kernel = AgentKernel(
        registry: McpToolRegistry(),
        statefulAgent: stub,
      );

      await kernel.runMission(Mission(
        missionId: 'm1',
        spark: 'scan',
        country: 'US',
      )).toList();

      // The kernel delegated the loop to the StatefulAgent — verified
      // by the stub's callCount being exactly 1 (no internal loop).
      expect(stub.callCount, equals(1));
    });
  });

  group('System prompt composition (FR-006)', () {
    test('composes playbook + tool manifests', () {
      final r = McpToolRegistry();
      r.register(namespace: 'device', tool: _FakeTool('scan', desc: 'Scans a product.'), source: 'spi');
      r.register(namespace: 'usecase', tool: _FakeTool('lookup', desc: 'Looks up details.'), source: 'usecase');

      final composer = SystemPromptComposer(playbook: 'You are a helpful agent.');
      final prompt = composer.compose(r);

      expect(prompt, contains('You are a helpful agent.'));
      expect(prompt, contains('device.scan: Scans a product.'));
      expect(prompt, contains('usecase.lookup: Looks up details.'));
      expect(prompt, contains('# Available tools'));
    });
  });

  group('FallbackLLMClient (FR-007)', () {
    test('uses primary when available', () async {
      final primary = _StubLlmClient('primary-response');
      final fallback = FallbackLLMClient(primary: primary);
      expect(await fallback.complete('hi'), equals('primary-response'));
    });

    test('falls back to secondary on primary failure', () async {
      final primary = _ThrowingLlmClient();
      final secondary = _StubLlmClient('secondary-response');
      final fallback = FallbackLLMClient(primary: primary, secondary: secondary);
      expect(await fallback.complete('hi'), equals('secondary-response'));
    });

    test('returns empty string when no clients configured (degraded)', () async {
      final fallback = FallbackLLMClient();
      expect(await fallback.complete('hi'), equals(''));
    });
  });

  group('Session state persistence (FR-009)', () {
    test('persists and loads state per missionId', () async {
      final storage = InMemoryFileStateStorage();
      final state = AgentState(missionId: 'm1', steps: ['step1', 'step2']);
      await storage.save(state);

      final loaded = await storage.load('m1');
      expect(loaded, isNotNull);
      expect(loaded!.missionId, equals('m1'));
      expect(loaded.steps, equals(['step1', 'step2']));
    });

    test('load returns null when no state', () async {
      final storage = InMemoryFileStateStorage();
      expect(await storage.load('unknown'), isNull);
    });
  });

  group('KernelStatus (FR-011)', () {
    test('reports providers, tool counts, and remote health', () {
      final plugin = AgentRuntimePlugin(
        spiProviders: [_DeviceProvider()],
        remoteServers: [
          RemoteMcpServer(
            id: 'sse1',
            tools: [_FakeTool('weather')],
            healthStatus: 'healthy',
          ),
        ],
      );

      final status = plugin.status();
      expect(status.providers['device'], equals('_DeviceProvider'));
      expect(status.toolCountPerNamespace['device'], equals(2));
      expect(status.toolCountPerNamespace['remote:sse1'], equals(1));
      expect(status.remoteServerHealth['sse1'], equals('healthy'));
      expect(status.totalToolCount, equals(3));
    });
  });

  group('AgentHook ordering (FR-010)', () {
    test('hooks run in registration order on mission start', () async {
      final order = <String>[];
      final kernel = AgentKernel(
        registry: McpToolRegistry(),
        statefulAgent: StubStatefulAgent(),
        hooks: [
          _OrderHook('a', order),
          _OrderHook('b', order),
          _OrderHook('c', order),
        ],
      );

      await kernel.runMission(Mission(
        missionId: 'm1',
        spark: 's',
        country: 'US',
      )).toList();

      expect(order, equals(['a-start', 'b-start', 'c-start']));
    });

    test('disabled hooks are skipped', () async {
      final order = <String>[];
      final disabled = _OrderHook('disabled', order);
      disabled.enabled = false;
      final kernel = AgentKernel(
        registry: McpToolRegistry(),
        statefulAgent: StubStatefulAgent(),
        hooks: [disabled, _OrderHook('enabled', order)],
      );

      await kernel.runMission(Mission(
        missionId: 'm1',
        spark: 's',
        country: 'US',
      )).toList();

      expect(order, equals(['enabled-start']));
    });
  });
}

class _FakeTool extends McpTool {
  _FakeTool(this.name, {this.desc = 'A tool.'});
  @override
  final String name;
  final String desc;
  @override
  String get description => desc;
  @override
  Map<String, Object?> get inputSchema => <String, Object?>{'type': 'object'};
  @override
  Future<Object?> invoke(Map<String, Object?> args) async => 'invoked:$name';
}

class _DeviceProvider implements McpToolProvider {
  @override
  String get namespace => 'device';

  @override
  List<McpTool> buildTools(McpToolContext ctx) {
    return [_FakeTool('scan'), _FakeTool('extract')];
  }
}

class _MyDependency {}

class _StubLlmClient implements LlmClient {
  _StubLlmClient(this.response);
  final String response;
  @override
  Future<String> complete(String prompt) async => response;
}

class _ThrowingLlmClient implements LlmClient {
  @override
  Future<String> complete(String prompt) async {
    throw StateError('primary failed');
  }
}

class _OrderHook extends AgentHook {
  _OrderHook(this.name, this.order);
  final String name;
  final List<String> order;

  @override
  String get id => 'order_$name';

  @override
  bool enabled = true;

  @override
  Future<void> onMissionStart(Mission mission) async {
    order.add('$name-start');
  }
}
