import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('Zuraffa Config', () {
    test('default environment should be development', () {
      expect(Zuraffa.environment, Environment.development);
      expect(Zuraffa.isDebugMode, isTrue);
    });

    test('setEnvironment should update environment, isDebug, and logging', () {
      Zuraffa.setEnvironment(Environment.production);
      expect(Zuraffa.environment, Environment.production);
      expect(Zuraffa.isDebugMode, isFalse);
      expect(Logger.root.level, Level.OFF);

      Zuraffa.setEnvironment(Environment.staging, isDebugMode: true);
      expect(Zuraffa.environment, Environment.staging);
      expect(Zuraffa.isDebugMode, isTrue);
      expect(Logger.root.level, isNot(Level.OFF));

      // Reset for other tests
      Zuraffa.setEnvironment(Environment.development);
    });

    test('setEnvironment should respect custom logLevel', () {
      Zuraffa.setEnvironment(
        Environment.development,
        logLevel: ZuraffaLogLevel.warning,
      );
      expect(Logger.root.level, Level.WARNING);

      Zuraffa.setEnvironment(
        Environment.staging,
        isDebugMode: true,
        logLevel: ZuraffaLogLevel.severe,
      );
      expect(Logger.root.level, Level.SEVERE);

      // Reset for other tests
      Zuraffa.setEnvironment(Environment.development);
    });

    test('enableLogging should configure Logger.root', () {
      bool logCalled = false;
      Zuraffa.enableLogging(
        level: ZuraffaLogLevel.info,
        onRecord: (record) {
          logCalled = true;
        },
      );

      expect(Logger.root.level, Level.INFO);

      Logger('test').info('test message');
      expect(logCalled, isTrue);

      Zuraffa.disableLogging();
      expect(Logger.root.level, Level.OFF);
    });
  });
}
