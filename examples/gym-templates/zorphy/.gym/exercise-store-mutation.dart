/// GYM exercise — zorphy store mutation round-trip (graded).
///
/// Brief: A genuine dev task — open a `Store<int>`, register a
/// subscriber, dispatch a `setValue(42)` mutation, and assert the
/// subscriber received the new value in the correct order. This
/// trains the same muscle as wiring a real feature's state
/// propagation — NOT a re-skinned unit test.
///
/// verifyCommand: `dart run .gym/exercise-store-mutation.dart`
/// evaluate: exit 0 => pass; exit !=0 => fail
///
/// A mis-fire is captured as a DROP CARD.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// A self-contained DROP CARD emitter (no cross-repo dependency on
/// zuraffa's helper). Mirrors the format defined in
/// `.gym/lib/drop_card.dart` of the zuraffa repo.
String _dropCard({
  required String did,
  required String expected,
  required String happened,
  required String where,
}) {
  return '''
# DROP CARD — store-mutation

**Did**: $did
**Expected**: $expected
**Happened**: $happened
**Where**: $where
''';
}

Future<void> main() async {
  final sandbox = Directory(p.canonicalize('.gym/.sandbox/store-mutation'));
  if (sandbox.existsSync()) {
    await sandbox.delete(recursive: true);
  }
  await sandbox.create(recursive: true);

  // The exercise drives a multi-subscriber round-trip — more
  // demanding than the smoke rep. Two subscribers; assert both
  // received the value in registration order.
  final script = File(p.join(sandbox.path, 'graded.dart'));
  script.writeAsStringSync(r'''
import 'package:zorphy/zorphy.dart';

Future<void> main() async {
  final store = Store<int>(0);
  final order = <String>[];

  store.subscribe((v) => order.add('first:$v'));
  store.subscribe((v) => order.add('second:$v'));

  await store.dispatch(SetValueAction(42));

  if (order.length != 2) {
    throw StateError('expected 2 subscriber calls, got ${order.length}: $order');
  }
  if (order[0] != 'first:42' || order[1] != 'second:42') {
    throw StateError('subscriber order wrong: $order');
  }
  if (store.state != 42) {
    throw StateError('state should be 42, got ${store.state}');
  }

  print('PASS: store-mutation — both subscribers fired in order with value 42.');
}
''');

  final result = await Process.run('dart', ['run', script.path]);
  if (result.exitCode != 0) {
    final card = _dropCard(
      did: 'run the zorphy Store<int> multi-subscriber round-trip',
      expected: 'exit 0 + stdout "PASS: store-mutation"',
      happened: 'exit ${result.exitCode}; stdout="${result.stdout}"; stderr="${result.stderr}"',
      where: 'spawn: `dart run ${script.path}`',
    );
    File(p.join(sandbox.path, 'DROP_CARD.md')).writeAsStringSync(card);
    stderr.writeln(card);
    exit(1);
  }

  final stdoutText = result.stdout.toString();
  if (!stdoutText.contains('PASS: store-mutation')) {
    final card = _dropCard(
      did: 'assert the graded script printed the PASS marker',
      expected: 'stdout contains "PASS: store-mutation"',
      happened: 'stdout was: "$stdoutText"',
      where: 'stdout-check: post-spawn assertion',
    );
    File(p.join(sandbox.path, 'DROP_CARD.md')).writeAsStringSync(card);
    stderr.writeln(card);
    exit(1);
  }

  stdout.writeln('PASS: store-mutation — graded exercise complete.');
  exit(0);
}
