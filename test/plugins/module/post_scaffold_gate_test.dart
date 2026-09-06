// Issue #1149 (kill list, part of EPIC #1132 Machine Contract):
// post-scaffold gate for `zfa module`.
//
// The gate runs REAL `dart pub get` + `dart analyze` inside the scaffolded
// package. These tests exercise it against a tiny pure-Dart package so the
// gate's honesty is proved end-to-end (no Flutter SDK required).
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/post_scaffold_gate.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('module_gate_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('gate passes on a valid pure-Dart package', () async {
    final pkg = Directory('${tempDir.path}/zuraffa_feature_todo');
    Directory('${pkg.path}/lib').createSync(recursive: true);
    File('${pkg.path}/pubspec.yaml').writeAsStringSync(
      'name: zuraffa_feature_todo\n'
      'environment:\n'
      '  sdk: ^3.0.0\n',
    );
    File(
      '${pkg.path}/lib/todo.dart',
    ).writeAsStringSync('int answer() => 42;\n');

    final gate = PostScaffoldGate(
      packageDir: pkg.path,
      packageName: 'zuraffa_feature_todo',
    );
    final ok = await gate.run();

    expect(
      ok,
      isTrue,
      reason: 'pub get + analyze on a valid package must pass the gate',
    );
  });

  test('gate FAILS (exit 1 from the command) on a broken package', () async {
    final pkg = Directory('${tempDir.path}/zuraffa_feature_broken');
    Directory('${pkg.path}/lib').createSync(recursive: true);
    File('${pkg.path}/pubspec.yaml').writeAsStringSync(
      'name: zuraffa_feature_broken\n'
      'environment:\n'
      '  sdk: ^3.0.0\n',
    );
    // A dangling import + unresolved symbol — the exact class of defect the
    // gate exists to catch (pre-merge, the generated orchestrator referenced
    // the nonexistent ZuraffaRouteBuilder and nobody noticed).
    File('${pkg.path}/lib/broken.dart').writeAsStringSync(
      "import 'missing_file.dart';\n\nint f() => doesNotExist();\n",
    );

    final gate = PostScaffoldGate(
      packageDir: pkg.path,
      packageName: 'zuraffa_feature_broken',
    );
    final ok = await gate.run();

    expect(
      ok,
      isFalse,
      reason:
          'analyze on a package with a dangling import must fail the gate — '
          'a silent pass would re-introduce the uncompilable-scaffold '
          'problem the merge was meant to kill.',
    );
  });
}
