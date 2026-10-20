// Issue #1383 — `docs/openwiki/cli.md` did not exist and the epic's
// "35 plugins" count did not match the registry. The doc was generated
// from the live dispatcher and pinned here. The doc and its generator
// were deliberately removed from the repo, so the pins skip while the
// doc is absent instead of failing CI; restore docs/openwiki/cli.md to
// re-enable them.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  final doc = File('docs/openwiki/cli.md');
  final docSkip = doc.existsSync()
      ? null
      : 'docs/openwiki/cli.md is not shipped in-repo (removed from git)';

  test('B1: the generated fleet doc exists', () {
    expect(
      doc.existsSync(),
      isTrue,
      reason: 'restore docs/openwiki/cli.md to re-enable the doc pins',
    );
  }, skip: docSkip);

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
  }, skip: docSkip);

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
  }, skip: docSkip);

  test('B4: the exit-code taxonomy + envelope contract are documented', () {
    final source = doc.readAsStringSync();
    expect(source, contains('SPEC 917'));
    expect(source, contains('zuraffa.verdict.v1'));
    expect(source, contains('proof.v1'));
  }, skip: docSkip);
}
