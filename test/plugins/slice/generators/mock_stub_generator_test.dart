@Tags(['slow'])

/// Tests for MockStubGenerator (U29, U30, U31).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U29: An abstract boundary interface gets a generated mock implementing
///        all its members with stub returns
///   U30: A boundary with `mockStrategy: existing` reuses the project's own
///        mock instead of generating one
///   U31: Mock generation is depth-aware: at `view` depth the presenter is
///        mocked; at `full` depth no mocks are made
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/mock_stub_generator.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_boundary.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_depth.dart';

import '../helpers/copy_fixture_project.dart';

void main() {
  late String projectRoot;
  late MockStubGenerator generator;

  setUp(() async {
    projectRoot = await copySliceFixtureProject();
    generator = MockStubGenerator();
  });

  tearDown(() async {
    final dir = Directory(projectRoot);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('MockStubGenerator (FR-003)', () {
    test(
      'U29: an abstract interface gets a mock implementing every member',
      () async {
        const boundary = SliceBoundary(
          typeName: 'ProductRepository',
          interfaceFile: 'lib/src/domain/repositories/product_repository.dart',
          diRegistrationFile:
              'lib/src/di/repositories/product_repository_di.dart',
          mockStrategy: 'auto',
        );

        final mock = await generator.generate(
          boundary: boundary,
          projectRoot: projectRoot,
          depth: SliceDepth.feature,
        );

        expect(mock, isNotNull);
        expect(
          mock!.relativePath,
          equals('lib/src/mocks/mock_product_repository.dart'),
        );
        expect(
          mock.content,
          contains('class MockProductRepository implements ProductRepository'),
        );
        // Every public member is stubbed.
        expect(mock.content, contains('getProduct'));
        expect(mock.content, contains('updateProduct'));
        expect(mock.content, contains('watchProductPrice'));
        // ...with stub returns that throw, mocktail-style.
        expect(mock.content, contains('throw UnimplementedError'));
        expect(mock.content, contains('@override'));
      },
    );

    test('U29: the mock carries the interface import so it compiles', () async {
      const boundary = SliceBoundary(
        typeName: 'ProductRepository',
        interfaceFile: 'lib/src/domain/repositories/product_repository.dart',
        mockStrategy: 'auto',
      );

      final mock = await generator.generate(
        boundary: boundary,
        projectRoot: projectRoot,
        depth: SliceDepth.feature,
      );

      expect(
        mock!.content,
        contains("import '../domain/repositories/product_repository.dart';"),
      );
    });

    test('U30: mockStrategy existing reuses the project mock (generates '
        'nothing)', () async {
      const boundary = SliceBoundary(
        typeName: 'ProductRepository',
        interfaceFile: 'lib/src/domain/repositories/product_repository.dart',
        mockStrategy: 'existing',
      );

      final mock = await generator.generate(
        boundary: boundary,
        projectRoot: projectRoot,
        depth: SliceDepth.feature,
      );

      expect(mock, isNull);
    });

    test('U31: at full depth no mocks are made', () async {
      const boundary = SliceBoundary(
        typeName: 'ProductRepository',
        interfaceFile: 'lib/src/domain/repositories/product_repository.dart',
        mockStrategy: 'auto',
      );

      final mock = await generator.generate(
        boundary: boundary,
        projectRoot: projectRoot,
        depth: SliceDepth.full,
      );

      expect(mock, isNull);
    });

    test(
      'U31: at view depth a concrete presenter boundary gets a mock too',
      () async {
        const boundary = SliceBoundary(
          typeName: 'ProductPresenter',
          interfaceFile:
              'lib/src/presentation/pages/product/product_presenter.dart',
          mockStrategy: 'auto',
        );

        final mock = await generator.generate(
          boundary: boundary,
          projectRoot: projectRoot,
          depth: SliceDepth.view,
        );

        expect(mock, isNotNull);
        expect(
          mock!.content,
          contains('class MockProductPresenter implements ProductPresenter'),
        );
        // Presenter members are stubbed.
        expect(mock.content, contains('loadProduct'));
        expect(mock.content, contains('saveProduct'));
      },
    );

    test('inline interfaces preserve getter and setter syntax', () async {
      final interface = File(
        '$projectRoot/lib/src/presentation/pages/account/'
        'account_presenter.dart',
      );
      await interface.create(recursive: true);
      await interface.writeAsString('''
abstract class AccountPresenter {
  String get label;
  set label(String value);
  void refresh();
}
''');
      const boundary = SliceBoundary(
        typeName: 'AccountPresenter',
        interfaceFile:
            'lib/src/presentation/pages/account/account_presenter.dart',
        mockStrategy: 'auto',
      );

      final mock = await generator.generate(
        boundary: boundary,
        projectRoot: projectRoot,
        depth: SliceDepth.view,
      );

      expect(mock, isNotNull);
      expect(mock!.content, contains('String get label;'));
      expect(mock.content, contains('set label(String value);'));
      expect(mock.content, contains('void refresh();'));
    });
  });
}
