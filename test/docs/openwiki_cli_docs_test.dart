// Issue #1383 — `docs/openwiki/cli.md` did not exist and the epic's
// "35 plugins" count did not match the registry. The doc is now
// GENERATED from the live dispatcher (`tool/generate_openwiki_cli_docs.dart`)
// so it cannot drift: this pin asserts it exists, covers the fleet, and
// carries the exit-code + envelope contract. Regenerate with:
//   dart run tool/generate_openwiki_cli_docs.dart

import 'dart:io';

import 'package:test/test.dart';

void main() {
  final doc = File('docs/openwiki/cli.md');

  test('B1: the generated fleet doc exists', () {
    expect(
      doc.existsSync(),
      isTrue,
      reason: 'regenerate with: dart run tool/generate_openwiki_cli_docs.dart',
    );
  });

  test('B2: the doc covers the fleet (>=50 command sections)', () {
    final source = doc.readAsStringSync();
    final sections = RegExp(
      r'^## `zfa (\S+)`',
      multiLine: true,
    ).allMatches(source);
    expect(
      sections.length,
      greaterThanOrEqualTo(50),
      reason:
          'the registry exposes 59 commands — a collapse means the '
          'generator or the doc regressed',
    );
  });

  test('B3: key verbs are documented', () {
    final source = doc.readAsStringSync();
    for (final verb in [
      'entity',
      'make',
      'tdd',
      'mock',
      'sync',
      'route',
      'proof',
      'simulate',
    ]) {
      expect(
        source,
        contains('## `zfa $verb`'),
        reason: '$verb is part of the fleet surface',
      );
    }
  });

  test('B4: the exit-code taxonomy + envelope contract are documented', () {
    final source = doc.readAsStringSync();
    expect(source, contains('SPEC 917'));
    expect(source, contains('zuraffa.verdict.v1'));
    expect(source, contains('proof.v1'));
  });
}
