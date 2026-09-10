// Issue #1387 — the SAME guard condition (a Flutter-dependent plugin
// refuses to generate on a pure-Dart package) exits differently by entry
// point, and NEITHER behavior was pinned:
//
//   A. orchestrator: `zfa make <E> view --no-entity` → skip note,
//      "Done.", exit 0 (the orchestrator continues past a skipped
//      plugin; other lanes still drive).
//   B. standalone: `zfa controller create <E>` → refusal, exit 1 with
//      the no-files note (standalone has nothing to show).
//
// This file pins BOTH contract halves so the asymmetry is documented and
// any future unification that changes either shape fails loudly here.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    // The TddFixture baseline is a PURE-DART package: the
    // Flutter-dependent view/controller plugins refuse to generate.
  });

  tearDown(() {
    exitCode = 0;
    if (fx.root.existsSync()) fx.root.deleteSync(recursive: true);
  });

  test('B1: the orchestrator contract — a skipped plugin is exit 0 with '
      'the skip note', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      'make',
      'User',
      'view',
      '--no-entity',
      '-C',
      fx.root.path,
    ]);
    expect(exitCode, 0, reason: output);
    expect(output, contains('Done'), reason: output);
  });

  test('B2: the standalone contract — a guard-skipped generation refuses '
      'with exit 1', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      'controller',
      'create',
      'Product',
      '-C',
      fx.root.path,
    ]);
    expect(exitCode, 1, reason: output);
    expect(
      output,
      anyOf(
        contains('No files were generated'),
        contains('No files generated'),
      ),
      reason: output,
    );
  });
}
