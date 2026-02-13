import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/models/generator_config.dart';

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
  Future<void> beforeGenerate(GeneratorConfig config) async {
    calls.add('before:${config.name}');
  }

  @override
  Future<void> afterGenerate(GeneratorConfig config) async {
    calls.add('after:${config.name}');
  }

  @override
  Future<void> onError(
    GeneratorConfig config,
    Object error,
    StackTrace stackTrace,
  ) async {
    calls.add('error:${config.name}:${error.toString()}');
  }
}

void main() {
  test('PluginRegistry forwards lifecycle calls', () async {
    final calls = <String>[];
    final plugin = _LifecyclePlugin(calls);
    final registry = PluginRegistry();
    registry.register(plugin);
    final config = GeneratorConfig(name: 'User');

    await registry.beforeGenerateAll(config);
    await registry.afterGenerateAll(config);
    await registry.onErrorAll(config, StateError('fail'), StackTrace.current);

    expect(calls[0], equals('before:User'));
    expect(calls[1], equals('after:User'));
    expect(calls[2].contains('error:User'), isTrue);
  });
}
