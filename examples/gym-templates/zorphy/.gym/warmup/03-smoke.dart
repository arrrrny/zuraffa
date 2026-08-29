/// GYM warmup rep #3 — authenticated smoke call into the zorphy API.
///
/// "Authenticated" here means: drive the package's public surface
/// end-to-end. For zorphy, that means opening a `Store<T>`,
/// registering a subscriber, and dispatching a mutation — the
/// canonical state-management round-trip.
///
/// Run: `dart run .gym/warmup/03-smoke.dart`
library;

import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main() async {
  // Write a smoke-test script that imports zorphy and drives a Store.
  final smoke = File(p.join('.gym', '.sandbox', 'smoke-zorphy.dart'));
  await smoke.parent.create(recursive: true);
  smoke.writeAsStringSync(r'''
import 'package:zorphy/zorphy.dart';

Future<void> main() async {
  final store = Store<int>(0);
  final values = <int>[];
  store.subscribe((v) => values.add(v));

  await store.dispatch(SetValueAction(42));
  if (store.state != 42) {
    throw StateError('smoke: state should be 42, got ${store.state}');
  }
  if (values.length != 1 || values.first != 42) {
    throw StateError('smoke: subscriber should have seen [42], got $values');
  }
  print('SMOKE PASS: zorphy Store<int> round-trip succeeded.');
}
''');

  final result = await Process.run('dart', ['run', smoke.path]);
  if (result.exitCode != 0) {
    stderr.writeln('REP FAIL: 03-smoke — smoke script exited ${result.exitCode}');
    stderr.writeln(result.stdout);
    stderr.writeln(result.stderr);
    exit(result.exitCode);
  }

  final stdoutText = result.stdout.toString();
  if (!stdoutText.contains('SMOKE PASS')) {
    stderr.writeln(
      'REP FAIL: 03-smoke — smoke script ran but did not print SMOKE PASS. '
      'Mis-fire — drop a card.',
    );
    exit(1);
  }

  stdout.writeln('REP PASS: 03-smoke — zorphy Store round-trip succeeded.');
  exit(0);
}
