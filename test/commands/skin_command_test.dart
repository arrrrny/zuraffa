// Issue #1102 — the `zfa skin` command group: `skin kit` (emit the
// runtime auditor glue) and `skin verify` (static route-contract
// reconciliation, the route-verify verdict precedent).
library;

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/skin_command.dart';

Future<String> captureOutput(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

void main() {
  late Directory tempDir;
  late String projectRoot;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('spec1102_skin_');
    projectRoot = tempDir.path;
    await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: skin_app
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa:
    path: ../
''');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    exitCode = 0;
  });

  Future<(String, int)> runSkin(List<String> args) async {
    exitCode = 0;
    final runner = CommandRunner<void>('zfa', 'test')
      ..addCommand(SkinCommand(projectRoot: projectRoot));
    final output = await captureOutput(() => runner.run(['skin', ...args]));
    return (output, exitCode);
  }

  String kitPath() =>
      p.join(projectRoot, 'lib', 'src', 'skin', 'skin_contract_auditor.dart');

  void writeRoutingBarrel({
    List<String> routes = const ['/product', '/deals'],
  }) {
    final routingDir = Directory(p.join(projectRoot, 'lib', 'src', 'routing'))
      ..createSync(recursive: true);
    final consts = routes
        .map((r) => "  static const String r${routes.indexOf(r)} = '$r';")
        .join('\n');
    File(p.join(routingDir.path, 'app_routes.dart')).writeAsStringSync('''
class AppRoutes {
$consts
}
''');
    final goRoutes = routes
        .map((r) => "GoRoute(path: AppRoutes.r${routes.indexOf(r)}),")
        .join('\n      ');
    File(p.join(routingDir.path, 'index.dart')).writeAsStringSync('''
import 'package:go_router/go_router.dart';
import 'app_routes.dart';

List<RouteBase> getAllRoutes() => [
      $goRoutes
    ];
''');
  }

  group('zfa skin kit', () {
    test('writes the kit file into <output>/skin/', () async {
      final (output, code) = await runSkin(['kit']);
      expect(code, 0, reason: output);
      expect(File(kitPath()).existsSync(), isTrue);
      expect(output, contains('skin_contract_auditor.dart'));
    });

    test('--route flags land in the emitted route contract table', () async {
      await runSkin(['kit', '--route', 'deal_list', '--route', 'login']);
      final src = File(kitPath()).readAsStringSync();
      expect(src, contains("'deal_list'"));
      expect(src, contains("'login'"));
    });

    test(
      'without --route, derives the table from the routing barrel',
      () async {
        writeRoutingBarrel(routes: ['/product', '/deals']);
        await runSkin(['kit']);
        final src = File(kitPath()).readAsStringSync();
        expect(src, contains("'/product'"));
        expect(src, contains("'/deals'"));
      },
    );

    test(
      'skip-if-exists preserves hand edits (the 1005 seam precedent)',
      () async {
        await runSkin(['kit']);
        final file = File(kitPath());
        file.writeAsStringSync('// hand-edited kit');
        final (output, code) = await runSkin(['kit']);
        expect(code, 0);
        expect(file.readAsStringSync(), '// hand-edited kit');
        expect(output, contains('skipped'));
      },
    );

    test('--force regenerates over a hand-edited kit', () async {
      await runSkin(['kit']);
      final file = File(kitPath());
      file.writeAsStringSync('// hand-edited kit');
      await runSkin(['kit', '--force']);
      expect(file.readAsStringSync(), contains('SkinContractAuditor'));
    });

    test('--dry-run writes nothing and reports the path', () async {
      final (output, code) = await runSkin(['kit', '--dry-run']);
      expect(code, 0);
      expect(File(kitPath()).existsSync(), isFalse);
      expect(output, contains(kitPath()));
    });
  });

  group('zfa skin verify', () {
    test('match: kit table == routing barrel routes -> exit 0', () async {
      writeRoutingBarrel(routes: ['/product', '/deals']);
      await runSkin(['kit']);
      final (output, code) = await runSkin(['verify']);
      expect(code, 0, reason: output);
      expect(output, contains('match'));
    });

    test(
      'drift: a barrel route missing from the kit -> exit 1 + fix line',
      () async {
        writeRoutingBarrel(routes: ['/product', '/deals']);
        // Kit table with only one of the two barrel routes.
        await runSkin(['kit', '--route', '/product']);
        final (output, code) = await runSkin(['verify']);
        expect(code, 1, reason: output);
        expect(output, contains('drift'));
        expect(output, contains('/deals'));
        expect(output, contains('--> fix:'));
      },
    );

    test(
      'insufficient-input: no kit emitted -> exit 2 (never a fake pass)',
      () async {
        writeRoutingBarrel(routes: ['/product']);
        final (output, code) = await runSkin(['verify']);
        expect(code, 2, reason: output);
        expect(output, contains('insufficient-input'));
      },
    );

    test('insufficient-input: no routing barrel -> exit 2', () async {
      await runSkin(['kit', '--route', '/product']);
      final (output, code) = await runSkin(['verify']);
      expect(code, 2, reason: output);
      expect(output, contains('insufficient-input'));
    });

    test('--json emits a machine-readable verdict envelope', () async {
      writeRoutingBarrel(routes: ['/product', '/deals']);
      await runSkin(['kit']);
      final (output, code) = await runSkin(['verify', '--json']);
      expect(code, 0, reason: output);
      // The final line is the JSON envelope.
      final lastLine = output.trim().split('\n').last;
      expect(lastLine, startsWith('{'));
      expect(lastLine, contains('"verdict":"match"'));
    });
  });
}
