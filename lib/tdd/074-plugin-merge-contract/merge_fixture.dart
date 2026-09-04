/// Shared fixture for the 074 plugin-merge-contract subjects: a host
/// route barrel, declared routes/bindings/views, and a byte-snapshot
/// sandbox — the facts a conformance-gated merge reads.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:zuraffa/src/plugins/slice/merger/host_baseline.dart';
import 'package:zuraffa/src/plugins/slice/verifier/route_barrel.dart';
export 'package:zuraffa/src/plugins/slice/verifier/route_barrel.dart';

/// The host barrel before the feature merges.
const String hostBarrel = '''
// GENERATED — host route barrel (getAllRoutes aggregation).
List<RouteBase> getAllRoutes() => [
  route('/home', page: HomePage(), // module: home)
  route('/settings', page: SettingsPage(), // module: settings)
];
''';

/// The feature's declared routes.
const List<RouteDecl> featureRoutes = <RouteDecl>[
  RouteDecl(path: '/login', page: 'LoginPage', module: 'login'),
  RouteDecl(path: '/register', page: 'RegisterPage', module: 'login'),
];

/// The feature's declared DI bindings (both flavors).
const List<({String token, List<String> flavors})> featureBindings =
    <({String token, List<String> flavors})>[
      (token: 'dependencies/auth', flavors: <String>['mock', 'real']),
      (token: 'dependencies/login_repo', flavors: <String>['mock', 'real']),
    ];

/// A merged view that follows the host shell convention.
const String conformingView = '''
class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AdaptiveShell(child: LoginView());
  }
}
''';

/// A merged view that violates the host shell convention.
const String offConventionView = '''
class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: LoginView());
  }
}
''';

/// Writes a tiny host tree and snapshots it (the pre-merge baseline).
Directory snapshotSandbox() {
  final host = Directory.systemTemp.createTempSync('merge-host-');
  final file = File(p.join(host.path, 'lib', 'router.dart'));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(hostBarrel);
  return host;
}

/// Captures the sandbox baseline of [host].
HostSnapshot captureBaseline(Directory host) => HostBaseline.capture(
  projectRoot: host.path,
  relativePaths: const <String>['lib/router.dart', 'lib/new_barrel.dart'],
);
