// A2/T016 (feature 071): `zfa tdd func` scaffolds the DECLARED
// signature when the behavior's trace names a function contract row —
// the #920 durable fix (no prose-inferred return types when a
// declaration exists). Undeclared behaviors keep the description-keyed
// deriver (fallback window). Issue #951.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('a declared function signature scaffolds the declared return '
      'type; the prose deriver stays only for undeclared behaviors', () async {
    await fx.seedTestList([
      (
        id: 'U-20',
        description: 'the label renders the template',
        traces: 'Formatter.format',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    // The gen-shaped int stub func rewrites (issue #657 contract).
    await fx.seedCertifiedRed(
      id: 'U-20',
      description: 'the label renders the template',
      subjectContent:
          "int subject_u_20() => throw UnimplementedError('subject_u_20');",
      testContent: "import 'package:test/test.dart';\nvoid main() {}\n",
    );
    // The spec declares Formatter.format -> bool: the return type the
    // subject must carry (the prose deriver would have said String).
    final featureDir = Directory(p.join(fx.root.path, 'specs', fx.featureName));
    await featureDir.create(recursive: true);
    await File(p.join(featureDir.path, 'spec.md')).writeAsString(
      '### Layer Contracts\n\n**Function**:\n'
      '- `Formatter`: `format(Template) -> bool`\n',
    );

    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing([
      'tdd',
      'func',
      'U-20',
      '--project',
      fx.root.path,
    ]);

    final subject = File(fx.subjectPathOf('U-20')).readAsStringSync();
    expect(
      subject,
      contains('bool subject_u_20()'),
      reason: 'the declared signature outranks prose inference (#920)',
    );
  });

  test('a malformed declaration refuses func (exit 1 + fix message) '
      'instead of silently falling back to prose inference '
      '(round-2 fix 3c)', () async {
    const description = 'the label renders the template';
    await fx.seedTestList([
      (
        id: 'U-21',
        description: description,
        traces: 'Broken.format',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.seedCertifiedRed(
      id: 'U-21',
      description: description,
      subjectContent:
          "int subject_u_21() => throw UnimplementedError('subject_u_21');",
      testContent: "import 'package:test/test.dart';\nvoid main() {}\n",
    );
    // A malformed FUNCTION row: the missing `-> Return` is the parser's
    // StateError refusal — func must surface it, never route on prose.
    final featureDir = Directory(p.join(fx.root.path, 'specs', fx.featureName));
    await featureDir.create(recursive: true);
    await File(p.join(featureDir.path, 'spec.md')).writeAsString(
      '### Layer Contracts\n\n**Function**:\n'
      '- `Broken`: `format(Template)`\n',
    );

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'func',
      'U-21',
      '--project',
      fx.root.path,
    ]);

    expect(exitCode, 1, reason: out);
    expect(out, contains('declaration refused'));
    expect(out, contains('--> fix:'));
    expect(
      File(fx.subjectPathOf('U-21')).readAsStringSync(),
      contains('UnimplementedError'),
      reason: 'the subject is left untouched: no prose-inferred scaffold',
    );
  });
}
