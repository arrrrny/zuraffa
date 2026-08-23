import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';

void main() {
  group('PluginContext.get<T>', () {
    late PluginContext context;

    setUp(() {
      context = PluginContext(
        core: CoreConfig(name: 'Test', projectRoot: '/tmp'),
        discovery: DiscoveryEngine(projectRoot: '/tmp'),
        data: {
          'stringKey': 'value',
          'boolKey': true,
          'intKey': 42,
        },
      );
    });

    test('returns value when type matches', () {
      expect(context.get<String>('stringKey'), equals('value'));
      expect(context.get<bool>('boolKey'), isTrue);
      expect(context.get<int>('intKey'), equals(42));
    });

    test('returns null when key is missing', () {
      expect(context.get<String>('missing'), isNull);
    });

    test('returns null on type mismatch instead of throwing', () {
      expect(context.get<String>('boolKey'), isNull);
      expect(context.get<bool>('stringKey'), isNull);
      expect(context.get<int>('stringKey'), isNull);
    });
  });

  group('PluginContext.isActive', () {
    late PluginContext context;

    setUp(() {
      context = PluginContext(
        core: CoreConfig(name: 'Test', projectRoot: '/tmp'),
        discovery: DiscoveryEngine(projectRoot: '/tmp'),
        data: {
          'legacyBool': true,
          '__active_service': true,
          'stringValue': 'foo',
          'intValue': 1,
        },
      );
    });

    test('returns true for legacy data[id] == true', () {
      expect(context.isActive('legacyBool'), isTrue);
    });

    test('returns true for __active_<id> == true', () {
      expect(context.isActive('service'), isTrue);
    });

    test('returns false when neither key is true', () {
      expect(context.isActive('unknown'), isFalse);
    });

    test('returns false when value is truthy but not boolean true', () {
      expect(context.isActive('stringValue'), isFalse);
      expect(context.isActive('intValue'), isFalse);
    });
  });

  group('PluginContext.getShared<T>', () {
    test('returns null on type mismatch instead of throwing', () {
      final context = PluginContext(
        core: CoreConfig(name: 'Test', projectRoot: '/tmp'),
        discovery: DiscoveryEngine(projectRoot: '/tmp'),
        sharedData: {'key': 123},
      );
      expect(context.getShared<String>('key'), isNull);
      expect(context.getShared<int>('key'), equals(123));
    });
  });
}
