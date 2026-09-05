// Spec 1098 — Typed FeatureContract: entity + registry + YAML loader tests.
//
// Feature identity today is a raw, unvalidated String everywhere it travels
// (slice `--feature`, xray subcommands, capability `args['name']`). These
// tests pin the typed carrier: one definition of 'feature' with id,
// displayName, entities, boundary, routes, xray layer, and the capability
// argument schema.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract_registry.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_boundary.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_feature_contract_');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  group('FeatureContract entity', () {
    test('constructs with all contract surfaces', () {
      final contract = FeatureContract(
        id: 'login',
        displayName: 'Login',
        entities: const ['User', 'Session'],
        boundary: const SliceBoundary(
          typeName: 'LoginRepository',
          interfaceFile: 'lib/src/domain/repositories/login_repository.dart',
          diRegistrationFile:
              'lib/src/di/repositories/login_repository_di.dart',
          mockStrategy: 'auto',
        ),
        routes: const {'/login', '/login/forgot'},
        xrayLayer: XRayLayer.presentation,
        argSchema: const {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
        },
      );

      expect(contract.id, 'login');
      expect(contract.displayName, 'Login');
      expect(contract.entities, ['User', 'Session']);
      expect(contract.boundary?.typeName, 'LoginRepository');
      expect(contract.routes, {'/login', '/login/forgot'});
      expect(contract.xrayLayer, XRayLayer.presentation);
      expect(contract.argSchema?['type'], 'object');
    });

    test('copyWith preserves unspecified fields and overrides the rest', () {
      final contract = FeatureContract(
        id: 'login',
        displayName: 'Login',
        entities: const ['User'],
        routes: const {'/login'},
      );

      final retargeted = contract.copyWith(id: 'logout', routes: {'/logout'});

      expect(retargeted.id, 'logout');
      expect(retargeted.routes, {'/logout'});
      expect(
        retargeted.displayName,
        'Login',
        reason: 'copyWith must not drop unspecified fields',
      );
      expect(retargeted.entities, ['User']);
    });

    test('equality is value-based', () {
      final a = FeatureContract(
        id: 'login',
        displayName: 'Login',
        entities: const ['User'],
        routes: const {'/login'},
      );
      final b = FeatureContract(
        id: 'login',
        displayName: 'Login',
        entities: const ['User'],
        routes: const {'/login'},
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('XRayLayer.parse accepts the clean-architecture layer names', () {
      expect(XRayLayer.parse('presentation'), XRayLayer.presentation);
      expect(XRayLayer.parse('domain'), XRayLayer.domain);
      expect(XRayLayer.parse('data'), XRayLayer.data);
      expect(
        () => XRayLayer.parse('blockchain'),
        throwsArgumentError,
        reason: 'an unvalidated layer string is the bug this spec fixes',
      );
    });
  });

  group('FeatureContractId', () {
    test('accepts stable kebab ids', () {
      expect(FeatureContractId.isValidKebab('login'), isTrue);
      expect(FeatureContractId.isValidKebab('login-skin'), isTrue);
      expect(FeatureContractId.isValidKebab('user-profile-v2'), isTrue);
    });

    test('rejects spaces, casing, and empty ids', () {
      expect(FeatureContractId.isValidKebab(''), isFalse);
      expect(FeatureContractId.isValidKebab('Login'), isFalse);
      expect(FeatureContractId.isValidKebab('login skin'), isFalse);
      expect(
        FeatureContractId.isValidKebab('login_skin'),
        isFalse,
        reason: 'underscores are not kebab',
      );
    });
  });

  group('FeatureContractRegistry', () {
    final yaml = '''
id: login
display_name: Login
xray_layer: presentation
entities:
  - User
  - Session
routes:
  - /login
  - /login/forgot
boundary:
  type_name: LoginRepository
  interface_file: lib/src/domain/repositories/login_repository.dart
  di_registration_file: lib/src/di/repositories/login_repository_di.dart
  mock_strategy: auto
''';

    test('parses a contract.yaml into a typed FeatureContract', () {
      final contract = parseFeatureContractYaml(yaml);

      expect(contract.id, 'login');
      expect(contract.displayName, 'Login');
      expect(contract.entities, ['User', 'Session']);
      expect(contract.routes, {'/login', '/login/forgot'});
      expect(contract.xrayLayer, XRayLayer.presentation);
      expect(contract.boundary?.typeName, 'LoginRepository');
      expect(
        contract.boundary?.interfaceFile,
        'lib/src/domain/repositories/login_repository.dart',
      );
      expect(
        contract.boundary?.diRegistrationFile,
        'lib/src/di/repositories/login_repository_di.dart',
      );
      expect(contract.boundary?.mockStrategy, 'auto');
    });

    test('parses a minimal contract without boundary/layer', () {
      final contract = parseFeatureContractYaml(
        'id: logout\ndisplay_name: Logout\n',
      );

      expect(contract.id, 'logout');
      expect(contract.boundary, isNull);
      expect(contract.xrayLayer, isNull);
      expect(contract.entities, isEmpty);
      expect(contract.routes, isEmpty);
    });

    test('rejects a contract.yaml without an id', () {
      expect(
        () => parseFeatureContractYaml('display_name: Nope\n'),
        throwsArgumentError,
      );
    });

    test('registers, finds, and replaces by id', () {
      final registry = FeatureContractRegistry();
      final login = parseFeatureContractYaml(yaml);
      registry.register(login);

      expect(registry.findById('login'), equals(login));
      expect(registry.knownIds, {'login'});
      expect(registry.require('login').displayName, 'Login');

      final renamed = login.copyWith(displayName: 'Auth Login');
      registry.register(renamed);
      expect(registry.knownIds, {
        'login',
      }, reason: 're-registering the same id replaces, not duplicates');
      expect(registry.findById('login')?.displayName, 'Auth Login');
    });

    test('require throws with the known ids listed (actionable failure)', () {
      final registry = FeatureContractRegistry()
        ..register(parseFeatureContractYaml(yaml));

      expect(
        () => registry.require('nonexistent'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('login'),
          ),
        ),
      );
    });

    test('findById returns null for unknown ids (no throw)', () {
      expect(FeatureContractRegistry().findById('nope'), isNull);
    });

    test('scanProject discovers specs/<id>/contract.yaml files', () async {
      final specDir = Directory(p.join(workspace.path, 'specs', 'login'));
      await specDir.create(recursive: true);
      await File(p.join(specDir.path, 'contract.yaml')).writeAsString(yaml);

      final otherDir = Directory(p.join(workspace.path, 'specs', 'logout'));
      await otherDir.create(recursive: true);
      await File(
        p.join(otherDir.path, 'contract.yaml'),
      ).writeAsString('id: logout\ndisplay_name: Logout\n');

      // A specs dir without a contract.yaml must be ignored, not crash.
      await Directory(
        p.join(workspace.path, 'specs', 'empty'),
      ).create(recursive: true);

      final registry = FeatureContractRegistry.scanProject(workspace.path);

      expect(registry.knownIds, {'login', 'logout'});
      expect(registry.findById('login')?.boundary?.typeName, 'LoginRepository');
    });

    test('scanProject on a root without specs/ yields an empty registry', () {
      final registry = FeatureContractRegistry.scanProject(workspace.path);
      expect(registry.knownIds, isEmpty);
    });

    test('loadFromSpecDir returns null when contract.yaml is absent', () {
      final dir = Directory(p.join(workspace.path, 'specs', 'nope'));
      dir.createSync(recursive: true);
      expect(FeatureContractRegistry.loadFromSpecDir(dir.path), isNull);
    });
  });
}
