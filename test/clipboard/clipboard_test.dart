import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Clipboard built-in: port contract, in-memory backing, facade.
void main() {
  group('ClipboardPort — in-memory adapter', () {
    test('setText/getText round-trip; clear empties', () async {
      final port = InMemoryClipboardAdapter();

      await port.setText('tok-1');
      expect(await port.getText(), 'tok-1');

      await port.clear();
      expect(await port.getText(), isNull);
    });

    test('setText overwrites and records the writes', () async {
      final port = InMemoryClipboardAdapter();

      await port.setText('first');
      await port.setText('second');

      expect(await port.getText(), 'second');
      expect(port.writes, ['first', 'second']);
    });

    test('an externally seeded value (user copied) reads back', () async {
      final port = InMemoryClipboardAdapter()..value = 'user-copied';

      expect(await port.getText(), 'user-copied');
    });
  });

  group('ClipboardService', () {
    test('copy/paste/hasText/clear flow', () async {
      final service = ClipboardService();

      expect(await service.hasText, isFalse);

      await service.copy('secret');
      expect(await service.paste(), 'secret');
      expect(await service.hasText, isTrue);

      await service.clear();
      expect(await service.paste(), isNull);
      expect(await service.hasText, isFalse);
    });

    test('copySensitive behaves as copy (semantic marker)', () async {
      final service = ClipboardService();

      await service.copySensitive('tok-9');
      expect(await service.paste(), 'tok-9');
    });

    test('registerClipboardDependencies wires port + service', () async {
      final getIt = GetIt.asNewInstance();
      registerClipboardDependencies(getIt);

      await getIt<ClipboardService>().copy('di');
      expect(await getIt<ClipboardPort>().getText(), 'di');
    });
  });
}
