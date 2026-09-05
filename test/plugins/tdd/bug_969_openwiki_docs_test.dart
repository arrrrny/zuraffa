/// Issue #969 (T006) — openwiki presence for the tdd plugin.
///
/// The docs contract: `openwiki/cli.md` carries a `zfa tdd` command
/// table covering every verb, and `openwiki/testing.md` has a TDD
/// section linking the cycle flow. Zero openwiki mentions of `tdd` was
/// the docs 3/5 holding the plugin below A+.
library;

import 'dart:io';

import 'package:test/test.dart';

const List<String> kExpectedVerbs = [
  'init',
  'plan',
  'gen',
  'fake',
  'verify-red',
  'make',
  'wire',
  'compose',
  'func',
  'view',
  'refactor',
  'run',
  'replay',
  'verify',
  'migrate-paths',
  'corpus',
  'referee',
  'diff-check',
  'reset',
  'doctor',
  'realize',
  'verdicts',
];

String _readRepoDoc(String rel) {
  // CWD-independent: resolve from this test file upward to the pubspec.
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        dir.path.endsWith('zuraffa')) {
      return File('${dir.path}/$rel').readAsStringSync();
    }
    dir = dir.parent;
  }
  // Fallback for package: resolution — the repo root is three levels up
  // from the package root when run from the repo, else CWD is the repo.
  return File(rel).readAsStringSync();
}

void main() {
  test('openwiki/cli.md has a zfa tdd section with the command table', () {
    final doc = _readRepoDoc('openwiki/cli.md');
    expect(doc, contains('## `zfa tdd` — TDD Loop Plugin'));
    for (final verb in kExpectedVerbs) {
      expect(
        doc,
        contains('`$verb'),
        reason: 'the tdd command table must list every verb: $verb',
      );
    }
    expect(doc, contains('verdict envelope'));
    expect(doc, contains('proof.v1 receipts'));
  });

  test('openwiki/testing.md has a TDD section linking the cycle flow', () {
    final doc = _readRepoDoc('openwiki/testing.md');
    expect(doc, contains('## TDD Cycle'));
    for (final step in ['plan', 'gen', 'verify-red', 'make', 'verify']) {
      expect(
        doc,
        contains('`zfa tdd $step'),
        reason: 'the TDD cycle section must link the flow step: $step',
      );
    }
    expect(doc, contains('tdd/verification.md'));
    expect(doc, contains('`.zfa/receipts/`'));
  });
}
