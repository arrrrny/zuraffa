import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Spec 980 / FR-007 — openwiki/testing.md must match reality: the
/// generated-test example shows native mocks (no mocktail) and documents
/// the Flutter-vs-pure-Dart flavor detection (#354).
void main() {
  late String doc;

  setUpAll(() {
    doc = File(
      path.joinAll([
        ...path.split(Directory.current.path),
        'openwiki',
        'testing.md',
      ]),
    ).readAsStringSync();
  });

  group('generated test example matches the real generator output (U17)', () {
    test('shows the native Throwing datasource mock', () {
      expect(doc, contains('ThrowingProductDataSource'));
    });

    test('shows the native mock datasource wiring', () {
      expect(doc, contains('ProductMockDataSource'));
    });

    test(
      'imports the canonical zuraffa core marker package:zuraffa/mock.dart',
      () {
        expect(doc, contains('package:zuraffa/mock.dart'));
      },
    );

    test('never shows a mocktail import', () {
      expect(
        doc,
        isNot(contains('package:mocktail/mocktail.dart')),
        reason:
            'test_builder_entity.dart emits native mocks; the docs must not '
            'show mocktail output (issue #980: docs actively mislead)',
      );
      expect(doc, isNot(contains('MockProductRepository')));
    });

    test(
      'documents the real generated path convention (<entity>/<method>_usecase_test.dart)',
      () {
        expect(doc, contains('test/domain/usecases/product/'));
        expect(doc, contains('get_product_usecase_test.dart'));
      },
    );
  });

  group('flavor detection documented (U18, #354)', () {
    test('documents the pure-Dart flavor import', () {
      expect(doc, contains('package:test/test.dart'));
    });

    test('documents the Flutter flavor import', () {
      expect(doc, contains('package:flutter_test/flutter_test.dart'));
    });

    test(
      'documents the detection rule (flutter sdk dependency in pubspec)',
      () {
        expect(doc, contains('sdk: flutter'));
        expect(doc, contains('354'));
      },
    );
  });

  group('self-certification documented (980)', () {
    test('documents the machine verdict line', () {
      expect(doc, contains('compile=pass|fail'));
      expect(doc, contains('test: entity='));
    });

    test('documents the per-method test receipt', () {
      expect(doc, contains('.zfa/receipts/test-'));
    });
  });
}
