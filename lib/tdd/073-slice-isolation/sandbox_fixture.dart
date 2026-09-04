/// Shared fixture for the 073 slice-isolation subjects: a throwaway
/// host project declaring the login feature — the spec's External
/// Dependencies & Contracts rows and declared routes — cut through the
/// real `CutSliceCapability` / composed through `SandboxComposition`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/cut_slice_capability.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_depth.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_manifest.dart';

/// The declared feature the fixture host carries.
const String fixtureFeature = 'login';

/// Declared routes (cut `--route` values): exactly two pages.
const List<String> fixtureRoutes = <String>[
  '/login:LoginPage',
  '/register:RegisterPage',
];

/// Declared dependency rows (cut `--dependency` values): the spec's
/// contract table plus a platform-channel row (AC-4).
const List<String> fixtureDependencies = <String>[
  'FirebaseAuth:service:signIn(email, password) -> User, signOut() -> void:'
      'P1:test/mock/dependencies/firebase_auth_fake.dart',
  'GoRouterHost:service:routeFor(path) -> PageRoute:'
      'P1:test/mock/dependencies/go_router_host_fake.dart',
  'SecureStore:platform-channel:read(key) -> String:'
      'P2:test/mock/dependencies/secure_store_fake.dart',
];

/// The certified fake artifacts cut installs for the declared rows.
const List<String> fixtureFakes = <String>[
  'test/mock/dependencies/firebase_auth_fake.dart',
  'test/mock/dependencies/go_router_host_fake.dart',
  'test/mock/dependencies/secure_store_fake.dart',
];

/// The 073-generated wiring whose bytes must be identical across cuts
/// with identical inputs (deterministic scaffolding, FR-007).
const List<String> fixtureWiring = <String>[
  'lib/main.dart',
  'lib/router.dart',
  'lib/di.dart',
  'lib/src/di/slice_di.dart',
  'main_slice.dart',
  ...fixtureFakes,
];

/// Writes a throwaway host project declaring the login feature.
Directory writeHostProject() {
  final host = Directory.systemTemp.createTempSync('slice-host-');
  File(p.join(host.path, 'pubspec.yaml')).writeAsStringSync(
    'name: host_app\n'
    'environment:\n  sdk: ^3.11.0\n'
    'dependencies:\n  flutter:\n    sdk: flutter\n'
    'dev_dependencies:\n  test: any\n',
  );
  final loginPage = File(
    p.join(host.path, 'lib/src/presentation/pages/login/login_page.dart'),
  );
  loginPage.parent.createSync(recursive: true);
  loginPage.writeAsStringSync('class LoginPage {}\n');
  final spec = File(p.join(host.path, 'specs', fixtureFeature, 'spec.md'));
  spec.parent.createSync(recursive: true);
  spec.writeAsStringSync('# Login feature spec (fixture)\n');
  final journal = File(
    p.join(host.path, 'specs', fixtureFeature, 'tdd', 'journal.json'),
  );
  journal.parent.createSync(recursive: true);
  journal.writeAsStringSync('{"cycle":1,"reds":2,"greens":3}\n');
  final registry = File(
    p.join(host.path, 'specs', fixtureFeature, 'tdd', 'artifacts.json'),
  );
  registry.writeAsStringSync('{"artifacts":[]}\n');
  return host;
}

/// Cuts the login sandbox from [host] through the real capability.
Future<ExecutionResult> cutSandbox(
  Directory host, {
  String name = fixtureFeature,
}) {
  return CutSliceCapability().execute(<String, dynamic>{
    'name': name,
    'entries': <String>['lib/src/presentation/pages/login/login_page.dart'],
    'depth': 'feature',
    'projectRoot': host.path,
    'feature': fixtureFeature,
    'routes': fixtureRoutes,
    'dependencies': fixtureDependencies,
  });
}

/// The sandbox root for the fixture cut.
String sandboxDirOf(Directory host, {String name = fixtureFeature}) =>
    CutSliceCapability.sandboxDirFor(host.path, name);

/// The manifest the fixture cut declares (in-memory twin of what
/// `slice.yaml` records — routes + dependency rows).
SliceManifest fixtureManifest(Directory host) => SliceManifest(
  name: fixtureFeature,
  createdAt: DateTime.parse('2026-09-04T00:00:00.000Z'),
  depth: SliceDepth.parse('feature'),
  entries: <String>['lib/src/presentation/pages/login/login_page.dart'],
  projectRoot: host.path,
  packageName: 'host_app',
  branch: 'sandbox-test',
  files: const [],
  boundaries: const [],
  routes: const [
    ManifestRoute(path: '/login', page: 'LoginPage'),
    ManifestRoute(path: '/register', page: 'RegisterPage'),
  ],
  dependencies: const [
    ManifestDependency(
      dependency: 'FirebaseAuth',
      kind: 'service',
      contract: 'signIn(email, password) -> User, signOut() -> void',
      priority: 'P1',
      mockArtifact: 'test/mock/dependencies/firebase_auth_fake.dart',
    ),
    ManifestDependency(
      dependency: 'GoRouterHost',
      kind: 'service',
      contract: 'routeFor(path) -> PageRoute',
      priority: 'P1',
      mockArtifact: 'test/mock/dependencies/go_router_host_fake.dart',
    ),
    ManifestDependency(
      dependency: 'SecureStore',
      kind: 'platform-channel',
      contract: 'read(key) -> String',
      priority: 'P2',
      mockArtifact: 'test/mock/dependencies/secure_store_fake.dart',
    ),
  ],
);

/// Reads a sandbox file, failing the enclosing test when absent.
String readSandboxFile(String sandboxPath, String rel) {
  final file = File(p.join(sandboxPath, rel));
  expect(file.existsSync(), isTrue, reason: 'missing sandbox file: $rel');
  return file.readAsStringSync();
}
