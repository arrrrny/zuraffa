// Issue #1513 — the contract lane hardcodes `package:test` and a relative
// subject import, so every generated contract test is dead on arrival on a
// Flutter host (`contract:A1 verify-red` → "Couldn't resolve the package
// 'test'"). The unit/acceptance lanes fixed both defects (#1351: flutter_test
// import surface; #1035: package subject import); the contract lane never
// received the same treatment.
//
// Fix under test (spec 1513-contract-lane-flutter-imports):
//   FR-1 — ContractTestWriter gains `flutterTest` (default false) +
//          `_testImport`; the parseable template honors it.
//   FR-2 — BehaviorTestWriter._packageSubjectImport is promoted to public
//          static `packageSubjectImportFor`; the contract lane's subject
//          import resolves a package: URI under lib/, relative fallback
//          otherwise.
//   FR-4 — the unparseable template honors flutterTest too.
//   FR-5 — the pure-Dart default render stays byte-stable (golden).
//
// Behaviors:
//   B1 — flutterTest: true emits the flutter_test import (parseable template).
//   B2 — default stays on package:test (guard).
//   B3 — the unparseable template honors flutterTest (true → flutter_test;
//        default → package:test).
//   B4 — the contract subject import resolves a package: URI under lib/.
//   B5 — relative fallback kept when the subject is outside lib/.
//   B6 — packageSubjectImportFor direct pins (under-lib → package URI;
//        no pubspec → null; outside lib → null).
//   B8 — the default render for the no-pubspec fixture shape is
//        byte-identical to the pre-fix output (committed golden).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/contract_test_writer.dart';

import '../../../helpers/project_root.dart' as pr;

Behavior _contract(String description) => Behavior(
  id: 'A1',
  feature: '033-golden',
  kind: BehaviorKind.contract,
  description: description,
  sourceCriterion: 'AC-1',
  target: 'add',
);

const parseableContractDescription =
    'contract:A1 — Calculator.add(int a, int b) -> int (usecase contract)';
const unparseableContractDescription =
    'contract:A1 — behaves per the declared seam contract';

Future<(Directory, String)> _writePair({
  required Behavior behavior,
  bool flutterTest = false,
  bool withPubspec = false,
  String pubspecName = 'fixture_pkg',
  String? subjectUnder,
}) async {
  final root = await Directory.systemTemp.createTemp('zfa_1513_');
  try {
    if (withPubspec) {
      await File(p.join(root.path, 'pubspec.yaml')).writeAsString('''
name: $pubspecName
environment:
  sdk: ^3.11.0
''');
    }
    final subjectDir = subjectUnder ?? p.join('lib', 'tdd', behavior.feature);
    final subjectPath = p.join(root.path, subjectDir, 'a1_subject.dart');
    final testPath = p.join(
      root.path,
      'test',
      'tdd',
      behavior.feature,
      'a1_contract_test.dart',
    );
    final writer = ContractTestWriter(flutterTest: flutterTest);
    await writer.write(
      behavior: behavior,
      testPath: testPath,
      subjectPath: subjectPath,
    );
    return (root, File(testPath).readAsStringSync());
  } catch (_) {
    // The helper owns the directory until it returns it; a post-creation
    // failure must not leak it (the caller never sees `root` to clean up).
    if (root.existsSync()) root.deleteSync(recursive: true);
    rethrow;
  }
}

Future<String> _golden() async {
  final root = await pr.findProjectRoot();
  return File(
    p.join(
      root,
      'test',
      'fixtures',
      'baseline_outputs',
      'bug_1513_contract_default_render.txt',
    ),
  ).readAsString();
}

