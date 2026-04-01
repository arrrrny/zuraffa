import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';

class _LifecyclePlugin extends ZuraffaPlugin {
  final List<String> calls;

  _LifecyclePlugin(this.calls);

  @override
  String get id => 'lifecycle';

  @override
  String get name => 'Lifecycle';

  @override
  String get version => '1.0.0';

  @override
  Future<void> beforeGenerate(PluginContext context) async {
    calls.add('before:${context.core.name}');
  }

  @override
  Future<void> afterGenerate(PluginContext context) async {
    calls.add('after:${context.core.name}');
  }

  @override
  Future<void> onError(
    PluginContext context,
    Object error,
    StackTrace stackTrace,
  ) async {
    calls.add('error:${context.core.name}:${error.toString()}');
  }
}

void main() {
  test('PluginRegistry forwards lifecycle calls', () async {
    final calls = <String>[];
    final plugin = _LifecyclePlugin(calls);
    final registry = PluginRegistry();
    registry.register(plugin);
    final context = PluginContext(
      core: const CoreConfig(name: 'User', projectRoot: '.'),
      discovery: const DiscoveryEngine(projectRoot: '.'),
    );

    await registry.beforeGenerateAll(context);
    await registry.afterGenerateAll(context);
    await registry.onErrorAll(context, StateError('fail'), StackTrace.current);

    expect(calls[0], equals('before:User'));
    expect(calls[1], equals('after:User'));
    expect(calls[2].contains('error:User'), isTrue);
  });
}
