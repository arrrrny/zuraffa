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

  test(
    'A6: --certify fails (exit 1 + --> fix:) on a deliberately drifted mock',
    () async {
      // Deterministic analyze stub for the fast tier: the analyzer agrees
      // with the structural check (drifted → non-zero).
      MockCertifier.analyzeRunnerOverride = (files, cwd) async {
        return (
          exitCode: 3,
          output:
              '  error - lib/src/data/datasources/product/'
              'product_mock_datasource.dart:20:3 - Missing concrete '
              "implementation of 'ProductDataSource.update' - "
              'non_abstract_class_inherits_abstract_member',
        );
      };

      // 1. A conforming generation (fresh, force not needed).
      await runCli(['mock', 'create', 'Product']);
      exitCode = exitCodeAtEntry;

      // 2. Hand-drift the mock: remove the `update` method.
      await driftMockByRemoving('update');

      // 3. Re-run with --certify: generation skips the existing files, the
      //    gate must refuse.
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
        reason: 'the fix line names the missing member',
      );
      expect(
        out,
        contains('ProductDataSource'),
        reason: 'the fix line names the interface the mock violates',
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

  test(
    'U5: the certifier names interface members missing from the mock class',
    () async {
      MockCertifier.analyzeRunnerOverride = (files, cwd) async {
        return (exitCode: 0, output: '');
      };
      await runCli(['mock', 'create', 'Product']);
      exitCode = exitCodeAtEntry;
      await driftMockByRemoving('toggle');

      final out = await runCli(['mock', 'create', 'Product', '--certify']);
      expect(exitCode, 1);
      expect(out, contains('--> fix: implement the missing'));
      expect(out, contains('toggle'));
      exitCode = exitCodeAtEntry;
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
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
