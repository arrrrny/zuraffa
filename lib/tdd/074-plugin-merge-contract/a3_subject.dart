// IMPLEMENTED (074 phase 2, issue #962): AC-3 — the only changes
// outside the feature's own artifacts are regenerated barrels: the
// regeneration is additive (host entries byte-stable) and the diff is
// exactly the appended feature entries.
library;

import 'package:test/test.dart';

import 'merge_fixture.dart';

void subject_a3() {
  final regenerated = RouteBarrel.regenerate(
    barrelSource: hostBarrel,
    module: 'login',
    incoming: featureRoutes,
  );
  // The regenerated barrel keeps every original line, in order — the
  // only diff is appended route entries.
  final originalLines = hostBarrel.trim().split('\n');
  final regeneratedLines = regenerated.barrel.trim().split('\n');
  expect(regeneratedLines.take(originalLines.length),
      equals(originalLines),
      reason: 'existing barrel content is untouched');
  expect(regeneratedLines.length, greaterThan(originalLines.length));
  for (final line in regeneratedLines.skip(originalLines.length)) {
    if (line.isEmpty) continue;
    expect(line, startsWith("route('/"),
        reason: 'only regenerated route entries are added');
  }

  // A route collision refuses BEFORE any landing — no silent rewrite.
  final conflicting = RouteBarrel.regenerate(
    barrelSource: hostBarrel,
    module: 'login',
    incoming: const [
      RouteDecl(path: '/home', page: 'LoginPage', module: 'login'),
    ],
  );
  expect(conflicting.passed, isFalse);
  expect(conflicting.conflicts.join(' '), contains('/home'));
  expect(conflicting.conflicts.join(' '), contains('--> fix:'));
}
