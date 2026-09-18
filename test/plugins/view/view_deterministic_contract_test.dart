// EPIC 3 / issue #1134, lane 2 — the mainline `zfa view` ported the
// deterministic contract from `zfa tdd view`: the already-implemented
// verdict (an existing view is reported as already implemented,
// nothing scaffolded, exit 0) and the machine summary line
// (`view: entity=… outcome=…`) — plus the FENCE between the two view
// generators: the mainline never silently clobbers a `zfa tdd view`
// subject.
//
// Drives the public CLI surface in-process (`CliRunner.runCapturing`)
// against a throwaway Flutter-flavored project, mirroring the
// view_structural_test.dart + cli_command_test.dart conventions:
//  U-1134-v3: the first `zfa view create` scaffolds and prints the
//             machine summary line `outcome=scaffolded`.
//  U-1134-v4: a re-run on the generator-written view reports
//             already-implemented (machine line + exit 0) and rewrites
//             NOTHING.
//  U-1134-v5: a target carrying the `zfa tdd view` subject marker
//             refuses (exit 1) naming the tdd generator and the
//             --force escape — the fence.
//  U-1134-v6: a hand-written target (no marker) reports
//             already-implemented without --force — hand-written views
//             are never silently overwritten.
//  U-1134-v7: --force escapes the fence with a loud warning (the
//             escape hatch is documented, never silent).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tempDir;
  late String primaryViewPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_view_contract_');
    await File(p.join(tempDir.path, 'pubspec.yaml')).writeAsString('''
name: view_contract_fixture
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter: ^6.1.0
''');
    primaryViewPath = p.join(
      tempDir.path,
      'lib',
      'src',
      'presentation',
      'pages',
      'login',
      'login_view.dart',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    exitCode = 0;
  });

  Future<String> runView({List<String> extra = const []}) {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(<String>[
      '-C',
      tempDir.path,
      'view',
      'create',
      'Login',
      ...extra,
    ]);
  }

  test('U-1134-v3: the first run scaffolds + prints the machine '
      'summary line', () async {
    final out = await runView();

    expect(exitCode, 0, reason: 'out: $out');
    expect(
      File(primaryViewPath).existsSync(),
      isTrue,
      reason: 'the primary view file is scaffolded',
    );
    expect(
      out,
      contains('view: entity=Login outcome=scaffolded files='),
      reason:
          'the deterministic machine summary line (issue #1134 '
          'lane 2 — the ported contract)',
    );
  });

  test('U-1134-v4: a re-run on the generator-written view reports '
      'already-implemented (exit 0), rewriting nothing', () async {
    await runView();
    final firstBytes = await File(primaryViewPath).readAsString();
    expect(firstBytes, isNot(contains('UnimplementedError')));
    exitCode = 0;

    final out = await runView();

    expect(exitCode, 0, reason: 'out: $out');
    expect(
      out,
      contains('is already implemented — nothing to scaffold'),
      reason:
          'the ported already-implemented verdict (the tdd view '
          'contract vocabulary)',
    );
    expect(
      out,
      contains('view: entity=Login outcome=already-implemented files=0'),
    );
    expect(
      await File(primaryViewPath).readAsString(),
      firstBytes,
      reason:
          'an already-implemented verdict rewrites nothing — the '
          'idempotency contract',
    );
  });

  test('U-1134-v5: a `zfa tdd view` subject refuses (the fence), '
      'naming the other generator and the --force escape', () async {
    await File(primaryViewPath)
        .create(recursive: true)
        .then(
          (f) => f.writeAsString('''
/// View-builder subject for behavior A-001 (issue #939): returns
/// the deterministic minimal view.
Widget subject_a_001() => A001View();
'''),
        );
    final before = await File(primaryViewPath).readAsString();

    final out = await runView();

    expect(exitCode, 1, reason: 'out: $out');
    expect(
      out,
      contains('zfa tdd view'),
      reason: 'the fence names the owning generator',
    );
    expect(out, contains('--force'));
    expect(
      await File(primaryViewPath).readAsString(),
      before,
      reason: 'a refused fence writes nothing',
    );
    expect(
      out,
      contains('view: entity=Login outcome=error files=0'),
      reason: 'the machine summary carries the error outcome',
    );
  });

  test('U-1134-v6: a hand-written target reports already-implemented '
      'without --force (never silently overwritten)', () async {
    final handWritten = '''
import 'package:flutter/material.dart';

/// The hand-written adaptive login seam (issue #1005) — tracked by
/// receipt, never clobbered by a generator.
class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''';
    await File(
      primaryViewPath,
    ).create(recursive: true).then((f) => f.writeAsString(handWritten));

    final out = await runView();

    expect(exitCode, 0, reason: 'out: $out');
    expect(
      out,
      contains('is already implemented — nothing to scaffold'),
      reason:
          'hand-written code reads as already-implemented: the '
          'generator scaffolds nothing over it',
    );
    expect(
      out,
      contains('view: entity=Login outcome=already-implemented files=0'),
    );
    expect(await File(primaryViewPath).readAsString(), handWritten);
  });

  test('U-1134-v7: --force escapes the fence with a loud warning', () async {
    await File(primaryViewPath)
        .create(recursive: true)
        .then(
          (f) => f.writeAsString('''
/// View-builder subject for behavior A-001 (issue #939): returns
/// the deterministic minimal view.
Widget subject_a_001() => A001View();
'''),
        );

    final out = await runView(extra: ['--force']);

    expect(exitCode, 0, reason: 'out: $out');
    expect(
      out,
      contains('overwriting the `zfa tdd view` subject'),
      reason: 'the force escape is loud — never a silent clobber',
    );
    expect(out, contains('view: entity=Login outcome=scaffolded files='));
    expect(
      await File(primaryViewPath).readAsString(),
      isNot(contains('View-builder subject for behavior')),
      reason: '--force took ownership of the file',
    );
  });
}
