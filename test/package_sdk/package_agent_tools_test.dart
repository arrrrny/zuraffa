import 'package:get_it/get_it.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/contracts.dart';
import 'package:zuraffa/src/core/module/mcp_tool.dart';
import 'package:zuraffa/src/core/module/mcp_tool_registry.dart';
import 'package:zuraffa/src/package/package_agent_tools.dart';

class _EchoTool implements McpTool {
  _EchoTool(this._name);

  final String _name;

  @override
  String get name => _name;

  @override
  String get description => 'Echoes its input ($_name)';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'message': {'type': 'string'},
    },
  };

  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async {
    return McpToolResult(text: 'echo: ${arguments['message']}');
  }
}

class _ToolModule extends PackageModule {
  _ToolModule(this._id, this.tools);

  final String _id;
  final List<McpTool> Function(ZuraffaDIContainer di) tools;

  @override
  String get pluginId => _id;

  @override
  List<McpTool> buildAgentTools(ZuraffaDIContainer di) => tools(di);

  @override
  void registerDependencies(ZuraffaDIContainer di) {}

  @override
  Map<String, ZuraffaRouteHandler> get routes => const {};
}

ZuraffaDIContainer _freshContainer() =>
    ZuraffaDIContainer(getIt: GetIt.asNewInstance());

void main() {
  group('PackageAgentTools (FR-008/FR-009 — spec 025)', () {
    test('U22: namespaced() builds the canonical tool id', () {
      expect(
        PackageAgentTools.namespaced('my_pkg', 'do_something'),
        'my_pkg.do_something',
      );
    });

    test(
      'U22: registerInto registers every tool under the package namespace',
      () {
        final registry = McpToolRegistry();
        final module = _ToolModule(
          'pkg_a',
          (di) => [_EchoTool('fetch_thing'), _EchoTool('refresh_thing')],
        );

        PackageAgentTools.registerInto(registry, module, _freshContainer());

        expect(registry.find('pkg_a.fetch_thing'), isNotNull);
        expect(registry.find('pkg_a.refresh_thing'), isNotNull);
        expect(
          registry.find('fetch_thing'),
          isNull,
          reason: 'un-namespaced name must not be registered',
        );
      },
    );

    test('U24: tool set is absent until registered (import-scoped)', () {
      final registry = McpToolRegistry();
      final module = _ToolModule('pkg_b', (di) => [_EchoTool('do_it')]);

      expect(registry.find('pkg_b.do_it'), isNull);
      PackageAgentTools.registerInto(registry, module, _freshContainer());
      expect(registry.find('pkg_b.do_it'), isNotNull);
    });

    test('U28: two packages, same tool name → coexist without collision', () {
      final registry = McpToolRegistry();
      PackageAgentTools.registerInto(
        registry,
        _ToolModule('pkg_a', (di) => [_EchoTool('do_it')]),
        _freshContainer(),
      );
      PackageAgentTools.registerInto(
        registry,
        _ToolModule('pkg_b', (di) => [_EchoTool('do_it')]),
        _freshContainer(),
      );

      expect(registry.find('pkg_a.do_it'), isNotNull);
      expect(registry.find('pkg_b.do_it'), isNotNull);
    });

    test('U28b: same package registered twice → clear duplicate error', () {
      final registry = McpToolRegistry();
      final module = _ToolModule('pkg_a', (di) => [_EchoTool('do_it')]);

      PackageAgentTools.registerInto(registry, module, _freshContainer());
      expect(
        () =>
            PackageAgentTools.registerInto(registry, module, _freshContainer()),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'U29: invoking a namespaced tool executes it and returns the standard result',
      () async {
        final registry = McpToolRegistry();
        PackageAgentTools.registerInto(
          registry,
          _ToolModule('pkg_a', (di) => [_EchoTool('echo')]),
          _freshContainer(),
        );

        final tool = registry.find('pkg_a.echo')!;
        final result = await tool.call({'message': 'hi'});

        expect(result.isError, isFalse);
        expect(result.text, 'echo: hi');
      },
    );
  });

  group('PackageUseCaseTool (FR-008 — DI-resolved usecase adapter)', () {
    ZuraffaDIContainer containerWith(_AddUseCase usecase) {
      final getIt = GetIt.asNewInstance();
      final container = ZuraffaDIContainer(getIt: getIt);
      container.registerLazySingleton<_AddUseCase>(() => usecase);
      return container;
    }

    test('U23: resolves its usecase from DI and returns ok result', () async {
      final tool = PackageUseCaseTool<_AddUseCase>(
        name: 'add',
        description: 'Adds two integers',
        container: containerWith(_AddUseCase()),
        inputSchema: const {
          'type': 'object',
          'properties': {
            'a': {'type': 'integer'},
            'b': {'type': 'integer'},
          },
        },
        invoke: (usecase, args) async =>
            usecase.add(args['a'] as int, args['b'] as int),
      );

      expect(tool.name, 'add');
      final response = await tool.call({'a': 2, 'b': 3});
      expect(response.isError, isFalse);
      expect(response.text, contains('5'));
    });

    test(
      'U23b: execution error surfaces as error result, not a throw',
      () async {
        final tool = PackageUseCaseTool<_AddUseCase>(
          name: 'boom',
          description: 'Always fails',
          container: containerWith(_AddUseCase()),
          invoke: (usecase, args) async {
            throw StateError('usecase exploded');
          },
        );

        final response = await tool.call({});
        expect(response.isError, isTrue);
        expect(response.text, contains('usecase exploded'));
      },
    );

    test('U23c: unregistered usecase surfaces as error result', () async {
      final getIt = GetIt.asNewInstance();
      final tool = PackageUseCaseTool<_AddUseCase>(
        name: 'missing',
        description: 'No usecase registered',
        container: ZuraffaDIContainer(getIt: getIt),
        invoke: (usecase, args) async => 'never reached',
      );

      final response = await tool.call({});
      expect(response.isError, isTrue);
      expect(response.text, contains('_AddUseCase'));
    });
  });
}

class _AddUseCase {
  int add(int a, int b) => a + b;
}
