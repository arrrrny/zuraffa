/// Tests for SandboxBootstrapper (U32, U33, U34).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U32: Generated `main_slice.dart` imports the root view, calls
///        `setupSliceDependencies()`, and runs the app
///   U33: Generated `slice_di.dart` registers exactly the slice's needed
///        bindings and boundary mocks — nothing else
///   U34: A multi-entry slice generates an entry point exposing every entry
///        root
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_bootstrapper.dart';

void main() {
  late SandboxBootstrapper bootstrapper;

  setUp(() {
    bootstrapper = SandboxBootstrapper();
  });

  group('SandboxBootstrapper main_slice.dart (FR-003)', () {
    test('U32: single entry imports the root view, sets up DI, runs the app',
        () {
      final content = bootstrapper.generateMainSlice(
        sliceName: 'product_feature',
        entryViews: const [
          EntryView(
            importPath:
                'package:zik_zak/src/presentation/pages/product/product_view.dart',
            className: 'ProductView',
            title: 'Product',
          ),
        ],
      );

      expect(
        content,
        contains(
          "import 'package:zik_zak/src/presentation/pages/product/product_view.dart';",
        ),
      );
      expect(content, contains('setupSliceDependencies()'));
      expect(content, contains('runApp('));
      expect(content, contains('MaterialApp'));
      expect(content, contains('ProductView'));
    });

    test('U34: a multi-entry slice exposes every entry root', () {
      final content = bootstrapper.generateMainSlice(
        sliceName: 'profile_flow',
        entryViews: const [
          EntryView(
            importPath:
                'package:zik_zak/src/presentation/pages/profile/profile_view.dart',
            className: 'ProfileView',
            title: 'Profile',
          ),
          EntryView(
            importPath:
                'package:zik_zak/src/presentation/pages/product/product_view.dart',
            className: 'ProductView',
            title: 'Product',
          ),
        ],
      );

      expect(
        content,
        contains("import 'package:zik_zak/src/presentation/pages/profile/profile_view.dart';"),
      );
      expect(
        content,
        contains("import 'package:zik_zak/src/presentation/pages/product/product_view.dart';"),
      );
      expect(content, contains('ProfileView'));
      expect(content, contains('ProductView'));
    });
  });

  group('SandboxBootstrapper slice_di.dart (FR-003)', () {
    test('U33: registers real bindings and boundary mocks, nothing else',
        () {
      final content = bootstrapper.generateSliceDi(
        sliceName: 'product_feature',
        realRegistrations: const [
          RealDiCall(
            importPath: 'usecases/get_product_usecase_di.dart',
            functionName: 'registerGetProductUseCase',
          ),
          RealDiCall(
            importPath: 'usecases/update_product_usecase_di.dart',
            functionName: 'registerUpdateProductUseCase',
          ),
        ],
        mockRegistrations: const [
          MockRegistration(
            typeName: 'ProductRepository',
            mockClassName: 'MockProductRepository',
            mockImportPath: '../mocks/mock_product_repository.dart',
            interfaceImportPath: '../domain/repositories/product_repository.dart',
          ),
        ],
      );

      expect(content, contains('void setupSliceDependencies()'));
      // Real wiring is delegated to the project's own (included) DI files.
      expect(content, contains("import 'usecases/get_product_usecase_di.dart';"));
      expect(content, contains('registerGetProductUseCase(getIt);'));
      expect(content, contains('registerUpdateProductUseCase(getIt);'));
      // The cut-off boundary gets its mock registered.
      expect(
        content,
        contains(
          'getIt.registerLazySingleton<ProductRepository>(',
        ),
      );
      expect(content, contains('MockProductRepository()'));
      expect(content, contains("import '../mocks/mock_product_repository.dart';"));
      // Nothing else: no data-layer registration leaks in.
      expect(content, isNot(contains('DataProductRepository')));
      expect(content, isNot(contains('ProductRemoteDataSource')));
    });

    test('with no mocks the setup only wires real registrations', () {
      final content = bootstrapper.generateSliceDi(
        sliceName: 'product_full',
        realRegistrations: const [
          RealDiCall(
            importPath: 'repositories/product_repository_di.dart',
            functionName: 'registerProductRepository',
          ),
        ],
        mockRegistrations: const [],
      );

      expect(content, contains('registerProductRepository(getIt);'));
      expect(content, isNot(contains('registerLazySingleton')));
    });
  });
}
