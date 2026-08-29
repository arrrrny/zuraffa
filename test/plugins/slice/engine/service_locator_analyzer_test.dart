/// Tests for ServiceLocatorAnalyzer (U9, U10, U11, U12).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U9:  Extracts every `getIt<T>()` type argument from a presenter
///        constructor body
///   U10: Extracts `T` nested inside `registerUseCase(getIt<T>())`
///   U11: Ignores generic method calls that are not `getIt` lookups
///   U12: Maps each extracted type to its DI registration file under
///        `lib/src/di/` via the snake_case naming convention
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/engine/service_locator_analyzer.dart';

void main() {
  late Directory tmpDir;
  late ServiceLocatorAnalyzer analyzer;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('slice_sl_analyzer_');
    analyzer = ServiceLocatorAnalyzer();
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('ServiceLocatorAnalyzer type extraction (FR-001)', () {
    test('U9: extracts every getIt<T>() from a presenter constructor body',
        () {
      const source = '''
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

class ProductPresenter {
  ProductPresenter() {
    _getProduct = getIt<GetProductUseCase>();
    _fetchSettings = getIt<FetchSettingsUseCase>();
  }

  late final GetProductUseCase _getProduct;
  late final FetchSettingsUseCase _fetchSettings;
}
''';

      final types = analyzer.extractServiceLocatorTypes(source);

      // T121: the exact list — spurious extra extractions fail, matching
      // the sibling test's assertion style.
      expect(types, equals(['GetProductUseCase', 'FetchSettingsUseCase']));
    });

    test('U10: extracts T nested inside registerUseCase(getIt<T>())', () {
      const source = '''
class ProductPresenter {
  ProductPresenter() {
    registerUseCase(getIt<UpdateProductUseCase>());
  }

  void registerUseCase(UpdateProductUseCase usecase) {}
}
''';

      final types = analyzer.extractServiceLocatorTypes(source);

      expect(types, contains('UpdateProductUseCase'));
    });

    test('U11: ignores generic method calls that are not getIt lookups', () {
      const source = '''
class CartPresenter {
  CartPresenter() {
    final items = listOf<CartItem>();
    final repo = repositoryOf<ProductRepository>();
    final plain = getStuff();
  }
}
''';

      final types = analyzer.extractServiceLocatorTypes(source);

      expect(types, isEmpty);
    });

    test('extracts types from every method, not only the constructor', () {
      const source = '''
class ProfilePresenter {
  void bootstrap() {
    _fetchSettings = getIt<FetchSettingsUseCase>();
  }

  late final FetchSettingsUseCase _fetchSettings;
}
''';

      final types = analyzer.extractServiceLocatorTypes(source);

      expect(types, equals(['FetchSettingsUseCase']));
    });
  });

  group('ServiceLocatorAnalyzer DI file mapping (FR-001, U12)', () {
    test('U12: maps a type to lib/src/di/**/<snake>_di.dart', () async {
      final diDir = await Directory(
        '${tmpDir.path}/lib/src/di/usecases',
      ).create(recursive: true);
      await File('${diDir.path}/get_product_usecase_di.dart')
          .writeAsString('void register(GetIt getIt) {}');

      final file = analyzer.diRegistrationFileFor(
        'GetProductUseCase',
        tmpDir.path,
      );

      expect(
        file?.replaceAll('\\\\', '/'),
        contains('lib/src/di/usecases/get_product_usecase_di.dart'),
      );
    });

    test('U12: returns null when no registration file matches', () async {
      await Directory('${tmpDir.path}/lib/src/di').create(recursive: true);

      final file = analyzer.diRegistrationFileFor(
        'UnregisteredUseCase',
        tmpDir.path,
      );

      expect(file, isNull);
    });
  });
}