void main() {
  Directory? root;

  tearDown(() {
    if (root != null && root!.existsSync()) root!.deleteSync(recursive: true);
  });

  group('B1/B2: the parseable contract template honors flutterTest', () {
    test('B1: flutterTest: true emits the flutter_test import', () async {
      final (dir, generated) = await _writePair(
        behavior: _contract(parseableContractDescription),
        flutterTest: true,
      );
      root = dir;
      expect(
        generated,
        contains("import 'package:flutter_test/flutter_test.dart';"),
        reason:
            'a Flutter host must generate the flutter_test import — '
            'plain package:test does not resolve under flutter_test:\n'
            '$generated',
      );
      expect(
        generated,
        isNot(contains("import 'package:test/test.dart';")),
        reason:
            'the unresolvable plain test import must not survive on a '
            'Flutter host (issue #1513):\n$generated',
      );
    });

    test(
      'B2: the default stays on the plain package:test import (guard)',
      () async {
        final (dir, generated) = await _writePair(
          behavior: _contract(parseableContractDescription),
        );
        root = dir;
        expect(
          generated,
          contains("import 'package:test/test.dart';"),
          reason:
              'the pure-Dart default must keep the plain test import '
              '(byte-stable default, issue #1513):\n$generated',
        );
        expect(generated, isNot(contains('flutter_test')));
      },
    );
  });

  group('B3: the unparseable contract template honors flutterTest', () {
    test('B3a: flutterTest: true emits the flutter_test import', () async {
      final (dir, generated) = await _writePair(
        behavior: _contract(unparseableContractDescription),
        flutterTest: true,
      );
      root = dir;
      expect(
        generated,
        contains("import 'package:flutter_test/flutter_test.dart';"),
        reason:
            'the refusal-shaped template is a first-class lane surface — '
            'no second-class hardcode left behind (issue #1513):\n$generated',
      );
      expect(generated, isNot(contains("import 'package:test/test.dart';")));
    });

    test('B3b: the default stays on the plain package:test import', () async {
      final (dir, generated) = await _writePair(
        behavior: _contract(unparseableContractDescription),
      );
      root = dir;
      expect(generated, contains("import 'package:test/test.dart';"));
      expect(generated, isNot(contains('flutter_test')));
    });
  });

  group('B4/B5: the contract subject import (one source of truth, #1035)', () {
    test('B4: the subject under lib/ resolves a package: import URI', () async {
      final (dir, generated) = await _writePair(
        behavior: _contract(parseableContractDescription),
        withPubspec: true,
        pubspecName: 'fixture_pkg',
      );
      root = dir;
      expect(
        generated,
        contains(
          "import 'package:fixture_pkg/tdd/033-golden/a1_subject.dart' "
          'as subject;',
        ),
        reason:
            'a relative import reaching into lib/ trips '
            'avoid_relative_lib_imports (#1035) — the contract lane must '
            'answer the same question the unit lane answers:\n$generated',
      );
      expect(generated, isNot(contains("import '../../../lib/")));
    });

    test('B5: the subject outside lib/ keeps the relative fallback', () async {
      final (dir, generated) = await _writePair(
        behavior: _contract(parseableContractDescription),
        // A resolvable pubspec is present, so the relative shape here is
        // forced by the subject sitting OUTSIDE lib/ — not by a missing
        // package identity (finding: B5 previously passed for the wrong
        // reason, withPubspec defaulted to false).
        withPubspec: true,
        pubspecName: 'fixture_pkg',
        subjectUnder: p.join('tool', 'seams'),
      );
      root = dir;
      final importLine = RegExp(
        r"^import '(.+)' as subject;",
        multiLine: true,
      ).firstMatch(generated)!.group(1)!;
      expect(
        importLine,
        isNot(startsWith('package:')),
        reason: 'a subject outside lib/ cannot be a package URI:\n$generated',
      );
      expect(
        importLine,
        contains('tool/seams/a1_subject.dart'),
        reason:
            'the relative fallback must still resolve the pair:\n$generated',
      );
    });
  });

  group('B6: packageSubjectImportFor — the promoted shared helper', () {
    test(
      'B6a: under lib/ with a resolvable pubspec → the package URI',
      () async {
        final dir = await Directory.systemTemp.createTemp('zfa_1513_b6_');
        root = dir;
        await File(
          p.join(dir.path, 'pubspec.yaml'),
        ).writeAsString('name: fixture_pkg\n');
        final testPath = p.join(
          dir.path,
          'test',
          'tdd',
          'f',
          'a1_contract_test.dart',
        );
        final subjectPath = p.join(
          dir.path,
          'lib',
          'tdd',
          'f',
          'a1_subject.dart',
        );
        expect(
          BehaviorTestWriter.packageSubjectImportFor(testPath, subjectPath),
          'package:fixture_pkg/tdd/f/a1_subject.dart',
        );
      },
    );

    test('B6b: no pubspec anywhere → null (caller keeps relative)', () async {
      final dir = await Directory.systemTemp.createTemp('zfa_1513_b6_');
      root = dir;
      final testPath = p.join(dir.path, 'test', 'tdd', 'f', 'a1_test.dart');
      final subjectPath = p.join(
        dir.path,
        'lib',
        'tdd',
        'f',
        'a1_subject.dart',
      );
      expect(
        BehaviorTestWriter.packageSubjectImportFor(testPath, subjectPath),
        isNull,
      );
    });

    test('B6c: subject outside lib/ → null (caller keeps relative)', () async {
      final dir = await Directory.systemTemp.createTemp('zfa_1513_b6_');
      root = dir;
      await File(
        p.join(dir.path, 'pubspec.yaml'),
      ).writeAsString('name: fixture_pkg\n');
      final testPath = p.join(dir.path, 'test', 'tdd', 'f', 'a1_test.dart');
      final subjectPath = p.join(dir.path, 'tool', 'seams', 'a1_subject.dart');
      expect(
        BehaviorTestWriter.packageSubjectImportFor(testPath, subjectPath),
        isNull,
      );
    });
  });

  group('B8: the pure-Dart default render is byte-stable (FR-5 / SC-5)', () {
    test('the no-pubspec default render matches the pre-fix golden byte '
        'for byte', () async {
      final (dir, generated) = await _writePair(
        behavior: _contract(parseableContractDescription),
      );
      root = dir;
      final golden = await _golden();
      expect(generated, golden);
    });
  });
}
