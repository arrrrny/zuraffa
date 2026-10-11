import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_contract_test_writer.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_contract_writer_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
    final entityDir = Directory(
      p.join(outputDir, 'domain', 'entities', 'login'),
    );
    entityDir.createSync(recursive: true);
    File(p.join(entityDir.path, 'login.dart')).writeAsStringSync('''
class Login {
  final String id;
  final String username;
  const Login({required this.id, required this.username});
}
''');
    final dsDir = Directory(p.join(outputDir, 'data', 'datasources', 'login'));
    dsDir.createSync(recursive: true);
    File(p.join(dsDir.path, 'login_datasource.dart')).writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';
import '../../../domain/entities/login/login.dart';

abstract class LoginDataSource with Loggable, FailureHandler {
  Future<Login> get(QueryParams<Login> params);
  Future<Login> update(UpdateParams<String, LoginPatch> params);
  Future<Login> toggle(ToggleParams<String, Field<Login, dynamic>> params);
}
''');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MockContractTestWriter (spec 1001)', () {
    test(
      'extractContract pins every interface method with signatures',
      () async {
        final writer = const MockContractTestWriter();
        final contract = await writer.extractContract('Login', outputDir);

        expect(contract, isNotNull);
        expect(contract!.length, 3);
        final names = contract.map((m) => m.name).toList();
        expect(names, containsAll(['get', 'update', 'toggle']));
        final get = contract.firstWhere((m) => m.name == 'get');
        expect(get.returnType, 'Future<Login>');
        expect(get.paramsType, 'QueryParams<Login>');
        final update = contract.firstWhere((m) => m.name == 'update');
        expect(update.paramsType, 'UpdateParams<String, LoginPatch>');
      },
    );

    test('extractContract returns null when the interface is absent', () async {
      final writer = const MockContractTestWriter();
      final contract = await writer.extractContract('Ghost', outputDir);
      expect(contract, isNull);
    });

    test('render pins every method through the interface type', () async {
      final writer = const MockContractTestWriter();
      final contract = (await writer.extractContract('Login', outputDir))!;

      final source = writer.render(
        entityName: 'Login',
        methods: contract,
        projectRoot: tempDir.path,
        outputDir: outputDir,
      );

      // The interface + mock are imported and the mock is viewed THROUGH
      // the interface type (the certification's drift detector).
      expect(
        source.contains(
          "import '../../../lib/src/data/datasources/login/"
          "login_datasource.dart';",
        ),
        isTrue,
        reason: 'relative import to the datasource interface',
      );
      expect(
        source.contains(
          "import '../../../lib/src/data/datasources/login/"
          "login_mock_datasource.dart';",
        ),
        isTrue,
        reason: 'relative import to the mock subject',
      );
      expect(source.contains('final LoginDataSource dataSource ='), isTrue);
      expect(source.contains('isA<LoginDataSource>'), isTrue);

      // Per-method signature pins: typed tear-offs reference the exact
      // interface signatures.
      expect(
        source.contains(
          'final Future<Login> Function(QueryParams<Login>) get\$ =',
        ),
        isTrue,
      );
      expect(
        source.contains(
          'final Future<Login> Function('
          'UpdateParams<String, LoginPatch>) update\$ =',
        ),
        isTrue,
      );
      expect(
        source.contains(
          'final Future<Login> Function('
          'ToggleParams<String, Field<Login, dynamic>>) toggle\$ =',
        ),
        isTrue,
      );
      expect(source.contains('dataSource.get;'), isTrue);
    });

    test(
      'render synthesizes behavioral invocations for canonical params',
      () async {
        final writer = const MockContractTestWriter();
        final contract = (await writer.extractContract('Login', outputDir))!;
        final source = writer.render(
          entityName: 'Login',
          methods: contract,
          projectRoot: tempDir.path,
          outputDir: outputDir,
        );

        // get: QueryParams is parameterless — behavioral call emitted.
        expect(
          source.contains('await dataSource.get(QueryParams<Login>())'),
          isTrue,
        );
        // update: id from the first mock record + parameterless patch.
        expect(
          source.contains(
            'UpdateParams<String, LoginPatch>(id: '
            'LoginMockData.logins.first.id, data: LoginPatch())',
          ),
          isTrue,
        );
        // toggle: constructed Field from the id field name + a
        // type-correct sample value (the repo's toggleSampleValue
        // convention — copyWithField casts the value).
        expect(source.contains("const Field<Login, dynamic>('id')"), isTrue);
        expect(source.contains("value: 'toggled')"), isTrue);
      },
    );

    test(
      'render degrades to signature pin for unsynthesizable params',
      () async {
        final writer = const MockContractTestWriter();
        const methods = [
          ContractMethod(
            name: 'login',
            returnType: 'Future<bool>',
            paramsType: 'AuthRequest',
          ),
        ];
        final source = writer.render(
          entityName: 'Login',
          methods: methods,
          projectRoot: tempDir.path,
          outputDir: outputDir,
        );

        expect(
          source.contains('final Future<bool> Function(AuthRequest) login\$ ='),
          isTrue,
        );
        expect(
          source.contains('Behavioral invocation omitted'),
          isTrue,
          reason: 'no safe default for AuthRequest — pin only',
        );
      },
    );

    test('receipt path follows the canonical layout', () {
      expect(
        MockContractTestWriter.receiptPath('Login'),
        p.join('test', 'mock', 'login', 'mock-cert.Login.json'),
      );
      expect(
        MockContractTestWriter.contractTestPath('Login'),
        p.join('test', 'mock', 'login', 'login_mock_contract_test.dart'),
      );
      expect(MockContractTestWriter.interfaceName('Login'), 'LoginDataSource');
      expect(
        MockContractTestWriter.mockClassName('Login'),
        'LoginMockDataSource',
      );
    });
  });
}
