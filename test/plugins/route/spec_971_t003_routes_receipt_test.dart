// Spec 0971 / T003 — persist the route table as a proof artifact:
// `.zfa/receipts/routes-<entity>.json` via ReceiptStore (issue #971
// order 3).
//
// The #963 route-coverage ledger will consume this receipt instead of
// re-parsing Dart, so it must carry the route table as data (routes,
// deepLinks, schemeRegistrations) plus the route-table test path AND
// its hash. It is a proof.v1 generation receipt — digests of the exact
// bytes that landed on disk — so `zfa proof check` turns red the moment
// a route artifact is hand-edited.
//
// Style: bug_912_route_dry_run_route_table_test.dart (failing-first).
//
// Driver note: command driven via CommandRunner + explicit projectRoot
// (no process-global CWD swap — see the T002 file's note); the proof
// gate is asserted through ProofChecker, the same engine `zfa proof
// check` dispatches to.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/route_command.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;
  late CommandRunner<void> runner;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('spec971_t003_');
    projectRoot = tempDir.path;
    await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: route_app
environment:
  sdk: ^3.0.0
dependencies:
  flutter:
    sdk: flutter
  go_router: ^14.0.0
''');
    runner = CommandRunner<void>('zfa', 'test')
      ..addCommand(
        RouteCommand(
          RoutePlugin(
            outputDir: '$projectRoot/lib/src',
            projectRoot: projectRoot,
          ),
          projectRoot: projectRoot,
        ),
      );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    exitCode = 0;
  });

  Future<void> createRoutes() => runner.run(['route', 'create', 'Product']);

  group('spec 0971 T003: routes receipt via ReceiptStore', () {
    test(
      'fresh route create writes .zfa/receipts/routes-Product.json',
      () async {
        await createRoutes();

        final receiptFile = File(
          p.join(projectRoot, '.zfa', 'receipts', 'routes-Product.json'),
        );
        expect(
          receiptFile.existsSync(),
          isTrue,
          reason:
              'issue #971 order 3: the route table must persist as a '
              'receipt at the deterministic ledger path',
        );
        final doc =
            jsonDecode(receiptFile.readAsStringSync()) as Map<String, dynamic>;

        // proof.v1 fields — ReceiptStore.loadAll()/ProofChecker parse these.
        expect(doc['schema'], equals('proof.v1'));
        expect(doc['command'], equals('zfa route create'));
        expect(doc['target'], equals('Product'));
        expect(doc['files'], isA<List>());
        expect(
          doc['files'],
          isNotEmpty,
          reason: 'the receipt must digest the route artifacts it wrote',
        );

        // Route-table ledger fields (#963).
        expect(doc['routes'], isA<List>());
        expect(
          (doc['routes'] as List).map((r) => r['path']),
          contains('/product'),
        );
        expect(doc['deepLinks'], isA<List>());
        expect(doc['schemeRegistrations'], isA<List>());
        expect(
          doc['routeTableTestPath'],
          equals('test/routing/route_table_test.dart'),
        );
      },
    );

    test(
      'the receipt carries the route-table test path AND its hash',
      () async {
        await createRoutes();

        final doc =
            jsonDecode(
                  File(
                    p.join(
                      projectRoot,
                      '.zfa',
                      'receipts',
                      'routes-Product.json',
                    ),
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;

        final testPath = doc['routeTableTestPath'] as String;
        final recordedHash = doc['routeTableTestSha256'] as String;
        final onDisk = File(p.join(projectRoot, testPath));
        expect(onDisk.existsSync(), isTrue);
        final actualHash = crypto.sha256
            .convert(onDisk.readAsBytesSync())
            .toString();
        expect(
          recordedHash,
          equals(actualHash),
          reason: 'the recorded hash must bind the exact test bytes on disk',
        );
      },
    );

    test('the proof gate is green on a fresh route create', () async {
      await createRoutes();

      final report = await ProofChecker(projectRoot: projectRoot).check();

      expect(
        report.findings,
        isEmpty,
        reason:
            'acceptance: fresh route create + proof check = green\n'
            '${report.findings.map((f) => f.detail)}',
      );
      expect(report.ok, isTrue);
      expect(report.receipts, greaterThanOrEqualTo(1));
    });

    test('the proof gate turns red on a hand-edited route file', () async {
      await createRoutes();

      // Hand-edit a generated route artifact (post-generation drift).
      final routeFile = File(
        p.join(projectRoot, 'lib/src/routing/product_routes.dart'),
      );
      expect(routeFile.existsSync(), isTrue);
      routeFile.writeAsStringSync(
        '${routeFile.readAsStringSync()}\n// hand edit\n',
      );

      final report = await ProofChecker(projectRoot: projectRoot).check();

      expect(
        report.ok,
        isFalse,
        reason: 'acceptance: hand-edited route file = proof check red',
      );
      final modified = report.findings
          .where((f) => f.kind == ProofFinding.kindModified)
          .toList();
      expect(
        modified,
        isNotEmpty,
        reason: 'the finding must name the modified artifact',
      );
      expect(
        modified.any((f) => f.path.contains('product_routes.dart')),
        isTrue,
      );
    });
  });
}
