import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/route_verify_command.dart';

void main() {
  test('discovers CLI and DDA routes and strict fails on overlap', () async {
    final project = await Directory.systemTemp.createTemp('route_verify_');
    addTearDown(() async {
      exitCode = 0;
      await project.delete(recursive: true);
    });
    final routing = Directory('${project.path}/lib/src/routing')
      ..createSync(recursive: true);
    File('${routing.path}/product_routes.dart').writeAsStringSync('''
abstract class ProductRoutes {
  static const String list = '/products';
}

List<Object> productRoutes() => [
  GoRoute(
    path: ProductRoutes.list,
    name: 'productList',
    builder: (context, state) => Object(),
  ),
];
''');
    File('${routing.path}/zfa_router.g.dart').writeAsStringSync('''
Object createZfaRouter() => GoRouter(routes: [
  GoRoute(
    path: '/products',
    name: 'ProductView',
    builder: (context, state) => Object(),
  ),
  GoRoute(path: '/about', name: 'AboutView'),
]);
''');
    final output = File('${project.path}/route-table.json');
    exitCode = 0;

    final runner = CommandRunner<void>('verify-test', 'test')
      ..addCommand(RouteVerifyCommand(projectRoot: project.path));
    await runner.run(['verify', '--json', '--strict', '--out', output.path]);

    expect(exitCode, 1);
    final payload =
        jsonDecode(output.readAsStringSync()) as Map<String, Object?>;
    final routes = (payload['routes']! as List).cast<Map<String, Object?>>();
    expect(routes.map((route) => route['path']), [
      '/about',
      '/products',
      '/products',
    ]);
    final drift = (payload['drift']! as List).single as Map<String, Object?>;
    expect(drift['path'], '/products');
    final sources = (drift['sources']! as List).cast<Map<String, Object?>>();
    expect(sources.map((source) => source['source']), ['cli', 'dda']);
    expect(sources.map((source) => source['file']), [
      'lib/src/routing/product_routes.dart',
      'lib/src/routing/zfa_router.g.dart',
    ]);
  });
}
