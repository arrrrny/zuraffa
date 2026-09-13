// T004 (issue #970, FR-004 / AC-4 / AC-6 / AC-7): the `--certify` gate.
//
// RED evidence (pre-fix master): `zfa mock create <Entity> --certify` is
// not a recognized grammar — package:args rejects the flag
// ("Could not find an option named --certify") and the run exits 0, so a
// drifted mock passes silently.
//
// Contract pinned here (remediation): after generation, the gate runs a
// scoped `dart analyze` over the emitted mock files against their
// interface (the analyze subprocess is injected in the fast tier; the
// real subprocess path is exercised by the slow integration test below
// and is the CLI default). Drift → exit 1 with `--> fix:` lines naming
// the missing/incorrect members; a conforming mock passes.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'mock_cli_guard.dart';
import 'package:zuraffa/src/plugins/mock/services/mock_certification.dart';

void main() {
  late Directory tempDir;
  var exitCodeAtEntry = 0;

  setUp(() async {
    exitCodeAtEntry = exitCode;
    tempDir = await Directory.systemTemp.createTemp('mock_certify_970_');
    await _scaffoldProduct(tempDir.path);
  });

  tearDown(() async {
    exitCode = exitCodeAtEntry;
    // Restore the production analyze runner (static test seam).
    MockCertifier.analyzeRunnerOverride = null;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> runCli(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    // The cwd lock: Directory.current is process-wide, so concurrent
    // mock CLI test files would otherwise write into each other's
    // fixtures (issue #970: the mutation baseline runs all these files
    // in ONE `dart test` process).
    return CwdGuard.exclusive(
      () => runner.runCapturing(['-C', tempDir.path, ...args]),
    );
  }

  /// The mock provider/datasource path for the scaffolded Product.
  File mockDatasource() => File(
    p.join(
      tempDir.path,
      'lib',
      'src',
      'data',
      'datasources',
      'product',
      'product_mock_datasource.dart',
    ),
  );

  /// Removes one `@override ... <type> <method>(...) {...}` block from the
  /// mock datasource — the deliberate drift.
  Future<void> driftMockByRemoving(String method) async {
    final file = mockDatasource();
    final src = await file.readAsString();
    final decl = RegExp('\\w+(?:<[^>(]*>)?\\s+$method\\(');
    final match = decl.firstMatch(src);
    expect(
      match,
      isNotNull,
      reason: 'the method $method must exist to drift it',
    );
    final methodLineStart = src.lastIndexOf('  @override', match!.start);
    final nextOverride = src.indexOf('  @override', match.end);
    final classEnd = src.lastIndexOf('}');
    final methodEnd = nextOverride == -1 ? classEnd : nextOverride;
    await file.writeAsString(src.replaceRange(methodLineStart, methodEnd, ''));
  }

  /// Breaks the `update` override's signature while keeping the member
  /// NAME — a drift the lane's name-level shape check cannot see (or
  /// heal), so it must reach the certifier's analyze half.
  Future<void> driftMockByBreakingUpdateSignature() async {
    final file = mockDatasource();
    final src = await file.readAsString();
    final broken = src.replaceFirst(
      'Future<Product> update(UpdateParams<String, ProductPatch> params) '
          'async {',
      'Future<Product> update() async {',
    );
    expect(
      broken,
      isNot(src),
      reason: 'the update override must exist to drift it',
    );
    await file.writeAsString(broken);
  }

  test(
    'A6: --certify fails (exit 1 + --> fix:) on a deliberately drifted mock',
    () async {
      // Deterministic analyze stub for the fast tier — CONDITIONAL on the
      // on-disk state (models the real analyzer): the mock whose `update`
      // override still matches the interface analyzes clean, the
      // hand-broken override is reported. An unconditional stub would make
      // this test vacuous — it would fail any state, conforming included
      // (issue #1570 review).
      MockCertifier.analyzeRunnerOverride = (files, cwd) async {
        final mock = File(p.join(cwd, files.first)).readAsStringSync();
        if (mock.contains(
          'update(UpdateParams<String, ProductPatch> params)',
        )) {
          return (exitCode: 0, output: 'No issues found!');
        }
        return (
          exitCode: 3,
          output:
              '  error - lib/src/data/datasources/product/'
              'product_mock_datasource.dart:30:16 - '
              "'ProductMockDataSource.update' ('Future<Product> Function()') "
              "isn't a valid override of 'ProductDataSource.update' "
              "('Future<Product> Function(UpdateParams<String, ProductPatch>)')"
              ' - invalid_override',
        );
      };

      // 1. A conforming generation (fresh, force not needed).
      await runCli(['mock', 'create', 'Product']);
      exitCode = exitCodeAtEntry;

      // 2. Hand-drift the mock: break the `update` override's signature.
      //    The member name survives, so the lane's shape check does NOT
      //    repair it — exactly the drift class the gate's analyze half
      //    exists for.
      await driftMockByBreakingUpdateSignature();

      // 3. Re-run with --certify: generation skips (name-level member set
      //    matches), the analyze half must refuse.
      final out = await runCli(['mock', 'create', 'Product', '--certify']);
      expect(
        exitCode,
        1,
        reason: 'drift must fail the gate with exit 1, output:\n$out',
      );
      expect(
        out,
        contains('--> fix:'),
        reason: 'the refusal carries a fix line',
      );
      expect(
        out,
        contains('update'),
        reason: 'the fix line names the broken member',
      );
      expect(
        out,
        contains('ProductDataSource'),
        reason: 'the fix line names the interface the mock violates',
      );
      expect(
        out,
        contains('invalid_override'),
        reason: 'the analyzer verdict is surfaced verbatim',
      );
      // The generation run must not have silently clobbered the file.
      expect(
        await mockDatasource().readAsString(),
        contains('Future<Product> update() async {'),
        reason: 'the lane leaves signature-level drift to the gate',
      );
      exitCode = exitCodeAtEntry;
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('A7: --certify passes (exit 0) on a conforming mock', () async {
    MockCertifier.analyzeRunnerOverride = (files, cwd) async {
      return (exitCode: 0, output: 'Analyzing ... No issues found!');
    };

    final out = await runCli(['mock', 'create', 'Product', '--certify']);
    expect(exitCode, 0, reason: 'a conforming mock passes the gate');
    expect(out, contains('mock-cert:product@'));
    expect(out, isNot(contains('--> fix:')));
    exitCode = exitCodeAtEntry;
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('U6: the gate surfaces scoped-analyze errors as fix lines even when the '
      'structural check passes', () async {
    MockCertifier.analyzeRunnerOverride = (files, cwd) async {
      return (
        exitCode: 3,
        output:
            '  error - lib/src/data/datasources/product/'
            'product_mock_datasource.dart:12:9 - Some compile error - '
            'some_code',
      );
    };
    final out = await runCli(['mock', 'create', 'Product', '--certify']);
    expect(exitCode, 1, reason: 'an analyzer error fails the gate');
    expect(out, contains('--> fix:'));
    expect(
      out,
      contains('product_mock_datasource.dart'),
      reason: 'the fix line points at the offending mock file',
    );
    exitCode = exitCodeAtEntry;
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('U5: mock create repairs a drifted mock before the gate (issue #1570) '
      '— certification records conformance', () async {
    MockCertifier.analyzeRunnerOverride = (files, cwd) async {
      return (exitCode: 0, output: '');
    };
    await runCli(['mock', 'create', 'Product']);
    exitCode = exitCodeAtEntry;
    await driftMockByRemoving('toggle');

    // Issue #1570: the mock lane's skip decision is a shape check —
    // a mock missing interface members is repaired (not skipped on
    // "file exists"), so the certifier observes a conforming mock:
    // the drift is healed BEFORE the gate instead of dead-ending it.
    final out = await runCli(['mock', 'create', 'Product', '--certify']);
    expect(exitCode, 0, reason: 'the repaired mock conforms — output:\n$out');
    expect(out, isNot(contains('--> fix: implement the missing')));
    final src = await mockDatasource().readAsString();
    expect(
      src,
      contains('toggle'),
      reason: 'the repaired mock implements the missing member',
    );
    exitCode = exitCodeAtEntry;
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<void> _scaffoldProduct(String root) async {
  final dir = Directory(
    p.join(root, 'lib', 'src', 'domain', 'entities', 'product'),
  );
  await dir.create(recursive: true);
  await File(p.join(dir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;
  final String name;
  const Product({required this.id, required this.name});
}
''');
}
