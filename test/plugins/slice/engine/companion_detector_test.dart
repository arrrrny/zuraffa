/// Tests for CompanionDetector (U17, U18, U19).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U17: An existing `.g.dart` companion is included alongside its source
///   U18: A missing `.g.dart` companion records a warning and still includes
///        the source file
///   U19: An existing `.freezed.dart` companion is included
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/engine/companion_detector.dart';

void main() {
  late Directory tmpDir;
  late CompanionDetector detector;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('slice_companion_');
    detector = CompanionDetector();
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('CompanionDetector (FR-006)', () {
    test('U17: an existing .g.dart companion is detected', () async {
      final source = await File('${tmpDir.path}/product.dart').writeAsString('''
part 'product.g.dart';

class Product {}
''');
      await File(
        '${tmpDir.path}/product.g.dart',
      ).writeAsString('part of product.dart;\n');

      final result = detector.detectCompanions(
        source.path,
        await source.readAsString(),
      );

      expect(result.companions, hasLength(1));
      expect(result.companions.single, endsWith('product.g.dart'));
      expect(result.warnings, isEmpty);
    });

    test('U18: a missing .g.dart companion records a warning', () async {
      final source = await File('${tmpDir.path}/order.dart').writeAsString('''
part 'order.g.dart';

class Order {}
''');
      // NOTE: order.g.dart deliberately not written.

      final result = detector.detectCompanions(
        source.path,
        await source.readAsString(),
      );

      expect(result.companions, isEmpty);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single, contains('order.g.dart'));
      // The detector never reports the source file itself as missing: the
      // caller keeps including it (FR-006 edge case).
      expect(result.warnings.single, isNot(contains('order.dart ')));
    });

    test('U19: an existing .freezed.dart companion is detected', () async {
      final source = await File('${tmpDir.path}/cart.dart').writeAsString('''
part 'cart.freezed.dart';

class Cart {}
''');
      await File(
        '${tmpDir.path}/cart.freezed.dart',
      ).writeAsString('part of cart.dart;\n');

      final result = detector.detectCompanions(
        source.path,
        await source.readAsString(),
      );

      expect(result.companions, hasLength(1));
      expect(result.companions.single, endsWith('cart.freezed.dart'));
      expect(result.warnings, isEmpty);
    });

    test(
      'a source without generated parts yields no companions or warnings',
      () async {
        final source = await File(
          '${tmpDir.path}/plain.dart',
        ).writeAsString('class Plain {}\n');

        final result = detector.detectCompanions(
          source.path,
          await source.readAsString(),
        );

        expect(result.companions, isEmpty);
        expect(result.warnings, isEmpty);
      },
    );

    test(
      'a companion on disk without a part directive is still included',
      () async {
        // Conventional companion discovery: even when the source lost its
        // `part` line, a sibling `name.g.dart` that exists is pulled in so the
        // mirrored tree stays consistent.
        final source = await File(
          '${tmpDir.path}/entity.dart',
        ).writeAsString('class Entity {}\n');
        await File(
          '${tmpDir.path}/entity.g.dart',
        ).writeAsString('// generated\n');

        final result = detector.detectCompanions(
          source.path,
          await source.readAsString(),
        );

        expect(result.companions, hasLength(1));
        expect(result.companions.single, endsWith('entity.g.dart'));
      },
    );
  });
}
