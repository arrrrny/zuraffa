import 'package:test/test.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:zuraffa/zuraffa.dart';

void main() {
  group('MigrationFinding', () {
    test('toString includes severity, path, and ruleId', () {
      const finding = MigrationFinding(
        message: 'test finding',
        filePath: 'lib/test.dart',
        line: 42,
        ruleId: 'test_rule',
        severity: MigrationSeverity.warning,
      );
      expect(finding.toString(), contains('[warning]'));
      expect(finding.toString(), contains('lib/test.dart:42'));
      expect(finding.toString(), contains('test_rule'));
    });

    test('suggestion is optional', () {
      const finding = MigrationFinding(
        message: 'no suggestion',
        filePath: 'f.dart',
        line: 1,
        ruleId: 'r',
        severity: MigrationSeverity.info,
      );
      expect(finding.suggestion, isNull);
    });
  });

  group('DetectorResult', () {
    test('hasFindings returns true when findings exist', () {
      final result = DetectorResult(
        detectorId: 'test',
        findings: [
          const MigrationFinding(
            message: 'm',
            filePath: 'f.dart',
            line: 1,
            ruleId: 'r',
            severity: MigrationSeverity.error,
          ),
        ],
      );
      expect(result.hasFindings, isTrue);
      expect(result.errorCount, equals(1));
      expect(result.warningCount, equals(0));
    });

    test('hasFindings returns false when empty', () {
      const result = DetectorResult(detectorId: 'test', findings: []);
      expect(result.hasFindings, isFalse);
    });
  });

  group('MigrationResult', () {
    test('counts actions correctly', () {
      final result = MigrationResult(
        migratorId: 'test',
        actions: [
          const MigrationAction(
            description: 'd',
            filePath: 'a.dart',
            action: 'created',
          ),
          const MigrationAction(
            description: 'd',
            filePath: 'b.dart',
            action: 'modified',
          ),
          const MigrationAction(
            description: 'd',
            filePath: 'c.dart',
            action: 'deleted',
          ),
        ],
      );
      expect(result.filesCreated, equals(1));
      expect(result.filesModified, equals(1));
      expect(result.filesDeleted, equals(1));
    });
  });

  group('MigrationReport', () {
    test('aggregates findings from multiple detectors', () {
      final report = MigrationReport(
        detectorResults: [
          DetectorResult(
            detectorId: 'a',
            findings: [
              const MigrationFinding(
                message: 'e1',
                filePath: 'f.dart',
                line: 1,
                ruleId: 'r1',
                severity: MigrationSeverity.error,
              ),
            ],
          ),
          DetectorResult(
            detectorId: 'b',
            findings: [
              const MigrationFinding(
                message: 'w1',
                filePath: 'g.dart',
                line: 2,
                ruleId: 'r2',
                severity: MigrationSeverity.warning,
              ),
              const MigrationFinding(
                message: 'i1',
                filePath: 'h.dart',
                line: 3,
                ruleId: 'r3',
                severity: MigrationSeverity.info,
              ),
            ],
          ),
        ],
      );
      expect(report.totalErrors, equals(1));
      expect(report.totalWarnings, equals(1));
      expect(report.totalInfo, equals(1));
      expect(report.hasIssues, isTrue);
      expect(report.isClean, isFalse);
    });

    test('isClean when no errors or warnings', () {
      final report = MigrationReport(
        detectorResults: [const DetectorResult(detectorId: 'a', findings: [])],
      );
      expect(report.isClean, isTrue);
    });
  });

  group('StateDetector', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('zuraffa_test_');
    });

    tearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('detects mixed state with both domain and UI fields', () async {
      final stateDir = Directory(
        p.join(tmpDir.path, 'lib', 'presentation', 'pages', 'product'),
      );
      await stateDir.create(recursive: true);

      final stateFile = File(p.join(stateDir.path, 'product_state.dart'));
      await stateFile.writeAsString('''
class ProductState {
  final AppFailure? error;
  final bool isLoading;
  final Product? product;
  final String searchTerm;

  const ProductState({
    this.error,
    this.isLoading = false,
    this.product,
    this.searchTerm = '',
  });
}
''');

      final detector = StateDetector();
      final result = await detector.detect(tmpDir.path);

      expect(result.hasFindings, isTrue);
      expect(result.findings.length, equals(1));
      expect(result.findings.first.ruleId, equals('v5_mixed_state'));
      expect(result.findings.first.severity, equals(MigrationSeverity.warning));
    });

    test('skips files with only UI fields', () async {
      final stateDir = Directory(
        p.join(tmpDir.path, 'lib', 'presentation', 'pages', 'product'),
      );
      await stateDir.create(recursive: true);

      final stateFile = File(p.join(stateDir.path, 'product_state.dart'));
      await stateFile.writeAsString('''
class ProductState {
  final AppFailure? error;
  final bool isLoading;
  final bool isRefreshing;

  const ProductState({
    this.error,
    this.isLoading = false,
    this.isRefreshing = false,
  });
}
''');

      final detector = StateDetector();
      final result = await detector.detect(tmpDir.path);

      expect(result.hasFindings, isFalse);
    });

    test('skips domain_state and view_state files', () async {
      final stateDir = Directory(p.join(tmpDir.path, 'lib', 'presentation'));
      await stateDir.create(recursive: true);

      await File(
        p.join(stateDir.path, 'product_domain_state.dart'),
      ).writeAsString('class ProductDomainState {}\n');
      await File(
        p.join(stateDir.path, 'product_view_state.dart'),
      ).writeAsString('class ProductViewState {}\n');

      final detector = StateDetector();
      final result = await detector.detect(tmpDir.path);

      expect(result.hasFindings, isFalse);
    });
  });

  group('ManualDiDetector', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('zuraffa_test_');
    });

    tearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('detects getIt.registerLazySingleton', () async {
      final diDir = Directory(p.join(tmpDir.path, 'lib', 'di'));
      await diDir.create(recursive: true);

      await File(p.join(diDir.path, 'setup.dart')).writeAsString('''
void setupDI() {
  getIt.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(),
  );
}
''');

      final detector = ManualDiDetector();
      final result = await detector.detect(tmpDir.path);

      expect(result.hasFindings, isTrue);
      expect(result.findings.first.ruleId, equals('v5_manual_di'));
    });

    test('detects GetIt.instance usage', () async {
      final srcDir = Directory(p.join(tmpDir.path, 'lib', 'services'));
      await srcDir.create(recursive: true);

      await File(p.join(srcDir.path, 'service.dart')).writeAsString('''
class MyService {
  void doWork() {
    final repo = GetIt.instance<ProductRepository>();
  }
}
''');

      final detector = ManualDiDetector();
      final result = await detector.detect(tmpDir.path);

      expect(result.hasFindings, isTrue);
    });
  });

  group('DependencyOverridesDetector', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('zuraffa_test_');
    });

    tearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('detects analyzer override as warning', () async {
      await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: test
dependencies:
  flutter:
    sdk: flutter

dependency_overrides:
  analyzer: 14.1.0
  meta: ^1.19.0

executables:
  zfa:
''');

      final detector = DependencyOverridesDetector();
      final result = await detector.detect(tmpDir.path);

      expect(result.hasFindings, isTrue);
      expect(
        result.findings.any((f) => f.severity == MigrationSeverity.warning),
        isTrue,
      );
      expect(
        result.findings.any((f) => f.message.contains('analyzer')),
        isTrue,
      );
    });

    test('no findings when no dependency_overrides', () async {
      await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: test
dependencies:
  flutter:
    sdk: flutter
''');

      final detector = DependencyOverridesDetector();
      final result = await detector.detect(tmpDir.path);

      expect(result.hasFindings, isFalse);
    });
  });

  group('ControlledWidgetDetector', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('zuraffa_test_');
    });

    tearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('detects extends ControlledWidget', () async {
      final viewDir = Directory(p.join(tmpDir.path, 'lib', 'presentation'));
      await viewDir.create(recursive: true);

      await File(p.join(viewDir.path, 'my_page.dart')).writeAsString('''
class MyPage extends ControlledWidget<MyController> {
  @override
  Widget buildView(BuildContext context) {
    return SizedBox();
  }
}
''');

      final detector = ControlledWidgetDetector();
      final result = await detector.detect(tmpDir.path);

      expect(result.hasFindings, isTrue);
      expect(result.findings.first.ruleId, equals('v5_controlled_widget'));
    });
  });

  group('GqlConstStringDetector', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('zuraffa_test_');
    });

    tearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('detects gql() calls', () async {
      final dsDir = Directory(
        p.join(tmpDir.path, 'lib', 'data', 'datasources'),
      );
      await dsDir.create(recursive: true);

      await File(p.join(dsDir.path, 'product_ds.dart')).writeAsString("""
import 'package:gql/gql.dart';

final getProductQuery = gql(r'''
  query GetProduct(\$id: ID!) {
    product(id: \$id) {
      name
      price
    }
  }
''');
""");

      final detector = GqlConstStringDetector();
      final result = await detector.detect(tmpDir.path);

      expect(result.hasFindings, isTrue);
      expect(result.findings.first.ruleId, equals('v5_gql_const_string'));
    });
  });

  group('StateMigrator', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('zuraffa_test_');
    });

    tearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('dry-run does not write files', () async {
      final stateDir = Directory(
        p.join(tmpDir.path, 'lib', 'presentation', 'pages', 'order'),
      );
      await stateDir.create(recursive: true);

      final stateFile = File(p.join(stateDir.path, 'order_state.dart'));
      await stateFile.writeAsString('''
class OrderState {
  final AppFailure? error;
  final bool isLoading;
  final Order? order;

  const OrderState({this.error, this.isLoading = false, this.order});
}
''');

      final migrator = StateMigrator();
      final result = await migrator.migrate(
        findings: [
          const MigrationFinding(
            message: 'Mixed state',
            filePath: 'lib/presentation/pages/order/order_state.dart',
            line: 1,
            ruleId: 'v5_mixed_state',
            severity: MigrationSeverity.warning,
          ),
        ],
        projectDir: tmpDir.path,
        dryRun: true,
      );

      expect(result.filesCreated, equals(2));
      // No new files should exist on disk
      expect(
        File(p.join(stateDir.path, 'order_domain_state.dart')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(stateDir.path, 'order_view_state.dart')).existsSync(),
        isFalse,
      );
    });

    test('wet-run creates domain and view state files', () async {
      final stateDir = Directory(
        p.join(tmpDir.path, 'lib', 'presentation', 'pages', 'cart'),
      );
      await stateDir.create(recursive: true);

      final stateFile = File(p.join(stateDir.path, 'cart_state.dart'));
      await stateFile.writeAsString('''
class CartState {
  final AppFailure? error;
  final bool isLoading;
  final Cart? cart;

  const CartState({this.error, this.isLoading = false, this.cart});
}
''');

      final migrator = StateMigrator();
      final result = await migrator.migrate(
        findings: [
          const MigrationFinding(
            message: 'Mixed state',
            filePath: 'lib/presentation/pages/cart/cart_state.dart',
            line: 1,
            ruleId: 'v5_mixed_state',
            severity: MigrationSeverity.warning,
          ),
        ],
        projectDir: tmpDir.path,
        dryRun: false,
      );

      expect(result.filesCreated, equals(2));
      expect(result.filesModified, equals(1));
      expect(
        File(p.join(stateDir.path, 'cart_domain_state.dart')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(stateDir.path, 'cart_view_state.dart')).existsSync(),
        isTrue,
      );
      // Verify generated domain state extends DomainState
      final domainContent = await File(
        p.join(stateDir.path, 'cart_domain_state.dart'),
      ).readAsString();
      expect(domainContent, contains('CartDomainState'));
      expect(domainContent, contains('extends DomainState'));
      // Verify generated view state extends ChangeNotifier
      final viewContent = await File(
        p.join(stateDir.path, 'cart_view_state.dart'),
      ).readAsString();
      expect(viewContent, contains('CartViewState'));
      expect(viewContent, contains('ChangeNotifier'));
    });
  });
}
